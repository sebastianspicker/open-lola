// Exercises deterministic parser, codec, and timing recovery seams without live runtimes.
import Foundation
import Testing

@testable import OpenLolaCore

@Test
func wave17ParsesRemainingConnectorKinds() throws {
    #expect(try parseExternalConnectorKind("mvtp-ultragrid") == .mvtpUltraGrid)
    #expect(try parseExternalConnectorKind("mvtpUltraGrid") == .mvtpUltraGrid)
    #expect(try parseExternalConnectorKind("jacktrip") == .jackTrip)
}

@Test
func wave17ParsesRemainingConnectorMediaModes() throws {
    #expect(try parseExternalConnectorMediaMode("audio") == .audio)
    #expect(try parseExternalConnectorMediaMode("video") == .video)
    #expect(try parseExternalConnectorMediaMode("audio-video") == .audioVideo)
    #expect(try parseExternalConnectorMediaMode("av") == .audioVideo)
}

@Test
func wave17ParsesRemainingConnectorRoles() throws {
    #expect(try parseExternalConnectorSessionRole("tx") == .tx)
    #expect(try parseExternalConnectorSessionRole("rx") == .rx)
    #expect(try parseExternalConnectorSessionRole("tx-rx") == .txRx)
    #expect(try parseExternalConnectorSessionRole("duplex") == .txRx)
    #expect(try parseExternalConnectorSessionRole("full-duplex") == .txRx)
}

@Test
func wave17RejectsUnknownConnectorRole() {
    #expect(throws: ExternalConnectorSessionError.invalidRole("relay")) {
        _ = try parseExternalConnectorSessionRole("relay")
    }
}

@Test
func wave17ParsesExternalControlTransports() throws {
    #expect(try parseExternalConnectorControlTransport("udp") == .udp)
    #expect(try parseExternalConnectorControlTransport("tcp") == .tcp)
}

@Test
func wave17RejectsUnknownControlTransport() {
    #expect(throws: ExternalConnectorSessionError.invalidControlTransport("quic")) {
        _ = try parseExternalConnectorControlTransport("quic")
    }
}

@Test
func wave17ParsesUltraGridTopologyAlternatives() throws {
    #expect(try parseUltraGridTopologyMode("direct-peer") == .directPeer)
    #expect(try parseUltraGridTopologyMode("peer") == .directPeer)
    #expect(try parseUltraGridTopologyMode("server-client") == .serverClient)
    #expect(try parseUltraGridTopologyMode("nat") == .serverClient)
}

@Test
func wave17ParsesUltraGridTopologyRoleAlternatives() throws {
    #expect(try parseUltraGridTopologyRole("direct") == .direct)
    #expect(try parseUltraGridTopologyRole("server") == .server)
    #expect(try parseUltraGridTopologyRole("listen") == .server)
    #expect(try parseUltraGridTopologyRole("client") == .client)
    #expect(try parseUltraGridTopologyRole("caller") == .client)
}

@Test
func wave17RejectsUnknownUltraGridTopology() {
    #expect(throws: ExternalConnectorSessionError.unknownArgument("--ultragrid-topology mesh")) {
        _ = try parseUltraGridTopologyMode("mesh")
    }
}

@Test
func wave17ParsesUltraGridFECAlternatives() throws {
    #expect(try parseUltraGridFECMode("off") == .none)
    #expect(try parseUltraGridFECMode("disabled") == .none)
    #expect(try parseUltraGridFECMode("single-parity") == .singleParity)
    #expect(try parseUltraGridFECMode("xor-parity") == .singleParity)
}

@Test
func wave17ParsesUltraGridEncryptionAlternatives() throws {
    #expect(try parseUltraGridEncryptionMode("off") == .none)
    #expect(try parseUltraGridEncryptionMode("disabled") == .none)
    #expect(try parseUltraGridEncryptionMode("aes-128-gcm") == .aes128GCM)
    #expect(try parseUltraGridEncryptionMode("gcm") == .aes128GCM)
    #expect(try parseUltraGridEncryptionMode("enabled") == .aes128GCM)
}

@Test
func wave17ParsesUltraGridControlAlternatives() throws {
    #expect(try parseUltraGridControlMode("none") == .disabled)
    #expect(try parseUltraGridControlMode("off") == .disabled)
    #expect(try parseUltraGridControlMode("local-tcp") == .localTCP)
    #expect(try parseUltraGridControlMode("tcp") == .localTCP)
}

