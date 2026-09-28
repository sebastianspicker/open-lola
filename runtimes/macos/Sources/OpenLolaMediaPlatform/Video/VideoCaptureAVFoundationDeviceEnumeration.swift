// Enumerates AVFoundation capture devices and resolves camera permission so capture and Integrations connectors share one source of truth.
import Foundation
import Dispatch
#if canImport(AVFoundation)
@preconcurrency import AVFoundation
import CoreMedia
#endif

#if canImport(AVFoundation)
public func currentAVCaptureVideoDevices() -> [AVCaptureDevice] {
    AVCaptureDevice.DiscoverySession(
        deviceTypes: [
            .external,
            .builtInWideAngleCamera,
            .continuityCamera,
            .deskViewCamera
        ],
        mediaType: .video,
        position: .unspecified
    ).devices
}
#endif

public func resolveAVFoundationVideoPermission() -> AVFoundationPermissionStatus {
    #if canImport(AVFoundation)
    let current = AVCaptureDevice.authorizationStatus(for: .video)
    guard current == .notDetermined else {
        return AVFoundationPermissionStatus(authorizationStatus: current)
    }

    let semaphore = DispatchSemaphore(value: 0)
    AVCaptureDevice.requestAccess(for: .video) { _ in
        semaphore.signal()
    }
    guard semaphore.wait(timeout: .now() + 5.0) == .success else {
        return .requestTimedOut
    }
    return AVFoundationPermissionStatus(
        authorizationStatus: AVCaptureDevice.authorizationStatus(for: .video)
    )
    #else
    return .unknown
    #endif
}

#if canImport(AVFoundation)
public extension AVFoundationPermissionStatus {
    init(authorizationStatus: AVAuthorizationStatus) {
        switch authorizationStatus {
        case .authorized:
            self = .authorized
        case .denied:
            self = .denied
        case .restricted:
            self = .restricted
        case .notDetermined:
            self = .notDetermined
        @unknown default:
            self = .unknown
        }
    }
}

public func avFoundationFormatDescription(
    _ format: AVCaptureDevice.Format
) -> AVFoundationVideoFormatDescription {
    let dimensions = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
    let frameRate = format.videoSupportedFrameRateRanges.map(\.maxFrameRate).max() ?? 0
    return AVFoundationVideoFormatDescription(
        width: Int(dimensions.width),
        height: Int(dimensions.height),
        maxFrameRate: frameRate,
        pixelFormat: videoCaptureFourCCString(
            CMFormatDescriptionGetMediaSubType(format.formatDescription)
        )
    )
}

public func avFoundationDeviceDescription(
    for device: AVCaptureDevice
) -> AVFoundationVideoDeviceDescription {
    AVFoundationVideoDeviceDescription.make(
        label: device.localizedName,
        uniqueId: device.uniqueID,
        modelId: device.modelID,
        manufacturer: device.manufacturer,
        transport: "AVFoundation",
        formats: device.formats.map(avFoundationFormatDescription)
    )
}

public func selectedAVFoundationDevice(
    from devices: [AVCaptureDevice],
    requestedUniqueId: String?
) throws -> AVCaptureDevice? {
    if let requestedUniqueId {
        return devices.first(where: { $0.uniqueID == requestedUniqueId })
    }
    let descriptions = devices.map(avFoundationDeviceDescription)
    guard let preferred = preferredAVFoundationVideoDevice(from: descriptions) else {
        return nil
    }
    return devices.first(where: { $0.uniqueID == preferred.uniqueId })
}
#endif
