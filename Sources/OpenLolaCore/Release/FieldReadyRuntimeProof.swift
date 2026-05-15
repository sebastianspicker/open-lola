import Foundation

public typealias FieldReadyRuntimeRunMode = MeasurementMethodology

public enum PrototypeRuntimeMode: String, Codable, Equatable, Sendable {
    case cliOnly
    case appShell
    case signedApp
}

public enum FieldNotarizationStatus: String, Codable, Equatable, Sendable {
    case deferred
    case notReady
    case ready
    case submitted
    case accepted
    case stapled
    case gatekeeperAccepted
}

public struct FieldReadyP04Evidence: Codable, Equatable, Sendable {
    public var integratedReportId: String
    public var verdict: MeasurementVerdict
    public var defensiblePartialAccepted: Bool

    public init(
        integratedReportId: String,
        verdict: MeasurementVerdict,
        defensiblePartialAccepted: Bool
    ) {
        self.integratedReportId = integratedReportId
        self.verdict = verdict
        self.defensiblePartialAccepted = defensiblePartialAccepted
    }
}

public struct FieldReadyRuntimeEvidence: Codable, Equatable, Sendable {
    public var mode: PrototypeRuntimeMode
    public var cliAuthoritative: Bool
    public var cliWorkflowCanWriteReports: Bool
    public var cliReportIds: [String]
    public var appShellReportId: String
    public var appShellOwnsRealtimePaths: Bool

    public init(
        mode: PrototypeRuntimeMode,
        cliAuthoritative: Bool,
        cliWorkflowCanWriteReports: Bool,
        cliReportIds: [String],
        appShellReportId: String,
        appShellOwnsRealtimePaths: Bool
    ) {
        self.mode = mode
        self.cliAuthoritative = cliAuthoritative
        self.cliWorkflowCanWriteReports = cliWorkflowCanWriteReports
        self.cliReportIds = cliReportIds
        self.appShellReportId = appShellReportId
        self.appShellOwnsRealtimePaths = appShellOwnsRealtimePaths
    }
}

public struct FieldReadyPermissionEvidence: Codable, Equatable, Sendable {
    public var microphonePurposeStringPresent: Bool
    public var cameraPurposeStringPresent: Bool
    public var localNetworkPurposeStringPresent: Bool
    public var promptsObserved: Bool

    public init(
        microphonePurposeStringPresent: Bool,
        cameraPurposeStringPresent: Bool,
        localNetworkPurposeStringPresent: Bool,
        promptsObserved: Bool
    ) {
        self.microphonePurposeStringPresent = microphonePurposeStringPresent
        self.cameraPurposeStringPresent = cameraPurposeStringPresent
        self.localNetworkPurposeStringPresent = localNetworkPurposeStringPresent
        self.promptsObserved = promptsObserved
    }
}

public struct FieldReadyRecordingEvidence: Codable, Equatable, Sendable {
    public var enabled: Bool
    public var reportId: String
    public var writesOutsideRealtimePaths: Bool
    public var dropOrGapEvidenceRecorded: Bool

    public init(
        enabled: Bool,
        reportId: String,
        writesOutsideRealtimePaths: Bool,
        dropOrGapEvidenceRecorded: Bool
    ) {
        self.enabled = enabled
        self.reportId = reportId
        self.writesOutsideRealtimePaths = writesOutsideRealtimePaths
        self.dropOrGapEvidenceRecorded = dropOrGapEvidenceRecorded
    }
}

public struct FieldReadyDistributionEvidence: Codable, Equatable, Sendable {
    public var signingIdentityLabel: String
    public var signingStatusRecorded: Bool
    public var notarizationStatus: FieldNotarizationStatus
    public var notarizationStatusRecorded: Bool

