// Shared Direct peer two peer run plan arguments helpers keep multi-file test scenarios deterministic.
import Foundation
import Testing

@testable import OpenLolaCore

func directPeerRunPlanReceiveProofArtifact(
    for report: DirectPeerSessionReport
) throws -> DirectPeerSessionReceiveProofArtifact {
    let avRuntime = try #require(report.avRuntime)
    let proof = try #require(avRuntime.receiveProof)
    return DirectPeerSessionReceiveProofArtifact(
        report: report,
        proof: proof,
        runtimeCounters: avRuntime.runtimeMetrics
    )
}

func manualRunConfiguration() -> DirectPeerSessionManualRunConfiguration {
    DirectPeerSessionManualRunConfiguration(identity: .init(role: .initiator, localPeerID: "mac-a", remotePeerID: "mac-b"), network: .init(localHost: "127.0.0.1", remoteHost: "127.0.0.1", ports: .init(controlPort: 57_000, remoteControlPort: 57_010, audioPort: 57_001, videoPort: 57_002, metricsPort: 57_003)), tuning: .init(packetCount: 3, audioChannelCount: 2, timeoutSeconds: 5, dscp: nil))
}

func measuredPassVideoFormat() -> DirectPeerSessionVideoFormatReport {
    DirectPeerSessionVideoFormatReport(
        request: .init(deviceID: "blackmagic-ultrastudio-a", frameRate: 30),
        selection: .init(
            deviceID: "blackmagic-ultrastudio-a", deviceLabel: "Blackmagic UltraStudio lab A",
            width: 1_280, height: 720, selectedPixelFormat: "BGRA", outputPixelFormat: "BGRA",
            frameRate: 30, sourcePolicy: .blackmagicFirstAvFoundationFallback
        )
    )
}

@Test
func measuredPassVideoFormatRoundTripsWithoutChangingWireKeys() throws {
    let format = measuredPassVideoFormat()
    let encoded = try JSONEncoder().encode(format)
    let decoded = try JSONDecoder().decode(DirectPeerSessionVideoFormatReport.self, from: encoded)
    let object = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])

    #expect(decoded == format)
    #expect(object["requestedDeviceID"] as? String == format.requestedDeviceID)
    #expect(object["selectedDeviceID"] as? String == format.selectedDeviceID)
}

func measuredPassReceiveProof() -> DirectPeerSessionVideoReceiveProofArtifact {
    let frame = DirectPeerSessionVideoFrameProof(
        streamID: 100,
        sequenceNumber: 42,
        width: 1_280,
        height: 720,
        pixelFormat: "BGRA",
        payloadByteCount: 1_280 * 720 * 4,
        fingerprint: "avfoundation-42-1280x720-BGRA",
        payloadDigest: "fnv1a64-42"
    )
    return DirectPeerSessionVideoReceiveProofArtifact(
        framesProven: 1,
        previewFramesSubmitted: 1,
        firstFrame: frame,
        latestFrame: frame
    )
}

func twoPeerPlanConfiguration() throws -> DirectPeerTwoPeerRunPlanConfiguration {
    try DirectPeerTwoPeerRunPlanConfiguration.parse(twoPeerPlanArguments())
}

func twoPeerPlanArguments() -> [String] {
    [
        "--output", "/tmp/open-lola-m06/plan.json",
        "--run-dir", "/tmp/open-lola-m06",
        "--mac-a-peer", "mac-a",
        "--mac-a-host", "192.0.2.10",
        "--mac-a-port-base", "57000",
        "--mac-a-input-uid", "rme-a",
        "--mac-a-output-uid", "rme-a",
        "--mac-a-video-device-id", "camera-a",
        "--mac-b-peer", "mac-b",
        "--mac-b-host", "192.0.2.20",
        "--mac-b-port-base", "57010",
        "--mac-b-input-uid", "rme-b",
        "--mac-b-output-uid", "rme-b",
        "--mac-b-video-device-id", "camera-b",
        "--duration-seconds", "30",
        "--channels", "2",
        "--preview", "on"
    ]
}

func twoPeerPlanArguments(replacing replacements: [String: String]) -> [String] {
    var arguments = twoPeerPlanArguments()
    for (argument, value) in replacements {
        guard let index = arguments.firstIndex(of: argument), index + 1 < arguments.count else {
            arguments += [argument, value]
            continue
        }
        arguments[index + 1] = value
    }
    return arguments
}

func directPeerRunPlanArgumentValue(_ name: String, in arguments: [String]) -> String? {
    guard let nameIndex = arguments.firstIndex(of: name) else { return nil }
    let valueIndex = arguments.index(after: nameIndex)
    guard valueIndex < arguments.endIndex else { return nil }
    return arguments[valueIndex]
}

func rxProofPath(for reportPath: String) -> String {
    if reportPath.hasSuffix(".json") {
        return String(reportPath.dropLast(5)) + "-rx-proof.json"
    }
    return reportPath + "-rx-proof.json"
}
