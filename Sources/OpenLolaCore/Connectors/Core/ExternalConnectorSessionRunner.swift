import Foundation

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
        let diagnosticLoLaMedia: LoLaCompatibilityMediaSessionReport?
        do {
            diagnosticLoLaMedia = try makeLoLaMediaSessionEvidence(configuration, allowRealMedia: false)
        } catch {
            diagnosticLoLaMedia = loLaMediaRuntimeFailureReport(configuration: configuration, error: error)
        }

        if configuration.dryRun {
            return ExternalConnectorSessionReport(
                id: "external-connector-\(configuration.connector.rawValue)-\(configuration.role.rawValue)-dry-run",
                capturedAt: capturedAt,
                connector: configuration.connector,
                role: configuration.role,
                dryRun: true,
                plan: plan,
                process: nil,
                auxiliaryProcesses: [],
                lolaControl: nil,
                lolaMedia: diagnosticLoLaMedia,
                verdict: .partial,
                notes: "Dry run only. The connector plan is protocol-aware, but no endpoint was launched or observed."
            )
        }

        switch plan.launchKind {
        case .internalLoLaControl, .internalLoLaControlUdp:
            let attempt = try runLoLaControlExchangeAttempt(
                configuration: configuration,
                onReceiveReady: loLaControlReady
            )
            if let runtimeError = attempt.runtimeError {
                return ExternalConnectorSessionReport(
                    id: "external-connector-lola-\(configuration.role.rawValue)-control-fail",
                    capturedAt: capturedAt,
                    connector: configuration.connector,
                    role: configuration.role,
                    dryRun: false,
                    plan: plan,
                    process: nil,
                    auxiliaryProcesses: [],
                    lolaControl: attempt.exchange,
                    lolaMedia: diagnosticLoLaMedia,
                    runtimeError: runtimeError,
                    verdict: .fail,
                    notes: appendLoLaControlNetworkPreflightNote(
                        "LoLa control \(configuration.controlTransport.rawValue.uppercased()) was attempted, and the partial sent/received control exchange was recorded before failure. Source-level A/V media envelope evidence is still attached for diagnostics.",
                        configuration: configuration
                    )
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
                retryResponder?.runtimeError,
            ].compactMap { $0 }
            let runtimeError = runtimeErrors.isEmpty ? nil : runtimeErrors.joined(separator: "; ")
            return ExternalConnectorSessionReport(
                id: "external-connector-lola-\(configuration.role.rawValue)-control-run",
                capturedAt: capturedAt,
                connector: configuration.connector,
                role: configuration.role,
                dryRun: false,
                plan: plan,
                process: nil,
                auxiliaryProcesses: [],
                lolaControl: attempt.exchange,
                lolaControlRetryResponder: retryResponder,
                lolaMedia: lolaMedia,
                runtimeError: runtimeError,
                verdict: runtimeError == nil ? .partial : .fail,
                notes: appendLoLaControlNetworkPreflightNote(
                    "LoLa control \(configuration.controlTransport.rawValue.uppercased()) was exercised from local reverse-engineering facts and source-level A/V media envelope evidence was attached. Media byte compatibility remains PARTIAL until captured Windows LoLa packets validate the payload grammar.",
                    configuration: configuration
                )
            )
        case .externalProcess:
            let processGroup = runExternalProcessGroup(
                plan: plan,
                durationSeconds: configuration.durationSeconds,
                processRunner: processRunner
            )
            let runtimeError = externalProcessRuntimeError(
                primary: processGroup.primary,
                auxiliaries: processGroup.auxiliaries
            )
            return ExternalConnectorSessionReport(
                id: "external-connector-\(configuration.connector.rawValue)-\(configuration.role.rawValue)-process-run",
                capturedAt: capturedAt,
                connector: configuration.connector,
                role: configuration.role,
                dryRun: false,
                plan: plan,
                process: processGroup.primary,
                auxiliaryProcesses: processGroup.auxiliaries,
                lolaControl: nil,
                lolaMedia: nil,
                runtimeError: runtimeError,
                verdict: runtimeError == nil ? .partial : .fail,
                notes: "External connector process group launch was attempted. Primary and auxiliary processes are started together for bounded A/V runs. PASS still requires measured endpoint, route, and audio timing evidence."
            )
        }
    }
}

func shouldStartLoLaControlRetryResponder(configuration: ExternalConnectorSessionConfiguration) -> Bool {
    configuration.connector == .lola && configuration.role.receives && configuration.controlTransport == .udp
}

