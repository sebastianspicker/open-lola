// Verifies that hardware validation run configuration parses required arguments.
import Foundation
import Testing

@testable import OpenLolaCore

@Test
func hardwareValidationRunConfigurationParsesRequiredArguments() throws {
    let configuration = try HardwareValidationRunConfiguration.parse([
        "--reference-rig", "reports/reference-rig.json",
        "--rme-fastest-audio", "reports/rme-fastest.json",
        "--video-capture", "reports/video-capture.json",
        "--atem-control", "reports/atem.json",
        "--lighting-gate", "reports/lighting.json",
        "--integrated-profile", "reports/integrated-profile.json",
        "--field-run-report", "reports/m13-field-run.md",
        "--duration-seconds", "1800",
        "--output", "reports/m13-hardware-validation.json"
    ])

    #expect(configuration.referenceRigPath == "reports/reference-rig.json")
    #expect(configuration.integratedProfilePath == "reports/integrated-profile.json")
    #expect(configuration.fieldRunReportId == "reports/m13-field-run.md")
    #expect(configuration.durationSeconds == 1800)
    #expect(configuration.outputPath == "reports/m13-hardware-validation.json")
}

@Test
func hardwareValidationRunnerAggregatesPartialInputs() throws {
    let report = HardwareValidationRunner.run(
        configuration: hardwareValidationRunConfiguration(root: "reports"),
        inputs: try partialHardwareValidationInputs()
    )

    try report.validate()

    #expect(report.verdict == .partial)
    #expect(report.hardware.rmeInterfaceModel.contains("TODO(human)"))
    #expect(report.routes.count == 3)
}

@Test
func hardwareValidationRunnerStripsAbsoluteInputPathsFromOperatorNotes() throws {
    let report = HardwareValidationRunner.run(
        configuration: hardwareValidationRunConfiguration(root: "/Users/operator/private"),
        inputs: try partialHardwareValidationInputs()
    )

    #expect(!report.fieldRun.operatorNotes.contains("/Users/operator/private"))
    #expect(report.fieldRun.operatorNotes.contains("reference-rig.json"))
    #expect(report.fieldRun.operatorNotes.contains("rme-fastest.json"))
    #expect(report.fieldRun.operatorNotes.contains("integrated-profile.json"))
}

private func partialHardwareValidationInputs() throws -> HardwareValidationRunInputs {
    HardwareValidationRunInputs(
        referenceRig: try loadReferenceRigFixture(named: "reference-rig-partial"),
        rmeFastestAudio: try loadRmeFastestFixture(named: "rme-fastest-audio-partial"),
        videoCapture: try loadVideoCaptureFixture(named: "video-capture-partial"),
        atemControl: AtemReadOnlyControlProbe.makeUnavailableReport(host: "192.0.2.20"),
        lightingGate: try loadLightingFixture(named: "lighting-gate-partial"),
        integratedProfile: try loadIntegratedProfileFixture(named: "integrated-profile-partial")
    )
}

