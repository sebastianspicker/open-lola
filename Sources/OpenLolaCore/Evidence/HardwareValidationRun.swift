import Foundation

public enum HardwareValidationSyntheticSmoke {
    public static func run() -> HardwareValidationReport {
        HardwareValidationReport(
            id: "m13-hardware-validation-synthetic-smoke",
            title: "Synthetic M13 hardware validation smoke",
            capturedAt: "2026-05-03T00:00:00Z",
            runMode: .synthetic,
            hardware: HardwareValidationHardwareIdentity(
                referenceRigReportId: "m01-reference-rig-required",
                macOSVersion: "TODO(human): [M13 macOS] -> Record reference Mac OS versions -> [source / receiver]",
                rmeInterfaceModel: "TODO(human): [M13 RME model] -> Record RME MADI or compatible interface -> [hardware / defer]",
                rmeDriverVersion: "TODO(human): [M13 RME driver] -> Record driver version -> [DriverKit / kext]",
                rmeFirmwareVersion: "TODO(human): [M13 RME firmware] -> Record firmware version -> [driver tool]",
                rmeCoreAudioInputUID: "TODO(human): [M13 RME input UID] -> Record Core Audio input UID -> [inventory]",
                rmeCoreAudioOutputUID: "TODO(human): [M13 RME output UID] -> Record Core Audio output UID -> [inventory]",
                blackmagicModel: "TODO(human): [M13 Blackmagic model] -> Record Blackmagic capture path -> [ATEM / DeckLink / UltraStudio]",
                atemModel: "TODO(human): [M13 ATEM model] -> Record ATEM model -> [read-only probe]",
                atemFirmwareVersion: "TODO(human): [M13 ATEM firmware] -> Record firmware version -> [device]",
                lightingBridge: "TODO(human): [M13 lighting bridge] -> Record bridge owner -> [QLC+ / OLA]",
                cablingArtifact: "TODO(human): [M13 cabling] -> Store cabling evidence -> [markdown / photos]",
                firmwareSnapshotArtifact: "TODO(human): [M13 firmware] -> Store firmware snapshot -> [markdown / screenshots]"
            ),
            evidence: HardwareValidationLane.allCases.map { lane in
                HardwareValidationEvidence(
                    lane: lane,
                    reportId: "\(lane.rawValue)-required",
                    verdict: .partial,
                    measured: false,
                    physicalEvidence: false,
                    synthetic: true,
                    notes: "TODO(human): [M13 \(lane.rawValue)] -> Replace synthetic row with measured physical evidence -> [run / defer]"
                )
            },
            routes: [
                syntheticRoute(.directLink, label: "direct-wired"),
                syntheticRoute(.dedicatedSwitch, label: "dedicated-switch"),
                syntheticRoute(.campusPath, label: "campus-route"),
            ],
            fieldRun: HardwareValidationFieldRunEvidence(
                reportId: "m13-field-run-required",
                durationSeconds: 0,
                routeLabels: ["direct-wired", "dedicated-switch", "campus-route"],
                fieldEvidenceSeparated: true,
                fastestProfileWithinAcceptedLatency: false,
                syntheticEvidenceUsedForPass: false,
                machineReadableVerdict: true,
                operatorNotes: "TODO(human): [M13 field run] -> Record physical run notes and evidence boundary -> [lab / venue / defer]"
            ),
            verdict: .partial,
            notes: "Synthetic M13 smoke report; validates the report shape without claiming physical hardware evidence."
        )
    }
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
        let evidence = evidenceRows(
            referenceRig: referenceRig,
            rmeFastestAudio: rmeFastestAudio,
            videoCapture: videoCapture,
            atemControl: atemControl,
            lightingGate: lightingGate,
            integratedProfile: integratedProfile,
            fieldRun: configuration.fieldRunReportId,
            durationSeconds: configuration.durationSeconds
        )
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
            fieldRun: HardwareValidationFieldRunEvidence(
                reportId: configuration.fieldRunReportId,
                durationSeconds: configuration.durationSeconds,
                routeLabels: routes.map(\.label),
                fieldEvidenceSeparated: true,
                fastestProfileWithinAcceptedLatency: integratedProfile.verdict == .pass,
                syntheticEvidenceUsedForPass: false,
                machineReadableVerdict: true,
                operatorNotes: "Aggregate generated from \(inputArtifactNames[0]), \(inputArtifactNames[1]), \(inputArtifactNames[2]), \(inputArtifactNames[3]), \(inputArtifactNames[4]), and \(inputArtifactNames[5])."
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
        routeDescription: "TODO(human): [M13 \(label)] -> Record route description -> [lab / venue]",
        packetCapturePoint: "TODO(human): [M13 \(label)] -> Record packet capture point -> [receiver / tap]",
        packetCaptureInterface: "TODO(human): [M13 \(label)] -> Record capture interface -> [en / mirror]",
        dscpClassification: .notTested,
        venueConstraints: "TODO(human): [M13 \(label)] -> Record venue constraints -> [allowed / blocked]",
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

private func evidenceRows(
    referenceRig: ReferenceRigReport,
    rmeFastestAudio: RmeFastestAudioPathReport,
    videoCapture: VideoCaptureReport,
    atemControl: AtemReadOnlyControlReport,
    lightingGate: LightingFixtureGateReport,
    integratedProfile: IntegratedProfileReport,
    fieldRun: String,
    durationSeconds: Double
) -> [HardwareValidationEvidence] {
    [
        evidence(.referenceRig, referenceRig.id, referenceRig.verdict, referenceRig.verdict == .pass),
        evidence(.rmeFastestAudio, rmeFastestAudio.id, rmeFastestAudio.verdict, rmeFastestAudio.verdict == .pass),
        evidence(.videoPath, videoCapture.id, videoCapture.verdict, videoCapture.verdict == .pass),
        evidence(.atemReadOnlyControl, atemControl.id, atemControl.verdict, atemControl.verdict == .pass),
        evidence(.lightingControlBridge, lightingGate.id, lightingGate.verdict, lightingGate.verdict == .pass),
        evidence(
            .integratedProfile,
            integratedProfile.id,
            integratedProfile.verdict,
            integratedProfile.runMode == .measured && integratedProfile.verdict == .pass
        ),
        evidence(
            .fieldRun,
            fieldRun,
            durationSeconds >= HardwareValidationReport.minimumPassDurationSeconds ? .pass : .partial,
            durationSeconds >= HardwareValidationReport.minimumPassDurationSeconds
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
