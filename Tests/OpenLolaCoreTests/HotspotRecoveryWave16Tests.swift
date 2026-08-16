// Exercises deterministic recovery seams without devices, sockets, or processes.
import CoreAudio
import Dispatch
import Foundation
import Testing

@testable import OpenLolaCore

private struct Wave16Provider: UltraGridMediaProviding {
    func audioPCM(sequenceNumber: Int, channels: Int, framesPerPacket: Int) throws -> Data {
        Data([UInt8(sequenceNumber), UInt8(channels), UInt8(framesPerPacket)])
    }

    func videoFrame(frameID: Int, width: Int, height: Int, bitsPerPixel: Int) throws -> Data {
        Data([UInt8(frameID), UInt8(width), UInt8(height), UInt8(bitsPerPixel)])
    }
}

@Test
func wave16DefaultUltraGridProviderUsesInjectedFixtureReport() throws {
    let provider = Wave16Provider()
    #expect(provider.providerReport.audioSource == "injected-fixture")
    #expect(try provider.audioPCM(sequenceNumber: 7, channels: 2, framesPerPacket: 4) == Data([7, 2, 4]))
}

@Test
func wave16DefaultUltraGridProviderForwardsNilAudioDeadline() throws {
    let provider = Wave16Provider()
    #expect(try provider.audioPCM(sequenceNumber: 1, channels: 1, framesPerPacket: 1,
                                  deadlineNanoseconds: nil) == Data([1, 1, 1]))
}

@Test
func wave16DefaultUltraGridProviderRejectsAudioDeadline() {
    #expect(throws: ExternalConnectorSessionError.unsupportedRuntimeMode(
        "ultragrid-full-duplex-provider-without-deadline"
    )) {
        _ = try Wave16Provider().audioPCM(sequenceNumber: 1, channels: 1, framesPerPacket: 1,
                                          deadlineNanoseconds: 1)
    }
}

@Test
func wave16DefaultUltraGridProviderForwardsNilVideoDeadline() throws {
    #expect(try Wave16Provider().videoFrame(frameID: 3, width: 4, height: 5, bitsPerPixel: 8,
                                             deadlineNanoseconds: nil) == Data([3, 4, 5, 8]))
}

@Test
func wave16DefaultUltraGridProviderRejectsVideoDeadline() {
    #expect(throws: ExternalConnectorSessionError.unsupportedRuntimeMode(
        "ultragrid-full-duplex-provider-without-deadline"
    )) {
        _ = try Wave16Provider().videoFrame(frameID: 1, width: 1, height: 1, bitsPerPixel: 8,
                                            deadlineNanoseconds: 1)
    }
}

@Test
func wave16SessionProviderSelectsAvFoundationWithoutStartingIt() throws {
    let provider = try UltraGridSessionMediaProvider(configuration: wave16UltraGridConfiguration { input in
        input.videoCapture = "avfoundation:synthetic-camera"
    })
    #expect(provider.providerReport.audioSource == "synthetic")
    #expect(provider.providerReport.videoSource == "avfoundation-raw8-live")
    #expect(provider.providerReport.observedEvidenceClasses == [.liveDevice])
}

@Test
func wave16UnstartedAvFoundationProviderReturnsCaptureUnavailable() throws {
    let provider = try UltraGridSessionMediaProvider(configuration: wave16UltraGridConfiguration { input in
        input.videoCapture = "avfoundation-raw8"
    })
    #expect(throws: LoLaVideoPayloadError.captureUnavailable) {
        _ = try provider.videoFrame(frameID: 1, width: 2, height: 1, bitsPerPixel: 8)
    }
}

@Test
func wave16UnstartedCoreAudioProviderReturnsMissingSourceError() throws {
    let provider = try UltraGridSessionMediaProvider(configuration: wave16UltraGridConfiguration { input in
        input.audioCapture = "coreaudio:in-memory"
    })
    #expect(throws: ExternalConnectorSessionError.socketFailed(
        "Core Audio UltraGrid provider was not started"
    )) {
        _ = try provider.audioPCM(sequenceNumber: 1, channels: 1, framesPerPacket: 1)
    }
}

@Test
func wave16LoLaBridgeDefersPCMUntilPlayoutStarts() throws {
    let bridge = try LoLaCoreAudioLiveBridge(
        configuration: wave16LoLaConfiguration(),
        inputDeviceUID: "input",
        outputDeviceUID: "output",
        inventory: wave16AudioInventory()
    )
    let payload = Data(repeating: 0, count: try LoLaCompatibilityMediaModel.audioPayloadByteCount(channels: 2))
    try bridge.enqueueLoLaPlaybackPayload(payload, hostTimeNanoseconds: 123)
    #expect(bridge.snapshot.receivedAudioPackets == 0)
    #expect(bridge.snapshot.queuedPlayoutBlocks == 0)
}

