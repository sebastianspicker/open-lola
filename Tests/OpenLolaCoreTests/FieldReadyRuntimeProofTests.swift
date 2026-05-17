import Foundation
import Testing

@testable import OpenLolaCore

@Test
func fieldReadyRuntimeRejectsSyntheticPassFixture() throws {
    let report = try loadFieldReadyRuntimeProofFixture(named: "field-runtime-proof-synthetic-pass")

    #expect(throws: FieldReadyRuntimeValidationError.passWithoutMeasuredRun) {
        try report.validate()
    }
}

@Test
func fieldReadyRuntimeProofRunConfigurationParsesRequiredArguments() throws {
    let configuration = try FieldReadyRuntimeProofRunConfiguration.parse([
        "--integrated-report", "reports/m10-integrated-av.json",
        "--app-report", "reports/m13-native-app-runtime-smoke.json",
        "--recording-report", "reports/m14-recording-session.json",
        "--packaging-report", "reports/m15-packaging-field.json",
        "--output", "reports/p05-field-runtime-proof.json",
    ])

    #expect(configuration.integratedReportPath == "reports/m10-integrated-av.json")
    #expect(configuration.appReportPath == "reports/m13-native-app-runtime-smoke.json")
    #expect(configuration.recordingReportPath == "reports/m14-recording-session.json")
    #expect(configuration.packagingReportPath == "reports/m15-packaging-field.json")
    #expect(configuration.outputPath == "reports/p05-field-runtime-proof.json")
}

@Test
func fieldReadyRuntimeProofRunConfigurationRejectsMissingOutput() {
    #expect(throws: FieldReadyRuntimeProofRunConfigurationError.missingRequiredArgument("--output")) {
        _ = try FieldReadyRuntimeProofRunConfiguration.parse([
            "--integrated-report", "reports/m10-integrated-av.json",
            "--app-report", "reports/m13-native-app-runtime-smoke.json",
            "--recording-report", "reports/m14-recording-session.json",
            "--packaging-report", "reports/m15-packaging-field.json",
        ])
    }
}

@Test
func fieldReadinessRunConfigurationParsesRequiredArguments() throws {
    let configuration = try FieldReadinessRunConfiguration.parse([
        "--integrated-report", "reports/m10-integrated-av.json",
        "--duration-seconds", "30",
        "--output-dir", "reports/f09-field-readiness",
    ])

    #expect(configuration.integratedReportPath == "reports/m10-integrated-av.json")
    #expect(configuration.durationSeconds == 30)
    #expect(configuration.outputDirectory == "reports/f09-field-readiness")
    #expect(configuration.appReportPath == "reports/f09-field-readiness/m13-native-app-runtime-smoke.json")
    #expect(configuration.recordingReportPath == "reports/f09-field-readiness/m14-recording-session.json")
    #expect(configuration.packagingReportPath == "reports/f09-field-readiness/m15-packaging-field.json")
    #expect(configuration.proofReportPath == "reports/f09-field-readiness/p05-field-runtime-proof.json")
}

@Test
func fieldReadinessRunWritesAppRecordingPackagingAndProofReports() throws {
    let outputDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("open-lola-f09-field-readiness-\(UUID().uuidString)", isDirectory: true)
    let integratedReport = IntegratedAvRunner.run(
        configuration: IntegratedAvRunConfiguration(
            audioBaselineReportId: "m05-route-baseline-required",
            videoCaptureEnabled: true,
            videoTransportEnabled: true,
            oscControlEnabled: true,
            atemReadOnlyHost: nil,
            durationSeconds: 30,
            outputPath: outputDirectory.appendingPathComponent("m10-integrated-av.json").path
        )
    )
    let configuration = FieldReadinessRunConfiguration(
        integratedReportPath: "reports/m10-integrated-av.json",
        durationSeconds: 30,
        outputDirectory: outputDirectory.path
    )

    let result = try FieldReadinessRunner.run(
        configuration: configuration,
        integratedReport: integratedReport
    )

    #expect(result.verdict == .partial)
    #expect(result.integratedReportId == integratedReport.id)
    #expect(result.appReportId == "m13-native-app-runtime-smoke")
    #expect(result.recordingReportId == "m14-recording-session-run")
    #expect(result.packagingReportId == "m15-packaging-field-run")
    #expect(result.proofReportId == "p05-field-ready-runtime-run")

    for path in [
        result.appReportPath,
        result.recordingReportPath,
        result.packagingReportPath,
        result.proofReportPath,
    ] {
        #expect(FileManager.default.fileExists(atPath: path))
    }

    try NativeAppShellReport.decode(from: Data(contentsOf: URL(fileURLWithPath: result.appReportPath))).validate()
    try RecordingSessionArtifactReport.decode(from: Data(contentsOf: URL(fileURLWithPath: result.recordingReportPath))).validate()
    try PackagingFieldTestReport.decode(from: Data(contentsOf: URL(fileURLWithPath: result.packagingReportPath))).validate()
    try FieldReadyRuntimeProofReport.decode(from: Data(contentsOf: URL(fileURLWithPath: result.proofReportPath))).validate()
}

