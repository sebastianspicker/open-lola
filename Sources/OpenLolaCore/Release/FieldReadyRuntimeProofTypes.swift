// Declares release-readiness configuration and value types with input checks so parsers, runners, and tests apply the same invariants.
import Foundation

/// Identifies the measurement methodology recorded with field-runtime proof artifacts so consumers distinguish measured, synthetic, and sandbox-limited results.
public typealias FieldReadyRuntimeRunMode = MeasurementMethodology

/// Defines the finite operating mode values recorded by field-runtime proof artifacts for deterministic validation and report interpretation.
public enum PrototypeRuntimeMode: String, Codable, Equatable, Sendable {
    case cliOnly
    case appShell
    case signedApp
}

/// Defines the finite structured result values recorded by field-runtime proof artifacts for deterministic validation and report interpretation.
public enum FieldNotarizationStatus: String, Codable, Equatable, Sendable {
    case deferred
    case notReady
    case ready
    case submitted
    case accepted
    case stapled
    case gatekeeperAccepted
}

/// Captures evidence provenance required to validate, interpret, and reproduce a field-runtime proof result.
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

/// Captures evidence provenance required to validate, interpret, and reproduce a field-runtime proof result.
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

/// Captures evidence provenance required to validate, interpret, and reproduce a field-runtime proof result.
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

/// Captures evidence provenance required to validate, interpret, and reproduce a field-runtime proof result.
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

/// Captures evidence provenance required to validate, interpret, and reproduce a field-runtime proof result.
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

/// Captures evidence provenance required to validate, interpret, and reproduce a field-runtime proof result.
public struct FieldReadyCleanMacEvidence: Codable, Equatable, Sendable {
    public struct Target: Codable, Equatable, Sendable {
        public var label: String
        public var hardwareIdentifier: String
        public var osVersion: String
        public var deviceInventoryReportID: String

        public init(
            label: String,
            hardwareIdentifier: String,
            osVersion: String,
            deviceInventoryReportID: String
        ) {
            self.label = label
            self.hardwareIdentifier = hardwareIdentifier
            self.osVersion = osVersion
            self.deviceInventoryReportID = deviceInventoryReportID
        }
    }

    public struct HardwareEvidence: Codable, Equatable, Sendable {
        public var rmeDeviceVisible: Bool
        public var atemReadOnlyReportID: String
        public var atemReadOnlyStatusRecorded: Bool

        public init(
            rmeDeviceVisible: Bool,
            atemReadOnlyReportID: String,
            atemReadOnlyStatusRecorded: Bool
        ) {
            self.rmeDeviceVisible = rmeDeviceVisible
            self.atemReadOnlyReportID = atemReadOnlyReportID
            self.atemReadOnlyStatusRecorded = atemReadOnlyStatusRecorded
        }
    }

    public struct Outcome: Codable, Equatable, Sendable {
        public var reportWriteSucceeded: Bool
        public var machineReadableVerdict: Bool
        public var verdict: MeasurementVerdict

        public init(
            reportWriteSucceeded: Bool,
            machineReadableVerdict: Bool,
            verdict: MeasurementVerdict
        ) {
            self.reportWriteSucceeded = reportWriteSucceeded
            self.machineReadableVerdict = machineReadableVerdict
            self.verdict = verdict
        }
    }

    public struct Input: Codable, Equatable, Sendable {
        public var target: Target
        public var hardwareEvidence: HardwareEvidence
        public var outcome: Outcome

        public init(target: Target, hardwareEvidence: HardwareEvidence, outcome: Outcome) {
            self.target = target
            self.hardwareEvidence = hardwareEvidence
            self.outcome = outcome
        }
    }

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