@Test
func wave16ParsesExternalConnectorKindAliases() throws {
    #expect(try parseExternalConnectorKind("ultragrid") == .mvtpUltraGrid)
    #expect(try parseExternalConnectorKind("jackTrip") == .jackTrip)
}

@Test
func wave16ParsesExternalConnectorMediaAndRoleAliases() throws {
    #expect(try parseExternalConnectorMediaMode("audioVideo") == .audioVideo)
    #expect(try parseExternalConnectorSessionRole("bidirectional") == .txRx)
}

@Test
func wave16ParsesUltraGridTopologyAliases() throws {
    #expect(try parseUltraGridTopologyMode("server-client-nat") == .serverClient)
    #expect(try parseUltraGridTopologyRole("listener") == .server)
}

@Test
func wave16ParsesUltraGridPayloadTypeAndModes() throws {
    #expect(try parseUltraGridRTPPayloadType("pt", ["pt": "127"]) == 127)
    #expect(try parseUltraGridRTPPayloadType("pt", [:]) == nil)
    #expect(try parseUltraGridFECMode("xor") == .singleParity)
    #expect(try parseUltraGridEncryptionMode("on") == .aes128GCM)
}

@Test
func wave16RejectsUnknownExternalConnectorParsingValues() {
    #expect(throws: ExternalConnectorSessionError.invalidConnector("unknown")) {
        _ = try parseExternalConnectorKind("unknown")
    }
    #expect(throws: ExternalConnectorSessionError.invalidMediaMode("screen")) {
        _ = try parseExternalConnectorMediaMode("screen")
    }
}

@Test
func wave16ParsesJackTripAliases() throws {
    #expect(try parseJackTripAudioBackend("jackd") == .jackGraph)
    #expect(try parseJackTripTransportMode("data-channel") == .webRTC)
    #expect(try parseJackTripPayloadEncoding("opus-celt") == .opusCELTLowDelay)
}

@Test
func wave16UltraGridFourCCRoundTripsNetworkOrder() throws {
    let fourCC = try UltraGridFourCC("RGBA")
    #expect(fourCC.rawValue == 0x5247_4241)
}

@Test
func wave16UltraGridVideoHeaderRoundTripsFlags() throws {
    let header = UltraGridVideoPayloadHeader(
        substreamID: 2, bufferNumber: 9, payloadOffset: 3, payloadByteCount: 10,
        geometry: .init(width: 4, height: 2, fourCC: try UltraGridFourCC("BGRA")),
        timing: .init(interlace: 1, frameRateNumerator: 60, frameRateDenominator: 1, fd: true, fi: true)
    )
    #expect(try UltraGridVideoPayloadHeader.decode(Array(header.encoded())) == header)
}

@Test
func wave16UltraGridVideoHeaderRejectsInvalidInterlace() throws {
    let header = UltraGridVideoPayloadHeader(
        bufferNumber: 1, payloadOffset: 0, payloadByteCount: 1,
        geometry: .init(width: 1, height: 1, fourCC: try UltraGridFourCC("BGRA")),
        timing: .init(interlace: 8, frameRateNumerator: 1)
    )
    #expect(throws: UltraGridCompatibilityError.invalidField("video.interlace", 8)) {
        _ = try header.encoded()
    }
}

@Test
func wave16UltraGridJPEGPayloadRoundTrips() throws {
    let payload = UltraGridRTPJPEGPayload(
        header: .init(fragmentOffset: 2, type: 0, quantization: 1, widthBlocks: 1, heightBlocks: 1),
        scanPayload: Data([3, 4])
    )
    #expect(try UltraGridRTPJPEGPayload.decode(payload.encoded()) == payload)
}

@Test
func wave16UltraGridJPEGPayloadRejectsEmptyScan() throws {
    let payload = UltraGridRTPJPEGPayload(
        header: .init(fragmentOffset: 0, type: 0, quantization: 1, widthBlocks: 1, heightBlocks: 1),
        scanPayload: Data()
    )
    #expect(throws: UltraGridCompatibilityError.invalidField("jpeg.scanPayload", 0)) {
        _ = try payload.encoded()
    }
}

