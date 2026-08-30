// Supplies receiver-preview lifecycle services, keeping camera and audio setup outside SwiftUI state ownership.
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
                    if granted {
                        self.startAuthorized(deviceID: deviceID)
                    } else {
                        self.setDeniedStatus()
                    }
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
        phase = .starting
        status = "Video preview starting."
        queue.async { [weak self] in
            do {
                let preview = try makeStartedVideoPreview(deviceID: deviceID)
                Task { @MainActor [weak self] in
                    self?.finishStartedPreview(preview, generation: generation)
                }
            } catch {
                Task { @MainActor [weak self] in
                    self?.failPreviewStart(error, generation: generation)
                }
            }
        }
    }

    private func finishStartedPreview(_ preview: AppStartedVideoPreview, generation: Int) {
        guard previewGeneration == generation else {
            queue.async {
                preview.session.stopRunning()
            }
            return
        }
        session = preview.session
        previewLayer?.session = preview.session
        phase = .active
        status = "Live video preview: \(preview.deviceName)"
    }

    private func failPreviewStart(_ error: Error, generation: Int) {
        guard previewGeneration == generation else {
            return
        }
        phase = .failed
        switch error {
        case AppVideoPreviewStartError.missingDevice:
            status = AppPreviewSetupRecoveryCopy.selectedVideoDeviceUnavailable
        case AppVideoPreviewStartError.cannotAddSelectedInput:
            status = "Video preview unavailable: cannot add selected input."
        case AppVideoPreviewStartError.sessionDidNotStart:
            status = "Video preview unavailable: capture session did not start."
        default:
            status = "Video preview unavailable: \(error)"
        }
    }

    private func setDeniedStatus() {
        phase = .failed
        status = AppPreviewSetupRecoveryCopy.cameraDenied
    }
}

private struct AppStartedVideoPreview {
    let deviceName: String
    let session: AVCaptureSession
}

private enum AppVideoPreviewStartError: Error {
    case missingDevice
    case cannotAddSelectedInput
    case sessionDidNotStart
}

private func makeStartedVideoPreview(deviceID: String) throws -> AppStartedVideoPreview {
    guard let device = AVCaptureDevice(uniqueID: deviceID) else {
        throw AppVideoPreviewStartError.missingDevice
    }
    let input = try AVCaptureDeviceInput(device: device)
    let session = AVCaptureSession()
    try configureVideoPreviewSession(session, input: input)
    session.startRunning()
    guard session.isRunning else {
        throw AppVideoPreviewStartError.sessionDidNotStart
    }
    return AppStartedVideoPreview(deviceName: device.localizedName, session: session)
}

private func configureVideoPreviewSession(
    _ session: AVCaptureSession,
    input: AVCaptureDeviceInput
) throws {
    session.beginConfiguration()
    defer { session.commitConfiguration() }
    guard session.canAddInput(input) else {
        throw AppVideoPreviewStartError.cannotAddSelectedInput
    }
    session.addInput(input)
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
                    if granted {
                        self.startAuthorized(inputUID: inputUID, gain: gain)
                    } else {
                        self.setDeniedStatus()
                    }
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
        "Camera permission denied or restricted. Enable Camera for Open LoLa in macOS System Settings "
            + "> Privacy & Security, then restart preview."
    static let cameraPermissionUnknown =
        "Camera permission state unknown. Check macOS System Settings > Privacy & Security, then restart preview."
    static let noAudioInputSelected =
        "No audio input selected. Open Devices, choose an audio input, or refresh inventory."
    static let microphoneDenied =
        "Microphone permission denied or restricted. Enable Microphone for Open LoLa in macOS System Settings "
            + "> Privacy & Security, then restart preview."
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
