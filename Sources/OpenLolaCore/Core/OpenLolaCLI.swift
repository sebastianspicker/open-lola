// Defines CLI capability and version defaults, centralizing values consumed by the executable and tests.
/// Provides the implementation version and local capability advertisement shared by the CLI and tests.
public enum OpenLolaCLI {
    public static let implementationVersion = "0.0.0-m06"

    public static func localCapabilitySet() -> CapabilitySet {
        CapabilitySet(
            peer: localPeerIdentity,
            supportedControlVersions: [SessionControlProtocol.currentVersion],
            audio: localAudioCapabilities,
            video: localVideoCapabilities,
            transport: localTransportCapabilities,
            latencyProfiles: [.directAudioFirst, .balancedAV, .multiVideoPerformance, .wanStable],
            rxBufferProfiles: [.direct, .small, .adaptive, .stableWan]
        )
    }

    private static let localPeerIdentity = PeerIdentity(
        peerID: "local-open-lola",
        displayName: "Local open-lola peer",
        implementationName: "open-lola",
        implementationVersion: implementationVersion
    )

    private static let localAudioCapabilities = AudioTransportCapabilities(
        transport: .init(
            protocolVersions: [.udpPcmV2, .udpPcmV1],
            payloadTypes: [.audioPcmV2, .audioOpusCeltLowDelayFrame, .audioRtpL24],
            audioTransports: [.openLolaRaw, .openLolaOpusCeltLowDelay, .aes67ST2110L24]
        ),
        audio: .init(
            channelSet: .defaultInput(count: 64),
            sampleRatesHertz: [48_000, 96_000],
            framesPerPacketOptions: [6, 8, 16, 32, 48, 64, 120],
            sampleFormats: [.float32LittleEndian, .int16LittleEndian]
        ),
        limits: .init(
            maxTransmissionUnitBytes: 1_200,
            maxFragmentsPerDeadline: 16,
            latencyProfiles: [.extremeLowLatency8, .ultraLowLatency16, .safeLowLatency],
            rxBufferProfiles: [.direct, .small],
            supportsMatrixMetadata: true
        )
    )

    private static let localVideoCapabilities = VideoCapabilities(
                supportedRoles: [
                    .disabled,
                    .testPattern,
                    .blackmagicInput,
                    .atemProgram,
                    .atemPreview,
                    .avFoundationDevice
                ],
                supportedPixelFormats: [.disabled, .rgb24, .bgra8, .yuv422],
                supportedTransportFormats: [.disabled, .rawFrameFragment, .jpegXSFrameFragment],
                maxWidth: 1_920,
                maxHeight: 1_080,
                maxFrameRateNumerator: 60,
                maxEnabledStreams: VideoTransportRunConfiguration.maximumStreamCount
    )

    private static let localTransportCapabilities = SessionTransportCapabilities(
        supportsDirectUDP: true,
        supportsRendezvous: true,
        minMTUBytes: 576,
        maxMTUBytes: 1_200
    )
}