@Test
func wave16UltraGridH264AcceptsSingleNAL() throws {
    let payload = try UltraGridRTPH264Payload(payload: Data([0x65, 0x88]))
    #expect(try payload.encoded() == Data([0x65, 0x88]))
}

@Test
func wave16UltraGridH264RejectsFUAWithBothBoundaryFlags() {
    #expect(throws: UltraGridCompatibilityError.invalidField("h264.fuA.startAndEnd", 1)) {
        _ = try UltraGridRTPH264Payload(payload: Data([0x7c, 0xc5, 0x01]))
    }
}

@Test
func wave16MediaClockRoundsAndAnchors() {
    #expect(MediaClock.nanoseconds(forFrameCount: 3, sampleRateHertz: 2_000_000_000) == 2)
    let anchor = MediaClockAnchor(senderFrameIndex: 10, hostTimeNanoseconds: 100, sampleRateHertz: 48_000)
    #expect(anchor.hostTimeNanoseconds(forFrameIndex: 9) == 100)
}

@Test
func wave16MediaClockDriftEstimatorProducesCorrectionBoundary() throws {
    let packets = [
        wave16TimingPacket(sequence: 0, remote: 100, local: 200),
        wave16TimingPacket(sequence: 1, remote: 1_100, local: 1_300)
    ]
    let estimate = try MediaClockDriftEstimator.estimate(from: packets, correctionBoundary: .outsideCallback)
    #expect(estimate.sampleCount == 2)
    #expect(estimate.offsetMicroseconds == 0.2)
}

@Test
func wave16MediaClockRejectsDuplicateRemoteTimestamp() {
    #expect(throws: MediaClockValidationError.nonMonotonicTimestamp(previous: 100, next: 100)) {
        _ = try MediaClockDriftEstimator.estimate(from: [
            wave16TimingPacket(sequence: 0, remote: 100, local: 200),
            wave16TimingPacket(sequence: 1, remote: 100, local: 300)
        ])
    }
}

@Test
func wave16DriftPlcConfigurationParsesCompleteArguments() throws {
    let configuration = try DriftPlcRunConfiguration.parse([
        "--route-report", "route.json", "--duration-seconds", "60", "--policy", "repeatLastGoodBlock",
        "--artifact-assessment-completed", "true", "--artifact-notes", "reviewed", "--output", "out.json"
    ])
    #expect(configuration.durationSeconds == 60)
    #expect(configuration.artifactAssessmentCompleted)
}

@Test
func wave16DriftPlcConfigurationRejectsInvalidBoolean() {
    #expect(throws: DriftPlcRunConfigurationError.invalidBoolean(
        argument: "--artifact-assessment-completed", value: "perhaps"
    )) {
        _ = try DriftPlcRunConfiguration.parse([
            "--route-report", "route.json", "--duration-seconds", "1", "--policy", "repeatLastGoodBlock",
            "--artifact-assessment-completed", "perhaps", "--artifact-notes", "n", "--output", "out.json"
        ])
    }
}

@Test
func wave16RealtimePacketHandoffMarksShutdownAfterInMemoryCallback() throws {
    var handoff = try RealtimeAudioPacketHandoff(configuration: packetHandoffConfiguration())
    #expect(handoff.captureCallback(startFrame: 0, hostTimeNanoseconds: 1) == .stored)
    handoff.markShutdownCompleted()
    #expect(handoff.metrics.shutdownCompleted)
}

@Test
func wave16RealtimePacketHandoffDropsLatePacket() throws {
    var handoff = try RealtimeAudioPacketHandoff(configuration: packetHandoffConfiguration(playoutTargetFrames: 0))
    _ = handoff.renderCallback()
    _ = handoff.renderCallback()
    #expect(try handoff.receive(packet(sequence: 1, senderFrameIndex: 0)) == .droppedLate)
}

@Test
func wave16GoalPreflightDetectsSummaryMismatch() throws {
    var report = blockedPreflightReport()
    report.summary.audioDeviceCount = 9
    #expect(throws: GoalRuntimePreflightValidationError.summaryMismatch) {
        try report.validate()
    }
}

@Test
func wave16GoalPreflightParsesOnlyQuotedSigningIdentities() {
    let probe = GoalRuntimePreflightSigningProbe.parse(
        command: "security", exitCode: 0,
        output: "noise\n  1) hash \"Developer ID Application: Wave 16\"\nunterminated \"",
        error: nil
    )
    #expect(probe.identities.map(\.label) == ["Developer ID Application: Wave 16"])
}

