import Foundation

public enum LoLaParityFeatureCategory: String, Codable, Equatable, Sendable {
    case topology
    case video
    case appRuntime
    case monitoring
    case session
    case recording
    case testSignal
    case windowsCompatibility = "compatibility"
}

public enum LoLaParityFeatureStatus: String, Codable, Equatable, Sendable {
    case deferred
    case requested
    case measured
}

public struct LoLaParityDeferredFeature: Codable, Equatable, Sendable {
    public var featureId: String
    public var title: String
    public var category: LoLaParityFeatureCategory
    public var status: LoLaParityFeatureStatus
    public var promotionGate: String
    public var requiredEvidenceBeforePromotion: [String]
    public var ownMeasuredReportId: String
    public var preservesDefaultAudioPlayoutLatency: Bool
    public var changesNativeUdpPcmDefaults: Bool
    public var uiOwnsRealtimePaths: Bool
    public var notes: String

    public init(
        featureId: String,
        title: String,
        category: LoLaParityFeatureCategory,
        status: LoLaParityFeatureStatus,
        promotionGate: String,
        requiredEvidenceBeforePromotion: [String],
        ownMeasuredReportId: String,
        preservesDefaultAudioPlayoutLatency: Bool,
        changesNativeUdpPcmDefaults: Bool,
        uiOwnsRealtimePaths: Bool,
        notes: String
    ) {
        self.featureId = featureId
        self.title = title
        self.category = category
        self.status = status
        self.promotionGate = promotionGate
        self.requiredEvidenceBeforePromotion = requiredEvidenceBeforePromotion
        self.ownMeasuredReportId = ownMeasuredReportId
        self.preservesDefaultAudioPlayoutLatency = preservesDefaultAudioPlayoutLatency
        self.changesNativeUdpPcmDefaults = changesNativeUdpPcmDefaults
        self.uiOwnsRealtimePaths = uiOwnsRealtimePaths
        self.notes = notes
    }
}

public enum LoLaParityDeferredValidationError: Error, Equatable, Sendable,
    ValidationEmptyFieldError,
    ValidationEmptyListError {
    case emptyField(String)
    case emptyList(String)
    case duplicateFeatureId(String)
    case measuredFeatureWithoutReport(String)
    case passWithoutMeasuredRun
    case passBlocksFastestPath
    case passWithoutG10PromotionGate
    case passWithoutNativePacketDefaultProtection
    case passWithoutMeasuredFeatureReport(String)
    case passWithDefaultAudioLatencyRisk(String)
    case passChangesNativePacketDefaults(String)
    case passWithUIRealtimeOwnership(String)
}

public struct LoLaParityDeferredLedgerReport: ReportValidatingArtifact, Codable, Equatable, Sendable {
    public var id: String
    public var title: String
    public var capturedAt: String
    public var runMode: MeasurementMethodology
    public var nativePacketContractId: String
    public var nativePacketContractDefaultsProtected: Bool
    public var g10PassRequiredBeforePromotion: Bool
    public var fastestPathBlockedByParity: Bool
    public var features: [LoLaParityDeferredFeature]
    public var verdict: MeasurementVerdict
    public var notes: String

    public init(
        id: String,
        title: String,
        capturedAt: String,
        runMode: MeasurementMethodology,
        nativePacketContractId: String,
        nativePacketContractDefaultsProtected: Bool,
        g10PassRequiredBeforePromotion: Bool,
        fastestPathBlockedByParity: Bool,
        features: [LoLaParityDeferredFeature],
        verdict: MeasurementVerdict,
        notes: String
    ) {
        self.id = id
        self.title = title
        self.capturedAt = capturedAt
        self.runMode = runMode
        self.nativePacketContractId = nativePacketContractId
        self.nativePacketContractDefaultsProtected = nativePacketContractDefaultsProtected
        self.g10PassRequiredBeforePromotion = g10PassRequiredBeforePromotion
        self.fastestPathBlockedByParity = fastestPathBlockedByParity
        self.features = features
        self.verdict = verdict
        self.notes = notes
    }

    public static func decode(from data: Data) throws -> LoLaParityDeferredLedgerReport {
        try JSONDecoder().decode(LoLaParityDeferredLedgerReport.self, from: data)
    }

    public func validate() throws {
        try validateIdentity()
        try validateFeatures()
        try VerdictValidationPolicy.validatePass(verdict) {
            try validatePassVerdict()
        }
    }

