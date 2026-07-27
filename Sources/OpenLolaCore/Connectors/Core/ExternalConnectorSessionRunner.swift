// Parses session commands, validates connector settings, and dispatches the selected runtime path.
import Foundation

/// Owns the execution lifecycle for external connector session.
public enum ExternalConnectorSessionRunner {
    public static func run(
        configuration: ExternalConnectorSessionConfiguration
    ) throws -> ExternalConnectorSessionReport {
        try run(configuration: configuration, processRunner: RealExternalConnectorProcessRunner())
    }

        static func run(
        configuration: ExternalConnectorSessionConfiguration,
        processRunner: any ExternalConnectorProcessRunning,
        loLaControlReady: (@Sendable () -> Void)? = nil
    ) throws -> ExternalConnectorSessionReport {
        let plan = try ExternalConnectorLaunchPlan.build(configuration: configuration)
        let capturedAt = ISO8601DateFormatter().string(from: Date())
        let diagnosticLoLaMedia = makeDiagnosticLoLaMediaSessionEvidence(configuration)

        if configuration.dryRun {
            return makeDryRunReport(
                configuration: configuration,
                plan: plan,
                capturedAt: capturedAt,
                diagnosticLoLaMedia: diagnosticLoLaMedia
            )
        }

        switch plan.launchKind {
        case .internalLoLaControl, .internalLoLaControlUdp:
            return try runLoLaControlSession(
                configuration: configuration,
                capturedAt: capturedAt,
                plan: plan,
                diagnosticLoLaMedia: diagnosticLoLaMedia,
                loLaControlReady: loLaControlReady
            )
        case .internalUltraGridMvtp:
            return runUltraGridMvtpSession(configuration: configuration, capturedAt: capturedAt, plan: plan)
        case .internalJackTripAudio:
            return runJackTripAudioSession(
                configuration: configuration,
                capturedAt: capturedAt,
                plan: plan,
                processRunner: processRunner
            )
        case .externalProcess:
            return runExternalProcessSession(
                configuration: configuration,
                capturedAt: capturedAt,
                plan: plan,
                processRunner: processRunner
            )
        }
    }

}

private func makeDiagnosticLoLaMediaSessionEvidence(
        _ configuration: ExternalConnectorSessionConfiguration
    ) -> LoLaCompatibilityMediaSessionReport? {
        do {
            return try makeLoLaMediaSessionEvidence(configuration, allowRealMedia: false)
        } catch {
            return loLaMediaRuntimeFailureReport(configuration: configuration, error: error)
        }
    }

private func makeDryRunReport(
        configuration: ExternalConnectorSessionConfiguration,
        plan: ExternalConnectorLaunchPlan,
        capturedAt: String,
        diagnosticLoLaMedia: LoLaCompatibilityMediaSessionReport?
    ) -> ExternalConnectorSessionReport {
        { () -> ExternalConnectorSessionReport in
  var input = ExternalConnectorSessionReportInput(
    id: "external-connector-\(configuration.connector.rawValue)-\(configuration.role.rawValue)-dry-run",
    capturedAt: capturedAt,
    connector: configuration.connector,
    role: configuration.role,
    dryRun: true,
    plan: plan,
    verdict: .partial,
    notes: "Dry run only. The connector plan is protocol-aware, but no endpoint was launched or observed."
  )
  input.process = nil
  input.auxiliaryProcesses = []
  input.lolaControl = nil
  input.lolaMedia = diagnosticLoLaMedia
  return ExternalConnectorSessionReport(input)
}()
    }

private func runLoLaControlSession(
        configuration: ExternalConnectorSessionConfiguration,
        capturedAt: String,
        plan: ExternalConnectorLaunchPlan,
        diagnosticLoLaMedia: LoLaCompatibilityMediaSessionReport?,
        loLaControlReady: (@Sendable () -> Void)?
    ) throws -> ExternalConnectorSessionReport {
let attempt = try runLoLaControlExchangeAttempt(
configuration: configuration,
onReceiveReady: loLaControlReady
)
let context = LoLaControlSessionReportContext(
configuration: configuration,
capturedAt: capturedAt,
plan: plan,
attempt: attempt
)
if let runtimeError = attempt.runtimeError {
return failedLoLaControlSessionReport(
context: context,
diagnosticLoLaMedia: diagnosticLoLaMedia,
runtimeError: runtimeError
)
}
        let retryResponder = shouldStartLoLaControlRetryResponder(configuration: configuration)
            ? startLoLaControlRetryResponder(configuration: configuration)
            : nil
        let lolaMedia: LoLaCompatibilityMediaSessionReport?
        do {
            lolaMedia = try makeLoLaMediaSessionEvidence(configuration, allowRealMedia: true)
        } catch {
            lolaMedia = loLaMediaRuntimeFailureReport(configuration: configuration, error: error)
        }
        let mediaRuntimeError = lolaMediaRuntimeError(lolaMedia)
let runtimeErrors = [
mediaRuntimeError,
retryResponder?.runtimeError
].compactMap { $0 }
let runtimeError = runtimeErrors.isEmpty ? nil : runtimeErrors.joined(separator: "; ")
return successfulLoLaControlSessionReport(
context: context,
retryResponder: retryResponder,
lolaMedia: lolaMedia,
runtimeError: runtimeError
)
}

