// Validates HardwareValidationRun acceptance rules, keeping failure policy close to its contract rather than the runtime path.
import Foundation

/// Creates deterministic synthetic hardware-validation evidence that exercises report validation without claiming physical measurement.
public enum HardwareValidationSyntheticSmoke {
    public static func run() -> HardwareValidationReport {
        let metadata = HardwareValidationReport.Metadata(
            id: "m13-hardware-validation-synthetic-smoke",
            title: "Synthetic M13 hardware validation smoke",
            capturedAt: "2026-05-03T00:00:00Z",
            runMode: .synthetic
        )
        let evidence = HardwareValidationLane.allCases.map { lane in
            HardwareValidationEvidence(
                lane: lane,
                reportId: "\(lane.rawValue)-required",
                verdict: .partial,
                measured: false,
                physicalEvidence: false,
                synthetic: true,
                notes: "M13 \(lane.rawValue) measured physical evidence required."
            )
        }
        let validationEvidence = HardwareValidationReport.ValidationEvidence(
            hardware: syntheticHardwareIdentity(),
            evidence: evidence,
            routes: [
                syntheticRoute(.directLink, label: "direct-wired"),
                syntheticRoute(.dedicatedSwitch, label: "dedicated-switch"),
                syntheticRoute(.campusPath, label: "campus-route")
            ],
            fieldRun: syntheticFieldRunEvidence()
        )
        return HardwareValidationReport(
            .init(
                metadata: metadata,
                validationEvidence: validationEvidence,
                outcome: .init(
                    verdict: .partial,
                    notes: "Synthetic M13 smoke report; validates the report shape without claiming physical hardware evidence."
                )
            )
        )
    }
}

private func syntheticHardwareIdentity() -> HardwareValidationHardwareIdentity {
    let referenceRig = HardwareValidationHardwareIdentity.ReferenceRig(
        reportID: "m01-reference-rig-required",
        macOSVersion: "M13 reference Mac OS version evidence required."
    )
    let rmeMadi = HardwareValidationHardwareIdentity.RmeMadi(
        interfaceModel: "M13 RME MADI or compatible interface evidence required.",
        driverVersion: "M13 RME driver version evidence required.",
        firmwareVersion: "M13 RME firmware version evidence required.",
        coreAudioInputUID: "M13 RME input Core Audio UID evidence required.",
        coreAudioOutputUID: "M13 RME output Core Audio UID evidence required."
    )
    let videoControl = HardwareValidationHardwareIdentity.VideoControl(
        blackmagicModel: "M13 Blackmagic capture path evidence required.",
        atemModel: "M13 ATEM model evidence required.",
        atemFirmwareVersion: "M13 ATEM firmware version evidence required."
    )
    let artifacts = HardwareValidationHardwareIdentity.Artifacts(
        lightingBridge: "M13 lighting bridge evidence required.",
        cabling: "M13 cabling evidence artifact required.",
        firmwareSnapshot: "M13 firmware snapshot artifact required."
    )
    return HardwareValidationHardwareIdentity(
        .init(
            referenceRig: referenceRig,
            rmeMadi: rmeMadi,
            videoControl: videoControl,
            artifacts: artifacts
        )
    )
}

private func syntheticFieldRunEvidence() -> HardwareValidationFieldRunEvidence {
    HardwareValidationFieldRunEvidence(
        reportId: "m13-field-run-required",
        durationSeconds: 0,
        routeLabels: ["direct-wired", "dedicated-switch", "campus-route"],
        fieldEvidenceSeparated: true,
        fastestProfileWithinAcceptedLatency: false,
        syntheticEvidenceUsedForPass: false,
        machineReadableVerdict: true,
        operatorNotes: "M13 field-run notes and evidence boundary required."
    )
}

/// Captures run configuration required to validate, interpret, and reproduce a hardware-validation result.
public struct HardwareValidationRunConfiguration: Codable, Equatable, Sendable {
    public struct ArtifactPaths: Codable, Equatable, Sendable {
        public var referenceRig: String
        public var rmeFastestAudio: String
        public var videoCapture: String
        public var atemControl: String
        public var lightingGate: String
        public var integratedProfile: String

        public init(
            referenceRig: String,
            rmeFastestAudio: String,
            videoCapture: String,
            atemControl: String,
            lightingGate: String,
            integratedProfile: String
        ) {
            self.referenceRig = referenceRig
            self.rmeFastestAudio = rmeFastestAudio
            self.videoCapture = videoCapture
            self.atemControl = atemControl
            self.lightingGate = lightingGate
            self.integratedProfile = integratedProfile
        }
    }

    public struct FieldRun: Codable, Equatable, Sendable {
        public var reportID: String
        public var durationSeconds: Double

        public init(reportID: String, durationSeconds: Double) {
            self.reportID = reportID
            self.durationSeconds = durationSeconds
        }
    }

    public struct Input: Codable, Equatable, Sendable {
        public var artifactPaths: ArtifactPaths
        public var fieldRun: FieldRun
        public var outputPath: String

        public init(artifactPaths: ArtifactPaths, fieldRun: FieldRun, outputPath: String) {
            self.artifactPaths = artifactPaths
            self.fieldRun = fieldRun
            self.outputPath = outputPath
        }
    }

    public let referenceRigPath: String
    public let rmeFastestAudioPath: String
    public let videoCapturePath: String
    public let atemControlPath: String
    public let lightingGatePath: String
    public let integratedProfilePath: String
    public let fieldRunReportId: String
    public let durationSeconds: Double
    public let outputPath: String