@Test
func hardwareValidationRejectsInvalidPassEvidence() throws {
    try expectHardwareValidationError(.passWithoutMeasuredRun) {
        $0.runMode = .synthetic
    }
    try expectHardwareValidationError(.passWithSyntheticEvidence(.videoPath)) {
        let index = try #require($0.evidence.firstIndex { $0.lane == .videoPath })
        $0.evidence[index].synthetic = true
    }
    try expectHardwareValidationError(.passWithPlaceholderField("hardware.rmeInterfaceModel")) {
        $0.hardware.rmeInterfaceModel = "Synthetic RME Interface"
    }
    try expectHardwareValidationError(.passWithPlaceholderField("hardware.cablingArtifact")) {
        $0.hardware.cablingArtifact = "not-supplied"
    }
    try expectHardwareValidationError(.passWithPlaceholderField("hardware.rmeDriverVersion")) {
        $0.hardware.rmeDriverVersion = "FIXME driver version"
    }
    try expectHardwareValidationError(.missingRoute(.campusPath)) {
        $0.routes.removeAll { $0.kind == .campusPath }
    }
    try expectHardwareValidationError(.fieldRunRouteLabelWithoutRoute("unlisted-route")) {
        $0.fieldRun.routeLabels[0] = "unlisted-route"
    }
    try expectHardwareValidationError(.passWithoutRmeMadiIdentity) {
        $0.hardware.rmeInterfaceModel = "Built-in Output"
    }
    try expectHardwareValidationError(.passWithoutRmeMadiIdentity) {
        $0.hardware.rmeInterfaceModel = "remedial amati output"
    }
    try expectHardwareValidationError(.passWithoutBlackmagicAtemIdentity) {
        $0.hardware.atemModel = "generic UVC camera"
    }
    try expectHardwareValidationError(.passWithoutBlackmagicAtemIdentity) {
        $0.hardware.blackmagicModel = "Decklink compatible capture"
        $0.hardware.atemModel = "Amati generic controller"
    }
    try expectHardwareValidationError(.passWithoutFastestProfileLatencyAcceptance) {
        $0.fieldRun.fastestProfileWithinAcceptedLatency = false
    }
}

@Test
func hardwareValidationRequiresEveryHardwareRouteKind() throws {
    let requiredRoutes = Set(UdpPcmRouteKind.allCases.filter(\.requiresHardwareValidation))
    #expect(requiredRoutes == [
        .directLink,
        .dedicatedSwitch,
        .campusPath
    ])

    for route in requiredRoutes {
        var report = passCandidateReport()
        report.routes.removeAll { $0.kind == route }

        #expect(throws: HardwareValidationValidationError.missingRoute(route)) {
            try report.validate()
        }
    }
}

@Test
func hardwareValidationPassCandidateValidates() throws {
    let report = passCandidateReport()

    try report.validate()

    #expect(report.verdict == .pass)
    #expect(report.fieldRun.durationSeconds == HardwareValidationReport.minimumPassDurationSeconds)
}

@Test
func hardwareValidationReportEncodingRemainsFlatAfterInputMigration() throws {
    let report = passCandidateReport()
    let object = try jsonObject(from: report)

    #expect(Set(object.keys) == [
        "id", "title", "capturedAt", "runMode", "hardware", "evidence", "routes", "fieldRun", "verdict", "notes"
    ])
    let hardware = try #require(object["hardware"] as? [String: Any])
    #expect(Set(hardware.keys) == [
        "referenceRigReportId", "macOSVersion", "rmeInterfaceModel", "rmeDriverVersion", "rmeFirmwareVersion",
        "rmeCoreAudioInputUID", "rmeCoreAudioOutputUID", "blackmagicModel", "atemModel", "atemFirmwareVersion",
        "lightingBridge", "cablingArtifact", "firmwareSnapshotArtifact"
    ])
    let routes = try #require(object["routes"] as? [[String: Any]])
    let firstRoute = try #require(routes.first)
    #expect(Set(firstRoute.keys) == [
        "kind", "label", "reportId", "routeDescription", "packetCapturePoint", "packetCaptureInterface",
        "dscpClassification", "venueConstraints", "measured", "verdict"
    ])
    let roundTrip = try JSONEncoder().encode(report)
    #expect(try JSONDecoder().decode(HardwareValidationReport.self, from: roundTrip) == report)
}

@Test
func hardwareValidationPassDurationAllowsOnlySerializationTolerance() throws {
    var report = passCandidateReport()
    report.fieldRun.durationSeconds = HardwareValidationReport.minimumPassDurationSeconds
        - (HardwareValidationReport.minimumPassDurationToleranceSeconds / 2)

    try report.validate()

    report.fieldRun.durationSeconds = HardwareValidationReport.minimumPassDurationSeconds
        - (HardwareValidationReport.minimumPassDurationToleranceSeconds * 2)

    #expect(throws: HardwareValidationValidationError.passRunTooShort(
        seconds: report.fieldRun.durationSeconds,
        minimumSeconds: HardwareValidationReport.minimumPassDurationSeconds
    )) {
        try report.validate()
    }
}

