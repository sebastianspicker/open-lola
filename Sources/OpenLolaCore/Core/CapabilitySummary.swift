public enum DevelopmentStage: String, Sendable {
    case m00Scaffold = "M00 scaffold"
    case m02ProtocolSession = "M02 protocol/session model"
    case m14ReleaseHardening = "M14 release hardening"
    case m15PackagingFieldTest = "M15 packaging field-test"
}

public struct CapabilitySummary: Equatable, Sendable {
    public let name: String
    public let version: String
    public let stage: DevelopmentStage
    public let capabilities: [String]

    public init(
        name: String,
        version: String,
        stage: DevelopmentStage,
        capabilities: [String]
    ) {
        self.name = name
        self.version = version
        self.stage = stage
        self.capabilities = capabilities
    }

    public static let m00Scaffold = CapabilitySummary(
        name: "open-lola",
        version: "0.0.0-m00",
        stage: .m00Scaffold,
        capabilities: [
            "swift-package",
            "core-model",
            "cli-summary",
        ]
    )

    public static let m02ProtocolSession = CapabilitySummary(
        name: "open-lola",
        version: "0.0.0-m02",
        stage: .m02ProtocolSession,
        capabilities: [
            "peer-identity",
            "session-capabilities",
            "clean-room-control-json",
            "session-negotiation",
            "latency-profile-agreement",
        ]
    )

    public static let m14ReleaseHardening = CapabilitySummary(
        name: "open-lola",
        version: "0.0.0-m14",
        stage: .m14ReleaseHardening,
        capabilities: [
            "recording-session-artifacts",
            "release-hardening",
            "open-source-release-readiness",
            "goal-completion-audit",
        ]
    )

    public static let m15PackagingFieldTest = CapabilitySummary(
        name: "open-lola",
        version: "0.0.0-m15",
        stage: .m15PackagingFieldTest,
        capabilities: [
            "packaging-field-test",
            "field-runtime-proof",
            "field-readiness",
            "release-hardening",
            "goal-completion-audit",
        ]
    )

    public static let current = m15PackagingFieldTest

    public var description: String {
        "\(name) \(version) (\(stage.rawValue))"
    }
}
