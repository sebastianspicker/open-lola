// Converts spawned process state and captured streams into bounded connector process results.
import Foundation

func runExternalProcessSession(
        configuration: ExternalConnectorSessionConfiguration,
        capturedAt: String,
        plan: ExternalConnectorLaunchPlan,
        processRunner: any ExternalConnectorProcessRunning
    ) -> ExternalConnectorSessionReport {
        let processGroup = runExternalProcessGroup(
            plan: plan,
            durationSeconds: configuration.durationSeconds,
            processRunner: processRunner
        )
        let runtimeError = externalProcessRuntimeError(
            primary: processGroup.primary,
            auxiliaries: processGroup.auxiliaries
        )
        return { () -> ExternalConnectorSessionReport in
  var input = ExternalConnectorSessionReportInput(
    id: "external-connector-\(configuration.connector.rawValue)-\(configuration.role.rawValue)-process-run",
    capturedAt: capturedAt,
    connector: configuration.connector,
    role: configuration.role,
    dryRun: false,
    plan: plan,
    verdict: runtimeError == nil ? .partial : .fail,
    notes: "External connector process group launch was attempted. Primary and auxiliary processes "
                + "are started together for bounded A/V runs. PASS still requires measured endpoint, "
                + "route, and audio timing evidence."
  )
  input.process = processGroup.primary
  input.auxiliaryProcesses = processGroup.auxiliaries
  input.lolaControl = nil
  input.lolaMedia = nil
  input.runtimeError = runtimeError
  return ExternalConnectorSessionReport(input)
}()
    }
func shouldStartLoLaControlRetryResponder(configuration: ExternalConnectorSessionConfiguration) -> Bool {
    configuration.connector == .lola && configuration.role.receives && configuration.controlTransport == .udp
}

func externalAuxiliaryProcessRuntimeError(_ auxiliaries: [ExternalConnectorProcessResult]) -> String? {
    var errors: [String] = []
    for (index, auxiliary) in auxiliaries.enumerated() {
        appendExternalProcessRuntimeError(auxiliary, label: "auxiliary \(index)", to: &errors)
    }
    return errors.isEmpty ? nil : errors.joined(separator: "; ")
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
    } else if result.waitStatusKnown == false {
        errors.append("\(label) process exit status unknown")
    } else if let cleanupStatus = result.cleanupStatus, cleanupStatus.hasPrefix("failed:") {
        errors.append("\(label) process cleanup \(cleanupStatus)")
    } else if !result.terminatedAfterDuration, let exitStatus = result.exitStatus {
        if exitStatus == 0 {
            errors.append("\(label) process exited before duration with status 0")
        } else {
            errors.append("\(label) process exited with status \(exitStatus)")
        }
    }
}

func lolaMediaRuntimeError(_ report: LoLaCompatibilityMediaSessionReport?) -> String? {
    guard let report, report.verdict == .fail else {
        return nil
    }
    return report.runtimeError ?? "LoLa media runtime failed"
}

func makeLoLaMediaSessionEvidence(
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
            return try LoLaUdpMediaReceiveRunner.run(configuration: loLaUdpMediaReceiveRunConfiguration(
                configuration,
                dryRun: false,
                maxDatagrams: lolaMediaFrameReadCount(configuration)
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

func loLaMediaRuntimeFailureReport(
    configuration: ExternalConnectorSessionConfiguration,
    error: Error
) -> LoLaCompatibilityMediaSessionReport {
    LoLaCompatibilityMediaSessionReport(input: .init(
        identity: .init(
            id: "lola-media-\(configuration.role.rawValue)-runtime-fail",
            capturedAt: ISO8601DateFormatter().string(from: Date()),
            role: LoLaCompatibilityMediaSessionRole(rawValue: configuration.role.rawValue) ?? .tx,
            mediaMode: configuration.mediaMode
        ),
        execution: .init(
            frames: [],
            realLinkTransmitted: false,
            verdict: .fail,
            runtimeError: String(describing: error)
        ),
        endpoint: .init(
            localHost: configuration.localHost,
            peer: configuration.peer,
            audioPort: configuration.audioPort,
            videoPort: configuration.videoPort,
            timeoutSeconds: configuration.durationSeconds,
            expectedDatagramCount: lolaMediaFrameReadCount(configuration),
            sentBytesTotal: nil
        ),
        evidenceBoundary: LoLaCompatibilityMediaModel.evidenceBoundary,
        notes: "LoLa media runtime failed before a bounded payload set could be sent or decoded."
    ))
}