    public init(_ input: Input) {
        self.referenceRigPath = input.artifactPaths.referenceRig
        self.rmeFastestAudioPath = input.artifactPaths.rmeFastestAudio
        self.videoCapturePath = input.artifactPaths.videoCapture
        self.atemControlPath = input.artifactPaths.atemControl
        self.lightingGatePath = input.artifactPaths.lightingGate
        self.integratedProfilePath = input.artifactPaths.integratedProfile
        self.fieldRunReportId = input.fieldRun.reportID
        self.durationSeconds = input.fieldRun.durationSeconds
        self.outputPath = input.outputPath
    }

    public static func parse(_ arguments: [String]) throws -> HardwareValidationRunConfiguration {
        let allowed = [
            "--reference-rig",
            "--rme-fastest-audio",
            "--video-capture",
            "--atem-control",
            "--lighting-gate",
            "--integrated-profile",
            "--field-run-report",
            "--duration-seconds",
            "--output"
        ]
        var values: [String: String] = [:]
        var index = 0

        while index < arguments.count {
            let argument = arguments[index]
            guard allowed.contains(argument) else {
                throw HardwareValidationRunConfigurationError.unknownArgument(argument)
            }
            guard values[argument] == nil else {
                throw HardwareValidationRunConfigurationError.duplicateArgument(argument)
            }
            let valueIndex = index + 1
            guard valueIndex < arguments.count, !arguments[valueIndex].hasPrefix("--") else {
                throw HardwareValidationRunConfigurationError.missingValue(argument)
            }
            values[argument] = arguments[valueIndex]
            index += 2
        }

        let artifactPaths = ArtifactPaths(
            referenceRig: try requiredHardwareValidationRunString("--reference-rig", values),
            rmeFastestAudio: try requiredHardwareValidationRunString("--rme-fastest-audio", values),
            videoCapture: try requiredHardwareValidationRunString("--video-capture", values),
            atemControl: try requiredHardwareValidationRunString("--atem-control", values),
            lightingGate: try requiredHardwareValidationRunString("--lighting-gate", values),
            integratedProfile: try requiredHardwareValidationRunString("--integrated-profile", values)
        )
        let fieldRun = FieldRun(
            reportID: try requiredHardwareValidationRunString("--field-run-report", values),
            durationSeconds: try requiredHardwareValidationRunPositiveDouble("--duration-seconds", values)
        )
        return HardwareValidationRunConfiguration(
            .init(
                artifactPaths: artifactPaths,
                fieldRun: fieldRun,
                outputPath: try requiredHardwareValidationRunString("--output", values)
            )
        )
    }
}

/// Describes failures that prevent hardware-validation inputs or evidence from satisfying the required validation invariants.
public enum HardwareValidationRunConfigurationError: Error, Equatable, Sendable {
    case missingRequiredArgument(String)
    case missingValue(String)
    case unknownArgument(String)
    case duplicateArgument(String)
    case invalidNumber(argument: String, value: String)
    case nonPositiveArgument(String)
}

/// Captures run inputs required to validate, interpret, and reproduce a hardware-validation result.
public struct HardwareValidationRunInputs: Sendable {
    public var referenceRig: ReferenceRigReport
    public var rmeFastestAudio: RmeFastestAudioPathReport
    public var videoCapture: VideoCaptureReport
    public var atemControl: AtemReadOnlyControlReport
    public var lightingGate: LightingFixtureGateReport
    public var integratedProfile: IntegratedProfileReport

    public init(
        referenceRig: ReferenceRigReport,
        rmeFastestAudio: RmeFastestAudioPathReport,
        videoCapture: VideoCaptureReport,
        atemControl: AtemReadOnlyControlReport,
        lightingGate: LightingFixtureGateReport,
        integratedProfile: IntegratedProfileReport
    ) {
        self.referenceRig = referenceRig
        self.rmeFastestAudio = rmeFastestAudio
        self.videoCapture = videoCapture
        self.atemControl = atemControl
        self.lightingGate = lightingGate
        self.integratedProfile = integratedProfile
    }
}

/// Runs the hardware-validation evaluation from supplied artifacts while retaining their measurement provenance in the resulting report.
public enum HardwareValidationRunner {
    public static func run(
        configuration: HardwareValidationRunConfiguration,
        inputs: HardwareValidationRunInputs
    ) -> HardwareValidationReport {
        let routes = inputs.referenceRig.networkProfiles.compactMap {
            route(from: $0, report: inputs.referenceRig)
        }
        let evidenceContext = HardwareValidationEvidenceContext(
            referenceRig: inputs.referenceRig,
            rmeFastestAudio: inputs.rmeFastestAudio,
            videoCapture: inputs.videoCapture,
            atemControl: inputs.atemControl,
            lightingGate: inputs.lightingGate,
            integratedProfile: inputs.integratedProfile,
            fieldRun: configuration.fieldRunReportId,
            durationSeconds: configuration.durationSeconds
        )
        let evidence = evidenceRows(evidenceContext)
        let inputArtifactNames = hardwareValidationInputArtifactNames(configuration)
        return hardwareValidationReport(
            configuration: configuration,
            inputs: inputs,
            evidence: evidence,
            routes: routes,
            inputArtifactNames: inputArtifactNames
        )
    }
}
