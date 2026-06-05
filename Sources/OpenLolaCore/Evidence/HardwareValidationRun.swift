import Foundation

public enum HardwareValidationSyntheticSmoke {
    public static func run() -> HardwareValidationReport {
        HardwareValidationReport(
            id: "m13-hardware-validation-synthetic-smoke",
            title: "Synthetic M13 hardware validation smoke",
            capturedAt: "2026-05-03T00:00:00Z",
            runMode: .synthetic,
            hardware: syntheticHardwareIdentity(),
            evidence: HardwareValidationLane.allCases.map { lane in
                HardwareValidationEvidence(
                    lane: lane,
                    reportId: "\(lane.rawValue)-required",
                    verdict: .partial,
                    measured: false,
                    physicalEvidence: false,
                    synthetic: true,
                    notes: "M13 \(lane.rawValue) measured physical evidence required."
                )
            },
            routes: [
                syntheticRoute(.directLink, label: "direct-wired"),
                syntheticRoute(.dedicatedSwitch, label: "dedicated-switch"),
                syntheticRoute(.campusPath, label: "campus-route"),
            ],
            fieldRun: syntheticFieldRunEvidence(),
            verdict: .partial,
            notes: "Synthetic M13 smoke report; validates the report shape without claiming physical hardware evidence."
        )
    }
}

