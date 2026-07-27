// Verifies that production AV preflight accepts split input and output UI IDs from inventory.
import Testing

@testable import OpenLolaCore

@Test
func productionAVPreflightAcceptsSplitInputOutputUIDsFromInventory() throws {
    let inventory = productionAVAudioInventory()
    let configuration = standardDirectPeerAudioGraphConfiguration(
        inputDeviceUID: "capture-uid",
        outputDeviceUID: "playback-uid"
    )

    let preflight = try DirectPeerRealtimeAudioGraph.preflight(
        configuration: configuration,
        inventory: inventory
    )

    #expect(preflight.canStart)
    #expect(preflight.device?.uid == "capture-uid")
    #expect(preflight.outputDevice?.uid == "playback-uid")
    #expect(preflight.fullDuplexSupported)
    #expect(preflight.blockers.isEmpty)
}

@Test
func productionAVPassValidationPreservesSplitInputOutputUIDs() throws {
    let report = try productionAVPassCandidate()

    try report.validate()

    let avRuntime = try #require(report.avRuntime)
    #expect(avRuntime.mediaSourceMode == .production)
    #expect(avRuntime.audioDeviceUID == "capture-uid")
    #expect(avRuntime.inputDeviceUID == "capture-uid")
    #expect(avRuntime.outputDeviceUID == "playback-uid")
    #expect(report.measuredEvidence?.kind == .physicalTwoPeerMacs)
}

@Test
func productionAVPreflightUsesInjectedAudioAndVideoInventories() throws {
    let report = try DirectPeerSessionProductionAVPreflight.evaluate(
        configuration: productionAVRunConfiguration(),
        audioInventory: productionAVAudioInventory(),
        videoInventory: productionAVVideoInventory(permissionStatus: .authorized)
    )

    #expect(report.mediaSourceMode == .production)
    #expect(report.audioCanStart)
    #expect(report.inputDeviceUID == "capture-uid")
    #expect(report.outputDeviceUID == "playback-uid")
    #expect(report.videoDeviceAvailable)
    #expect(report.videoFormatAvailable)
    #expect(report.verdict == .partial)
    #expect(report.blockers == ["physical two-peer production AV run evidence is still required"])
}

@Test
func productionAVPreflightReportsAbsentHardwareAsPartialBlockers() throws {
    let report = try DirectPeerSessionProductionAVPreflight.evaluate(
        configuration: productionAVRunConfiguration(),
        audioInventory: CoreAudioInventoryReport(
            capturedAt: "2026-05-09T00:00:00Z",
            hostName: "mac-av-lab",
            devices: []
        ),
        videoInventory: productionAVVideoInventory(permissionStatus: .denied, devices: [])
    )

    #expect(!report.audioCanStart)
    #expect(!report.videoDeviceAvailable)
    #expect(!report.videoFormatAvailable)
    #expect(report.verdict == .partial)
    #expect(report.blockers.contains("input audio device UID not found"))
    #expect(report.blockers.contains("output audio device UID not found"))
    #expect(report.blockers.contains("AVFoundation video permission is denied"))
    #expect(report.blockers.contains("requested production video device is not available"))
    #expect(report.blockers.contains("physical two-peer production AV run evidence is still required"))
}

@Test
func productionAVPreflightBlockersAreDeduplicatedAndBounded() {
    let blockers = (0..<20).map { "blocker-\($0)" } + ["blocker-0", "blocker-1"]

    let normalized = directPeerProductionAVPreflightBlockers(blockers, limit: 4)

    #expect(normalized == [
        "blocker-0",
        "blocker-1",
        "blocker-2",
        "blocker-3",
        "additional production AV preflight blockers omitted: 16"
    ])
}

private func productionAVPassCandidate() throws -> DirectPeerSessionReport {
    var report = try DirectPeerSessionSocketRunner.runLoopback(packetCount: 2)
    directPeerSessionUsePhysicalEndpointHosts(&report)
    let videoFormat = DirectPeerSessionVideoFormatReport(
        request: .init(deviceID: "camera-uid", frameRate: 30),
        selection: .init(
            deviceID: "camera-uid", deviceLabel: "Production camera", width: 1_280, height: 720,
            selectedPixelFormat: "BGRA", outputPixelFormat: "bgra8", frameRate: 30,
            sourcePolicy: .blackmagicFirstAvFoundationFallback
        )
    )
    let receiveProof = DirectPeerSessionVideoReceiveProofArtifact(
        framesProven: 2,
        previewFramesSubmitted: 0,
        firstFrame: productionAVFrame(sequenceNumber: 1),
        latestFrame: productionAVFrame(sequenceNumber: 2)
    )
    report.metrics.videoPacketsRouted = 2
    report.avRuntime = productionAVRuntimeMetadata(
        videoFormat: videoFormat,
        receiveProof: receiveProof
    )
    report.measuredEvidence = productionAVMeasuredEvidence()
    report.verdict = .pass
    return report
}

