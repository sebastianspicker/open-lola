// Covers Wave 8 hotspot branches with decoded fixtures and injected local values only.
import Darwin
import Foundation
import Testing

@testable import OpenLolaCore

@Test
func wave8AudioLoopbackChannelMapRejectsNegativeAndWrongSizedMaps() throws {
    #expect(throws: AudioLoopbackRunConfigurationError.invalidChannelMap(
        argument: "--input-channels", value: "0,-1"
    )) {
        _ = try parseAudioLoopbackChannelMap("0,-1", argument: "--input-channels", expectedCount: 2)
    }
    #expect(throws: AudioLoopbackRunConfigurationError.channelMapCountMismatch(
        argument: "--input-channels", expected: 2, actual: 1
    )) {
        _ = try parseAudioLoopbackChannelMap("0", argument: "--input-channels", expectedCount: 2)
    }
}

@Test
func wave8AudioLoopbackProfileDefaultsAndBoundsStayDeterministic() throws {
    #expect(try parseLatencyProfile(nil, framesPerBuffer: 32) == .safeLowLatency)
    #expect(try parseRxBufferProfile(nil) == nil)
    #expect(channelMapFits([0, 1], available: 2))
    #expect(!channelMapFits([], available: 2))
    #expect(percentile([], 0.9) == 0)
    #expect(percentile([1, 4, 9], 2) == 9)
}

@Test
func wave8ExternalConnectorDefaultsChooseBuiltInExecutables() throws {
    let configuration = ExternalConnectorSessionConfiguration(.init(
        connector: .lola,
        role: .rx,
        peer: "192.0.2.20",
        outputPath: "/tmp/wave8-defaults.json"
    ))

    #expect(try requiredExecutable(configuration, connector: .lola, defaultName: "lola") == "lola")
    #expect(try requiredVideoExecutable(configuration, defaultName: "video-tool") == "video-tool")
}

@Test
func wave8ExternalConnectorParsersRejectUnsupportedAliasesAndBounds() throws {
    #expect(try parseJackTripTransportMode("quic") == .webTransport)
    #expect(try parseUltraGridControlMode("tcp") == .localTCP)
    #expect(throws: ExternalConnectorSessionError.invalidConnector("LoLa")) {
        _ = try parseExternalConnectorKind("LoLa")
    }
    #expect(throws: ExternalConnectorSessionError.invalidPositiveInteger("payload", "128")) {
        _ = try parseUltraGridRTPPayloadType("payload", ["payload": "128"])
    }
}

@Test
func wave8FixtureByteParserRejectsInvalidPairsAndRepeatsBoundedly() throws {
    #expect(try parseFixtureBytes("fixture:00Ff", field: "--fixture") == Data([0, 0xff]))
    #expect(repeatedFixtureData(Data([0xaa, 0xbb]), byteCount: 5) == Data([0xaa, 0xbb, 0xaa, 0xbb, 0xaa]))
    #expect(repeatedFixtureData(Data(), byteCount: 5).isEmpty)
    #expect(throws: ExternalConnectorSessionError.invalidProcessArgument("--fixture", "fixture:0")) {
        _ = try parseFixtureBytes("fixture:0", field: "--fixture")
    }
}

@Test
func wave8ProcessArgumentValidationRejectsOptionInjectionAndUnsafeCharacters() throws {
    #expect(try validateExternalConnectorProcessArgument(
        "[2001:db8::1]", field: "peer", argumentClass: .peerHost
    ) == "[2001:db8::1]")
    #expect(throws: ExternalConnectorSessionError.invalidProcessArgument("peer", "-oProxyCommand=x")) {
        _ = try validateExternalConnectorProcessArgument(
            "-oProxyCommand=x", field: "peer", argumentClass: .peerHost
        )
    }
    #expect(throws: ExternalConnectorSessionError.invalidProcessArgument("peer", "host;rm")) {
        _ = try validateExternalConnectorProcessArgument("host;rm", field: "peer", argumentClass: .peerHost)
    }
}

