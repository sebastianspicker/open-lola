import OpenLolaSessionDomain

public extension PeerSessionCapabilityProvider {
    /// The product advertisement used when callers do not inject deployment-specific capabilities.
    static let openLolaDefault = PeerSessionCapabilityProvider(
        implementationVersion: "0.0.0-m06"
    ) {
        CapabilitySet(
            peer: PeerIdentity(
                peerID: "local-open-lola",
                displayName: "Local open-lola peer",
                implementationName: "open-lola",
                implementationVersion: "0.0.0-m06"
            ),
            supportedControlVersions: [SessionControlProtocol.currentVersion],
            audio: AudioTransportCapabilities(
                transport: .init(
                    protocolVersions: [.udpPcmV2, .udpPcmV1],
                    payloadTypes: [.audioPcmV2, .audioRtpL24],
                    audioTransports: [.openLolaRaw, .aes67ST2110L24]
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
            ),
            video: VideoCapabilities(
                supportedRoles: [
                    .disabled,
                    .testPattern,
                    .blackmagicInput,
                    .atemProgram,
                    .atemPreview,
                    .avFoundationDevice
                ],
                supportedPixelFormats: [.disabled, .rgb24, .bgra8, .yuv422],
                supportedTransportFormats: [.disabled, .rawFrameFragment],
                maxWidth: 1_920,
                maxHeight: 1_080,
                maxFrameRateNumerator: 60,
                maxEnabledStreams: 8
            ),
            transport: SessionTransportCapabilities(
                supportsDirectUDP: true,
                supportsRendezvous: true,
                minMTUBytes: 576,
                maxMTUBytes: 1_200
            ),
            latencyProfiles: [.directAudioFirst, .balancedAV, .multiVideoPerformance, .wanStable],
            rxBufferProfiles: [.direct, .small, .adaptive, .stableWan]
        )
    }
}