@Test
func wave17ParsesLoLaVideoPayloadKinds() throws {
    #expect(try parseLoLaVideoPayloadKind("generated") == .generated)
    #expect(try parseLoLaVideoPayloadKind("avfoundation-mjpeg") == .avFoundationMjpeg)
    #expect(try parseLoLaVideoPayloadKind("avfoundation-raw8") == .avFoundationRaw8)
    #expect(try parseLoLaVideoPayloadKind("avfoundation-jpeg-xs") == .avFoundationJpegXS)
}

@Test
func wave17RejectsUnknownLoLaVideoPayloadKind() {
    #expect(throws: ExternalConnectorSessionError.unknownArgument("--lola-video-payload h265")) {
        _ = try parseLoLaVideoPayloadKind("h265")
    }
}

@Test
func wave17ParsesJackTripBackendAlternatives() throws {
    #expect(try parseJackTripAudioBackend("coreaudio") == .coreAudio)
    #expect(try parseJackTripAudioBackend("native-coreaudio") == .coreAudio)
    #expect(try parseJackTripAudioBackend("jack") == .jackGraph)
    #expect(try parseJackTripAudioBackend("jack-graph-backend") == .jackGraph)
}

@Test
func wave17ParsesJackTripHeaderAlternatives() throws {
    #expect(try parseJackTripPacketHeaderMode("default") == .default)
    #expect(try parseJackTripPacketHeaderMode("jamlink-header") == .jamLink)
    #expect(try parseJackTripPacketHeaderMode("empty-header") == .empty)
}

@Test
func wave17ParsesJackTripTransportAlternatives() throws {
    #expect(try parseJackTripTransportMode("udp") == .udp)
    #expect(try parseJackTripTransportMode("web-rtc") == .webRTC)
    #expect(try parseJackTripTransportMode("webrtc-data-channel") == .webRTC)
    #expect(try parseJackTripTransportMode("webtransport") == .webTransport)
    #expect(try parseJackTripTransportMode("quic") == .webTransport)
}

@Test
func wave17ParsesJackTripPluginAlternatives() throws {
    #expect(try parseJackTripPluginMode("none") == .disabled)
    #expect(try parseJackTripPluginMode("off") == .disabled)
    #expect(try parseJackTripPluginMode("audio-bridge") == .audioBridge)
    #expect(try parseJackTripPluginMode("vst3") == .audioBridge)
}

@Test
func wave17ParsesJackTripPayloadAlternatives() throws {
    #expect(try parseJackTripPayloadEncoding("pcm") == .pcm)
    #expect(try parseJackTripPayloadEncoding("raw-pcm") == .pcm)
    #expect(try parseJackTripPayloadEncoding("opus") == .opusCELTLowDelay)
    #expect(try parseJackTripPayloadEncoding("non-pcm-audio") == .opusCELTLowDelay)
}

@Test
func wave17ParsesRTPPayloadBounds() throws {
    #expect(try parseUltraGridRTPPayloadType("--pt", ["--pt": "0"]) == 0)
    #expect(try parseUltraGridRTPPayloadType("--pt", ["--pt": "127"]) == 127)
}

@Test
func wave17RejectsOutOfRangeRTPPayloadType() {
    #expect(throws: ExternalConnectorSessionError.invalidPositiveInteger("--pt", "128")) {
        _ = try parseUltraGridRTPPayloadType("--pt", ["--pt": "128"])
    }
}

@Test
func wave17ParsesFixtureBytes() throws {
    #expect(try parseFixtureBytes("fixture:00Aaff", field: "fixture") == Data([0, 0xAA, 0xFF]))
}

@Test
func wave17RejectsMalformedFixtureBytes() {
    for value in ["data:00", "fixture:", "fixture:0", "fixture:gg"] {
        #expect(throws: ExternalConnectorSessionError.invalidProcessArgument("fixture", value)) {
            _ = try parseFixtureBytes(value, field: "fixture")
        }
    }
}

@Test
func wave17RepeatsFixtureBytesToExactLength() {
    #expect(repeatedFixtureData(Data([1, 2]), byteCount: 5) == Data([1, 2, 1, 2, 1]))
}

@Test
func wave17ReturnsEmptyRepeatedFixtureForEmptyInputs() {
    #expect(repeatedFixtureData(Data(), byteCount: 3).isEmpty)
    #expect(repeatedFixtureData(Data([1]), byteCount: 0).isEmpty)
}

@Test
func wave17AcceptsSafeProcessArgumentCharacters() throws {
    #expect(try validateExternalConnectorProcessArgument(
        "[2001:db8::1]", field: "peer", argumentClass: .peerHost
    ) == "[2001:db8::1]")
    #expect(try validateExternalConnectorProcessArgument(
        "Core Audio/Bus 1", field: "device", argumentClass: .jackTripAudioDevice
    ) == "Core Audio/Bus 1")
    #expect(try validateExternalConnectorProcessArgument(
        "module:foo@1", field: "module", argumentClass: .ultraGridModule
    ) == "module:foo@1")
}