private func expectHardwareValidationError(
    _ expected: HardwareValidationValidationError,
    mutate: (inout HardwareValidationReport) throws -> Void
) throws {
    var report = passCandidateReport()
    try mutate(&report)

    #expect(throws: expected) {
        try report.validate()
    }
}

private func hardwareValidationRunConfiguration(root: String) -> HardwareValidationRunConfiguration {
    let paths = HardwareValidationRunConfiguration.ArtifactPaths(
        referenceRig: "\(root)/reference-rig.json",
        rmeFastestAudio: "\(root)/rme-fastest.json",
        videoCapture: "\(root)/video-capture.json",
        atemControl: "\(root)/atem.json",
        lightingGate: "\(root)/lighting.json",
        integratedProfile: "\(root)/integrated-profile.json"
    )
    let input = HardwareValidationRunConfiguration.Input(
        artifactPaths: paths,
        fieldRun: .init(reportID: "reports/m13-field-run.md", durationSeconds: 30),
        outputPath: "\(root)/m13-hardware-validation.json"
    )
    return HardwareValidationRunConfiguration(input)
}

private func passCandidateReport() -> HardwareValidationReport {
    let evidence = hardwareValidationPassEvidence()
    let validationEvidence = HardwareValidationReport.ValidationEvidence(
        hardware: hardwareValidationPassIdentity(),
        evidence: evidence,
        routes: hardwareValidationPassRoutes(),
        fieldRun: hardwareValidationPassFieldRun()
    )
    let input = HardwareValidationReport.Input(
        metadata: .init(
            id: "m13-hardware-validation-pass-candidate",
            title: "M13 hardware validation pass candidate",
            capturedAt: "2026-05-03T00:00:00Z",
            runMode: .measured
        ),
        validationEvidence: validationEvidence,
        outcome: .init(verdict: .pass, notes: "Pass candidate for validator behavior only.")
    )
    return HardwareValidationReport(input)
}

private func hardwareValidationPassEvidence() -> [HardwareValidationEvidence] {
    HardwareValidationLane.allCases.map {
        HardwareValidationEvidence(
            lane: $0,
            reportId: "measured-\($0.rawValue)-report",
            verdict: .pass,
            measured: true,
            physicalEvidence: true,
            synthetic: false,
            notes: "Measured physical rig evidence for \($0.rawValue)."
        )
    }
}

private func hardwareValidationPassRoutes() -> [HardwareValidationRouteEvidence] {
    [
        passRoute(.directLink, label: "direct-wired"),
        passRoute(.dedicatedSwitch, label: "dedicated-switch"),
        passRoute(.campusPath, label: "campus-route")
    ]
}

private func hardwareValidationPassFieldRun() -> HardwareValidationFieldRunEvidence {
    HardwareValidationFieldRunEvidence(
        reportId: "m13-field-run-pass",
        durationSeconds: HardwareValidationReport.minimumPassDurationSeconds,
        routeLabels: ["direct-wired", "dedicated-switch", "campus-route"],
        fieldEvidenceSeparated: true,
        fastestProfileWithinAcceptedLatency: true,
        syntheticEvidenceUsedForPass: false,
        machineReadableVerdict: true,
        operatorNotes: "Physical reference rig run with source evidence stored outside generated fixtures."
    )
}

