// Validates HardwareValidationRunSupport acceptance rules, keeping failure policy close to its contract rather than the runtime path.
import Foundation

func hardwareValidationReport(
    configuration: HardwareValidationRunConfiguration,
    inputs: HardwareValidationRunInputs,
    evidence: [HardwareValidationEvidence],
    routes: [HardwareValidationRouteEvidence],
    inputArtifactNames: [String]
) -> HardwareValidationReport {
    let metadata = HardwareValidationReport.Metadata(
        id: "m13-hardware-validation-run",
        title: "M13 hardware validation aggregate run",
        capturedAt: ISO8601DateFormatter().string(from: Date()),
        runMode: .measured
    )
    let hardware = hardwareIdentity(
            referenceRig: inputs.referenceRig,
            rmeFastestAudio: inputs.rmeFastestAudio,
            videoCapture: inputs.videoCapture,
            atemControl: inputs.atemControl,
            lightingGate: inputs.lightingGate
    )
    let fieldRun = hardwareValidationFieldRunEvidence(
            configuration: configuration,
            routes: routes,
            integratedProfile: inputs.integratedProfile,
            inputArtifactNames: inputArtifactNames
    )
    let validationEvidence = HardwareValidationReport.ValidationEvidence(
        hardware: hardware,
        evidence: evidence,
        routes: routes,
        fieldRun: fieldRun
    )
    let outcome = HardwareValidationReport.Outcome(
        verdict: hardwareValidationVerdict(
            evidence: evidence,
            integratedProfile: inputs.integratedProfile,
            durationSeconds: configuration.durationSeconds
        ),
        notes: "M13 aggregate hardware-validation report. PASS still depends " +
            "on every subordinate report carrying measured physical evidence."
    )
    return HardwareValidationReport(
        HardwareValidationReport.Input(
            metadata: metadata,
            validationEvidence: validationEvidence,
            outcome: outcome
        )
    )
}

func hardwareValidationFieldRunEvidence(
    configuration: HardwareValidationRunConfiguration,
    routes: [HardwareValidationRouteEvidence],
    integratedProfile: IntegratedProfileReport,
    inputArtifactNames: [String]
) -> HardwareValidationFieldRunEvidence {
    HardwareValidationFieldRunEvidence(
        reportId: configuration.fieldRunReportId,
        durationSeconds: configuration.durationSeconds,
        routeLabels: routes.map(\.label),
        fieldEvidenceSeparated: true,
        fastestProfileWithinAcceptedLatency: integratedProfile.verdict == .pass,
        syntheticEvidenceUsedForPass: false,
        machineReadableVerdict: true,
        operatorNotes: "Aggregate generated from \(inputArtifactNames[0]), " +
"\(inputArtifactNames[1]), \(inputArtifactNames[2]), " +
"\(inputArtifactNames[3]), \(inputArtifactNames[4]), " +
"and \(inputArtifactNames[5])."
    )
}

func hardwareValidationInputArtifactNames(
    _ configuration: HardwareValidationRunConfiguration
) -> [String] {
    [
        configuration.referenceRigPath,
        configuration.rmeFastestAudioPath,
        configuration.videoCapturePath,
        configuration.atemControlPath,
        configuration.lightingGatePath,
        configuration.integratedProfilePath
    ].map(hardwareValidationArtifactName)
}

func hardwareValidationArtifactName(_ path: String) -> String {
    URL(fileURLWithPath: path).lastPathComponent
}

func syntheticRoute(_ kind: UdpPcmRouteKind, label: String) -> HardwareValidationRouteEvidence {
    let identity = HardwareValidationRouteEvidence.Identity(
        kind: kind,
        label: label,
        reportID: "\(label)-route-required"
    )
    let capture = HardwareValidationRouteEvidence.Capture(
        routeDescription: "M13 \(label) route description evidence required.",
        point: "M13 \(label) packet-capture point evidence required.",
        interface: "M13 \(label) capture interface evidence required.",
        dscpClassification: .notTested,
        venueConstraints: "M13 \(label) venue-constraint evidence required."
    )
    let outcome = HardwareValidationRouteEvidence.Outcome(measured: false, verdict: .partial)
    return HardwareValidationRouteEvidence(
        HardwareValidationRouteEvidence.Input(
            identity: identity,
            capture: capture,
            outcome: outcome
        )
    )
}

func route(
from profile: ReferenceNetworkProfile,
report: ReferenceRigReport
) -> HardwareValidationRouteEvidence? {
    let kind: UdpPcmRouteKind
    switch profile.topology {
    case .directWired:
        kind = .directLink
    case .dedicatedSwitch:
        kind = .dedicatedSwitch
    case .campus:
        kind = .campusPath
    case .singleHost:
        return nil
    }
    let identity = HardwareValidationRouteEvidence.Identity(
        kind: kind,
        label: profile.label,
        reportID: "\(report.id):\(profile.label)"
    )
    let capture = HardwareValidationRouteEvidence.Capture(
        routeDescription: profile.routeDescription,
        point: profile.packetCapturePoint,
        interface: profile.packetCaptureInterface,
        dscpClassification: profile.dscp.classification,
        venueConstraints: profile.vlanState
    )
    let outcome = HardwareValidationRouteEvidence.Outcome(
        measured: report.verdict == .pass,
        verdict: report.verdict
    )
    return HardwareValidationRouteEvidence(
        HardwareValidationRouteEvidence.Input(
            identity: identity,
            capture: capture,
            outcome: outcome
        )
    )
}