private struct LoLaControlSessionReportContext {
 let configuration: ExternalConnectorSessionConfiguration
 let capturedAt: String
 let plan: ExternalConnectorLaunchPlan
 let attempt: LoLaControlExchangeAttempt
}

private func failedLoLaControlSessionReport(
    context: LoLaControlSessionReportContext,
    diagnosticLoLaMedia: LoLaCompatibilityMediaSessionReport?,
    runtimeError: String
) -> ExternalConnectorSessionReport {
 let configuration = context.configuration
return { () -> ExternalConnectorSessionReport in
  var input = ExternalConnectorSessionReportInput(
    id: "external-connector-lola-\(configuration.role.rawValue)-control-fail",
    capturedAt: context.capturedAt,
    connector: configuration.connector,
    role: configuration.role,
    dryRun: false,
    plan: context.plan,
    verdict: .fail,
    notes: appendLoLaControlNetworkPreflightNote(
            "LoLa control \(configuration.controlTransport.rawValue.uppercased()) was attempted, "
                + "and the partial sent/received control exchange was recorded before failure. "
                + "Source-level A/V media envelope evidence is still attached for diagnostics.",
            configuration: configuration
        )
  )
  input.process = nil
  input.auxiliaryProcesses = []
  input.lolaControl = context.attempt.exchange
  input.lolaMedia = diagnosticLoLaMedia
  input.runtimeError = runtimeError
  return ExternalConnectorSessionReport(input)
}()
}
private func successfulLoLaControlSessionReport(
    context: LoLaControlSessionReportContext,
    retryResponder: LoLaControlRetryResponderReport?,
    lolaMedia: LoLaCompatibilityMediaSessionReport?,
    runtimeError: String?
) -> ExternalConnectorSessionReport {
 let configuration = context.configuration
return { () -> ExternalConnectorSessionReport in
  var input = ExternalConnectorSessionReportInput(
    id: "external-connector-lola-\(configuration.role.rawValue)-control-run",
    capturedAt: context.capturedAt,
    connector: configuration.connector,
    role: configuration.role,
    dryRun: false,
    plan: context.plan,
    verdict: runtimeError == nil ? .partial : .fail,
    notes: appendLoLaControlNetworkPreflightNote(
            "LoLa control \(configuration.controlTransport.rawValue.uppercased()) was exercised "
                + "from local reverse-engineering facts and source-level A/V media envelope "
                + "evidence was attached. Media byte compatibility remains PARTIAL until "
                + "captured Windows LoLa packets validate the payload grammar.",
            configuration: configuration
        )
  )
  input.process = nil
  input.auxiliaryProcesses = []
  input.lolaControl = context.attempt.exchange
  input.lolaControlRetryResponder = retryResponder
  input.lolaMedia = lolaMedia
  input.runtimeError = runtimeError
  return ExternalConnectorSessionReport(input)
}()
}

private func runUltraGridMvtpSession(
        configuration: ExternalConnectorSessionConfiguration,
        capturedAt: String,
        plan: ExternalConnectorLaunchPlan
    ) -> ExternalConnectorSessionReport {
        let ultraGridMedia: UltraGridCompatibilityMediaReport
        do {
            ultraGridMedia = try UltraGridCompatibilityRunner.run(configuration: configuration)
        } catch {
            return { () -> ExternalConnectorSessionReport in
  var input = ExternalConnectorSessionReportInput(
    id: "external-connector-mvtp-ultragrid-\(configuration.role.rawValue)-native-fail",
    capturedAt: capturedAt,
    connector: configuration.connector,
    role: configuration.role,
    dryRun: false,
    plan: plan,
    verdict: .fail,
    notes: "Swift-native UltraGrid RTP/MVTP runtime failed before bounded media evidence could be "
                    + "recorded."
  )
  input.process = nil
  input.auxiliaryProcesses = []
  input.lolaControl = nil
  input.ultraGridMedia = nil
  input.runtimeError = String(describing: error)
  return ExternalConnectorSessionReport(input)
}()
        }
        return { () -> ExternalConnectorSessionReport in
  var input = ExternalConnectorSessionReportInput(
    id: "external-connector-mvtp-ultragrid-\(configuration.role.rawValue)-native-run",
    capturedAt: capturedAt,
    connector: configuration.connector,
    role: configuration.role,
    dryRun: false,
    plan: plan,
    verdict: ultraGridMedia.verdict,
    notes: "Swift-native UltraGrid RTP/MVTP media was exercised for the bounded session. PASS still "
                + "requires measured UltraGrid peer evidence, route evidence, and audio/video timing "
                + "evidence."
  )
  input.process = nil
  input.auxiliaryProcesses = []
  input.lolaControl = nil
  input.ultraGridMedia = ultraGridMedia
  input.runtimeError = ultraGridMedia.runtimeError
  return ExternalConnectorSessionReport(input)
}()
    }