@Test
func wave17RejectsUnsafeProcessArgumentCharacters() {
    #expect(throws: ExternalConnectorSessionError.invalidProcessArgument("peer", "-host")) {
        _ = try validateExternalConnectorProcessArgument("-host", field: "peer", argumentClass: .peerHost)
    }
    #expect(throws: ExternalConnectorSessionError.invalidProcessArgument("peer", "host;rm")) {
        _ = try validateExternalConnectorProcessArgument("host;rm", field: "peer", argumentClass: .peerHost)
    }
}

@Test
func wave17MediaClockHandlesInvalidAndOverflowingRates() {
    #expect(MediaClock.nanoseconds(forFrameCount: 10, sampleRateHertz: 0) == 0)
    #expect(MediaClock.nanoseconds(forFrameCount: .max, sampleRateHertz: 1) == .max)
}

@Test
func wave17MediaClockValidatesStrictMonotonicity() throws {
    try MediaClock.validateMonotonicHostTimes([1, 2, 3])
    #expect(throws: MediaClockValidationError.nonMonotonicTimestamp(previous: 3, next: 2)) {
        try MediaClock.validateMonotonicHostTimes([1, 3, 2])
    }
}

@Test
func wave17MediaClockAnchorRejectsInvalidFields() {
    #expect(throws: MediaClockValidationError.invalidSampleRate(0)) {
        try MediaClockAnchor(senderFrameIndex: 0, hostTimeNanoseconds: 1, sampleRateHertz: 0).validate()
    }
    #expect(throws: MediaClockValidationError.invalidTimestamp(0)) {
        try MediaClockAnchor(senderFrameIndex: 0, hostTimeNanoseconds: 0, sampleRateHertz: 48_000).validate()
    }
}

@Test
func wave17MediaClockAnchorClampsEarlierFramesAndOverflow() {
    let anchor = MediaClockAnchor(senderFrameIndex: 5, hostTimeNanoseconds: 9, sampleRateHertz: 1)
    #expect(anchor.hostTimeNanoseconds(forFrameIndex: 4) == 9)
    let overflow = MediaClockAnchor(senderFrameIndex: 0, hostTimeNanoseconds: .max, sampleRateHertz: 1)
    #expect(overflow.hostTimeNanoseconds(forFrameIndex: 1) == .max)
}

@Test
func wave17MediaTimingPacketRejectsInvalidStreamAndObservationTime() {
    #expect(throws: MediaClockValidationError.invalidStreamID(0)) {
        try wave17TimingPacket(streamID: 0, remote: 1, local: 1).validate()
    }
    #expect(throws: MediaClockValidationError.invalidTimestamp(0)) {
        try wave17TimingPacket(streamID: 1, remote: 1, local: 0).validate()
    }
}

@Test
func wave17DriftEstimatorRejectsInsufficientSamples() {
    #expect(throws: MediaClockValidationError.insufficientDriftSamples(1)) {
        _ = try MediaClockDriftEstimator.estimate(from: [wave17TimingPacket(streamID: 1, remote: 1, local: 1)])
    }
}

@Test
func wave17DriftEstimatorRejectsNonMonotonicLocalTimes() {
    #expect(throws: MediaClockValidationError.nonMonotonicTimestamp(previous: 4, next: 3)) {
        _ = try MediaClockDriftEstimator.estimate(from: [
            wave17TimingPacket(streamID: 1, remote: 1, local: 4),
            wave17TimingPacket(streamID: 1, remote: 2, local: 3)
        ])
    }
}

@Test
func wave17DriftConfigurationRejectsMissingRequiredOption() {
    #expect(throws: DriftPlcRunConfigurationError.missingRequiredArgument("--route-report")) {
        _ = try DriftPlcRunConfiguration.parse([])
    }
}

@Test
func wave17DriftConfigurationRejectsInvalidDuration() {
    #expect(throws: DriftPlcRunConfigurationError.invalidInteger(
        argument: "--duration-seconds", value: "soon"
    )) {
        _ = try DriftPlcRunConfiguration.parse(wave17DriftArguments("--duration-seconds", "soon"))
    }
}

@Test
func wave17DriftConfigurationRejectsNonPositiveDuration() {
    #expect(throws: DriftPlcRunConfigurationError.nonPositiveArgument("--duration-seconds")) {
        _ = try DriftPlcRunConfiguration.parse(wave17DriftArguments("--duration-seconds", "0"))
    }
}