    public init(
        signingIdentityLabel: String,
        signingStatusRecorded: Bool,
        notarizationStatus: FieldNotarizationStatus,
        notarizationStatusRecorded: Bool
    ) {
        self.signingIdentityLabel = signingIdentityLabel
        self.signingStatusRecorded = signingStatusRecorded
        self.notarizationStatus = notarizationStatus
        self.notarizationStatusRecorded = notarizationStatusRecorded
    }
}

public struct FieldReadyCleanMacEvidence: Codable, Equatable, Sendable {
    public var targetLabel: String
    public var hardwareIdentifier: String
    public var osVersion: String
    public var deviceInventoryReportId: String
    public var rmeDeviceVisible: Bool
    public var atemReadOnlyReportId: String
    public var atemReadOnlyStatusRecorded: Bool
    public var reportWriteSucceeded: Bool
    public var machineReadableVerdict: Bool
    public var verdict: MeasurementVerdict

    public init(
        targetLabel: String,
        hardwareIdentifier: String,
        osVersion: String,
        deviceInventoryReportId: String,
        rmeDeviceVisible: Bool,
        atemReadOnlyReportId: String,
        atemReadOnlyStatusRecorded: Bool,
        reportWriteSucceeded: Bool,
        machineReadableVerdict: Bool,
        verdict: MeasurementVerdict
    ) {
        self.targetLabel = targetLabel
        self.hardwareIdentifier = hardwareIdentifier
        self.osVersion = osVersion
        self.deviceInventoryReportId = deviceInventoryReportId
        self.rmeDeviceVisible = rmeDeviceVisible
        self.atemReadOnlyReportId = atemReadOnlyReportId
        self.atemReadOnlyStatusRecorded = atemReadOnlyStatusRecorded
        self.reportWriteSucceeded = reportWriteSucceeded
        self.machineReadableVerdict = machineReadableVerdict
        self.verdict = verdict
    }
}

public enum FieldReadyRuntimeValidationError: Error, Equatable, Sendable,
    ValidationEmptyFieldError,
    ValidationEmptyListError {
    case emptyField(String)
    case emptyList(String)
    case passWithoutMeasuredRun
    case passWithoutDefensibleP04
    case passWithoutSignedAppRuntime(PrototypeRuntimeMode)
    case passWithoutCliAuthority
    case passWithoutCliReportWriting
    case passWithAppRealtimeOwnership
    case passWithoutPurposeStrings
    case passWithoutPermissionPromptRecord
    case passWithoutRecordingEvidence
    case passWithoutRecordingSideLane
    case passWithoutSigningStatusRecord
    case passWithoutNotarizationStatusRecord
    case passWithoutGatekeeperAcceptedDistribution(FieldNotarizationStatus)
    case passWithoutSignedAppDistributionReadiness
    case passWithoutCleanMacTarget
    case passWithoutCleanMacPass
    case passWithoutMachineReadableFieldVerdict
    case passWithoutRmeVisibility
    case passWithoutAtemStatus
    case passWithoutReportWrite
}

enum FieldReadyRuntimeValidator: ReportPrimitiveValidating {
    typealias ValidationError = FieldReadyRuntimeValidationError
}

public struct FieldReadyRuntimeProofReport: ReportMetadataArtifact, PrettyJSONCodable, Equatable, Sendable {
    public var id: String
    public var title: String
    public var capturedAt: String
    public var runMode: FieldReadyRuntimeRunMode
    public var p04: FieldReadyP04Evidence
    public var runtime: FieldReadyRuntimeEvidence
    public var permissions: FieldReadyPermissionEvidence
    public var recording: FieldReadyRecordingEvidence
    public var distribution: FieldReadyDistributionEvidence
    public var cleanMac: FieldReadyCleanMacEvidence
    public var verdict: MeasurementVerdict
    public var notes: String