private func externalProcessRuntimeError(
    primary: ExternalConnectorProcessResult,
    auxiliaries: [ExternalConnectorProcessResult]
) -> String? {
    var errors: [String] = []
    appendExternalProcessRuntimeError(primary, label: "primary", to: &errors)
    for (index, auxiliary) in auxiliaries.enumerated() {
        appendExternalProcessRuntimeError(auxiliary, label: "auxiliary \(index)", to: &errors)
    }
    return errors.isEmpty ? nil : errors.joined(separator: "; ")
}

private func appendExternalProcessRuntimeError(
    _ result: ExternalConnectorProcessResult,
    label: String,
    to errors: inout [String]
) {
    if !result.launched {
        errors.append("\(label) process launch failed: \(result.error ?? "unknown error")")
    } else if !result.terminatedAfterDuration, let exitStatus = result.exitStatus {
        errors.append(exitStatus == 0 ? "\(label) process exited before duration with status 0" : "\(label) process exited with status \(exitStatus)")
    }
}

private func lolaMediaRuntimeError(_ report: LoLaCompatibilityMediaSessionReport?) -> String? {
    guard let report, report.verdict == .fail else {
        return nil
    }
    return report.runtimeError ?? "LoLa media runtime failed"
}

private func makeLoLaMediaSessionEvidence(
    _ configuration: ExternalConnectorSessionConfiguration,
    allowRealMedia: Bool
) throws -> LoLaCompatibilityMediaSessionReport? {
    guard configuration.connector == .lola else {
        return nil
    }
    if allowRealMedia, !configuration.dryRun, configuration.rawLinkInterface == nil {
        switch configuration.role {
        case .tx:
            return try LoLaUdpMediaTransmitRunner.run(sessionConfiguration: configuration)
        case .rx:
            return try LoLaUdpMediaReceiveRunner.run(configuration: LoLaUdpMediaReceiveRunConfiguration(
                localHost: configuration.localHost,
                peer: configuration.peer.isEmpty ? "0.0.0.0" : configuration.peer,
                outputPath: configuration.outputPath,
                dryRun: false,
                maxDatagrams: lolaMediaFrameReadCount(configuration),
                mediaMode: configuration.mediaMode,
                audioPort: configuration.audioPort,
                videoPort: configuration.videoPort,
                videoWidth: configuration.videoWidth,
                videoHeight: configuration.videoHeight,
                videoBitsPerPixel: configuration.videoBitsPerPixel,
                timeoutSeconds: configuration.durationSeconds
            ))
        case .txRx:
            return try LoLaUdpMediaBidirectionalRunner.run(
                configuration: configuration,
            )
        }
    }
    return try LoLaConnectorRawLinkMediaEvidence.build(configuration)
}

private func lolaMediaFrameReadCount(_ configuration: ExternalConnectorSessionConfiguration) -> Int {
    LoLaCompatibilityMediaCodec.expectedDatagramCount(
        mediaMode: configuration.mediaMode,
        videoWidth: configuration.videoWidth,
        videoHeight: configuration.videoHeight,
        videoBitsPerPixel: configuration.videoBitsPerPixel,
        frameCountPerStream: configuration.mediaPacketCount
    )
}

private func loLaMediaRuntimeFailureReport(
    configuration: ExternalConnectorSessionConfiguration,
    error: Error
) -> LoLaCompatibilityMediaSessionReport {
    LoLaCompatibilityMediaSessionReport(
        id: "lola-media-\(configuration.role.rawValue)-runtime-fail",
        capturedAt: ISO8601DateFormatter().string(from: Date()),
        role: LoLaCompatibilityMediaSessionRole(rawValue: configuration.role.rawValue) ?? .tx,
        mediaMode: configuration.mediaMode,
        frames: [],
        realLinkTransmitted: !configuration.dryRun,
        verdict: .fail,
        runtimeError: String(describing: error),
        localHost: configuration.localHost,
        peer: configuration.peer,
        audioPort: configuration.audioPort,
        videoPort: configuration.videoPort,
        timeoutSeconds: configuration.durationSeconds,
        expectedDatagramCount: lolaMediaFrameReadCount(configuration),
        evidenceBoundary: LoLaCompatibilityMediaModel.evidenceBoundary,
        notes: "LoLa media runtime failed before a bounded payload set could be sent or decoded."
    )
}