@Test
func wave16MultiVideoSelectionRejectsEmptySelection() {
    let selection = VideoReceiverSelection(
        mode: .multiView, selectedStreamIDs: [], layout: .init(kind: .grid, maxVisibleStreams: 2)
    )
    #expect(throws: VideoTransportValidationError.emptyList(
        "multiVideo.receiverSelection.selectedStreamIDs"
    )) {
        try selection.validate(against: [])
    }
}

@Test
func wave16MultiVideoSelectionRejectsSelectedStreamMultiLayout() {
    let selection = VideoReceiverSelection(
        mode: .selectedStream, selectedStreamIDs: [1], layout: .init(kind: .single, maxVisibleStreams: 2)
    )
    #expect(throws: VideoTransportValidationError.invalidMultiVideoLayout(
        "selectedStream requires maxVisibleStreams=1"
    )) {
        try selection.validate(against: [VideoStreamDescription.disabled(id: 1, sourceLabel: "off")])
    }
}

@Test
func wave16DirectPeerAES67MapperUsesInitialObservationAndWrapDelta() {
    var mapper = DirectPeerAES67RTPHostTimeMapper(sampleRateHertz: 48_000)
    #expect(mapper.hostTimeNanoseconds(rtpTimestamp: UInt32.max, observedHostTimeNanoseconds: 100) == 100)
    #expect(mapper.hostTimeNanoseconds(rtpTimestamp: 47, observedHostTimeNanoseconds: 999) == 1_000_100)
}

@Test
func wave16DirectPeerDrainResultDefaultsToNoWork() {
    let result = DirectPeerAudioTXDrainResult()
    #expect(result.payloadsSent == 0)
    #expect(!result.budgetExhausted)
}

@Test
func wave16DirectPeerTwoPeerPartialReportValidatesWithoutArtifacts() throws {
    let report = wave16DirectPeerReport(verdict: .partial)
    try report.validate()
    #expect(report.executionMode == .local)
    #expect(report.processResults.map(\.peerID) == ["initiator", "responder"])
}

@Test
func wave16DirectPeerTwoPeerPassRequiresExecution() {
    let report = wave16DirectPeerReport(verdict: .pass)
    #expect(throws: DirectPeerTwoPeerLocalRunError.passRequiresExecution) {
        try report.validate()
    }
}

@Test
func wave16RxBufferBenchmarkRejectsMissingRowsBeforeHardwareClaims() {
    let report = RxBufferBenchmarkReport(
        identity: .init(id: "wave16", title: "Wave 16", capturedAt: "now", evidenceKind: .localRuntime),
        environment: .init(
            hardware: .init(referenceMac: "mac", audioInterface: "interface", osVersion: "os", driverVersion: "driver"),
            route: .init(label: "route", topology: "direct"),
            audioMode: .init(sampleRateHertz: 48_000, framesPerBuffer: 32, channelCount: 2, sampleFormat: "int16")
        ),
        outcome: .init(rows: [], verdict: .partial, notes: "deterministic validator coverage")
    )
    #expect(throws: RxBufferBenchmarkValidationError.emptyList("rows")) {
        try report.validate()
    }
}

@Test
func wave16SessionNegotiationUsesDefaultReconnectDeadline() throws {
    let peerA = PeerIdentity(peerID: "a", displayName: "A", implementationName: "test", implementationVersion: "1")
    let peerB = PeerIdentity(peerID: "b", displayName: "B", implementationName: "test", implementationVersion: "1")
    let audio = AudioStreamDescription(
        identity: .init(id: 1, direction: .bidirectional, clockDomain: "test"),
        format: .init(sampleRateHertz: 48_000, sampleFormat: .float32LittleEndian, channelCount: 2,
                      channelOrder: AudioChannelSet.defaultInput(count: 2).sortedByStableSourceIndex),
        packet: .init(framesPerPacket: 32, payloadType: .audioPcmV2)
    )
    let proposal = SessionNegotiationTestFixtures.proposal(.init(
        sessionID: "wave16", proposer: peerA, responder: peerB, audio: audio, video: [],
        latencyProfile: .directAudioFirst, rxBufferProfile: .direct
    ))
    let capabilities = SessionNegotiationTestFixtures.capabilities(
        peer: peerA, supportedVideoRoles: [.disabled], maxEnabledVideoStreams: 0,
        latencyProfiles: [.directAudioFirst], rxBufferProfiles: [.direct]
    )
    var responder = capabilities
    responder.peer = peerB
    #expect(try SessionNegotiation.negotiate(
        proposal: proposal, proposerCapabilities: capabilities, responderCapabilities: responder
    ).reconnectDeadlineMilliseconds == SessionNegotiation.defaultReconnectDeadlineMilliseconds)
}