    public init(
        id: String,
        title: String,
        capturedAt: String,
        runMode: FieldReadyRuntimeRunMode,
        p04: FieldReadyP04Evidence,
        runtime: FieldReadyRuntimeEvidence,
        permissions: FieldReadyPermissionEvidence,
        recording: FieldReadyRecordingEvidence,
        distribution: FieldReadyDistributionEvidence,
        cleanMac: FieldReadyCleanMacEvidence,
        verdict: MeasurementVerdict,
        notes: String
    ) {
        self.id = id
        self.title = title
        self.capturedAt = capturedAt
        self.runMode = runMode
        self.p04 = p04
        self.runtime = runtime
        self.permissions = permissions
        self.recording = recording
        self.distribution = distribution
        self.cleanMac = cleanMac
        self.verdict = verdict
        self.notes = notes
    }
}

public enum FieldReadyRuntimeSyntheticSmoke {
    public static func run() -> FieldReadyRuntimeProofReport {
        FieldReadyRuntimeProofReport(
            id: "p05-field-ready-runtime-synthetic-smoke",
            title: "Synthetic P05 field-ready runtime proof",
            capturedAt: "2026-05-02T00:00:00Z",
            runMode: .synthetic,
            p04: FieldReadyP04Evidence(
                integratedReportId: "m10-integrated-av-proof-required",
                verdict: .partial,
                defensiblePartialAccepted: false
            ),
            runtime: FieldReadyRuntimeEvidence(
                mode: .cliOnly,
                cliAuthoritative: true,
                cliWorkflowCanWriteReports: true,
                cliReportIds: [
                    "m13-native-app-shell-partial-fixture",
                    "m14-recording-session-partial-fixture",
                    "m15-packaging-field-test-partial-fixture",
                ],
                appShellReportId: "m13-native-app-shell-partial-fixture",
                appShellOwnsRealtimePaths: false
            ),
            permissions: FieldReadyPermissionEvidence(
                microphonePurposeStringPresent: true,
                cameraPurposeStringPresent: true,
                localNetworkPurposeStringPresent: true,
                promptsObserved: false
            ),
            recording: FieldReadyRecordingEvidence(
                enabled: true,
                reportId: "m14-recording-session-partial-fixture",
                writesOutsideRealtimePaths: true,
                dropOrGapEvidenceRecorded: true
            ),
            distribution: FieldReadyDistributionEvidence(
                signingIdentityLabel: "Q010 signing identity not supplied",
                signingStatusRecorded: true,
                notarizationStatus: .deferred,
                notarizationStatusRecorded: true
            ),
            cleanMac: FieldReadyCleanMacEvidence(
                targetLabel: "",
                hardwareIdentifier: "",
                osVersion: "",
                deviceInventoryReportId: "",
                rmeDeviceVisible: false,
                atemReadOnlyReportId: "",
                atemReadOnlyStatusRecorded: false,
                reportWriteSucceeded: false,
                machineReadableVerdict: true,
                verdict: .partial
            ),
            verdict: .partial,
            notes: "Synthetic P05 proof; clean-Mac RME/ATEM/report-writing evidence remains open."
        )
    }
}

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
            "--output",
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

public enum FieldReadyRuntimeProofRunConfigurationError: Error, Equatable, Sendable {
    case missingRequiredArgument(String)
    case missingValue(String)
    case unknownArgument(String)
    case duplicateArgument(String)
}

