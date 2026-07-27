// Coordinates release-readiness execution and its result lifecycle, keeping runtime side effects separate from protocol values and validation policy.
import Foundation

/// Creates deterministic synthetic field-runtime proof evidence that exercises report validation without claiming physical measurement.
public enum FieldReadyRuntimeSyntheticSmoke {
    public static func run() -> FieldReadyRuntimeProofReport {
        let metadata = FieldReadyRuntimeProofReport.Metadata(
            id: "p05-field-ready-runtime-synthetic-smoke",
            title: "Synthetic P05 field-ready runtime proof",
            capturedAt: "2026-05-02T00:00:00Z",
            runMode: .synthetic
        )
        let evidence = FieldReadyRuntimeProofReport.Evidence(
            p04: syntheticFieldReadyP04Evidence(),
            runtime: syntheticFieldReadyRuntimeEvidence(),
            permissions: syntheticFieldReadyPermissionEvidence(),
            recording: syntheticFieldReadyRecordingEvidence(),
            distribution: syntheticFieldReadyDistributionEvidence(),
            cleanMac: syntheticFieldReadyCleanMacEvidence()
        )
        let outcome = FieldReadyRuntimeProofReport.Outcome(
            verdict: .partial,
            notes: "Synthetic P05 proof; clean-Mac RME/ATEM/report-writing evidence remains open."
        )
        return FieldReadyRuntimeProofReport(.init(metadata: metadata, evidence: evidence, outcome: outcome))
    }
}

/// Captures run configuration required to validate, interpret, and reproduce a field-runtime proof result.
public struct FieldReadyRuntimeProofRunConfiguration: Codable, Equatable, Sendable {
    public let integratedReportPath: String
    public let appReportPath: String
    public let recordingReportPath: String
    public let packagingReportPath: String
    public let outputPath: String

    public init(
        integratedReportPath: String,
        appReportPath: String,
        recordingReportPath: String,
        packagingReportPath: String,
        outputPath: String
    ) {
        self.integratedReportPath = integratedReportPath
        self.appReportPath = appReportPath
        self.recordingReportPath = recordingReportPath
        self.packagingReportPath = packagingReportPath
        self.outputPath = outputPath
    }

    public static func parse(_ arguments: [String]) throws -> FieldReadyRuntimeProofRunConfiguration {
        let allowed = [
            "--integrated-report",
            "--app-report",
            "--recording-report",
            "--packaging-report",
            "--output"
        ]
        let values = try KeyValueArgumentParser.parseValues(
            arguments,
            allowed: Set(allowed),
            unknown: FieldReadyRuntimeProofRunConfigurationError.unknownArgument,
            duplicate: FieldReadyRuntimeProofRunConfigurationError.duplicateArgument,
            missingValue: FieldReadyRuntimeProofRunConfigurationError.missingValue
        )

        return FieldReadyRuntimeProofRunConfiguration(
            integratedReportPath: try requiredFieldRuntimeRunString("--integrated-report", values),
            appReportPath: try requiredFieldRuntimeRunString("--app-report", values),
            recordingReportPath: try requiredFieldRuntimeRunString("--recording-report", values),
            packagingReportPath: try requiredFieldRuntimeRunString("--packaging-report", values),
            outputPath: try requiredFieldRuntimeRunString("--output", values)
        )
    }
}

// swiftlint:disable:next type_name
/// Describes failures that prevent field-runtime proof inputs or evidence from satisfying the required validation invariants.
public enum FieldReadyRuntimeProofRunConfigurationError: Error, Equatable, Sendable {
    case missingRequiredArgument(String)
    case missingValue(String)
    case unknownArgument(String)
    case duplicateArgument(String)
}