@Test
func wave8DirectPeerRuntimeMetricsDecodeSparseLegacyJSONWithZeroDefaults() throws {
    let decoded = try JSONDecoder().decode(DirectPeerSessionAVRuntimeMetrics.self, from: Data("{}".utf8))

    #expect(decoded.audioPayloadsCaptured == 0)
    #expect(decoded.videoFramesReassembled == 0)
    #expect(decoded.previewFramesDropped == 0)
    #expect(decoded.metricsMessagesPublishFailures == 0)
    #expect(decoded.audioRXBuffer == nil)
}

@Test
func wave8NativeAppShellPathsAndExecutableGuardRemainLocalOnly() throws {
    let runDirectory = NativeAppShellExecutionPaths.defaultRunDirectory()
    #expect(runDirectory.hasSuffix("/OpenLoLa/MacToMac"))
    #expect(NativeAppShellExecutionPaths.defaultPlanPath().hasSuffix("/plan.json"))

    let settings = NativeAppShellExecutionSettings()
    #expect(throws: NativeAppShellExecutionValidationError.invalidSupervisorExecutable("/tmp/not-open-lola")) {
        _ = try settings.validatorArguments(executablePath: "/tmp/not-open-lola")
    }
}

@Test
func wave8HandshakeRetryRejectsMissingRequiredFieldsWithoutTransport() throws {
    let configuration = ExternalConnectorSessionConfiguration(.init(
        connector: .lola,
        role: .rx,
        peer: "192.0.2.20",
        outputPath: "/tmp/wave8-handshake.json"
    ) { input in
        input.localHost = "192.0.2.10"
    })
    let message = "/MESG_CHECKLOLASTATUS;SRCIP:192.0.2.20"
    let parsed = try LoLaCompatibilityControlMessage.parse(message)

    #expect(try lolaRetryResponderAck(
        configuration: configuration,
        message: message,
        parsed: parsed,
        senderHost: "192.0.2.20"
    ) == nil)
}

@Test
func wave8MemoryUdpReceiverAcceptsWildcardPeersAndFiltersPorts() throws {
    let receiver = LoLaMemoryUdpMediaReceiver(datagrams: [
        .init(stream: .audio, port: 19_788, sourceHost: "198.51.100.7", payload: Data([1])),
        .init(stream: .video, port: 19_798, sourceHost: "198.51.100.8", payload: Data([2])),
        .init(stream: .audio, port: 19_799, sourceHost: "198.51.100.7", payload: Data([3]))
    ])

    let datagrams = try receiver.receive(
        maxDatagrams: 3,
        localHost: "192.0.2.10",
        peer: "0.0.0.0",
        audioPort: 19_788,
        videoPort: 19_798
    )
    #expect(datagrams.map(\.payload) == [Data([1]), Data([2])])
}

@Test
func wave8UdpAddressBuilderRejectsBadInputBeforeAnySocketOperation() throws {
    let address = try loLaUdpMediaAddress(host: "192.0.2.44", port: 19_788)
    #expect(address.sin_family == sa_family_t(AF_INET))
    #expect(UInt16(bigEndian: address.sin_port) == 19_788)
    #expect(throws: ExternalConnectorSessionError.self) {
        _ = try loLaUdpMediaAddress(host: "not-an-ip", port: 19_788)
    }
}

@Test
func wave8VideoTransportErrorsKeepFieldDiagnosticsStable() {
    #expect(VideoTransportFragmentError.invalidMagic.validationField == "magic")
    #expect(VideoTransportFragmentError.unsupportedVersion(9).validationField == "version")
    #expect(VideoTransportFragmentError.payloadOutOfBounds(
        offset: 1, payloadBytes: 2, framePayloadBytes: 2
    ).validationField == "payloadOffset")
    #expect(VideoTransportFragmentError.encodingValidationFailed(field: "payload", reason: "fixture").validationField == "payload")
}
