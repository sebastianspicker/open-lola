// Renders AppCoreAudioInputMeterTap in the operator UI, keeping presentation and user affordances separate from execution state.
import COpenLolaAtomics
import CoreAudio
import Foundation
import OpenLolaCore
import os

final class AppCoreAudioInputMeterTap: @unchecked Sendable {
    private static let levelChannelCount = 8
    private static let atomicLevelScale = 1_000_000.0
    private var lock = os_unfair_lock_s()
    private let rawLevels: UnsafeMutableBufferPointer<OpenLolaAtomicUInt64>
    private var callbacksActive = OpenLolaAtomicUInt64()
    private var callbacksCanReadFloat32 = OpenLolaAtomicUInt64()
    private var deviceID: AudioObjectID?
    private var ioProcID: AudioDeviceIOProcID?
    private var inputSampleFormat: AppCoreAudioInputMeterSampleFormat?

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

    func start(inputUID: String) throws {
        stop()
        let report = try CoreAudioInventoryReader().capture()
        guard let device = report.devices.first(where: { $0.uid == inputUID && $0.inputChannelCount > 0 }) else {
            throw AppCoreAudioInputMeterError.inputDeviceUnavailable(inputUID)
        }
        let selectedDeviceID = AudioObjectID(device.id)
        let selectedSampleFormat = try Self.inputSampleFormat(for: selectedDeviceID)
        var createdIOProcID: AudioDeviceIOProcID?
        var status = AudioDeviceCreateIOProcID(
            selectedDeviceID,
            appCoreAudioInputMeterIOProc,
            Unmanaged.passUnretained(self).toOpaque(),
            &createdIOProcID
        )
        try throwAudioMeterStatusIfNeeded(status, "create AudioDeviceIOProcID")
        guard let createdIOProcID else {
            throw AppCoreAudioInputMeterError.ioProcUnavailable
        }
        os_unfair_lock_lock(&lock)
        deviceID = selectedDeviceID
        ioProcID = createdIOProcID
        inputSampleFormat = selectedSampleFormat
        os_unfair_lock_unlock(&lock)
        open_lola_atomic_u64_store(&callbacksCanReadFloat32, selectedSampleFormat == .float32 ? 1 : 0)
        open_lola_atomic_u64_store(&callbacksActive, 1)
        status = AudioDeviceStart(selectedDeviceID, createdIOProcID)
        if status != noErr {
            open_lola_atomic_u64_store(&callbacksActive, 0)
            open_lola_atomic_u64_store(&callbacksCanReadFloat32, 0)
            os_unfair_lock_lock(&lock)
            deviceID = nil
            ioProcID = nil
            inputSampleFormat = nil
            os_unfair_lock_unlock(&lock)
            AudioDeviceDestroyIOProcID(selectedDeviceID, createdIOProcID)
        }
        try throwAudioMeterStatusIfNeeded(status, "start AudioDeviceIOProc")
    }

    func stop() {
        open_lola_atomic_u64_store(&callbacksActive, 0)
        open_lola_atomic_u64_store(&callbacksCanReadFloat32, 0)
        os_unfair_lock_lock(&lock)
        let currentDeviceID = deviceID
        let currentIOProcID = ioProcID
        self.deviceID = nil
        self.ioProcID = nil
        inputSampleFormat = nil
        os_unfair_lock_unlock(&lock)
        if let currentDeviceID, let currentIOProcID {
            AudioDeviceStop(currentDeviceID, currentIOProcID)
            AudioDeviceDestroyIOProcID(currentDeviceID, currentIOProcID)
        }
        clearLevels()
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

    fileprivate func update(from input: UnsafePointer<AudioBufferList>) {
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

    private func clearLevels() {
        storeZeroLevels()
    }

    private func storeZeroLevels() {
        for index in 0..<Self.levelChannelCount {
            open_lola_atomic_u64_store(rawLevels.baseAddress!.advanced(by: index), 0)
        }
    }

    private static func inputSampleFormat(for deviceID: AudioObjectID) throws -> AppCoreAudioInputMeterSampleFormat {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreamFormat,
            mScope: kAudioObjectPropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )
        var format = AudioStreamBasicDescription()
        var byteCount = UInt32(MemoryLayout<AudioStreamBasicDescription>.stride)
        try throwAudioMeterStatusIfNeeded(
            AudioObjectGetPropertyData(deviceID, &address, 0, nil, &byteCount, &format),
            "read input stream format"
        )
        guard format.mFormatID == kAudioFormatLinearPCM,
              format.mBitsPerChannel == 32,
              format.mBytesPerFrame >= UInt32(MemoryLayout<Float32>.stride),
              (format.mFormatFlags & kAudioFormatFlagIsFloat) != 0 else {
            throw AppCoreAudioInputMeterError.unsupportedInputFormat(audioMeterFormatDescription(format))
        }
        return .float32
    }
}

enum AppCoreAudioInputMeterError: Error, Equatable {
    case inputDeviceUnavailable(String)
    case ioProcUnavailable
    case unsupportedInputFormat(String)
    case coreAudioStatus(OSStatus, String)
}

private enum AppCoreAudioInputMeterSampleFormat: Equatable {
    case float32
}

private func throwAudioMeterStatusIfNeeded(_ status: OSStatus, _ operation: String) throws {
    if status != noErr {
        throw AppCoreAudioInputMeterError.coreAudioStatus(
            status,
            "\(operation): \(audioMeterStatusDescription(status))"
        )
    }
}

private func audioMeterStatusDescription(_ status: OSStatus) -> String {
    if status == kAudioHardwareUnsupportedOperationError {
        return "unsupported CoreAudio operation"
    }
    return "CoreAudio OSStatus \(status)"
}

private func audioMeterFormatDescription(_ format: AudioStreamBasicDescription) -> String {
    "formatID=\(format.mFormatID), flags=\(format.mFormatFlags), bits=\(format.mBitsPerChannel), "
        + "bytesPerFrame=\(format.mBytesPerFrame)"
}

private let appCoreAudioInputMeterIOProc: AudioDeviceIOProc = { _, _, inInputData, _, _, _, inClientData in
    guard let inClientData else {
        return noErr
    }
    let tap = Unmanaged<AppCoreAudioInputMeterTap>.fromOpaque(inClientData).takeUnretainedValue()
    tap.update(from: inInputData)
    return noErr
}