/// Runs the field-runtime proof evaluation from supplied artifacts while retaining their measurement provenance in the resulting report.
public enum FieldReadyRuntimeProofRunner {
    public static func run(
        configuration: FieldReadyRuntimeProofRunConfiguration,
        integratedReport: IntegratedAvReport,
        appShellReport: NativeAppShellReport,
        recordingReport: RecordingSessionArtifactReport,
        packagingReport: PackagingFieldTestReport
    ) -> FieldReadyRuntimeProofReport {
        let metadata = FieldReadyRuntimeProofReport.Metadata(
            id: "p05-field-ready-runtime-run",
            title: "P05 field-ready runtime aggregate proof",
            capturedAt: ISO8601DateFormatter().string(from: Date()),
            runMode: .measured
        )
        let runtimeEvidence = fieldReadyRuntimeEvidence(
            integratedReport: integratedReport,
            appShellReport: appShellReport,
            recordingReport: recordingReport,
            packagingReport: packagingReport
        )
        let cleanMacEvidence = fieldReadyCleanMacEvidence(
            integratedReport: integratedReport,
            packagingReport: packagingReport
        )
        let evidence = FieldReadyRuntimeProofReport.Evidence(
            p04: fieldReadyP04Evidence(integratedReport),
            runtime: runtimeEvidence,
            permissions: fieldReadyPermissionEvidence(packagingReport),
            recording: fieldReadyRecordingEvidence(recordingReport),
            distribution: fieldReadyDistributionEvidence(packagingReport),
            cleanMac: cleanMacEvidence
        )
        let outcome = FieldReadyRuntimeProofReport.Outcome(
            verdict: fieldReadyRuntimeVerdict(
                integratedReport: integratedReport,
                appShellReport: appShellReport,
                recordingReport: recordingReport,
                packagingReport: packagingReport
            ),
            notes: "Aggregate proof from \(configuration.integratedReportPath), "
                + "\(configuration.appReportPath), \(configuration.recordingReportPath), "
                + "and \(configuration.packagingReportPath); clean-Mac and notarized "
                + "distribution evidence remain required before PASS."
        )
        return FieldReadyRuntimeProofReport(.init(metadata: metadata, evidence: evidence, outcome: outcome))
    }
}

private func syntheticFieldReadyP04Evidence() -> FieldReadyP04Evidence {
    FieldReadyP04Evidence(
        integratedReportId: "m10-integrated-av-proof-required",
        verdict: .partial,
        defensiblePartialAccepted: false
    )
}

private func syntheticFieldReadyRuntimeEvidence() -> FieldReadyRuntimeEvidence {
    FieldReadyRuntimeEvidence(
        mode: .cliOnly,
        cliAuthoritative: true,
        cliWorkflowCanWriteReports: true,
        cliReportIds: [
            "m13-native-app-shell-partial-fixture",
            "m14-recording-session-partial-fixture",
            "m15-packaging-field-test-partial-fixture"
        ],
        appShellReportId: "m13-native-app-shell-partial-fixture",
        appShellOwnsRealtimePaths: false
    )
}

private func syntheticFieldReadyPermissionEvidence() -> FieldReadyPermissionEvidence {
    FieldReadyPermissionEvidence(
        microphonePurposeStringPresent: true,
        cameraPurposeStringPresent: true,
        localNetworkPurposeStringPresent: true,
        promptsObserved: false
    )
}

private func syntheticFieldReadyRecordingEvidence() -> FieldReadyRecordingEvidence {
    FieldReadyRecordingEvidence(
        enabled: true,
        reportId: "m14-recording-session-partial-fixture",
        writesOutsideRealtimePaths: true,
        dropOrGapEvidenceRecorded: true
    )
}

private func syntheticFieldReadyDistributionEvidence() -> FieldReadyDistributionEvidence {
    FieldReadyDistributionEvidence(
        signingIdentityLabel: "Q010 signing identity not supplied",
        signingStatusRecorded: true,
        notarizationStatus: .deferred,
        notarizationStatusRecorded: true
    )
}

