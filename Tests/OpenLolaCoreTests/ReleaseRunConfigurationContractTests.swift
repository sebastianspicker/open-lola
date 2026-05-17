import Foundation
import Testing

@testable import OpenLolaCore

@Test
func releaseRunConfigurationsRejectMissingRequiredOutputPaths() throws {
    #expect(throws: FieldReadinessRunConfigurationError.missingRequiredArgument("--output-dir")) {
        _ = try FieldReadinessRunConfiguration.parse([
            "--integrated-report", "reports/m10-integrated-av.json",
            "--duration-seconds", "30",
        ])
    }

    #expect(throws: PackagingFieldRunConfigurationError.missingRequiredArgument("--report")) {
        _ = try PackagingFieldRunConfiguration.parse([
            "--integrated-report", "reports/m10-integrated-av.json",
            "--app-report", "reports/m13-native-app-runtime-smoke.json",
            "--recording-report", "reports/m14-recording-session.json",
            "--output-dir", "reports/m15-package",
        ])
    }

    #expect(throws: RecordingSessionRunConfigurationError.missingRequiredArgument("--report")) {
        _ = try RecordingSessionRunConfiguration.parse([
            "--integrated-baseline", "reports/m10-integrated-av.json",
            "--duration-seconds", "30",
            "--output-dir", "reports/m14-session",
        ])
    }

    #expect(throws: FasterThanLoLaClosureRunConfigurationError.missingRequiredArgument("--output")) {
        _ = try FasterThanLoLaClosureRunConfiguration.parse([
            "--claim-scope", "audioOnly",
            "--f01-report", "m01-rme-hardware",
            "--f02-report", "m02-realtime-engine",
            "--f03-report", "m05-direct-route",
            "--f04-report", "m06-drift-lola-baseline",
        ])
    }
}

@Test
func releaseRunHarnessRejectsMalformedReportInput() throws {
    let outputDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("open-lola-release-run-contract-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
    defer {
        try? FileManager.default.removeItem(at: outputDirectory)
    }
    let malformedBaseline = outputDirectory.appendingPathComponent("malformed-integrated-av.json")
    try Data("{".utf8).write(to: malformedBaseline)

    let configuration = RecordingSessionRunConfiguration(
        integratedBaselinePath: malformedBaseline.path,
        durationSeconds: 30,
        outputDirectory: outputDirectory.appendingPathComponent("recording", isDirectory: true).path,
        reportPath: outputDirectory.appendingPathComponent("m14-recording-session.json").path
    )

    #expect(throws: RecordingSessionRunConfigurationError.integratedBaselineDecodeFailed(malformedBaseline.path)) {
        _ = try RecordingSessionRunner.run(configuration: configuration)
    }
}

@Test
func releaseRunHarnessKeepsSyntheticClosurePartialAndRejectsFalsePass() throws {
    let report = FasterThanLoLaClosureRunner.run(configuration: audioOnlyClosureConfiguration())

    try report.validate()

    #expect(report.runMode == .synthetic)
    #expect(report.verdict == .partial)

    var falsePass = report
    falsePass.verdict = .pass

    #expect(throws: FasterThanLoLaClosureValidationError.passWithoutMeasuredRun) {
        try falsePass.validate()
    }
}

private func audioOnlyClosureConfiguration() -> FasterThanLoLaClosureRunConfiguration {
    FasterThanLoLaClosureRunConfiguration(
        claimScope: .audioOnly,
        reportIds: [
            .f01RmeMadiHardwareBaseline: "m01-rme-hardware",
            .f02RealtimeDuplexAudioEngine: "m02-realtime-engine",
            .f03PeerToPeerRoute: "m05-direct-route",
            .f04DriftPlcLolaBaseline: "m06-drift-lola-baseline",
        ],
        outputPath: "reports/f10-faster-than-lola.json"
    )
}
