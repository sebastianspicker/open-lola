// Builds and validates a connector-session report from process, control, media, and runtime outcomes.
import Foundation

/// Collects plan, process, control, media, runtime, verdict, and note inputs for a session report.
public struct ExternalConnectorSessionReportInput: Equatable, Sendable {
  public var id: String
  public var capturedAt: String
  public var connector: ExternalConnectorKind
  public var role: ExternalConnectorSessionRole
  public var dryRun: Bool
  public var plan: ExternalConnectorLaunchPlan
  public var process: ExternalConnectorProcessResult?
  public var runtimeError: String?
  public var runtimeErrorFree: Bool?
  public var auxiliaryProcesses: [ExternalConnectorProcessResult] = []
  public var lolaControl: LoLaControlExchange?
  public var lolaControlRetryResponder: LoLaControlRetryResponderReport?
  public var lolaMedia: LoLaCompatibilityMediaSessionReport?
  public var ultraGridMedia: UltraGridCompatibilityMediaReport?
  public var jackTripMedia: JackTripCompatibilityMediaReport?
  public var verdict: MeasurementVerdict
  public var notes: String

  public init(
    id: String,
    capturedAt: String,
    connector: ExternalConnectorKind,
    role: ExternalConnectorSessionRole,
    dryRun: Bool,
    plan: ExternalConnectorLaunchPlan,
    verdict: MeasurementVerdict,
    notes: String
  ) {
    self.id = id
    self.capturedAt = capturedAt
    self.connector = connector
    self.role = role
    self.dryRun = dryRun
    self.plan = plan
    self.process = nil
    self.lolaControl = nil
    self.verdict = verdict
    self.notes = notes
  }
}

/// Records the evidence and outcome for external connector session report.
public struct ExternalConnectorSessionReport: ReportValidatingArtifact, PrettyJSONCodable, Equatable, Sendable {
    public var id: String
    public var capturedAt: String
    public var connector: ExternalConnectorKind
    public var role: ExternalConnectorSessionRole
    public var dryRun: Bool
    public var plan: ExternalConnectorLaunchPlan
    public var process: ExternalConnectorProcessResult?
    public var auxiliaryProcesses: [ExternalConnectorProcessResult]
    public var lolaControl: LoLaControlExchange?
    public var lolaControlRetryResponder: LoLaControlRetryResponderReport?
    public var lolaMedia: LoLaCompatibilityMediaSessionReport?
    public var ultraGridMedia: UltraGridCompatibilityMediaReport?
    public var jackTripMedia: JackTripCompatibilityMediaReport?
    public var runtimeError: String?
    public var runtimeErrorFree: Bool?
    public var verdict: MeasurementVerdict
    public var notes: String

  public init(_ input: ExternalConnectorSessionReportInput) {
    self.id = input.id
    self.capturedAt = input.capturedAt
    self.connector = input.connector
    self.role = input.role
    self.dryRun = input.dryRun
    self.plan = input.plan
    self.process = input.process
    self.auxiliaryProcesses = input.auxiliaryProcesses
    self.lolaControl = input.lolaControl
    self.lolaControlRetryResponder = input.lolaControlRetryResponder
    self.lolaMedia = input.lolaMedia
    self.ultraGridMedia = input.ultraGridMedia
    self.jackTripMedia = input.jackTripMedia
    self.runtimeError = input.runtimeError
    self.runtimeErrorFree = input.runtimeErrorFree ?? (input.runtimeError == nil)
    self.verdict = input.verdict
    self.notes = input.notes
  }
}

