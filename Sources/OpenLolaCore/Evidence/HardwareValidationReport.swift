// Validates HardwareValidationReport acceptance rules, keeping failure policy close to its contract rather than the runtime path.
import Foundation

/// Identifies the measurement methodology recorded with hardware-validation artifacts so consumers distinguish measured, synthetic, and sandbox-limited results.
public typealias HardwareValidationRunMode = MeasurementMethodology

/// Defines the finite structured result values recorded by hardware-validation artifacts for deterministic validation and report interpretation.
public enum HardwareValidationLane: String, CaseIterable, Codable, Equatable, Hashable, Sendable {
    case referenceRig
    case rmeFastestAudio
    case videoPath
    case atemReadOnlyControl
    case lightingControlBridge
    case integratedProfile
    case fieldRun
}

/// Captures hardware and endpoint identity required to validate, interpret, and reproduce a hardware-validation result.
public struct HardwareValidationHardwareIdentity: Codable, Equatable, Sendable {
    public struct ReferenceRig: Codable, Equatable, Sendable {
        public var reportID: String
        public var macOSVersion: String

        public init(reportID: String, macOSVersion: String) {
            self.reportID = reportID
            self.macOSVersion = macOSVersion
        }
    }

    public struct RmeMadi: Codable, Equatable, Sendable {
        public var interfaceModel: String
        public var driverVersion: String
        public var firmwareVersion: String
        public var coreAudioInputUID: String
        public var coreAudioOutputUID: String

        public init(
            interfaceModel: String,
            driverVersion: String,
            firmwareVersion: String,
            coreAudioInputUID: String,
            coreAudioOutputUID: String
        ) {
            self.interfaceModel = interfaceModel
            self.driverVersion = driverVersion
            self.firmwareVersion = firmwareVersion
            self.coreAudioInputUID = coreAudioInputUID
            self.coreAudioOutputUID = coreAudioOutputUID
        }
    }

    public struct VideoControl: Codable, Equatable, Sendable {
        public var blackmagicModel: String
        public var atemModel: String
        public var atemFirmwareVersion: String

        public init(blackmagicModel: String, atemModel: String, atemFirmwareVersion: String) {
            self.blackmagicModel = blackmagicModel
            self.atemModel = atemModel
            self.atemFirmwareVersion = atemFirmwareVersion
        }
    }

    public struct Artifacts: Codable, Equatable, Sendable {
        public var lightingBridge: String
        public var cabling: String
        public var firmwareSnapshot: String

        public init(lightingBridge: String, cabling: String, firmwareSnapshot: String) {
            self.lightingBridge = lightingBridge
            self.cabling = cabling
            self.firmwareSnapshot = firmwareSnapshot
        }
    }

    public struct Input: Codable, Equatable, Sendable {
        public var referenceRig: ReferenceRig
        public var rmeMadi: RmeMadi
        public var videoControl: VideoControl
        public var artifacts: Artifacts

        public init(
            referenceRig: ReferenceRig,
            rmeMadi: RmeMadi,
            videoControl: VideoControl,
            artifacts: Artifacts
        ) {
            self.referenceRig = referenceRig
            self.rmeMadi = rmeMadi
            self.videoControl = videoControl
            self.artifacts = artifacts
        }
    }

    public var referenceRigReportId: String
    public var macOSVersion: String
    public var rmeInterfaceModel: String
    public var rmeDriverVersion: String
    public var rmeFirmwareVersion: String
    public var rmeCoreAudioInputUID: String
    public var rmeCoreAudioOutputUID: String
    public var blackmagicModel: String
    public var atemModel: String
    public var atemFirmwareVersion: String
    public var lightingBridge: String
    public var cablingArtifact: String
    public var firmwareSnapshotArtifact: String

    public init(_ input: Input) {
        self.referenceRigReportId = input.referenceRig.reportID
        self.macOSVersion = input.referenceRig.macOSVersion
        self.rmeInterfaceModel = input.rmeMadi.interfaceModel
        self.rmeDriverVersion = input.rmeMadi.driverVersion
        self.rmeFirmwareVersion = input.rmeMadi.firmwareVersion
        self.rmeCoreAudioInputUID = input.rmeMadi.coreAudioInputUID
        self.rmeCoreAudioOutputUID = input.rmeMadi.coreAudioOutputUID
        self.blackmagicModel = input.videoControl.blackmagicModel
        self.atemModel = input.videoControl.atemModel
        self.atemFirmwareVersion = input.videoControl.atemFirmwareVersion
        self.lightingBridge = input.artifacts.lightingBridge
        self.cablingArtifact = input.artifacts.cabling
        self.firmwareSnapshotArtifact = input.artifacts.firmwareSnapshot
    }
}