func hardwareIdentity(
    referenceRig: ReferenceRigReport,
    rmeFastestAudio: RmeFastestAudioPathReport,
    videoCapture: VideoCaptureReport,
    atemControl: AtemReadOnlyControlReport,
    lightingGate: LightingFixtureGateReport
) -> HardwareValidationHardwareIdentity {
    let macOSVersion = Array(Set(referenceRig.referenceMacs.map(\.macOSProductVersion)))
        .sorted()
        .joined(separator: ", ")
    let identity = HardwareValidationHardwareIdentity.Input(
        referenceRig: HardwareValidationHardwareIdentity.ReferenceRig(
            reportID: referenceRig.id,
            macOSVersion: macOSVersion
        ),
        rmeMadi: HardwareValidationHardwareIdentity.RmeMadi(
            interfaceModel: referenceRig.audioPath.interfaceModel,
            driverVersion: referenceRig.audioPath.driverVersion,
            firmwareVersion: referenceRig.audioPath.firmwareVersion,
            coreAudioInputUID: referenceRig.audioPath.coreAudioInputUID,
            coreAudioOutputUID: referenceRig.audioPath.coreAudioOutputUID
        ),
        videoControl: HardwareValidationHardwareIdentity.VideoControl(
            blackmagicModel: videoCapture.productionCaptureEvidence?.modelName ?? videoCapture.source.label,
            atemModel: atemControl.model,
            atemFirmwareVersion: atemControl.firmware
        ),
        artifacts: HardwareValidationHardwareIdentity.Artifacts(
            lightingBridge: lightingGate.workflow?.localFixtureOwner.rawValue
                ?? lightingGate.probe.interopTarget.rawValue,
            cabling: referenceRig.audioPath.cableLoopDescription,
            firmwareSnapshot: "\(rmeFastestAudio.driverEvidence.firmwareVersion); \(atemControl.firmware)"
        )
    )
    return HardwareValidationHardwareIdentity(identity)
}

struct HardwareValidationEvidenceContext {
    var referenceRig: ReferenceRigReport
    var rmeFastestAudio: RmeFastestAudioPathReport
    var videoCapture: VideoCaptureReport
    var atemControl: AtemReadOnlyControlReport
    var lightingGate: LightingFixtureGateReport
    var integratedProfile: IntegratedProfileReport
    var fieldRun: String
    var durationSeconds: Double
}

func evidenceRows(_ context: HardwareValidationEvidenceContext) -> [HardwareValidationEvidence] {
    [
        evidence(
            .referenceRig,
            context.referenceRig.id,
            context.referenceRig.verdict,
            context.referenceRig.verdict == .pass
        ),
        evidence(
            .rmeFastestAudio,
            context.rmeFastestAudio.id,
            context.rmeFastestAudio.verdict,
            context.rmeFastestAudio.verdict == .pass
        ),
        evidence(
            .videoPath,
            context.videoCapture.id,
            context.videoCapture.verdict,
            context.videoCapture.verdict == .pass
        ),
        evidence(
            .atemReadOnlyControl,
            context.atemControl.id,
            context.atemControl.verdict,
            context.atemControl.verdict == .pass
        ),
        evidence(
            .lightingControlBridge,
            context.lightingGate.id,
            context.lightingGate.verdict,
            context.lightingGate.verdict == .pass
        ),
        evidence(
            .integratedProfile,
            context.integratedProfile.id,
            context.integratedProfile.verdict,
            context.integratedProfile.runMode == .measured && context.integratedProfile.verdict == .pass
        ),
        evidence(
            .fieldRun,
            context.fieldRun,
            context.durationSeconds >= HardwareValidationReport.minimumPassDurationSeconds ? .pass : .partial,
            context.durationSeconds >= HardwareValidationReport.minimumPassDurationSeconds
        )
    ]
}

func evidence(
    _ lane: HardwareValidationLane,
    _ reportId: String,
    _ verdict: MeasurementVerdict,
    _ physical: Bool
) -> HardwareValidationEvidence {
    HardwareValidationEvidence(
        lane: lane,
        reportId: reportId,
        verdict: verdict,
        measured: physical,
        physicalEvidence: physical,
        synthetic: !physical,
        notes: physical ? "Measured physical evidence is present." : "Physical evidence remains open."
    )
}

func hardwareValidationVerdict(
    evidence: [HardwareValidationEvidence],
    integratedProfile: IntegratedProfileReport,
    durationSeconds: Double
) -> MeasurementVerdict {
    if evidence.contains(where: { $0.verdict == .fail }) {
        return .fail
    }
    if evidence.allSatisfy({ $0.verdict == .pass }),
       integratedProfile.runMode == .measured,
       durationSeconds >= HardwareValidationReport.minimumPassDurationSeconds {
        return .pass
    }
    return .partial
}

func requiredHardwareValidationRunString(
    _ argument: String,
    _ values: [String: String]
) throws -> String {
    guard let value = values[argument], !value.isEmpty else {
        throw HardwareValidationRunConfigurationError.missingRequiredArgument(argument)
    }
    return value
}

func requiredHardwareValidationRunPositiveDouble(
    _ argument: String,
    _ values: [String: String]
) throws -> Double {
    let value = try requiredHardwareValidationRunString(argument, values)
    guard let double = Double(value) else {
        throw HardwareValidationRunConfigurationError.invalidNumber(argument: argument, value: value)
    }
    guard double > 0 else {
        throw HardwareValidationRunConfigurationError.nonPositiveArgument(argument)
    }
    return double
}