@Test
func wave17DriftConfigurationRejectsInvalidPolicy() {
    #expect(throws: DriftPlcRunConfigurationError.invalidPolicy("grow")) {
        _ = try DriftPlcRunConfiguration.parse(wave17DriftArguments("--policy", "grow"))
    }
}

@Test
func wave17DriftConfigurationRejectsUnknownAndDuplicateOptions() {
    #expect(throws: DriftPlcRunConfigurationError.unknownArgument("--unknown")) {
        _ = try DriftPlcRunConfiguration.parse(wave17DriftArguments("--unknown", "x"))
    }
    #expect(throws: DriftPlcRunConfigurationError.duplicateArgument("--output")) {
        _ = try DriftPlcRunConfiguration.parse(wave17DriftArguments("--output", "first", trailing: ["--output", "second"]))
    }
}

@Test
func wave17UltraGridFourCCRejectsInvalidWidths() {
    #expect(throws: UltraGridCompatibilityError.unsupportedMode("fourcc-RGB")) {
        _ = try UltraGridFourCC("RGB")
    }
}

@Test
func wave17UltraGridHeaderRejectsZeroGeometryAndPayload() throws {
    let fourCC = try UltraGridFourCC("BGRA")
    let timing = UltraGridVideoPayloadTiming(frameRateNumerator: 60)
    #expect(throws: UltraGridCompatibilityError.invalidField("video.payloadByteCount", 0)) {
        try UltraGridVideoPayloadHeader(
            bufferNumber: 1, payloadOffset: 0, payloadByteCount: 0,
            geometry: .init(width: 1, height: 1, fourCC: fourCC), timing: timing
        ).validate()
    }
    #expect(throws: UltraGridCompatibilityError.invalidField("video.width", 0)) {
        try UltraGridVideoPayloadHeader(
            bufferNumber: 1, payloadOffset: 0, payloadByteCount: 1,
            geometry: .init(width: 0, height: 1, fourCC: fourCC), timing: timing
        ).validate()
    }
}

@Test
func wave17UltraGridJPEGRejectsInvalidHeaders() {
    #expect(throws: UltraGridCompatibilityError.invalidField("jpeg.widthBlocks", 0)) {
        try UltraGridRTPJPEGHeader(fragmentOffset: 0, type: 0, quantization: 0, widthBlocks: 0, heightBlocks: 1).validate()
    }
    #expect(throws: UltraGridCompatibilityError.invalidField("jpeg.heightBlocks", 0)) {
        try UltraGridRTPJPEGHeader(fragmentOffset: 0, type: 0, quantization: 0, widthBlocks: 1, heightBlocks: 0).validate()
    }
}

@Test
func wave17UltraGridH264AcceptsStapAAndFUA() throws {
    #expect(try UltraGridRTPH264Payload(payload: Data([24, 0, 1, 0x65])).payload == Data([24, 0, 1, 0x65]))
    #expect(try UltraGridRTPH264Payload(payload: Data([28, 0x81, 0x55])).payload == Data([28, 0x81, 0x55]))
}

@Test
func wave17UltraGridH264RejectsMalformedStapA() {
    #expect(throws: UltraGridCompatibilityError.invalidField("h264.stapA.nalUnitLength", 0)) {
        _ = try UltraGridRTPH264Payload(payload: Data([24, 0, 0]))
    }
    #expect(throws: UltraGridCompatibilityError.invalidPayloadLength(expected: 5, actual: 4)) {
        _ = try UltraGridRTPH264Payload(payload: Data([24, 0, 2, 0x65]))
    }
}

private func wave17TimingPacket(streamID: UInt32, remote: UInt64, local: UInt64) -> MediaTimingPacket {
    MediaTimingPacket(
        streamID: streamID,
        sequenceNumber: 1,
        observedPayloadType: .audioPcmV2,
        senderFrameIndex: 0,
        remoteSenderTimeNanoseconds: remote,
        localObservationTimeNanoseconds: local,
        timestampOrigin: .audioPacketSenderHostTimeNanoseconds
    )
}

private func wave17DriftArguments(
    _ replacing: String,
    _ replacement: String,
    trailing: [String] = []
) -> [String] {
    var arguments = [
        "--route-report", "route.json",
        "--duration-seconds", "1",
        "--policy", "silence",
        "--artifact-assessment-completed", "true",
        "--artifact-notes", "reviewed",
        "--output", "out.json"
    ]
    if let index = arguments.firstIndex(of: replacing), index + 1 < arguments.count {
        arguments[index + 1] = replacement
    } else {
        arguments.append(contentsOf: [replacing, replacement])
    }
    arguments.append(contentsOf: trailing)
    return arguments
}