extension ExternalConnectorSessionReport {
    public func validate() throws {
        try requireExternalConnectorSessionNonEmpty(id, "id")
        try requireExternalConnectorSessionNonEmpty(capturedAt, "capturedAt")
        try requireExternalConnectorSessionNonEmpty(notes, "notes")
        if verdict == .pass, dryRun {
            throw ExternalConnectorSessionError.dryRunCannotPass
        }
        if plan.connector != connector {
            throw ExternalConnectorSessionError.invalidConnector(plan.connector.rawValue)
        }
        if plan.role != role {
            throw ExternalConnectorSessionError.invalidRole(plan.role.rawValue)
        }
        if plan.launchKind == .externalProcess, plan.executable == nil {
            throw ExternalConnectorSessionError.externalConnectorRequiresExecutable(connector)
        }
        try validateProcessResultShape()
        if verdict == .fail {
            try requireExternalConnectorSessionNonEmpty(runtimeError ?? "", "runtimeError")
        }
        try lolaMedia?.validate()
        try ultraGridMedia?.validate()
        try jackTripMedia?.validate()
        try lolaControlRetryResponder?.validate()
        try validateAuxiliaryProcesses()
        try validateMediaMode(plan.mediaProfile.mode, connector: connector)
        if verdict == .pass {
            try validatePassEvidence()
        }
        try validateTransmitPeer()
        try validateMediaProfileFlags()
        try requireExternalConnectorSessionNonEmptyList(plan.protocolFacts, "plan.protocolFacts")
        try requireExternalConnectorSessionNonEmptyList(plan.sourceReferences, "plan.sourceReferences")
        try validateSourceReferences()
    }

    private func validateTransmitPeer() throws {
        guard role.transmits, plan.peer.isEmpty else {
            return
        }
        if connector == .lola {
            throw ExternalConnectorSessionError.lolaRequiresPeerForTx
        }
        throw ExternalConnectorSessionError.connectorRequiresPeerForTx(connector)
    }

    private func validateMediaProfileFlags() throws {
        guard plan.mediaProfile.audioEnabled == plan.mediaProfile.mode.hasAudio,
              plan.mediaProfile.videoEnabled == plan.mediaProfile.mode.hasVideo else {
            throw ExternalConnectorSessionError.invalidMediaMode(plan.mediaProfile.mode.rawValue)
        }
    }

    private func validateProcessResultShape() throws {
        guard !dryRun, plan.launchKind == .externalProcess else {
            return
        }
        guard process != nil else {
            throw ExternalConnectorSessionError.processLaunchFailed("missing primary process result")
        }
        guard auxiliaryProcesses.count == plan.auxiliaryProcesses.count else {
            throw ExternalConnectorSessionError.processLaunchFailed("auxiliary process result count mismatch")
        }
    }

    private func validatePassEvidence() throws {
        guard runtimeError == nil else {
            throw ExternalConnectorSessionError.runtimePassWithRuntimeError("runtimeError")
        }
        guard runtimeErrorFree == true else {
            throw ExternalConnectorSessionError.runtimePassWithRuntimeError("runtimeErrorFree")
        }
        try validateProcessPassEvidence()
        switch connector {
        case .lola:
            try validateLoLaPassEvidence()
        case .mvtpUltraGrid:
            try validateUltraGridPassEvidence()
        case .jackTrip:
            try validateJackTripPassEvidence()
        }
    }

    private func validateLoLaPassEvidence() throws {
        guard lolaControl != nil else {
            throw ExternalConnectorSessionError.runtimePassMissingEvidence("lolaControl")
        }
        guard let lolaMedia else {
            throw ExternalConnectorSessionError.runtimePassMissingEvidence("lolaMedia")
        }
        guard lolaMedia.runtimeError == nil else {
            throw ExternalConnectorSessionError.runtimePassWithRuntimeError("lolaMedia.runtimeError")
        }
        guard lolaMedia.verdict == .pass else {
            throw ExternalConnectorSessionError.runtimePassMissingEvidence("lolaMedia.verdict")
        }
    }

    private func validateUltraGridPassEvidence() throws {
        guard let ultraGridMedia else {
            throw ExternalConnectorSessionError.runtimePassMissingEvidence("ultraGridMedia")
        }
        try validatePassMediaEvidence(
            runtimeError: ultraGridMedia.runtimeError,
            runtimeErrorFree: ultraGridMedia.runtimeErrorFree,
            verdict: ultraGridMedia.verdict,
            prefix: "ultraGridMedia"
        )
    }