private func wave16UltraGridConfiguration(
    _ update: (inout ExternalConnectorSessionConfigInput) -> Void = { _ in }
) -> ExternalConnectorSessionConfiguration {
    ExternalConnectorSessionConfiguration(.init(
        connector: .mvtpUltraGrid, role: .tx, peer: "203.0.113.16", outputPath: "/tmp/wave16.json"
    ) { input in
        input.mediaMode = .audioVideo
        input.framesPerPacket = 2
        input.videoWidth = 2
        input.videoHeight = 1
        input.videoBitsPerPixel = 8
        update(&input)
    })
}

private func wave16LoLaConfiguration() -> ExternalConnectorSessionConfiguration {
    ExternalConnectorSessionConfiguration(.init(
        connector: .lola, role: .txRx, peer: "192.0.2.16", outputPath: "/tmp/wave16-lola.json"
    ) { input in
        input.dryRun = false
        input.sampleRateHertz = 48_000
        input.framesPerPacket = 64
        input.channels = 2
        input.audioCapture = "coreaudio:input"
        input.audioPlayback = "coreaudio:output"
    })
}

private func wave16AudioInventory() -> CoreAudioInventoryReport {
    CoreAudioInventoryReport(capturedAt: "test", hostName: "test", devices: [
        wave16AudioDevice(uid: "input", inputChannels: 2, outputChannels: 0),
        wave16AudioDevice(uid: "output", inputChannels: 0, outputChannels: 2)
    ])
}

private func wave16AudioDevice(uid: String, inputChannels: Int, outputChannels: Int) -> CoreAudioDeviceInventory {
    CoreAudioDeviceInventory(
        identity: .init(id: UInt32(abs(uid.hashValue % 10_000) + 1), name: uid, uid: uid,
                        manufacturer: nil, transportType: nil, isAggregate: false),
        streams: .init(inputChannelCount: inputChannels, outputChannelCount: outputChannels,
                       inputStreamCount: inputChannels > 0 ? 1 : 0, outputStreamCount: outputChannels > 0 ? 1 : 0,
                       inputChannelLayout: nil, outputChannelLayout: nil),
        sampleRates: .init(nominalSampleRateHertz: 48_000,
                           availableSampleRateRanges: [.init(minimum: 48_000, maximum: 48_000)]),
        buffering: .init(currentBufferFrameSize: 64, bufferFrameSizeRange: .init(minimum: 64, maximum: 512),
                          candidateBufferFrames: .init(inReportedRange: [64], outsideReportedRange: [], note: "test")),
        timing: .init(inputLatencyFrames: nil, outputLatencyFrames: nil, inputSafetyOffsetFrames: nil,
                      outputSafetyOffsetFrames: nil, clockDomain: nil),
        diagnosticNotes: []
    )
}

private func wave16TimingPacket(sequence: UInt64, remote: UInt64, local: UInt64) -> MediaTimingPacket {
    MediaTimingPacket(streamID: 1, sequenceNumber: sequence, observedPayloadType: .audioPcmV2,
                      senderFrameIndex: sequence, remoteSenderTimeNanoseconds: remote,
                      localObservationTimeNanoseconds: local,
                      timestampOrigin: .audioPacketSenderHostTimeNanoseconds)
}

private func wave16DirectPeerReport(verdict: MeasurementVerdict) -> DirectPeerTwoPeerLocalRunReport {
    let processResults = [
        DirectPeerTwoPeerLocalRunProcessResult(
            identity: .init(peerID: "initiator", role: .initiator, reportPath: "initiator.json"),
            execution: .init(command: ["open-lola"])
        ),
        DirectPeerTwoPeerLocalRunProcessResult(
            identity: .init(peerID: "responder", role: .responder, reportPath: "responder.json"),
            execution: .init(command: ["open-lola"])
        )
    ]
    return DirectPeerTwoPeerLocalRunReport(.init(
        metadata: .init(id: "wave16", capturedAt: "now", planID: "plan", runDirectory: "/tmp"),
        processExecution: .init(executed: false, processResults: processResults),
        aggregation: .init(command: ["aggregate"]),
        evidence: .init(
            preflightChecks: [.init(id: "ready", severity: .pass, passed: true, message: "ready")],
            gates: ["gate"], verdict: verdict, notes: "deterministic report validation"
        )
    ))
}
