import AppKit
@preconcurrency import AVFoundation
import COpenLolaAtomics
import CoreAudio
import Foundation
import Observation
import OpenLolaCore
import SwiftUI
import os

@MainActor
@Observable
final class AppVideoPreviewController {
    var status = "Video preview idle." {
        didSet { onStatusChange?() }
    }
    var phase: AppPreviewReceiverState.Phase = .idle {
        didSet { onStatusChange?() }
    }

    @ObservationIgnored private let queue = DispatchQueue(label: "de.hfmt.open-lola.app.video-preview")
    @ObservationIgnored private var session: AVCaptureSession?
    @ObservationIgnored weak var previewLayer: AVCaptureVideoPreviewLayer?
    @ObservationIgnored private var previewGeneration = 0
    @ObservationIgnored var onStatusChange: (() -> Void)?

    func attach(_ layer: AVCaptureVideoPreviewLayer) {
        previewLayer = layer
        layer.videoGravity = .resizeAspect
        layer.session = session
    }

    func start(deviceID: String?, enabled: Bool) {
        stop()
        guard enabled else {
            phase = .disabled
            status = "Video preview disabled."
            return
        }
        guard let deviceID, !deviceID.isEmpty else {
            phase = .failed
            status = AppPreviewSetupRecoveryCopy.noVideoDeviceSelected
            return
        }

        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            startAuthorized(deviceID: deviceID)
        case .notDetermined:
            phase = .starting
            status = "Camera permission requested."
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                Task { @MainActor [weak self] in
                    guard let self else {
                        return
                    }
                    granted ? self.startAuthorized(deviceID: deviceID) : self.setDeniedStatus()
                }
            }
        case .denied, .restricted:
            setDeniedStatus()
        @unknown default:
            phase = .failed
            status = AppPreviewSetupRecoveryCopy.cameraPermissionUnknown
        }
    }

    func stop() {
        previewGeneration += 1
        let currentSession = session
        session = nil
        previewLayer?.session = nil
        phase = .idle
        status = "Video preview idle."
        queue.async {
            currentSession?.stopRunning()
        }
    }

    private func startAuthorized(deviceID: String) {
        previewGeneration += 1
        let generation = previewGeneration
        let captureQueue = queue
        phase = .starting
        status = "Video preview starting."
        captureQueue.async { [weak self] in
            guard let device = AVCaptureDevice(uniqueID: deviceID) else {
                Task { @MainActor [weak self] in
                    self?.phase = .failed
                    self?.status = AppPreviewSetupRecoveryCopy.selectedVideoDeviceUnavailable
                }
                return
            }
            do {
                let input = try AVCaptureDeviceInput(device: device)
                let nextSession = AVCaptureSession()
                nextSession.beginConfiguration()
                guard nextSession.canAddInput(input) else {
                    nextSession.commitConfiguration()
                    Task { @MainActor [weak self] in
                        guard let self, self.previewGeneration == generation else {
                            return
                        }
                        self.phase = .failed
                        self.status = "Video preview unavailable: cannot add selected input."
                    }
                    return
                }
                nextSession.addInput(input)
                nextSession.commitConfiguration()
                nextSession.startRunning()
                guard nextSession.isRunning else {
                    Task { @MainActor [weak self] in
                        guard let self, self.previewGeneration == generation else {
                            return
                        }
                        self.phase = .failed
                        self.status = "Video preview unavailable: capture session did not start."
                    }
                    return
                }
                Task { @MainActor [weak self] in
                    guard let self, self.previewGeneration == generation else {
                        captureQueue.async {
                            nextSession.stopRunning()
                        }
                        return
                    }
                    self.session = nextSession
                    self.previewLayer?.session = nextSession
                    self.phase = .active
                    self.status = "Live video preview: \(device.localizedName)"
                }
            } catch {
                Task { @MainActor [weak self] in
                    guard let self, self.previewGeneration == generation else {
                        return
                    }
                    self.phase = .failed
                    self.status = "Video preview unavailable: \(error)"
                }
            }
        }
    }

    private func setDeniedStatus() {
        phase = .failed
        status = AppPreviewSetupRecoveryCopy.cameraDenied
    }
}

struct AppVideoPreviewLayerView: NSViewRepresentable {
    let controller: AppVideoPreviewController

    func makeNSView(context: Context) -> AppVideoPreviewNSView {
        let view = AppVideoPreviewNSView()
        controller.attach(view.previewLayer)
        return view
    }

    func updateNSView(_ nsView: AppVideoPreviewNSView, context: Context) {
        controller.attach(nsView.previewLayer)
    }
}

final class AppVideoPreviewNSView: NSView {
    let previewLayer = AVCaptureVideoPreviewLayer()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer = previewLayer
    }

    required init?(coder: NSCoder) {
        nil
    }
}

@MainActor
@Observable
final class AppAudioLevelMeter {
    var status = "Audio meter idle." {
        didSet { onStatusChange?() }
    }
    var phase: AppPreviewReceiverState.Phase = .idle {
        didSet { onStatusChange?() }
    }
    var levels = Array(repeating: 0.0, count: 8)