    public init(_ input: Input) {
        self.targetLabel = input.target.label
        self.hardwareIdentifier = input.target.hardwareIdentifier
        self.osVersion = input.target.osVersion
        self.deviceInventoryReportId = input.target.deviceInventoryReportID
        self.rmeDeviceVisible = input.hardwareEvidence.rmeDeviceVisible
        self.atemReadOnlyReportId = input.hardwareEvidence.atemReadOnlyReportID
        self.atemReadOnlyStatusRecorded = input.hardwareEvidence.atemReadOnlyStatusRecorded
        self.reportWriteSucceeded = input.outcome.reportWriteSucceeded
        self.machineReadableVerdict = input.outcome.machineReadableVerdict
        self.verdict = input.outcome.verdict
    }
}

/// Describes failures that prevent field-runtime proof inputs or evidence from satisfying the required validation invariants.
public enum FieldReadyRuntimeValidationError: Error, Equatable, Sendable,
    ValidationEmptyFieldError,
    ValidationEmptyListError,
    ValidationMalformedFieldError {
    case emptyField(String)
    case emptyList(String)
    case malformedField(String)
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
    // swiftlint:disable:next identifier_name
    case passWithoutGatekeeperAcceptedDistribution(FieldNotarizationStatus)
    // swiftlint:disable:next identifier_name
    case passWithoutSignedAppDistributionReadiness
    case passWithoutCleanMacTarget
    case passWithoutCleanMacPass
    case passWithoutMachineReadableFieldVerdict
    case passWithoutRmeVisibility
    case passWithoutAtemStatus
    case passWithoutReportWrite
}

/// Captures report contents required to validate, interpret, and reproduce a field-runtime proof result.
public struct FieldReadyRuntimeProofReport: ReportValidatingArtifact, PrettyJSONCodable, Equatable, Sendable {
    public struct Metadata: Codable, Equatable, Sendable {
        public var id: String
        public var title: String
        public var capturedAt: String
        public var runMode: FieldReadyRuntimeRunMode

        public init(id: String, title: String, capturedAt: String, runMode: FieldReadyRuntimeRunMode) {
            self.id = id
            self.title = title
            self.capturedAt = capturedAt
            self.runMode = runMode
        }
    }

    public struct Evidence: Codable, Equatable, Sendable {
        public var p04: FieldReadyP04Evidence
        public var runtime: FieldReadyRuntimeEvidence
        public var permissions: FieldReadyPermissionEvidence
        public var recording: FieldReadyRecordingEvidence
        public var distribution: FieldReadyDistributionEvidence
        public var cleanMac: FieldReadyCleanMacEvidence

        public init(
            p04: FieldReadyP04Evidence,
            runtime: FieldReadyRuntimeEvidence,
            permissions: FieldReadyPermissionEvidence,
            recording: FieldReadyRecordingEvidence,
            distribution: FieldReadyDistributionEvidence,
            cleanMac: FieldReadyCleanMacEvidence
        ) {
            self.p04 = p04
            self.runtime = runtime
            self.permissions = permissions
            self.recording = recording
            self.distribution = distribution
            self.cleanMac = cleanMac
        }
    }

    public enum OutcomeDomain {}
    public typealias Outcome = MutableReportOutcome<OutcomeDomain>

    public struct Input: Codable, Equatable, Sendable {
        public var metadata: Metadata
        public var evidence: Evidence
        public var outcome: Outcome

        public init(metadata: Metadata, evidence: Evidence, outcome: Outcome) {
            self.metadata = metadata
            self.evidence = evidence
            self.outcome = outcome
        }
    }

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

    public init(_ input: Input) {
        ((self.id, self.title), (self.capturedAt, self.runMode)) = reportMetadataValues(input.metadata)
        self.p04 = input.evidence.p04
        self.runtime = input.evidence.runtime
        self.permissions = input.evidence.permissions
        self.recording = input.evidence.recording
        self.distribution = input.evidence.distribution
        self.cleanMac = input.evidence.cleanMac
        self.verdict = input.outcome.verdict
        self.notes = input.outcome.notes
    }
}

extension FieldReadyRuntimeProofReport.Metadata: ReportMetadataFields {}