@Test
func fieldReadyRuntimeProofRunBuildsPartialAggregateFromRuntimeReports() throws {
    let outputDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("open-lola-field-runtime-\(UUID().uuidString)", isDirectory: true)
    let integratedReport = IntegratedAvRunner.run(
        configuration: IntegratedAvRunConfiguration(
            audioBaselineReportId: "m05-route-baseline-required",
            videoCaptureEnabled: true,
            videoTransportEnabled: true,
            oscControlEnabled: true,
            atemReadOnlyHost: nil,
            durationSeconds: 30,
            outputPath: outputDirectory.appendingPathComponent("m10-integrated-av.json").path
        )
    )
    let appReport = NativeAppRuntimeSmoke.run(
        configuration: NativeAppRuntimeSmokeConfiguration(
            headlessReportPath: "reports/m10-integrated-av.json",
            outputPath: "reports/m13-native-app-runtime-smoke.json"
        ),
        headlessReport: integratedReport
    )
    let recordingReport = try RecordingSessionRunner.run(
        configuration: RecordingSessionRunConfiguration(
            integratedBaselinePath: "reports/m10-integrated-av.json",
            durationSeconds: 30,
            outputDirectory: outputDirectory.appendingPathComponent("m14-session", isDirectory: true).path,
            reportPath: outputDirectory.appendingPathComponent("m14-recording-session.json").path
        ),
        integratedBaseline: integratedReport
    )
    let packagingReport = try PackagingFieldRunner.run(
        configuration: PackagingFieldRunConfiguration(
            integratedReportPath: "reports/m10-integrated-av.json",
            appReportPath: "reports/m13-native-app-runtime-smoke.json",
            recordingReportPath: "reports/m14-recording-session.json",
            outputDirectory: outputDirectory.appendingPathComponent("m15-package", isDirectory: true).path,
            reportPath: outputDirectory.appendingPathComponent("m15-packaging-field.json").path
        ),
        integratedReport: integratedReport,
        appShellReport: appReport,
        recordingReport: recordingReport
    )
    let configuration = FieldReadyRuntimeProofRunConfiguration(
        integratedReportPath: "reports/m10-integrated-av.json",
        appReportPath: "reports/m13-native-app-runtime-smoke.json",
        recordingReportPath: "reports/m14-recording-session.json",
        packagingReportPath: "reports/m15-packaging-field.json",
        outputPath: outputDirectory.appendingPathComponent("p05-field-runtime-proof.json").path
    )

    let report = FieldReadyRuntimeProofRunner.run(
        configuration: configuration,
        integratedReport: integratedReport,
        appShellReport: appReport,
        recordingReport: recordingReport,
        packagingReport: packagingReport
    )

    try report.validate()

    #expect(report.id == "p05-field-ready-runtime-run")
    #expect(report.runMode == .measured)
    #expect(report.verdict == .partial)
    #expect(report.p04.integratedReportId == integratedReport.id)
    #expect(report.runtime.mode == .appShell)
    #expect(report.runtime.cliReportIds.contains(packagingReport.id))
    #expect(report.runtime.appShellReportId == appReport.id)
    #expect(report.runtime.appShellOwnsRealtimePaths == false)
    #expect(report.permissions.microphonePurposeStringPresent)
    #expect(report.permissions.promptsObserved == false)
    #expect(report.recording.reportId == recordingReport.id)
    #expect(report.recording.writesOutsideRealtimePaths)
    #expect(report.distribution.signingIdentityLabel == packagingReport.signing.signingIdentityLabel)
    #expect(report.distribution.notarizationStatus == .deferred)
    #expect(report.cleanMac.verdict == .partial)
    #expect(report.cleanMac.machineReadableVerdict)
}