private func syntheticFieldReadyCleanMacEvidence() -> FieldReadyCleanMacEvidence {
    let target = FieldReadyCleanMacEvidence.Target(
        label: "",
        hardwareIdentifier: "",
        osVersion: "",
        deviceInventoryReportID: ""
    )
    let hardwareEvidence = FieldReadyCleanMacEvidence.HardwareEvidence(
        rmeDeviceVisible: false,
        atemReadOnlyReportID: "",
        atemReadOnlyStatusRecorded: false
    )
    let outcome = FieldReadyCleanMacEvidence.Outcome(
        reportWriteSucceeded: false,
        machineReadableVerdict: true,
        verdict: .partial
    )
    return FieldReadyCleanMacEvidence(.init(target: target, hardwareEvidence: hardwareEvidence, outcome: outcome))
}

private func fieldReadyP04Evidence(_ integratedReport: IntegratedAvReport) -> FieldReadyP04Evidence {
    FieldReadyP04Evidence(
        integratedReportId: integratedReport.id,
        verdict: integratedReport.verdict,
        defensiblePartialAccepted: false
    )
}

private func fieldReadyRuntimeEvidence(
    integratedReport: IntegratedAvReport,
    appShellReport: NativeAppShellReport,
    recordingReport: RecordingSessionArtifactReport,
    packagingReport: PackagingFieldTestReport
) -> FieldReadyRuntimeEvidence {
    FieldReadyRuntimeEvidence(
        mode: fieldReadyRuntimeMode(appShellReport: appShellReport, packagingReport: packagingReport),
        cliAuthoritative: true,
        cliWorkflowCanWriteReports: packagingReport.fieldReport.verdictLineRecorded,
        cliReportIds: [
            integratedReport.id,
            appShellReport.id,
            recordingReport.id,
            packagingReport.id
        ],
        appShellReportId: appShellReport.id,
        appShellOwnsRealtimePaths: appShellOwnsRealtimePaths(appShellReport)
    )
}

private func fieldReadyPermissionEvidence(
    _ packagingReport: PackagingFieldTestReport
) -> FieldReadyPermissionEvidence {
    FieldReadyPermissionEvidence(
        microphonePurposeStringPresent: packagingReport.entitlements.microphoneUsageDescriptionPresent,
        cameraPurposeStringPresent: packagingReport.entitlements.cameraUsageDescriptionPresent,
        localNetworkPurposeStringPresent: packagingReport.entitlements.localNetworkUsageDescriptionPresent,
        promptsObserved: packagingReport.cleanMac.permissionsPrompted
    )
}

private func fieldReadyRecordingEvidence(
    _ recordingReport: RecordingSessionArtifactReport
) -> FieldReadyRecordingEvidence {
    FieldReadyRecordingEvidence(
        enabled: true,
        reportId: recordingReport.id,
        writesOutsideRealtimePaths: !recordingReport.sideLane.fileIOAllowedInRealtimeCallback
            && recordingReport.sideLane.queueFedByCopiedMedia
            && recordingReport.sideLane.writesAsynchronously,
        dropOrGapEvidenceRecorded: recordingReport.writerPressure.droppedChunkCount > 0
            || recordingReport.writerPressure.gapMarkerCount > 0
    )
}

private func fieldReadyDistributionEvidence(
    _ packagingReport: PackagingFieldTestReport
) -> FieldReadyDistributionEvidence {
    FieldReadyDistributionEvidence(
        signingIdentityLabel: packagingReport.signing.signingIdentityLabel,
        signingStatusRecorded: true,
        notarizationStatus: fieldNotarizationStatus(packagingReport.notarization),
        notarizationStatusRecorded: true
    )
}

