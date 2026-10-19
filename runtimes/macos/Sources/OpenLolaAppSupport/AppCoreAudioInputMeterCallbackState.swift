// Owns the Core Audio meter callback storage so it outlives every HAL IOProc registration that can still call into it.
import COpenLolaAtomics
import CoreAudio
import Foundation

final class AppCoreAudioInputMeterCallbackState: @unchecked Sendable {
    static let levelChannelCount = 8
    private static let atomicLevelScale = 1_000_000.0
    private let rawLevels: UnsafeMutableBufferPointer<OpenLolaAtomicUInt64>
    private var callbacksActive = OpenLolaAtomicUInt64()
    private var callbacksCanReadFloat32 = OpenLolaAtomicUInt64()

    init() {
        rawLevels = UnsafeMutableBufferPointer<OpenLolaAtomicUInt64>.allocate(capacity: Self.levelChannelCount)
        rawLevels.initialize(repeating: OpenLolaAtomicUInt64())
        for index in 0..<Self.levelChannelCount {
            open_lola_atomic_u64_init(rawLevels.baseAddress!.advanced(by: index), 0)
        }
        open_lola_atomic_u64_init(&callbacksActive, 0)
        open_lola_atomic_u64_init(&callbacksCanReadFloat32, 0)
    }

    deinit {
        rawLevels.deinitialize()
        rawLevels.deallocate()
    }

    /// Returns the client-data pointer for one IOProc registration, owning a retain that `releaseRegistration()` balances.
    func retainedRegistration() -> UnsafeMutableRawPointer {
        Unmanaged.passRetained(self).toOpaque()
    }

    /// Balances one `retainedRegistration()` after the HAL has destroyed (or never created) the IOProc.
    func releaseRegistration() {
        Unmanaged.passUnretained(self).release()
    }

    func setActive(_ active: Bool, canReadFloat32: Bool) {
        open_lola_atomic_u64_store(&callbacksCanReadFloat32, active && canReadFloat32 ? 1 : 0)
        open_lola_atomic_u64_store(&callbacksActive, active ? 1 : 0)
    }

    func snapshot(gain: Double) -> [Double] {
        let clampedGain = max(0.0, gain)
        var values = Array(repeating: 0.0, count: Self.levelChannelCount)
        for index in 0..<Self.levelChannelCount {
            let rawValue = open_lola_atomic_u64_load(rawLevels.baseAddress!.advanced(by: index))
            values[index] = min(1.0, (Double(rawValue) / Self.atomicLevelScale) * clampedGain)
        }
        return values
    }

    func clearLevels() {
        storeZeroLevels()
    }

    func update(from input: UnsafePointer<AudioBufferList>) {
        guard open_lola_atomic_u64_load(&callbacksActive) == 1 else {
            return
        }
        guard open_lola_atomic_u64_load(&callbacksCanReadFloat32) == 1 else {
            storeZeroLevels()
            return
        }
        let buffers = UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: input))
        for index in 0..<Self.levelChannelCount {
            let level = index < buffers.count ? level(for: buffers[index]) : 0
            storeLevel(level, at: index)
        }
    }

    private func level(for buffer: AudioBuffer) -> Double {
        guard let data = buffer.mData, buffer.mDataByteSize > 0 else {
            return 0
        }
        guard buffer.mDataByteSize % UInt32(MemoryLayout<Float32>.stride) == 0 else {
            return 0
        }
        let samples = data.assumingMemoryBound(to: Float32.self)
        let count = Int(buffer.mDataByteSize) / MemoryLayout<Float32>.stride
        var peak = 0.0
        for index in 0..<count {
            peak = max(peak, min(1.0, abs(Double(samples[index]))))
        }
        return peak
    }

    private func storeLevel(_ level: Double, at index: Int) {
        let clamped = min(1.0, max(0.0, level))
        let scaled = UInt64((clamped * Self.atomicLevelScale).rounded())
        open_lola_atomic_u64_store(rawLevels.baseAddress!.advanced(by: index), scaled)
    }

    private func storeZeroLevels() {
        for index in 0..<Self.levelChannelCount {
            open_lola_atomic_u64_store(rawLevels.baseAddress!.advanced(by: index), 0)
        }
    }
}

let appCoreAudioInputMeterIOProc: AudioDeviceIOProc = { _, _, inInputData, _, _, _, inClientData in
    guard let inClientData else {
        return noErr
    }
    let state = Unmanaged<AppCoreAudioInputMeterCallbackState>.fromOpaque(inClientData).takeUnretainedValue()
    state.update(from: inInputData)
    return noErr
}
