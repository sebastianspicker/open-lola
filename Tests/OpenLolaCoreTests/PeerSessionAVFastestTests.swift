import Testing

@testable import OpenLolaCore

@Test
func directPeerRealtimeAudioPreflightBlocksUnsupportedFastestFrameSize() throws {
    let inventory = CoreAudioInventoryReport(
        capturedAt: "2026-05-08T00:00:00Z",
        hostName: "test-host",
        devices: [
            CoreAudioDeviceInventory(
                id: 1,
                name: "Full Duplex",
                uid: "full-duplex",
                manufacturer: nil,
                transportType: nil,
                isAggregate: false,
                inputChannelCount: 2,
                outputChannelCount: 2,
                inputStreamCount: 1,
                outputStreamCount: 1,
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
        ]
    )
    let configuration = DirectPeerRealtimeAudioGraphConfiguration(
        audioDeviceUID: "full-duplex",
        sampleRateHertz: 48_000,
        framesPerBuffer: 16,
        channelCount: 2,
        sampleFormat: .float32LittleEndian,
        inputChannelMap: [0, 1],
        outputChannelMap: [0, 1]
    )

    #expect(throws: DirectPeerAudioGraphError.unsupportedFrameSize(
        uid: "full-duplex",
        framesPerBuffer: 16
    )) {
        _ = try DirectPeerRealtimeAudioGraph.preflight(configuration: configuration, inventory: inventory)
    }
}

@Test
func directPeerSessionManualAudioVideoFastestModeIsAudioFirstAndReportDistinct() async throws {
    try await SocketHeavyTestGate.shared.run {
        let ports = try freeLocalUdpPorts(count: 8)
        let initiatorManual = DirectPeerSessionManualRunConfiguration(
            role: .initiator,
            localPeerID: "peer-a",
            remotePeerID: "peer-b",
            localHost: "127.0.0.1",
            remoteHost: "127.0.0.1",
            controlPort: ports[0],
            remoteControlPort: ports[4],
            audioPort: ports[1],
            videoPort: ports[2],
            metricsPort: ports[3],
            packetCount: 1,
            audioChannelCount: 2,
            timeoutSeconds: 10
        )
        let responderManual = DirectPeerSessionManualRunConfiguration(
            role: .responder,
            localPeerID: "peer-b",
            remotePeerID: "peer-a",
            localHost: "127.0.0.1",
            remoteHost: "127.0.0.1",
            controlPort: ports[4],
            remoteControlPort: ports[0],
            audioPort: ports[5],
            videoPort: ports[6],
            metricsPort: ports[7],
            packetCount: 1,
            audioChannelCount: 2,
            timeoutSeconds: 10
        )
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
            (acceptedResponderReport, "synthetic-b"),
        ] {
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
    }
}

private func avFastestConfiguration(
    manual: DirectPeerSessionManualRunConfiguration,
    uid: String
) -> DirectPeerSessionAVRunConfiguration {
    DirectPeerSessionAVRunConfiguration(
        manual: manual,
        durationSeconds: 1,
        audioDeviceUID: uid,
        inputDeviceUID: uid,
        outputDeviceUID: uid,
        framesPerPacket: 32,
        videoDeviceID: "synthetic-test-device",
        videoWidth: 16,
        videoHeight: 16,
        avProfile: .fastest,
        preview: .off,
        mediaSourceMode: .syntheticFixture
    )
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
    #expect(metrics.videoFramesDroppedOutsideAudioWindow == 0)
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

    #expect(receiveProof.framesProven == avRuntime.runtimeMetrics.videoFramesReassembled)
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