/// Captures evidence provenance required to validate, interpret, and reproduce a hardware-validation result.
public struct HardwareValidationEvidence: Codable, Equatable, Sendable {
    public var lane: HardwareValidationLane
    public var reportId: String
    public var verdict: MeasurementVerdict
    public var measured: Bool
    public var physicalEvidence: Bool
    public var synthetic: Bool
    public var notes: String

    public init(
        lane: HardwareValidationLane,
        reportId: String,
        verdict: MeasurementVerdict,
        measured: Bool,
        physicalEvidence: Bool,
        synthetic: Bool,
        notes: String
    ) {
        self.lane = lane
        self.reportId = reportId
        self.verdict = verdict
        self.measured = measured
        self.physicalEvidence = physicalEvidence
        self.synthetic = synthetic
        self.notes = notes
    }
}

/// Captures evidence provenance required to validate, interpret, and reproduce a hardware-validation result.
public struct HardwareValidationRouteEvidence: Codable, Equatable, Sendable {
    public struct Identity: Codable, Equatable, Sendable {
        public var kind: UdpPcmRouteKind
        public var label: String
        public var reportID: String

        public init(kind: UdpPcmRouteKind, label: String, reportID: String) {
            self.kind = kind
            self.label = label
            self.reportID = reportID
        }
    }

    public struct Capture: Codable, Equatable, Sendable {
        public var routeDescription: String
        public var point: String
        public var interface: String
        public var dscpClassification: UdpPcmDscpClassification
        public var venueConstraints: String

        public init(
            routeDescription: String,
            point: String,
            interface: String,
            dscpClassification: UdpPcmDscpClassification,
            venueConstraints: String
        ) {
            self.routeDescription = routeDescription
            self.point = point
            self.interface = interface
            self.dscpClassification = dscpClassification
            self.venueConstraints = venueConstraints
        }
    }

    public struct Outcome: Codable, Equatable, Sendable {
        public var measured: Bool
        public var verdict: MeasurementVerdict

        public init(measured: Bool, verdict: MeasurementVerdict) {
            self.measured = measured
            self.verdict = verdict
        }
    }

    public struct Input: Codable, Equatable, Sendable {
        public var identity: Identity
        public var capture: Capture
        public var outcome: Outcome

        public init(identity: Identity, capture: Capture, outcome: Outcome) {
            self.identity = identity
            self.capture = capture
            self.outcome = outcome
        }
    }

    public var kind: UdpPcmRouteKind
    public var label: String
    public var reportId: String
    public var routeDescription: String
    public var packetCapturePoint: String
    public var packetCaptureInterface: String
    public var dscpClassification: UdpPcmDscpClassification
    public var venueConstraints: String
    public var measured: Bool
    public var verdict: MeasurementVerdict

    public init(_ input: Input) {
        self.kind = input.identity.kind
        self.label = input.identity.label
        self.reportId = input.identity.reportID
        self.routeDescription = input.capture.routeDescription
        self.packetCapturePoint = input.capture.point
        self.packetCaptureInterface = input.capture.interface
        self.dscpClassification = input.capture.dscpClassification
        self.venueConstraints = input.capture.venueConstraints
        self.measured = input.outcome.measured
        self.verdict = input.outcome.verdict
    }
}

/// Captures evidence provenance required to validate, interpret, and reproduce a hardware-validation result.
public struct HardwareValidationFieldRunEvidence: Codable, Equatable, Sendable {
    public var reportId: String
    public var durationSeconds: Double
    public var routeLabels: [String]
    public var fieldEvidenceSeparated: Bool
    public var fastestProfileWithinAcceptedLatency: Bool
    public var syntheticEvidenceUsedForPass: Bool
    public var machineReadableVerdict: Bool
    public var operatorNotes: String

    public init(
        reportId: String,
        durationSeconds: Double,
        routeLabels: [String],
        fieldEvidenceSeparated: Bool,
        fastestProfileWithinAcceptedLatency: Bool,
        syntheticEvidenceUsedForPass: Bool,
        machineReadableVerdict: Bool,
        operatorNotes: String
    ) {
        self.reportId = reportId
        self.durationSeconds = durationSeconds
        self.routeLabels = routeLabels
        self.fieldEvidenceSeparated = fieldEvidenceSeparated
        self.fastestProfileWithinAcceptedLatency = fastestProfileWithinAcceptedLatency
        self.syntheticEvidenceUsedForPass = syntheticEvidenceUsedForPass
        self.machineReadableVerdict = machineReadableVerdict
        self.operatorNotes = operatorNotes
    }
}

