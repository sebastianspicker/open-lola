// Verifies that direct peer real-time audio preflight blocks unsupported fastest frame size.
import Testing

@testable import OpenLolaCore

@Test
func directPeerRealtimeAudioPreflightBlocksUnsupportedFastestFrameSize() throws {
    let inventory = CoreAudioInventoryReport(
        capturedAt: "2026-05-08T00:00:00Z",
        hostName: "test-host",
        devices: [
            fastestFrameSizeFixtureDevice()
        ]
    )
    let configuration = DirectPeerRealtimeAudioGraphConfiguration(
            devices: .init(audioDeviceUID: "full-duplex", inputDeviceUID: nil, outputDeviceUID: nil),
            format: .init(sampleRateHertz: 48_000, framesPerBuffer: 16, channelCount: 2, sampleFormat: .float32LittleEndian),
            channelMaps: .init(input: [0, 1], output: [0, 1]),
            buffering: .init(ringCapacityBlocks: 8, rxBufferPolicy: nil)
        )

    #expect(throws: DirectPeerAudioGraphError.unsupportedFrameSize(
        uid: "full-duplex",
        framesPerBuffer: 16
    )) {
        _ = try DirectPeerRealtimeAudioGraph.preflight(configuration: configuration, inventory: inventory)
    }
}

private func fastestFrameSizeFixtureDevice() -> CoreAudioDeviceInventory {
    var fixture = SyntheticFullDuplexDeviceFixture(id: 1, name: "Full Duplex", uid: "full-duplex")
    fixture.candidateBufferFrames = syntheticFullDuplexBufferCandidates()
    return syntheticFullDuplexDevice(fixture)
}

@Test
func directPeerSessionManualAudioVideoFastestModeIsAudioFirstAndReportDistinct() async throws {
    try await SocketHeavyTestGate.shared.run {
        let ports = try freeLocalUdpPorts(count: 8)
        let (initiatorManual, responderManual) = avFastestManualConfigurations(ports: ports)
        let initiator = avFastestConfiguration(manual: initiatorManual, uid: "synthetic-a")
        let responder = avFastestConfiguration(manual: responderManual, uid: "synthetic-b")

        let responderReady = AsyncReadinessGate()
        async let responderReport = DirectPeerSessionSocketRunner.runManualAddressAudioVideo(
            configuration: responder,
            onReady: { Task { await responderReady.signal() } }
        )
        #expect(await responderReady.wait(timeout: .seconds(5)))
        let initiatorReport = try DirectPeerSessionSocketRunner.runManualAddressAudioVideo(
            configuration: initiator
        )
        let acceptedResponderReport = try await responderReport

        for (report, expectedUID) in [
            (initiatorReport, "synthetic-a"),
            (acceptedResponderReport, "synthetic-b")
        ] {
            try expectFastestManualAVReport(report, expectedUID: expectedUID)
        }
    }
}

private func avFastestManualConfigurations(
    ports: [UInt16]
) -> (DirectPeerSessionManualRunConfiguration, DirectPeerSessionManualRunConfiguration) {
    pairedDirectPeerManualConfigurations(ports: ports, packetCount: 1)
}

private func avFastestConfiguration(
    manual: DirectPeerSessionManualRunConfiguration,
    uid: String
) -> DirectPeerSessionAVRunConfiguration {
    var fixture = DirectPeerSyntheticAVFixture(manual: manual)
    fixture.audioDeviceUID = uid
    fixture.inputDeviceUID = uid
    fixture.outputDeviceUID = uid
    fixture.avProfile = .fastest
    fixture.rxBufferProfile = nil
    return fixture.configuration()
}

private func expectFastestManualAVReport(
    _ report: DirectPeerSessionReport,
    expectedUID: String
) throws {
    try report.validate()
    #expect(report.id.contains("fastest"))
    #expect(report.configuration.latencyProfile == .directAudioFirst)
    #expect(report.configuration.rxBufferProfile == .direct)
    #expect(report.avRuntime?.avProfile == .fastest)
    #expect(report.avRuntime?.previewMode == .off)
    #expect(report.avRuntime?.selectedBufferFrameSize == 32)
    #expect(report.avRuntime?.latencyProfile == .directAudioFirst)
    #expect(report.avRuntime?.rxBufferProfile == .direct)
    #expect(report.avRuntime?.fastestPassBlockedReason.contains("audio-only baseline") == true)
    try expectFastestAVNegotiatedVideoStream(in: report)
    try expectFastestAVRuntimeDeviceUIDs(
        in: report,
        inputDeviceUID: expectedUID,
        outputDeviceUID: expectedUID
    )
    try expectFastestSyntheticAVRouteCounters(in: report)
    try expectFastestVideoReportArtifacts(in: report)
    #expect(report.notes.contains("fastest AV"))
    #expect(report.metrics.audioPacketsRouted > 0)
    #expect(report.metrics.videoPacketsRouted > 0)
    #expect(report.verdict == .partial)
}