    private func validateJackTripPassEvidence() throws {
        guard let jackTripMedia else {
            throw ExternalConnectorSessionError.runtimePassMissingEvidence("jackTripMedia")
        }
        try validatePassMediaEvidence(
            runtimeError: jackTripMedia.runtimeError,
            runtimeErrorFree: jackTripMedia.runtimeErrorFree,
            verdict: jackTripMedia.verdict,
            prefix: "jackTripMedia"
        )
    }

    private func validatePassMediaEvidence(
        runtimeError: String?,
        runtimeErrorFree: Bool?,
        verdict: MeasurementVerdict,
        prefix: String
    ) throws {
        guard runtimeError == nil else {
            throw ExternalConnectorSessionError.runtimePassWithRuntimeError("\(prefix).runtimeError")
        }
        guard runtimeErrorFree == true else {
            throw ExternalConnectorSessionError.runtimePassWithRuntimeError("\(prefix).runtimeErrorFree")
        }
        guard verdict == .pass else {
            throw ExternalConnectorSessionError.runtimePassMissingEvidence("\(prefix).verdict")
        }
    }

    private func validateProcessPassEvidence() throws {
        if plan.launchKind == .externalProcess {
            guard let process else {
                throw ExternalConnectorSessionError.processLaunchFailed("missing primary process result")
            }
            try validatePassProcessResult(process, label: "primary")
        }
        for (index, auxiliary) in auxiliaryProcesses.enumerated() {
            try validatePassProcessResult(auxiliary, label: "auxiliary \(index)")
        }
    }

    private func validatePassProcessResult(
        _ result: ExternalConnectorProcessResult,
        label: String
    ) throws {
        guard result.launched else {
            throw ExternalConnectorSessionError.processLaunchFailed(
                "\(label) process launch failed: \(result.error ?? "unknown error")"
            )
        }
        if result.waitStatusKnown == false {
            throw ExternalConnectorSessionError.processLaunchFailed("\(label) process exit status unknown")
        }
        if let cleanupStatus = result.cleanupStatus, cleanupStatus.hasPrefix("failed:") {
            throw ExternalConnectorSessionError.processLaunchFailed("\(label) process cleanup \(cleanupStatus)")
        }
        if !result.terminatedAfterDuration, let exitStatus = result.exitStatus {
            throw ExternalConnectorSessionError.processLaunchFailed(
                exitStatus == 0
                    ? "\(label) process exited before duration with status 0"
                    : "\(label) process exited with status \(exitStatus)"
            )
        }
    }

    private func validateAuxiliaryProcesses() throws {
        for auxiliary in plan.auxiliaryProcesses {
            try requireExternalConnectorSessionNonEmpty(auxiliary.label, "plan.auxiliaryProcesses.label")
            try requireExternalConnectorSessionNonEmpty(auxiliary.executable, "plan.auxiliaryProcesses.executable")
            try requireExternalConnectorSessionNonEmptyList(
                auxiliary.arguments,
                "plan.auxiliaryProcesses.arguments"
            )
            try requireExternalConnectorSessionNonEmptyList(
                auxiliary.protocolFacts,
                "plan.auxiliaryProcesses.protocolFacts"
            )
            try requireExternalConnectorSessionNonEmptyList(
                auxiliary.sourceReferences,
                "plan.auxiliaryProcesses.sourceReferences"
            )
        }
    }

    private func validateSourceReferences() throws {
        switch connector {
        case .lola:
            guard plan.sourceReferences.contains("docs/reverse-engineering-boundary.md") else {
                throw ExternalConnectorSessionError.missingSourceReference(connector)
            }
        case .mvtpUltraGrid:
            guard plan.sourceReferences.contains("https://github.com/CESNET/UltraGrid") else {
                throw ExternalConnectorSessionError.missingSourceReference(connector)
            }
        case .jackTrip:
            guard plan.sourceReferences.contains("https://github.com/jacktrip/jacktrip") else {
                throw ExternalConnectorSessionError.missingSourceReference(connector)
            }
        }
    }
}