/// Describes failures that prevent hardware-validation inputs or evidence from satisfying the required validation invariants.
public enum HardwareValidationValidationError: Error, Equatable, Sendable,
    ValidationEmptyFieldError,
    ValidationEmptyListError,
    ValidationMalformedFieldError,
    ValidationNegativeFieldError,
    ValidationNonPositiveFieldError {
    case emptyField(String)
    case emptyList(String)
    case malformedField(String)
    case negativeField(String)
    case nonPositiveField(String)
    case duplicateEvidenceLane(HardwareValidationLane)
    case missingEvidenceLane(HardwareValidationLane)
    case duplicateRoute(UdpPcmRouteKind)
    case missingRoute(UdpPcmRouteKind)
    case passWithoutMeasuredRun
    case passWithNonPassEvidence(HardwareValidationLane, MeasurementVerdict)
    case passWithoutMeasuredEvidence(HardwareValidationLane)
    case passWithoutPhysicalEvidence(HardwareValidationLane)
    case passWithSyntheticEvidence(HardwareValidationLane)
    case passWithNonPassRoute(UdpPcmRouteKind, MeasurementVerdict)
    case passWithoutMeasuredRoute(UdpPcmRouteKind)
    case passWithoutDscpClassification(UdpPcmRouteKind)
case passWithHarmfulDscp(UdpPcmRouteKind)
case passRunTooShort(seconds: Double, minimumSeconds: Double)
case passWithoutSeparatedFieldEvidence
// swiftlint:disable:next identifier_name
case passWithoutFastestProfileLatencyAcceptance
case passUsesSyntheticEvidence
    case passWithoutMachineReadableVerdict
    case passWithPlaceholderField(String)
    case fieldRunRouteLabelWithoutRoute(String)
    case passWithoutRmeMadiIdentity
    case passWithoutBlackmagicAtemIdentity
}

/// Captures report contents required to validate, interpret, and reproduce a hardware-validation result.
public struct HardwareValidationReport: ReportValidatingArtifact, PrettyJSONCodable, Equatable, Sendable {
    public struct Metadata: Codable, Equatable, Sendable {
        public var id: String
        public var title: String
        public var capturedAt: String
        public var runMode: HardwareValidationRunMode

        public init(id: String, title: String, capturedAt: String, runMode: HardwareValidationRunMode) {
            self.id = id
            self.title = title
            self.capturedAt = capturedAt
            self.runMode = runMode
        }
    }

    public struct ValidationEvidence: Codable, Equatable, Sendable {
        public var hardware: HardwareValidationHardwareIdentity
        public var evidence: [HardwareValidationEvidence]
        public var routes: [HardwareValidationRouteEvidence]
        public var fieldRun: HardwareValidationFieldRunEvidence

        public init(
            hardware: HardwareValidationHardwareIdentity,
            evidence: [HardwareValidationEvidence],
            routes: [HardwareValidationRouteEvidence],
            fieldRun: HardwareValidationFieldRunEvidence
        ) {
            self.hardware = hardware
            self.evidence = evidence
            self.routes = routes
            self.fieldRun = fieldRun
        }
    }

    public enum OutcomeDomain {}
    public typealias Outcome = MutableReportOutcome<OutcomeDomain>

    public struct Input: Codable, Equatable, Sendable {
        public var metadata: Metadata
        public var validationEvidence: ValidationEvidence
        public var outcome: Outcome

        public init(metadata: Metadata, validationEvidence: ValidationEvidence, outcome: Outcome) {
            self.metadata = metadata
            self.validationEvidence = validationEvidence
            self.outcome = outcome
        }
    }

    public static let minimumPassDurationSeconds = VerdictValidationPolicy.hardwareValidationMinimumPassDurationSeconds
    static let minimumPassDurationToleranceSeconds = 0.001

    public var id: String
    public var title: String
    public var capturedAt: String
    public var runMode: HardwareValidationRunMode
    public var hardware: HardwareValidationHardwareIdentity
    public var evidence: [HardwareValidationEvidence]
    public var routes: [HardwareValidationRouteEvidence]
    public var fieldRun: HardwareValidationFieldRunEvidence
    public var verdict: MeasurementVerdict
    public var notes: String

    public init(_ input: Input) {
        ((self.id, self.title), (self.capturedAt, self.runMode)) = reportMetadataValues(input.metadata)
        self.hardware = input.validationEvidence.hardware
        self.evidence = input.validationEvidence.evidence
        self.routes = input.validationEvidence.routes
        self.fieldRun = input.validationEvidence.fieldRun
        self.verdict = input.outcome.verdict
        self.notes = input.outcome.notes
    }
}

extension HardwareValidationReport.Metadata: ReportMetadataFields {}