    private func validateIdentity() throws {
        try LoLaParityDeferredValidator.requireNonEmpty(id, "id")
        try LoLaParityDeferredValidator.requireNonEmpty(title, "title")
        try LoLaParityDeferredValidator.requireNonEmpty(capturedAt, "capturedAt")
        try LoLaParityDeferredValidator.requireNonEmpty(nativePacketContractId, "nativePacketContractId")
        try LoLaParityDeferredValidator.requireNonEmpty(notes, "notes")
    }

    private func validateFeatures() throws {
        guard !features.isEmpty else {
            throw LoLaParityDeferredValidationError.emptyList("features")
        }

        var seenIds: Set<String> = []
        for feature in features {
            try LoLaParityDeferredValidator.requireNonEmpty(feature.featureId, "features.featureId")
            try LoLaParityDeferredValidator.requireNonEmpty(feature.title, "features.title")
            try LoLaParityDeferredValidator.requireNonEmpty(feature.promotionGate, "features.promotionGate")
            try LoLaParityDeferredValidator.requireNonEmpty(feature.notes, "features.notes")
            guard !feature.requiredEvidenceBeforePromotion.isEmpty else {
                throw LoLaParityDeferredValidationError.emptyList("features.requiredEvidenceBeforePromotion")
            }
            for evidence in feature.requiredEvidenceBeforePromotion {
                try LoLaParityDeferredValidator.requireNonEmpty(evidence, "features.requiredEvidenceBeforePromotion")
            }
            guard seenIds.insert(feature.featureId).inserted else {
                throw LoLaParityDeferredValidationError.duplicateFeatureId(feature.featureId)
            }
            if feature.status == .measured && feature.ownMeasuredReportId.isEmpty {
                throw LoLaParityDeferredValidationError.measuredFeatureWithoutReport(feature.featureId)
            }
        }
    }

    private func validatePassVerdict() throws {
        guard runMode == .measured else {
            throw LoLaParityDeferredValidationError.passWithoutMeasuredRun
        }
        guard !fastestPathBlockedByParity else {
            throw LoLaParityDeferredValidationError.passBlocksFastestPath
        }
        guard g10PassRequiredBeforePromotion else {
            throw LoLaParityDeferredValidationError.passWithoutG10PromotionGate
        }
        guard nativePacketContractDefaultsProtected else {
            throw LoLaParityDeferredValidationError.passWithoutNativePacketDefaultProtection
        }
        for feature in features {
            guard feature.status == .measured, !feature.ownMeasuredReportId.isEmpty else {
                throw LoLaParityDeferredValidationError.passWithoutMeasuredFeatureReport(feature.featureId)
            }
            guard feature.preservesDefaultAudioPlayoutLatency else {
                throw LoLaParityDeferredValidationError.passWithDefaultAudioLatencyRisk(feature.featureId)
            }
            guard !feature.changesNativeUdpPcmDefaults else {
                throw LoLaParityDeferredValidationError.passChangesNativePacketDefaults(feature.featureId)
            }
            guard !feature.uiOwnsRealtimePaths else {
                throw LoLaParityDeferredValidationError.passWithUIRealtimeOwnership(feature.featureId)
            }
        }
    }
}

public enum LoLaParityDeferredFixtures {
    public static func partialLedger() -> LoLaParityDeferredLedgerReport {
        LoLaParityDeferredLedgerReport(
            id: "g16-lola-parity-deferred-synthetic-smoke",
            title: "Synthetic G16 LoLa parity deferred ledger",
            capturedAt: "2026-05-03T00:00:00Z",
            runMode: .synthetic,
            nativePacketContractId: "m04-udp-pcm-packet-contract",
            nativePacketContractDefaultsProtected: true,
            g10PassRequiredBeforePromotion: true,
            fastestPathBlockedByParity: false,
            features: syntheticDeferredFeatures(),
            verdict: .partial,
            notes: "Synthetic deferred parity ledger; no LoLa parity feature is promoted into the fastest Mac-native path."
        )
    }
}

private struct LoLaParityDeferredFeatureDraft {
    var featureId: String
    var title: String
    var category: LoLaParityFeatureCategory
    var promotionGate: String
    var requiredEvidence: [String]
    var notes: String
}