private func expectFastestAVNegotiatedVideoStream(in report: DirectPeerSessionReport) throws {
    let stream = try #require(report.configuration.videoStreams.first)

    #expect(stream.id == 100)
    #expect(stream.resolution == VideoResolution(width: 16, height: 16))
    #expect(stream.frameRate == VideoFrameRate(numerator: 30, denominator: 1))
    #expect(stream.pixelFormat == .bgra8)
}

private func expectFastestAVRuntimeDeviceUIDs(
    in report: DirectPeerSessionReport,
    inputDeviceUID: String,
    outputDeviceUID: String
) throws {
    let avRuntime = try #require(report.avRuntime)

    #expect(avRuntime.inputDeviceUID == inputDeviceUID)
    #expect(avRuntime.outputDeviceUID == outputDeviceUID)
}

private func expectFastestSyntheticAVRouteCounters(in report: DirectPeerSessionReport) throws {
    let metrics = try #require(report.avRuntime?.runtimeMetrics)

    #expect(metrics.videoFramesCaptured >= 0)
    #expect(metrics.videoFramesSent >= 0)
    #expect(metrics.videoFragmentsReceived >= 0)
    #expect(metrics.videoFramesReassembled >= 0)
    #expect(metrics.previewFramesSubmitted >= 0)
    #expect(metrics.videoFramesCaptured > 0)
    #expect(metrics.videoFramesSent > 0)
    #expect(metrics.videoFragmentsReceived > 0)
    #expect(metrics.videoFramesReassembled > 0)
    #expect(metrics.previewFramesSubmitted == 0)
}

private func expectFastestVideoReportArtifacts(in report: DirectPeerSessionReport) throws {
    let avRuntime = try #require(report.avRuntime)
    let videoFormat = try #require(avRuntime.videoFormat)
    let receiveProof = try #require(avRuntime.receiveProof)

    #expect(videoFormat.requestedDeviceID == "synthetic-test-device")
    #expect(videoFormat.selectedDeviceID == "synthetic-test-device")
    #expect(videoFormat.selectedDeviceLabel == "synthetic BGRA fixture")
    #expect(videoFormat.requestedFrameRate == 30)
    #expect(videoFormat.selectedWidth == 16)
    #expect(videoFormat.selectedHeight == 16)
    #expect(videoFormat.selectedPixelFormat == "bgra8")
    #expect(videoFormat.outputPixelFormat == "bgra8")
    #expect(videoFormat.selectedFrameRate == 30)

    #expect(
        receiveProof.framesProven
            == avRuntime.runtimeMetrics.videoFramesReassembled
            - avRuntime.runtimeMetrics.videoFramesDroppedForSync
    )
    #expect(
        avRuntime.runtimeMetrics.videoFramesDroppedOutsideAudioWindow
            <= avRuntime.runtimeMetrics.videoFramesDroppedForSync
    )
    #expect(receiveProof.previewFramesSubmitted == avRuntime.runtimeMetrics.previewFramesSubmitted)
    #expect(receiveProof.previewFramesSubmitted == 0)
    #expect(receiveProof.firstFrame.width == 16)
    #expect(receiveProof.firstFrame.height == 16)
    #expect(receiveProof.firstFrame.pixelFormat == "bgra8")
    #expect(receiveProof.firstFrame.payloadByteCount == 16 * 16 * 4)
    #expect(receiveProof.firstFrame.fingerprint.hasPrefix("avfoundation-runtime-"))
    #expect(receiveProof.latestFrame.sequenceNumber >= receiveProof.firstFrame.sequenceNumber)
    #expect(receiveProof.latestFrame.payloadByteCount == 16 * 16 * 4)
}