private func runJackTripAudioSession(
        configuration: ExternalConnectorSessionConfiguration,
        capturedAt: String,
        plan: ExternalConnectorLaunchPlan,
        processRunner: any ExternalConnectorProcessRunning
    ) -> ExternalConnectorSessionReport {
        let jackTripMedia: JackTripCompatibilityMediaReport
        let auxiliaryProcesses = runExternalAuxiliaryProcessGroup(
            plan: plan,
            durationSeconds: configuration.durationSeconds,
            processRunner: processRunner
        )
        do {
            jackTripMedia = try JackTripCompatibilityRunner.run(configuration: configuration)
        } catch {
            let auxiliaryRuntimeError = externalAuxiliaryProcessRuntimeError(auxiliaryProcesses)
            let errors = [
                String(describing: error),
                auxiliaryRuntimeError
            ].compactMap { $0 }
            return failedJackTripAudioSessionReport(
                configuration: configuration,
                capturedAt: capturedAt,
                plan: plan,
                auxiliaryProcesses: auxiliaryProcesses,
                runtimeError: errors.joined(separator: "; ")
            )
        }
        let auxiliaryRuntimeError = externalAuxiliaryProcessRuntimeError(auxiliaryProcesses)
let runtimeError = [
jackTripMedia.runtimeError,
auxiliaryRuntimeError
].compactMap { $0 }.joined(separator: "; ")
let context = JackTripSessionReportContext(
configuration: configuration,
capturedAt: capturedAt,
plan: plan,
auxiliaryProcesses: auxiliaryProcesses
)
return successfulJackTripAudioSessionReport(
context: context,
jackTripMedia: jackTripMedia,
runtimeError: runtimeError
)
}

private func failedJackTripAudioSessionReport(
    configuration: ExternalConnectorSessionConfiguration,
    capturedAt: String,
    plan: ExternalConnectorLaunchPlan,
    auxiliaryProcesses: [ExternalConnectorProcessResult],
    runtimeError: String
) -> ExternalConnectorSessionReport {
    { () -> ExternalConnectorSessionReport in
  var input = ExternalConnectorSessionReportInput(
    id: "external-connector-jacktrip-\(configuration.role.rawValue)-native-fail",
    capturedAt: capturedAt,
    connector: configuration.connector,
    role: configuration.role,
    dryRun: false,
    plan: plan,
    verdict: .fail,
    notes: "Swift-native JackTrip UDP audio runtime failed before bounded media evidence could be "
            + "recorded."
  )
  input.process = nil
  input.auxiliaryProcesses = auxiliaryProcesses
  input.lolaControl = nil
  input.jackTripMedia = nil
  input.runtimeError = runtimeError
  return ExternalConnectorSessionReport(input)
}()
}

private struct JackTripSessionReportContext {
let configuration: ExternalConnectorSessionConfiguration
let capturedAt: String
let plan: ExternalConnectorLaunchPlan
let auxiliaryProcesses: [ExternalConnectorProcessResult]
}

private func successfulJackTripAudioSessionReport(
    context: JackTripSessionReportContext,
    jackTripMedia: JackTripCompatibilityMediaReport,
    runtimeError: String
) -> ExternalConnectorSessionReport {
let configuration = context.configuration
return { () -> ExternalConnectorSessionReport in
  var input = ExternalConnectorSessionReportInput(
    id: "external-connector-jacktrip-\(configuration.role.rawValue)-native-run",
    capturedAt: context.capturedAt,
    connector: configuration.connector,
    role: configuration.role,
    dryRun: false,
    plan: context.plan,
    verdict: runtimeError.isEmpty ? jackTripMedia.verdict : .fail,
    notes: "Swift-native JackTrip UDP audio was exercised for the bounded session. PASS still "
            + "requires measured JackTrip peer evidence, route evidence, and audio timing evidence."
  )
  input.process = nil
  input.auxiliaryProcesses = context.auxiliaryProcesses
  input.lolaControl = nil
  input.jackTripMedia = jackTripMedia
  input.runtimeError = runtimeError.isEmpty ? nil : runtimeError
  return ExternalConnectorSessionReport(input)
}()
}