private let syntheticLoLaParityDeferredFeatureDrafts: [LoLaParityDeferredFeatureDraft] = [
    LoLaParityDeferredFeatureDraft(
        featureId: "three-host-topology",
        title: "Three-host connection",
        category: .topology,
        promotionGate: "after-g10-pass",
        requiredEvidence: ["G10", "M05"],
        notes: "Requires a separate topology report and fanout latency proof after G10."
    ),
    LoLaParityDeferredFeatureDraft(
        featureId: "multicamera-switching",
        title: "Multicamera switching",
        category: .video,
        promotionGate: "after-g10-pass",
        requiredEvidence: ["G07", "G08", "G09", "G10"],
        notes: "Requires G07-G09 evidence and switching outside audio deadlines."
    ),
    LoLaParityDeferredFeatureDraft(
        featureId: "local-remote-rendering-windows",
        title: "Local and remote rendering windows",
        category: .appRuntime,
        promotionGate: "after-g13-pass",
        requiredEvidence: ["G09", "G13"],
        notes: "Requires app observation only; rendering windows cannot own realtime paths."
    ),
    LoLaParityDeferredFeatureDraft(
        featureId: "network-monitoring",
        title: "Network monitoring",
        category: .monitoring,
        promotionGate: "after-g13-pass",
        requiredEvidence: ["G05", "G13"],
        notes: "Requires read-only metrics surfaces and no audio callback logging."
    ),
    LoLaParityDeferredFeatureDraft(
        featureId: "buffer-tuning",
        title: "Buffer tuning",
        category: .appRuntime,
        promotionGate: "after-g10-pass",
        requiredEvidence: ["G03", "G10", "G13"],
        notes: "Requires explicit user action and measured proof that defaults do not grow."
    ),
    LoLaParityDeferredFeatureDraft(
        featureId: "connect-disconnect-negotiation",
        title: "Connect and disconnect negotiation",
        category: .session,
        promotionGate: "after-g10-pass",
        requiredEvidence: ["G04", "G10"],
        notes: "Requires a separate session state report outside audio packet deadlines."
    ),
    LoLaParityDeferredFeatureDraft(
        featureId: "bounce-back",
        title: "Bounce-back",
        category: .session,
        promotionGate: "after-g10-pass",
        requiredEvidence: ["G05", "G10"],
        notes: "Requires its own route and latency report before promotion."
    ),
    LoLaParityDeferredFeatureDraft(
        featureId: "audio-video-test-signals",
        title: "Audio and video test signals",
        category: .testSignal,
        promotionGate: "after-g10-pass",
        requiredEvidence: ["G07", "G10"],
        notes: "Requires synthetic signal generation outside realtime audio deadlines."
    ),
    LoLaParityDeferredFeatureDraft(
        featureId: "chat-session-monitoring",
        title: "Chat, session save/load, and monitor UI",
        category: .appRuntime,
        promotionGate: "after-g13-pass",
        requiredEvidence: ["G13"],
        notes: "Requires app/runtime observation after G13 without realtime ownership."
    ),
    LoLaParityDeferredFeatureDraft(
        featureId: "recording-tools",
        title: "Recording tools",
        category: .recording,
        promotionGate: "after-g14-pass",
        requiredEvidence: ["G14"],
        notes: "Requires G14 side-lane recording evidence before parity tooling."
    ),
    LoLaParityDeferredFeatureDraft(
        featureId: "windows-wire-compatibility",
        title: "Windows LoLa wire compatibility",
        category: .windowsCompatibility,
        promotionGate: "separate-compatibility-mode-only",
        requiredEvidence: ["G04", "G10", "G16"],
        notes: "Requires a separate compatibility mode with captures against a live Windows LoLa peer."
    ),
]

private func syntheticDeferredFeatures() -> [LoLaParityDeferredFeature] {
    syntheticLoLaParityDeferredFeatureDrafts.map(deferredFeature)
}

private func deferredFeature(_ draft: LoLaParityDeferredFeatureDraft) -> LoLaParityDeferredFeature {
    LoLaParityDeferredFeature(
        featureId: draft.featureId,
        title: draft.title,
        category: draft.category,
        status: .deferred,
        promotionGate: draft.promotionGate,
        requiredEvidenceBeforePromotion: draft.requiredEvidence,
        ownMeasuredReportId: "",
        preservesDefaultAudioPlayoutLatency: true,
        changesNativeUdpPcmDefaults: false,
        uiOwnsRealtimePaths: false,
        notes: draft.notes
    )
}
