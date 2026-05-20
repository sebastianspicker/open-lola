import Testing

@testable import OpenLolaCore

@Test
func productionAVPreflightAcceptsSplitInputOutputUIDsFromInventory() throws {
    let inventory = CoreAudioInventoryReport(
        capturedAt: "2026-05-09T00:00:00Z",
        hostName: "mac-av-lab",
        devices: [
            productionAVDevice(id: 10, uid: "capture-uid", inputChannels: 2, outputChannels: 0),
            productionAVDevice(id: 11, uid: "playback-uid", inputChannels: 0, outputChannels: 2),
        ]
    )
    let configuration = DirectPeerRealtimeAudioGraphConfiguration(
        audioDeviceUID: "capture-uid",
        inputDeviceUID: "capture-uid",
        outputDeviceUID: "playback-uid",
        sampleRateHertz: 48_000,
        framesPerBuffer: 32,
        channelCount: 2,
        sampleFormat: .float32LittleEndian,
        inputChannelMap: [0, 1],
        outputChannelMap: [0, 1]
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
        "additional production AV preflight blockers omitted: 16",
    ])
}

private func productionAVPassCandidate() throws -> DirectPeerSessionReport {
    var report = try DirectPeerSessionSocketRunner.runLoopback(packetCount: 2)
    directPeerSessionUsePhysicalEndpointHosts(&report)
    let videoFormat = DirectPeerSessionVideoFormatReport(
        requestedDeviceID: "camera-uid",
        selectedDeviceID: "camera-uid",
        selectedDeviceLabel: "Production camera",
        requestedFrameRate: 30,
        selectedWidth: 1_280,
        selectedHeight: 720,
        selectedPixelFormat: "BGRA",
        outputPixelFormat: "bgra8",
        selectedFrameRate: 30,
        sourcePolicy: .blackmagicFirstAvFoundationFallback
    )
    let receiveProof = DirectPeerSessionVideoReceiveProofArtifact(
        framesProven: 2,
        previewFramesSubmitted: 0,
        firstFrame: productionAVFrame(sequenceNumber: 1),
        latestFrame: productionAVFrame(sequenceNumber: 2)
    )
    report.metrics.videoPacketsRouted = 2
    report.avRuntime = DirectPeerSessionAVRuntimeMetadata(
        avProfile: .fastest,
        previewMode: .off,
        mediaSourceMode: .production,
        audioDeviceUID: "capture-uid",
        inputDeviceUID: "capture-uid",
        outputDeviceUID: "playback-uid",
        sampleRateHertz: 48_000,
        selectedBufferFrameSize: 32,
        latencyProfile: .directAudioFirst,
        rxBufferProfile: .direct,
        videoDeviceID: "camera-uid",
        videoFrameRate: 30,
        videoStreamID: 100,
        fastestPassBlockedReason: "physical fastest AV proof attached for validation fixture",
        runtimeMetrics: DirectPeerSessionAVRuntimeMetrics(
            audioPayloadsCaptured: 2,
            audioPayloadsSent: 2,
            audioPayloadsQueuedForPlayout: 2,
            videoFramesCaptured: 2,
            videoFramesSent: 2,
            videoFragmentsSent: 4,
            videoFragmentsReceived: 4,
            videoFramesReassembled: 2,
            audioReceiveDrainIterations: 2,
            videoReceiveDrainIterations: 2
        ),
        videoFormat: videoFormat,
        receiveProof: receiveProof,
        fastestAVBaselineComparison: directPeerSessionFastestAVBaselineComparison()
    )
    report.measuredEvidence = DirectPeerSessionMeasuredEvidence(
        kind: .physicalTwoPeerMacs,
        sourcePeerLabel: "mac-a",
        receiverPeerLabel: "mac-b",
        routeLabel: "direct-thunderbolt-bridge",
        packetCapturePath: "reports/captures/production-av.pcapng",
        packetCapture: directPeerSessionPacketCaptureArtifact("reports/captures/production-av.pcapng"),
        dscpObservation: "EF preserved on receiver ingress",
        dscp: directPeerSessionDSCPEvidence(),
        clockSyncSummary: "PTP offset below one millisecond",
        clock: directPeerSessionClockEvidence(),
        rawVideoReceiveEvidence: "receiver report recorded two BGRA frames from camera-uid",
        durationSeconds: 30
    )
    report.verdict = .pass
    return report
}

private func productionAVRunConfiguration() -> DirectPeerSessionAVRunConfiguration {
    DirectPeerSessionAVRunConfiguration(
        manual: DirectPeerSessionManualRunConfiguration(
            role: .initiator,
            localPeerID: "mac-a",
            remotePeerID: "mac-b",
            localHost: "127.0.0.1",
            remoteHost: "127.0.0.1",
            controlPort: 57_000,
            remoteControlPort: 57_010,
            audioPort: 57_001,
            videoPort: 57_002,
            metricsPort: 57_003,
            packetCount: 1,
            audioChannelCount: 2,
            timeoutSeconds: 1
        ),
        durationSeconds: 1,
        audioDeviceUID: "capture-uid",
        inputDeviceUID: "capture-uid",
        outputDeviceUID: "playback-uid",
        framesPerPacket: 32,
        videoDeviceID: "camera-uid",
        videoWidth: 1_280,
        videoHeight: 720,
        videoPixelFormat: "bgra8",
        videoFrameRate: 30,
        avProfile: .fastest,
        preview: .off,
        mediaSourceMode: .production
    )
}

private func productionAVAudioInventory() -> CoreAudioInventoryReport {
    CoreAudioInventoryReport(
        capturedAt: "2026-05-09T00:00:00Z",
        hostName: "mac-av-lab",
        devices: [
            productionAVDevice(id: 10, uid: "capture-uid", inputChannels: 2, outputChannels: 0),
            productionAVDevice(id: 11, uid: "playback-uid", inputChannels: 0, outputChannels: 2),
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
                    ),
                ]
            ),
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
    CoreAudioDeviceInventory(
        id: id,
        name: uid,
        uid: uid,
        manufacturer: "Test",
        transportType: nil,
        isAggregate: false,
        inputChannelCount: inputChannels,
        outputChannelCount: outputChannels,
        inputStreamCount: inputChannels > 0 ? 1 : 0,
        outputStreamCount: outputChannels > 0 ? 1 : 0,
        nominalSampleRateHertz: 48_000,
        availableSampleRateRanges: [AudioValueRangeSnapshot(minimum: 48_000, maximum: 48_000)],
        currentBufferFrameSize: 32,
        bufferFrameSizeRange: AudioValueRangeSnapshot(minimum: 32, maximum: 128),
        candidateBufferFrames: BufferFrameCandidates(
            candidates: [32, 64, 128],
            reportedRange: AudioValueRangeSnapshot(minimum: 32, maximum: 128)
        ),
        inputLatencyFrames: nil,
        outputLatencyFrames: nil,
        inputSafetyOffsetFrames: nil,
        outputSafetyOffsetFrames: nil,
        clockDomain: nil,
        diagnosticNotes: []
    )
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