public enum FieldReadyRuntimeProofRunner {
    public static func run(
        configuration: FieldReadyRuntimeProofRunConfiguration,
        integratedReport: IntegratedAvReport,
        appShellReport: NativeAppShellReport,
        recordingReport: RecordingSessionArtifactReport,
        packagingReport: PackagingFieldTestReport
    ) -> FieldReadyRuntimeProofReport {
        FieldReadyRuntimeProofReport(
            id: "p05-field-ready-runtime-run",
            title: "P05 field-ready runtime aggregate proof",
            capturedAt: ISO8601DateFormatter().string(from: Date()),
            runMode: .measured,
            p04: FieldReadyP04Evidence(
                integratedReportId: integratedReport.id,
                verdict: integratedReport.verdict,
                defensiblePartialAccepted: false
            ),
            runtime: FieldReadyRuntimeEvidence(
                mode: fieldReadyRuntimeMode(appShellReport: appShellReport, packagingReport: packagingReport),
                cliAuthoritative: true,
                cliWorkflowCanWriteReports: packagingReport.fieldReport.verdictLineRecorded,
                cliReportIds: [
                    integratedReport.id,
                    appShellReport.id,
                    recordingReport.id,
                    packagingReport.id,
                ],
                appShellReportId: appShellReport.id,
                appShellOwnsRealtimePaths: appShellOwnsRealtimePaths(appShellReport)
            ),
            permissions: FieldReadyPermissionEvidence(
                microphonePurposeStringPresent: packagingReport.entitlements.microphoneUsageDescriptionPresent,
                cameraPurposeStringPresent: packagingReport.entitlements.cameraUsageDescriptionPresent,
                localNetworkPurposeStringPresent: packagingReport.entitlements.localNetworkUsageDescriptionPresent,
                promptsObserved: packagingReport.cleanMac.permissionsPrompted
            ),
            recording: FieldReadyRecordingEvidence(
                enabled: true,
                reportId: recordingReport.id,
                writesOutsideRealtimePaths: !recordingReport.sideLane.fileIOAllowedInRealtimeCallback
                    && recordingReport.sideLane.queueFedByCopiedMedia
                    && recordingReport.sideLane.writesAsynchronously,
                dropOrGapEvidenceRecorded: recordingReport.writerPressure.droppedChunkCount > 0
                    || recordingReport.writerPressure.gapMarkerCount > 0
            ),
            distribution: FieldReadyDistributionEvidence(
                signingIdentityLabel: packagingReport.signing.signingIdentityLabel,
                signingStatusRecorded: true,
                notarizationStatus: fieldNotarizationStatus(packagingReport.notarization),
                notarizationStatusRecorded: true
            ),
            cleanMac: FieldReadyCleanMacEvidence(
                targetLabel: packagingReport.cleanMac.cleanMacTested ? "clean-mac-field-target" : "",
                hardwareIdentifier: packagingReport.cleanMac.cleanMacTested
                    ? packagingReport.cleanMac.hardwareIdentifier
                    : "",
                osVersion: packagingReport.cleanMac.cleanMacTested ? packagingReport.cleanMac.osVersion : "",
                deviceInventoryReportId: cleanMacDeviceInventoryReportId(
                    integratedReport: integratedReport,
                    packagingReport: packagingReport
                ),
                rmeDeviceVisible: packagingReport.cleanMac.audioDeviceAccessConfirmed
                    && integratedReport.proof?.rmeAudioDeviceVisible == true,
                atemReadOnlyReportId: integratedReport.proof?.atemControlReportId ?? "",
                atemReadOnlyStatusRecorded: integratedReport.proof?.atemReadOnlyPollingEnabled == true,
                reportWriteSucceeded: packagingReport.cleanMac.reportWriteSucceeded,
                machineReadableVerdict: packagingReport.fieldReport.verdictLineRecorded,
                verdict: packagingReport.verdict
            ),
            verdict: fieldReadyRuntimeVerdict(
                integratedReport: integratedReport,
                appShellReport: appShellReport,
                recordingReport: recordingReport,
                packagingReport: packagingReport
            ),
            notes: "Aggregate proof from \(configuration.integratedReportPath), \(configuration.appReportPath), \(configuration.recordingReportPath), and \(configuration.packagingReportPath); clean-Mac and notarized distribution evidence remain required before PASS."
        )
    }
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
       packagingReport.notarization.accepted
    {
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
        || packagingReport.verdict == .fail
    {
        return .fail
    }
    if integratedReport.verdict == .pass,
       appShellReport.verdict == .pass,
       recordingReport.verdict == .pass,
       packagingReport.verdict == .pass
    {
        return .pass
    }
    return .partial
}