private func productionAVRuntimeMetadata(
    videoFormat: DirectPeerSessionVideoFormatReport,
    receiveProof: DirectPeerSessionVideoReceiveProofArtifact
) -> DirectPeerSessionAVRuntimeMetadata {
    DirectPeerSessionAVRuntimeMetadata(
        session: .init(
            avProfile: .fastest,
            previewMode: .off,
            mediaSourceMode: .production,
            qualityPolicy: .requireUsefulMedia,
            usefulMediaProof: .requiredAndProven
        ),
 audio: directPeerSessionAudioFixture(
    deviceUID: "capture-uid",
    inputDeviceUID: "capture-uid",
    outputDeviceUID: "playback-uid",
    latencyProfile: .directAudioFirst,
    rxBufferProfile: .direct
 ),
 transport: directPeerSessionRawTransportFixture(),
 video: directPeerSessionRawVideoFixture(deviceID: "camera-uid"),
        evidence: .init(
            fastestPassBlockedReason: "physical fastest AV proof attached for validation fixture",
            runtimeMetrics: directPeerMeasuredAVRuntimeMetrics(
                mediaUnitCount: 2,
                fragmentCount: 4,
                includePreview: false
            ),
            videoFormat: videoFormat,
            receiveProof: receiveProof,
            fastestAVBaselineComparison: directPeerSessionFastestAVBaselineComparison()
        )
    )
}

private func productionAVMeasuredEvidence() -> DirectPeerSessionMeasuredEvidence {
    directPeerSessionMeasuredEvidence(
        sourcePeerLabel: "mac-a",
        receiverPeerLabel: "mac-b",
        routeLabel: "direct-thunderbolt-bridge",
        packetCapturePath: "reports/captures/production-av.pcapng",
        dscpObservation: "EF preserved on receiver ingress",
        rawVideoReceiveEvidence: "receiver report recorded two BGRA frames from camera-uid"
    )
}

private func productionAVRunConfiguration() -> DirectPeerSessionAVRunConfiguration {
    var fixture = DirectPeerSyntheticAVFixture(manual: productionAVManualConfiguration())
    fixture.audioDeviceUID = "capture-uid"
    fixture.inputDeviceUID = "capture-uid"
    fixture.outputDeviceUID = "playback-uid"
    fixture.videoDeviceID = "camera-uid"
    fixture.videoWidth = 1_280
    fixture.videoHeight = 720
    fixture.avProfile = .fastest
    fixture.rxBufferProfile = nil
    fixture.mediaSourceMode = .production
    return fixture.configuration()
}

private func productionAVManualConfiguration() -> DirectPeerSessionManualRunConfiguration {
    var fixture = DirectPeerManualTestFixture()
    fixture.localPeerID = "mac-a"
    fixture.remotePeerID = "mac-b"
    return fixture.configuration()
}

private func productionAVAudioInventory() -> CoreAudioInventoryReport {
    CoreAudioInventoryReport(
        capturedAt: "2026-05-09T00:00:00Z",
        hostName: "mac-av-lab",
        devices: [
            productionAVDevice(id: 10, uid: "capture-uid", inputChannels: 2, outputChannels: 0),
            productionAVDevice(id: 11, uid: "playback-uid", inputChannels: 0, outputChannels: 2)
        ]
    )
}

private func productionAVVideoInventory(
    permissionStatus: AVFoundationPermissionStatus,
    devices: [AVFoundationVideoDeviceDescription]? = nil
) -> AVFoundationVideoDeviceInventoryReport {
    AVFoundationVideoDeviceInventoryReport(
        id: "m08-production-av-inventory-test",
        title: "Production AV inventory test",
        capturedAt: "2026-05-09T00:00:00Z",
        permissionStatus: permissionStatus,
        devices: devices ?? [
            AVFoundationVideoDeviceDescription.make(
                label: "Blackmagic Production Camera",
                uniqueId: "camera-uid",
                modelId: "blackmagic-test",
                manufacturer: "Blackmagic Design",
                transport: "AVFoundation",
                formats: [
                    AVFoundationVideoFormatDescription(
                        width: 1_280,
                        height: 720,
                        maxFrameRate: 30,
                        pixelFormat: "BGRA"
                    )
                ]
            )
        ],
        blackmagicSdkStatus: .notLinkedOptionalBoundary,
        verdict: .partial,
        notes: "Injected production AV source-level inventory for deterministic CI preflight."
    )
}

private func productionAVDevice(
    id: UInt32,
    uid: String,
    inputChannels: Int,
    outputChannels: Int
) -> CoreAudioDeviceInventory {
    var fixture = SyntheticFullDuplexDeviceFixture(id: id, name: uid, uid: uid)
    fixture.manufacturer = "Test"
    fixture.inputChannelCount = inputChannels
    fixture.outputChannelCount = outputChannels
    fixture.candidateBufferFrames = syntheticFullDuplexBufferCandidates()
    return syntheticFullDuplexDevice(fixture)
}

private func productionAVFrame(sequenceNumber: UInt64) -> DirectPeerSessionVideoFrameProof {
    DirectPeerSessionVideoFrameProof(
        streamID: 100,
        sequenceNumber: sequenceNumber,
        width: 1_280,
        height: 720,
        pixelFormat: "BGRA",
        payloadByteCount: 1_280 * 720 * 4,
        fingerprint: "production-av-\(sequenceNumber)",
        payloadDigest: "fnv1a64-\(sequenceNumber)"
    )
}
