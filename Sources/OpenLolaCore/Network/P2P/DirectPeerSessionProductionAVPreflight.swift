// Coordinates direct-peer session execution and its result lifecycle, keeping runtime side effects separate from protocol values and validation policy.
import Foundation

// swiftlint:disable:next type_name
/// Captures DirectPeerSessionProductionAVPreflightReport evidence in a stable form for validation and serialized reporting.
public struct DirectPeerSessionProductionAVPreflightReport: Codable, Equatable, Sendable {
    public var mediaSourceMode: DirectPeerSessionAVMediaSourceMode
    public var audioCanStart: Bool
    public var inputDeviceUID: String
    public var outputDeviceUID: String
    public var videoDeviceID: String
    public var videoPermissionStatus: AVFoundationPermissionStatus
    public var videoDeviceAvailable: Bool
    public var videoFormatAvailable: Bool
    public var blockers: [String]
    public var verdict: MeasurementVerdict
    public var notes: String
}

/// Evaluates Core Audio and AVFoundation inventories for production A/V readiness while preserving the physical-run evidence gate.
public enum DirectPeerSessionProductionAVPreflight {
    public static func evaluate(
        configuration: DirectPeerSessionAVRunConfiguration,
        audioInventory: CoreAudioInventoryReport,
        videoInventory: AVFoundationVideoDeviceInventoryReport
    ) throws -> DirectPeerSessionProductionAVPreflightReport {
        let graphConfiguration = try audioGraphConfiguration(for: configuration)
        let audioPreflight = DirectPeerRealtimeAudioGraphPreflight.evaluate(
            configuration: graphConfiguration,
            inventory: audioInventory
        )
        let videoDevice = selectedPreflightVideoDevice(
            id: configuration.videoDeviceID,
            devices: videoInventory.devices
        )
        let videoFormatAvailable = videoDevice.map {
            preflightVideoFormatMatches(configuration: configuration, device: $0)
        } ?? false
        var blockers = audioPreflight.blockers
        if configuration.mediaSourceMode != .production {
            blockers.append("configuration is not production media source mode")
        }
        if videoInventory.permissionStatus != .authorized {
            blockers.append("AVFoundation video permission is \(videoInventory.permissionStatus.rawValue)")
        }
        if videoDevice == nil {
            blockers.append("requested production video device is not available")
        } else if !videoFormatAvailable {
            blockers.append("requested production video format is not available")
        }
        blockers.append("physical two-peer production AV run evidence is still required")
        blockers = directPeerProductionAVPreflightBlockers(blockers)
        return DirectPeerSessionProductionAVPreflightReport(
            mediaSourceMode: configuration.mediaSourceMode,
            audioCanStart: audioPreflight.canStart,
            inputDeviceUID: configuration.inputDeviceUID,
            outputDeviceUID: configuration.outputDeviceUID,
            videoDeviceID: configuration.videoDeviceID,
            videoPermissionStatus: videoInventory.permissionStatus,
            videoDeviceAvailable: videoDevice != nil,
            videoFormatAvailable: videoFormatAvailable,
            blockers: blockers,
            verdict: .partial,
            notes: "Source-level production AV preflight uses injected Core Audio and AVFoundation inventories. "
                + "Hardware PASS still requires measured two-peer runtime evidence."
        )
    }
}

func directPeerProductionAVPreflightBlockers(_ blockers: [String], limit: Int = 16) -> [String] {
    var seen: Set<String> = []
    var deduplicated: [String] = []
    deduplicated.reserveCapacity(min(blockers.count, limit))
    for blocker in blockers where seen.insert(blocker).inserted {
        if deduplicated.count < limit {
            deduplicated.append(blocker)
        }
    }
    let omittedCount = max(0, seen.count - deduplicated.count)
    if omittedCount > 0 {
        deduplicated.append("additional production AV preflight blockers omitted: \(omittedCount)")
    }
    return deduplicated
}

private func selectedPreflightVideoDevice(
    id: String,
    devices: [AVFoundationVideoDeviceDescription]
) -> AVFoundationVideoDeviceDescription? {
    if id == "auto" {
        return preferredAVFoundationVideoDevice(from: devices)
    }
    return devices.first { $0.uniqueId == id }
}

private func preflightVideoFormatMatches(
    configuration: DirectPeerSessionAVRunConfiguration,
    device: AVFoundationVideoDeviceDescription
) -> Bool {
    let requestedPixelFormat = directPeerNormalizedVideoPixelFormat(configuration.videoPixelFormat)
    return device.formats.contains { format in
        format.width == configuration.videoWidth
            && format.height == configuration.videoHeight
            && directPeerNormalizedVideoPixelFormat(format.pixelFormat) == requestedPixelFormat
            && format.maxFrameRate >= Double(configuration.videoFrameRate)
    }
}