@Test
func fieldReadyRuntimeRejectsInvalidPassEvidence() throws {
    try expectFieldReadyRuntimeError(.passWithoutMeasuredRun) {
        $0.runMode = .synthetic
    }
    try expectFieldReadyRuntimeError(.passWithoutDefensibleP04) {
        $0.p04.verdict = .partial
        $0.p04.defensiblePartialAccepted = false
    }
    try expectFieldReadyRuntimeError(.passWithoutDefensibleP04) {
        $0.p04.verdict = .partial
        $0.p04.defensiblePartialAccepted = true
    }
    try expectFieldReadyRuntimeError(.passWithoutSignedAppRuntime(.cliOnly)) {
        $0.runtime.mode = .cliOnly
    }
    try expectFieldReadyRuntimeError(.passWithoutCliReportWriting) {
        $0.runtime.cliWorkflowCanWriteReports = false
    }
    try expectFieldReadyRuntimeError(.passWithAppRealtimeOwnership) {
        $0.runtime.appShellOwnsRealtimePaths = true
    }
    try expectFieldReadyRuntimeError(.passWithoutPermissionPromptRecord) {
        $0.permissions.promptsObserved = false
    }
    try expectFieldReadyRuntimeError(.passWithoutRecordingEvidence) {
        $0.recording.enabled = false
    }
    try expectFieldReadyRuntimeError(.passWithoutGatekeeperAcceptedDistribution(.accepted)) {
        $0.distribution.notarizationStatus = .accepted
    }
    try expectFieldReadyRuntimeError(.passWithoutCleanMacTarget) {
        $0.cleanMac.targetLabel = ""
    }
    try expectFieldReadyRuntimeError(.passWithoutRmeVisibility) {
        $0.cleanMac.rmeDeviceVisible = false
    }
    try expectFieldReadyRuntimeError(.passWithoutAtemStatus) {
        $0.cleanMac.atemReadOnlyStatusRecorded = false
    }
    try expectFieldReadyRuntimeError(.passWithoutMachineReadableFieldVerdict) {
        $0.cleanMac.machineReadableVerdict = false
    }
}

private func passCandidateReport() throws -> FieldReadyRuntimeProofReport {
    var report = try loadFieldReadyRuntimeProofFixture(named: "field-runtime-proof-partial")
    report.verdict = .pass
    report.runMode = .measured
    report.p04.verdict = .pass
    report.p04.defensiblePartialAccepted = false
    report.runtime.mode = .signedApp
    report.runtime.cliWorkflowCanWriteReports = true
    report.runtime.cliReportIds = [
        "m02-core-audio-inventory-pass",
        "m10-integrated-av-proof-partial",
    ]
    report.permissions.promptsObserved = true
    report.recording.enabled = true
    report.recording.reportId = "m14-recording-session-pass"
    report.recording.dropOrGapEvidenceRecorded = true
    report.distribution.notarizationStatus = .gatekeeperAccepted
    report.cleanMac.targetLabel = "clean-mac-field-target-1"
    report.cleanMac.hardwareIdentifier = "Mac14,7"
    report.cleanMac.osVersion = "macOS 15.5"
    report.cleanMac.deviceInventoryReportId = "m02-clean-mac-inventory-pass"
    report.cleanMac.rmeDeviceVisible = true
    report.cleanMac.atemReadOnlyReportId = "m11-atem-readonly-field-pass"
    report.cleanMac.atemReadOnlyStatusRecorded = true
    report.cleanMac.reportWriteSucceeded = true
    report.cleanMac.machineReadableVerdict = true
    report.cleanMac.verdict = .pass
    return report
}

private func expectFieldReadyRuntimeError(
    _ expected: FieldReadyRuntimeValidationError,
    mutate: (inout FieldReadyRuntimeProofReport) throws -> Void
) throws {
    var report = try passCandidateReport()
    try mutate(&report)

    #expect(throws: expected) {
        try report.validate()
    }
}

private func loadFieldReadyRuntimeProofFixture(named name: String) throws -> FieldReadyRuntimeProofReport {
    let url = try fieldReadyRuntimeProofFixtureURL(named: name)
    return try FieldReadyRuntimeProofReport.decode(from: Data(contentsOf: url))
}

private func fieldReadyRuntimeProofFixtureURL(named name: String) throws -> URL {
    let validURL = Bundle.module.url(
        forResource: name,
        withExtension: "json",
        subdirectory: "FieldReadyRuntimeProofs/valid"
    )
    let invalidURL = Bundle.module.url(
        forResource: name,
        withExtension: "json",
        subdirectory: "FieldReadyRuntimeProofs/invalid"
    )
    let rootURL = Bundle.module.url(
        forResource: name,
        withExtension: "json",
        subdirectory: nil
    )

    return try #require(validURL ?? invalidURL ?? rootURL)
}