private func syntheticHardwareIdentity() -> HardwareValidationHardwareIdentity {
    HardwareValidationHardwareIdentity(
        referenceRigReportId: "m01-reference-rig-required",
        macOSVersion: "M13 reference Mac OS version evidence required.",
        rmeInterfaceModel: "M13 RME MADI or compatible interface evidence required.",
        rmeDriverVersion: "M13 RME driver version evidence required.",
        rmeFirmwareVersion: "M13 RME firmware version evidence required.",
        rmeCoreAudioInputUID: "M13 RME input Core Audio UID evidence required.",
        rmeCoreAudioOutputUID: "M13 RME output Core Audio UID evidence required.",
        blackmagicModel: "M13 Blackmagic capture path evidence required.",
        atemModel: "M13 ATEM model evidence required.",
        atemFirmwareVersion: "M13 ATEM firmware version evidence required.",
        lightingBridge: "M13 lighting bridge evidence required.",
        cablingArtifact: "M13 cabling evidence artifact required.",
        firmwareSnapshotArtifact: "M13 firmware snapshot artifact required."
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

public struct HardwareValidationRunConfiguration: Codable, Equatable, Sendable {
    public let referenceRigPath: String
    public let rmeFastestAudioPath: String
    public let videoCapturePath: String
    public let atemControlPath: String
    public let lightingGatePath: String
    public let integratedProfilePath: String
    public let fieldRunReportId: String
    public let durationSeconds: Double
    public let outputPath: String

    public init(
        referenceRigPath: String,
        rmeFastestAudioPath: String,
        videoCapturePath: String,
        atemControlPath: String,
        lightingGatePath: String,
        integratedProfilePath: String,
        fieldRunReportId: String,
        durationSeconds: Double,
        outputPath: String
    ) {
        self.referenceRigPath = referenceRigPath
        self.rmeFastestAudioPath = rmeFastestAudioPath
        self.videoCapturePath = videoCapturePath
        self.atemControlPath = atemControlPath
        self.lightingGatePath = lightingGatePath
        self.integratedProfilePath = integratedProfilePath
        self.fieldRunReportId = fieldRunReportId
        self.durationSeconds = durationSeconds
        self.outputPath = outputPath
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
            "--output",
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

        return HardwareValidationRunConfiguration(
            referenceRigPath: try requiredHardwareValidationRunString("--reference-rig", values),
            rmeFastestAudioPath: try requiredHardwareValidationRunString("--rme-fastest-audio", values),
            videoCapturePath: try requiredHardwareValidationRunString("--video-capture", values),
            atemControlPath: try requiredHardwareValidationRunString("--atem-control", values),
            lightingGatePath: try requiredHardwareValidationRunString("--lighting-gate", values),
            integratedProfilePath: try requiredHardwareValidationRunString("--integrated-profile", values),
            fieldRunReportId: try requiredHardwareValidationRunString("--field-run-report", values),
            durationSeconds: try requiredHardwareValidationRunPositiveDouble("--duration-seconds", values),
            outputPath: try requiredHardwareValidationRunString("--output", values)
        )
    }
}

public enum HardwareValidationRunConfigurationError: Error, Equatable, Sendable {
    case missingRequiredArgument(String)
    case missingValue(String)
    case unknownArgument(String)
    case duplicateArgument(String)
    case invalidNumber(argument: String, value: String)
    case nonPositiveArgument(String)
}

public enum HardwareValidationRunner {
    public static func run(
        configuration: HardwareValidationRunConfiguration,
        referenceRig: ReferenceRigReport,
        rmeFastestAudio: RmeFastestAudioPathReport,
        videoCapture: VideoCaptureReport,
        atemControl: AtemReadOnlyControlReport,
        lightingGate: LightingFixtureGateReport,
        integratedProfile: IntegratedProfileReport
    ) -> HardwareValidationReport {
        let routes = referenceRig.networkProfiles.compactMap { route(from: $0, report: referenceRig) }
        let evidenceContext = HardwareValidationEvidenceContext(
            referenceRig: referenceRig,
            rmeFastestAudio: rmeFastestAudio,
            videoCapture: videoCapture,
            atemControl: atemControl,
            lightingGate: lightingGate,
            integratedProfile: integratedProfile,
            fieldRun: configuration.fieldRunReportId,
            durationSeconds: configuration.durationSeconds
        )
        let evidence = evidenceRows(evidenceContext)
        let inputArtifactNames = hardwareValidationInputArtifactNames(configuration)
        return HardwareValidationReport(
            id: "m13-hardware-validation-run",
            title: "M13 hardware validation aggregate run",
            capturedAt: ISO8601DateFormatter().string(from: Date()),
            runMode: .measured,
            hardware: hardwareIdentity(
                referenceRig: referenceRig,
                rmeFastestAudio: rmeFastestAudio,
                videoCapture: videoCapture,
                atemControl: atemControl,
                lightingGate: lightingGate
            ),
            evidence: evidence,
            routes: routes,
            fieldRun: hardwareValidationFieldRunEvidence(
                configuration: configuration,
                routes: routes,
                integratedProfile: integratedProfile,
                inputArtifactNames: inputArtifactNames
            ),
            verdict: hardwareValidationVerdict(
                evidence: evidence,
                integratedProfile: integratedProfile,
                durationSeconds: configuration.durationSeconds
            ),
            notes: "M13 aggregate hardware-validation report. PASS still depends on every subordinate report carrying measured physical evidence."
        )
    }
}

private func hardwareValidationFieldRunEvidence(
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
        operatorNotes: "Aggregate generated from \(inputArtifactNames[0]), \(inputArtifactNames[1]), \(inputArtifactNames[2]), \(inputArtifactNames[3]), \(inputArtifactNames[4]), and \(inputArtifactNames[5])."
    )
}

private func hardwareValidationInputArtifactNames(
    _ configuration: HardwareValidationRunConfiguration
) -> [String] {
    [
        configuration.referenceRigPath,
        configuration.rmeFastestAudioPath,
        configuration.videoCapturePath,
        configuration.atemControlPath,
        configuration.lightingGatePath,
        configuration.integratedProfilePath,
    ].map(hardwareValidationArtifactName)
}

private func hardwareValidationArtifactName(_ path: String) -> String {
    URL(fileURLWithPath: path).lastPathComponent
}

private func syntheticRoute(_ kind: UdpPcmRouteKind, label: String) -> HardwareValidationRouteEvidence {
    HardwareValidationRouteEvidence(
        kind: kind,
        label: label,
        reportId: "\(label)-route-required",
        routeDescription: "M13 \(label) route description evidence required.",
        packetCapturePoint: "M13 \(label) packet-capture point evidence required.",
        packetCaptureInterface: "M13 \(label) capture interface evidence required.",
        dscpClassification: .notTested,
        venueConstraints: "M13 \(label) venue-constraint evidence required.",
        measured: false,
        verdict: .partial
    )
}

private func route(from profile: ReferenceNetworkProfile, report: ReferenceRigReport) -> HardwareValidationRouteEvidence? {
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
    return HardwareValidationRouteEvidence(
        kind: kind,
        label: profile.label,
        reportId: "\(report.id):\(profile.label)",
        routeDescription: profile.routeDescription,
        packetCapturePoint: profile.packetCapturePoint,
        packetCaptureInterface: profile.packetCaptureInterface,
        dscpClassification: profile.dscp.classification,
        venueConstraints: profile.vlanState,
        measured: report.verdict == .pass,
        verdict: report.verdict
    )
}

private func hardwareIdentity(
    referenceRig: ReferenceRigReport,
    rmeFastestAudio: RmeFastestAudioPathReport,
    videoCapture: VideoCaptureReport,
    atemControl: AtemReadOnlyControlReport,
    lightingGate: LightingFixtureGateReport
) -> HardwareValidationHardwareIdentity {
    HardwareValidationHardwareIdentity(
        referenceRigReportId: referenceRig.id,
        macOSVersion: Array(Set(referenceRig.referenceMacs.map(\.macOSProductVersion))).sorted().joined(separator: ", "),
        rmeInterfaceModel: referenceRig.audioPath.interfaceModel,
        rmeDriverVersion: referenceRig.audioPath.driverVersion,
        rmeFirmwareVersion: referenceRig.audioPath.firmwareVersion,
        rmeCoreAudioInputUID: referenceRig.audioPath.coreAudioInputUID,
        rmeCoreAudioOutputUID: referenceRig.audioPath.coreAudioOutputUID,
        blackmagicModel: videoCapture.productionCaptureEvidence?.modelName ?? videoCapture.source.label,
        atemModel: atemControl.model,
        atemFirmwareVersion: atemControl.firmware,
        lightingBridge: lightingGate.workflow?.localFixtureOwner.rawValue ?? lightingGate.probe.interopTarget.rawValue,
        cablingArtifact: referenceRig.audioPath.cableLoopDescription,
        firmwareSnapshotArtifact: "\(rmeFastestAudio.driverEvidence.firmwareVersion); \(atemControl.firmware)"
    )
}

private struct HardwareValidationEvidenceContext {
    var referenceRig: ReferenceRigReport
    var rmeFastestAudio: RmeFastestAudioPathReport
    var videoCapture: VideoCaptureReport
    var atemControl: AtemReadOnlyControlReport
    var lightingGate: LightingFixtureGateReport
    var integratedProfile: IntegratedProfileReport
    var fieldRun: String
    var durationSeconds: Double
}

private func evidenceRows(_ context: HardwareValidationEvidenceContext) -> [HardwareValidationEvidence] {
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
        ),
    ]
}

private func evidence(
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

private func hardwareValidationVerdict(
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

private func requiredHardwareValidationRunString(
    _ argument: String,
    _ values: [String: String]
) throws -> String {
    guard let value = values[argument], !value.isEmpty else {
        throw HardwareValidationRunConfigurationError.missingRequiredArgument(argument)
    }
    return value
}

private func requiredHardwareValidationRunPositiveDouble(
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
