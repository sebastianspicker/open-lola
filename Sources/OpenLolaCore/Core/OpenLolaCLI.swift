public enum OpenLolaCLI {
    public static func localCapabilitySet() -> CapabilitySet {
        CapabilitySet(
            peer: PeerIdentity(
                peerID: "local-open-lola",
                displayName: "Local open-lola peer",
                implementationName: "open-lola",
                implementationVersion: "0.0.0-m06"
            ),
            supportedControlVersions: [SessionControlProtocol.currentVersion],
            audio: AudioTransportCapabilities(
                supportedProtocolVersions: [.udpPcmV2, .udpPcmV1],
                supportedPayloadTypes: [.audioPcmV2, .audioOpusCeltLowDelayFrame, .audioRtpL24],
                supportedAudioTransports: [.openLolaRaw, .openLolaOpusCeltLowDelay, .aes67ST2110L24],
                channelSet: .defaultInput(count: 64),
                sampleRatesHertz: [48_000, 96_000],
                framesPerPacketOptions: [32, 64, 120],
                sampleFormats: [.float32LittleEndian, .int16LittleEndian],
                maxTransmissionUnitBytes: 1_200,
                maxFragmentsPerDeadline: 16,
                latencyProfiles: [.safeLowLatency],
                rxBufferProfiles: [.direct, .small],
                supportsMatrixMetadata: true
            ),
            video: VideoCapabilities(
                supportedRoles: [.disabled, .testPattern, .blackmagicInput, .atemProgram, .atemPreview, .avFoundationDevice],
                supportedPixelFormats: [.disabled, .rgb24, .bgra8, .yuv422],
                supportedTransportFormats: [.disabled, .rawFrameFragment, .jpegXSFrameFragment],
                maxWidth: 1_920,
                maxHeight: 1_080,
                maxFrameRateNumerator: 60,
                maxEnabledStreams: VideoTransportRunConfiguration.maximumStreamCount
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