    @ObservationIgnored private let tap = AppCoreAudioInputMeterTap()
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var timerTarget: AppAudioLevelMeterTimerTarget?
    @ObservationIgnored var onStatusChange: (() -> Void)?

    func start(inputUID: String?, enabled: Bool, gain: Double) {
        stop()
        guard enabled else {
            phase = .disabled
            status = "Audio meter disabled."
            return
        }
        guard let inputUID, !inputUID.isEmpty else {
            phase = .failed
            status = AppPreviewSetupRecoveryCopy.noAudioInputSelected
            return
        }

        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            startAuthorized(inputUID: inputUID, gain: gain)
        case .notDetermined:
            phase = .starting
            status = "Microphone permission requested."
            AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
                Task { @MainActor [weak self] in
                    guard let self else {
                        return
                    }
                    granted ? self.startAuthorized(inputUID: inputUID, gain: gain) : self.setDeniedStatus()
                }
            }
        case .denied, .restricted:
            setDeniedStatus()
        @unknown default:
            phase = .failed
            status = AppPreviewSetupRecoveryCopy.microphonePermissionUnknown
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        timerTarget = nil
        tap.stop()
        levels = Array(repeating: 0.0, count: levels.count)
        phase = .idle
        status = "Audio meter idle."
    }

    func setGain(_ gain: Double) {
        timerTarget?.gain = gain
        updateLevels(gain: gain)
    }

    private func startAuthorized(inputUID: String, gain: Double) {
        do {
            try tap.start(inputUID: inputUID)
            phase = .active
            status = "Live input meter: \(inputUID)"
            let target = AppAudioLevelMeterTimerTarget(meter: self, gain: gain)
            timerTarget = target
            timer = Timer.scheduledTimer(
                timeInterval: 0.08,
                target: target,
                selector: #selector(AppAudioLevelMeterTimerTarget.updateLevels(_:)),
                userInfo: nil,
                repeats: true
            )
        } catch {
            phase = .failed
            status = "Audio meter unavailable: \(error)"
        }
    }

    private func setDeniedStatus() {
        phase = .failed
        status = AppPreviewSetupRecoveryCopy.microphoneDenied
    }

    fileprivate func updateLevels(gain: Double) {
        levels = tap.snapshot(gain: gain)
    }
}

enum AppPreviewSetupRecoveryCopy {
    static let noVideoDeviceSelected =
        "No video device selected. Open Devices, choose a video device, or refresh inventory."
    static let selectedVideoDeviceUnavailable =
        "Selected video device unavailable. Refresh inventory or choose another video device in Devices."
    static let cameraDenied =
        "Camera permission denied or restricted. Enable Camera for Open LoLa in macOS System Settings > Privacy & Security, then restart preview."
    static let cameraPermissionUnknown =
        "Camera permission state unknown. Check macOS System Settings > Privacy & Security, then restart preview."
    static let noAudioInputSelected =
        "No audio input selected. Open Devices, choose an audio input, or refresh inventory."
    static let microphoneDenied =
        "Microphone permission denied or restricted. Enable Microphone for Open LoLa in macOS System Settings > Privacy & Security, then restart preview."
    static let microphonePermissionUnknown =
        "Microphone permission state unknown. Check macOS System Settings > Privacy & Security, then restart preview."
}

@MainActor
private final class AppAudioLevelMeterTimerTarget: NSObject {
    weak var meter: AppAudioLevelMeter?
    var gain: Double

    init(meter: AppAudioLevelMeter, gain: Double) {
        self.meter = meter
        self.gain = gain
    }

    @objc func updateLevels(_ timer: Timer) {
        guard let meter else {
            timer.invalidate()
            return
        }
        meter.updateLevels(gain: gain)
    }
}

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
        throw AppCoreAudioInputMeterError.coreAudioStatus(status, "\(operation): \(audioMeterStatusDescription(status))")
    }
}

private func audioMeterStatusDescription(_ status: OSStatus) -> String {
    if status == kAudioHardwareUnsupportedOperationError {
        return "unsupported CoreAudio operation"
    }
    return "CoreAudio OSStatus \(status)"
}

private func audioMeterFormatDescription(_ format: AudioStreamBasicDescription) -> String {
    "formatID=\(format.mFormatID), flags=\(format.mFormatFlags), bits=\(format.mBitsPerChannel), bytesPerFrame=\(format.mBytesPerFrame)"
}

private func appCoreAudioInputMeterIOProc(
    _ inDevice: AudioObjectID,
    _ inNow: UnsafePointer<AudioTimeStamp>,
    _ inInputData: UnsafePointer<AudioBufferList>,
    _ inInputTime: UnsafePointer<AudioTimeStamp>,
    _ outOutputData: UnsafeMutablePointer<AudioBufferList>,
    _ inOutputTime: UnsafePointer<AudioTimeStamp>,
    _ inClientData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let inClientData else {
        return noErr
    }
    let tap = Unmanaged<AppCoreAudioInputMeterTap>.fromOpaque(inClientData).takeUnretainedValue()
    tap.update(from: inInputData)
    return noErr
}