private func hardwareValidationPassIdentity() -> HardwareValidationHardwareIdentity {
    let referenceRig = HardwareValidationHardwareIdentity.ReferenceRig(
        reportID: "m01-reference-rig-pass",
        macOSVersion: "macOS 15.5 build 24F74"
    )
    let rmeMadi = HardwareValidationHardwareIdentity.RmeMadi(
        interfaceModel: "RME Fireface UFX+ MADI Thunderbolt",
        driverVersion: "RME Thunderbolt Driver 4.08",
        firmwareVersion: "230",
        coreAudioInputUID: "rme-madi-input-uid",
        coreAudioOutputUID: "rme-madi-output-uid"
    )
    let videoControl = HardwareValidationHardwareIdentity.VideoControl(
        blackmagicModel: "Blackmagic UltraStudio 4K Mini",
        atemModel: "ATEM Television Studio HD8 ISO",
        atemFirmwareVersion: "9.5.1"
    )
    let artifacts = HardwareValidationHardwareIdentity.Artifacts(
        lightingBridge: "QLC+ over OSC to isolated sACN universe",
        cabling: "artifacts/m13/reference-rig-cabling.md",
        firmwareSnapshot: "artifacts/m13/firmware-and-drivers.md"
    )
    let input = HardwareValidationHardwareIdentity.Input(
        referenceRig: referenceRig,
        rmeMadi: rmeMadi,
        videoControl: videoControl,
        artifacts: artifacts
    )
    return HardwareValidationHardwareIdentity(input)
}

private func passRoute(_ kind: UdpPcmRouteKind, label: String) -> HardwareValidationRouteEvidence {
    let identity = HardwareValidationRouteEvidence.Identity(
        kind: kind,
        label: label,
        reportID: "measured-\(label)-route-report"
    )
    let capture = HardwareValidationRouteEvidence.Capture(
        routeDescription: "Measured \(label) route on the reference rig.",
        point: "\(label) receiver ingress",
        interface: "en6",
        dscpClassification: .honored,
        venueConstraints: "Venue constraint and packet-capture permission recorded."
    )
    let outcome = HardwareValidationRouteEvidence.Outcome(measured: true, verdict: .pass)
    return HardwareValidationRouteEvidence(
        HardwareValidationRouteEvidence.Input(
            identity: identity,
            capture: capture,
            outcome: outcome
        )
    )
}

private func loadHardwareValidationFixture(named name: String) throws -> HardwareValidationReport {
    let url = try fixtureURL(named: name, subdirectory: "HardwareValidationReports/valid")
    return try HardwareValidationReport.decode(from: Data(contentsOf: url))
}

private func loadReferenceRigFixture(named name: String) throws -> ReferenceRigReport {
    let url = try fixtureURL(named: name, subdirectory: "ReferenceRigReports/valid")
    return try ReferenceRigReport.decode(from: Data(contentsOf: url))
}

private func loadRmeFastestFixture(named name: String) throws -> RmeFastestAudioPathReport {
    let url = try fixtureURL(named: name, subdirectory: "RmeFastestAudioPathReports/valid")
    return try RmeFastestAudioPathReport.decode(from: Data(contentsOf: url))
}

private func loadVideoCaptureFixture(named name: String) throws -> VideoCaptureReport {
    let url = try fixtureURL(named: name, subdirectory: "VideoCaptureReports/valid")
    return try VideoCaptureReport.decode(from: Data(contentsOf: url))
}

private func loadLightingFixture(named name: String) throws -> LightingFixtureGateReport {
    let url = try fixtureURL(named: name, subdirectory: "LightingFixtureGateReports/valid")
    return try LightingFixtureGateReport.decode(from: Data(contentsOf: url))
}

private func loadIntegratedProfileFixture(named name: String) throws -> IntegratedProfileReport {
    let url = try fixtureURL(named: name, subdirectory: "IntegratedProfileReports/valid")
    return try IntegratedProfileReport.decode(from: Data(contentsOf: url))
}

private func fixtureURL(named name: String, subdirectory: String) throws -> URL {
    let nestedURL = Bundle.module.url(
        forResource: name,
        withExtension: "json",
        subdirectory: subdirectory
    )
    let rootURL = Bundle.module.url(
        forResource: name,
        withExtension: "json",
        subdirectory: nil
    )

    return try #require(nestedURL ?? rootURL)
}
