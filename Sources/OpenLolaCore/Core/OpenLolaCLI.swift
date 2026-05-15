import Foundation

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

    public static func sessionCapabilitiesData() throws -> Data {
        try validatedJSONData(localCapabilitySet) {
            try $0.validate()
        }
    }

    public static func sessionCapabilitiesJSONString() throws -> String {
        String(decoding: try sessionCapabilitiesData(), as: UTF8.self)
    }

    public static func fixtureSmokeMatrixData() throws -> Data {
        try jsonData(FixtureSmokeMatrix.report)
    }

    public static func fixtureSmokeMatrixJSONString() throws -> String {
        String(decoding: try fixtureSmokeMatrixData(), as: UTF8.self)
    }

    public static func commandInventoryData() throws -> Data {
        try jsonData(CLICommandInventory.report)
    }

    public static func commandInventoryJSONString() throws -> String {
        String(decoding: try commandInventoryData(), as: UTF8.self)
    }

    public static func reportSchemaInventoryData() throws -> Data {
        try jsonData(ReportSchemaInventory.report)
    }

    public static func reportSchemaInventoryJSONString() throws -> String {
        String(decoding: try reportSchemaInventoryData(), as: UTF8.self)
    }

    public static func goalCodewiseClosureData() throws -> Data {
        try validatedJSONData(GoalCodewiseClosureReport.codewiseClosure) {
            try $0.validate()
        }
    }

    public static func goalCodewiseClosureJSONString() throws -> String {
        String(decoding: try goalCodewiseClosureData(), as: UTF8.self)
    }

    public static func goalRuntimeEvidenceTemplateData() throws -> Data {
        try validatedJSONData(GoalRuntimeEvidenceTemplateReport.template) {
            try $0.validate()
        }
    }

    public static func goalRuntimeEvidenceTemplateJSONString() throws -> String {
        String(decoding: try goalRuntimeEvidenceTemplateData(), as: UTF8.self)
    }

    public static func goalRuntimePreflightData() throws -> Data {
        try validatedJSONData(GoalRuntimePreflightRunner.run) {
            try $0.validate()
        }
    }

    public static func goalRuntimePreflightJSONString() throws -> String {
        String(decoding: try goalRuntimePreflightData(), as: UTF8.self)
    }

    public static func goalCompletionAuditData() throws -> Data {
        try validatedJSONData({ GoalCompletionAuditRunner.run() }) {
            try $0.validate()
        }
    }

    public static func goalCompletionAuditJSONString() throws -> String {
        String(decoding: try goalCompletionAuditData(), as: UTF8.self)
    }

    public static func currentEvidenceStatusMatrixData() throws -> Data {
        try validatedJSONData(CurrentEvidenceStatusMatrixReport.current) {
            try $0.validate()
        }
    }

    public static func currentEvidenceStatusMatrixJSONString() throws -> String {
        String(decoding: try currentEvidenceStatusMatrixData(), as: UTF8.self)
    }

    public static func realtimeAudioPathInventoryData() throws -> Data {
        try jsonData(RealtimeAudioPathInventory.report)
    }

    public static func realtimeAudioPathInventoryJSONString() throws -> String {
        String(decoding: try realtimeAudioPathInventoryData(), as: UTF8.self)
    }

    public static func networkRouteCommandMatrixData() throws -> Data {
        try jsonData(NetworkRouteCommandMatrix.report)
    }

    public static func networkRouteCommandMatrixJSONString() throws -> String {
        String(decoding: try networkRouteCommandMatrixData(), as: UTF8.self)
    }

    public static func videoControlDegradeMatrixData() throws -> Data {
        try jsonData(VideoControlDegradeMatrix.report)
    }

    public static func videoControlDegradeMatrixJSONString() throws -> String {
        String(decoding: try videoControlDegradeMatrixData(), as: UTF8.self)
    }

    public static func sourceOwnershipInventoryData() throws -> Data {
        try jsonData(SourceOwnershipInventory.report)
    }

    public static func sourceOwnershipInventoryJSONString() throws -> String {
        String(decoding: try sourceOwnershipInventoryData(), as: UTF8.self)
    }

    private static func jsonData<Report>(
        _ factory: () throws -> Report
    ) throws -> Data where Report: Encodable {
        try JSONReportCoder.prettyJSONData(for: factory())
    }

    private static func validatedJSONData<Report>(
        _ factory: () throws -> Report,
        validate: (Report) throws -> Void
    ) throws -> Data where Report: Encodable {
        let report = try factory()
        try validate(report)
        return try JSONReportCoder.prettyJSONData(for: report)
    }
}