private func fieldReadyCleanMacEvidence(
    integratedReport: IntegratedAvReport,
    packagingReport: PackagingFieldTestReport
) -> FieldReadyCleanMacEvidence {
    let target = FieldReadyCleanMacEvidence.Target(
        label: packagingReport.cleanMac.cleanMacTested ? "clean-mac-field-target" : "",
        hardwareIdentifier: packagingReport.cleanMac.cleanMacTested
            ? packagingReport.cleanMac.hardwareIdentifier
            : "",
        osVersion: packagingReport.cleanMac.cleanMacTested ? packagingReport.cleanMac.osVersion : "",
        deviceInventoryReportID: cleanMacDeviceInventoryReportId(
            integratedReport: integratedReport,
            packagingReport: packagingReport
        )
    )
    let hardwareEvidence = FieldReadyCleanMacEvidence.HardwareEvidence(
        rmeDeviceVisible: packagingReport.cleanMac.audioDeviceAccessConfirmed
            && integratedReport.proof?.rmeAudioDeviceVisible == true,
        atemReadOnlyReportID: integratedReport.proof?.atemControlReportId ?? "",
        atemReadOnlyStatusRecorded: integratedReport.proof?.atemReadOnlyPollingEnabled == true
    )
    let outcome = FieldReadyCleanMacEvidence.Outcome(
        reportWriteSucceeded: packagingReport.cleanMac.reportWriteSucceeded,
        machineReadableVerdict: packagingReport.fieldReport.verdictLineRecorded,
        verdict: packagingReport.verdict
    )
    return FieldReadyCleanMacEvidence(.init(target: target, hardwareEvidence: hardwareEvidence, outcome: outcome))
}

private func requiredFieldRuntimeRunString(
    _ argument: String,
    _ values: [String: String]
) throws -> String {
    guard let value = values[argument], !value.isEmpty else {
        throw FieldReadyRuntimeProofRunConfigurationError.missingRequiredArgument(argument)
    }
    return value
}

private func fieldReadyRuntimeMode(
    appShellReport: NativeAppShellReport,
    packagingReport: PackagingFieldTestReport
) -> PrototypeRuntimeMode {
    if packagingReport.distributionMethod == .developerID,
       packagingReport.signing.signed,
       packagingReport.notarization.accepted {
        return .signedApp
    }
    if appShellReport.smokeProbe.appTargetBuilds {
        return .appShell
    }
    return .cliOnly
}

private func appShellOwnsRealtimePaths(_ report: NativeAppShellReport) -> Bool {
    report.realtimeBoundary.uiOwnsAudioLane
        || report.realtimeBoundary.uiOwnsVideoLane
        || report.realtimeBoundary.uiOwnsControlLane
}

private func fieldNotarizationStatus(_ notarization: MacNotarizationReadiness) -> FieldNotarizationStatus {
    if notarization.gatekeeperAccepted {
        return .gatekeeperAccepted
    }
    if notarization.ticketStapled {
        return .stapled
    }
    if notarization.accepted {
        return .accepted
    }
    if notarization.submitted {
        return .submitted
    }
    if notarization.readyForSubmission {
        return .ready
    }
    if notarization.tool == .none {
        return .deferred
    }
    return .notReady
}

private func cleanMacDeviceInventoryReportId(
    integratedReport: IntegratedAvReport,
    packagingReport: PackagingFieldTestReport
) -> String {
    guard packagingReport.cleanMac.cleanMacTested,
          packagingReport.cleanMac.audioDeviceAccessConfirmed,
          integratedReport.proof?.rmeAudioDeviceVisible == true
    else {
        return ""
    }
    return "\(integratedReport.id)-clean-mac-device-inventory"
}

private func fieldReadyRuntimeVerdict(
    integratedReport: IntegratedAvReport,
    appShellReport: NativeAppShellReport,
    recordingReport: RecordingSessionArtifactReport,
    packagingReport: PackagingFieldTestReport
) -> MeasurementVerdict {
    if integratedReport.verdict == .fail
        || appShellReport.verdict == .fail
        || recordingReport.verdict == .fail
        || packagingReport.verdict == .fail {
        return .fail
    }
    if integratedReport.verdict == .pass,
       appShellReport.verdict == .pass,
       recordingReport.verdict == .pass,
       packagingReport.verdict == .pass {
        return .pass
    }
    return .partial
}
