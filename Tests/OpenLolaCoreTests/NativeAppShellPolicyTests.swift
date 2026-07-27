// Verifies that native app shell rejects invalid pass policy evidence.
import Foundation
import Testing

@testable import OpenLolaCore

@Test
func nativeAppShellRejectsInvalidPassPolicyEvidence() throws {
    var report = try passCandidateReport()
    report.realtimeBoundary.uiOwnsAudioLane = true

    #expect(throws: NativeAppShellValidationError.passWithUIRealtimeOwnership("audio")) {
        try report.validate()
    }

    report = try passCandidateReport()
    report.metricsObserver.blocksRealtimePaths = true

    #expect(throws: NativeAppShellValidationError.passWithBlockingMetricsObserver) {
        try report.validate()
    }

    report = try passCandidateReport()
    report.realtimeBoundary.realtimeDependsOnSwiftUILifecycle = true

    #expect(throws: NativeAppShellValidationError.passWithSwiftUILifecycleDependency) {
        try report.validate()
    }

    report = try passCandidateReport()
    report.configuration.immutableHandoff = false

    #expect(throws: NativeAppShellValidationError.passWithoutImmutableConfigSnapshot) {
        try report.validate()
    }

    report = try passCandidateReport()
    report.realtimeBoundary.latencyChangeRequiresExplicitUserAction = false

    #expect(throws: NativeAppShellValidationError.passAllowsSilentLatencyChange) {
        try report.validate()
    }

    report = try passCandidateReport()
    report.smokeProbe.runtimeSmokeProbed = false

    #expect(throws: NativeAppShellValidationError.passWithoutRuntimeSmoke) {
        try report.validate()
    }

    report = try passCandidateReport()
    report.smokeProbe.comparedWithCLIMetrics = false

    #expect(throws: NativeAppShellValidationError.passWithoutCLIMetricsComparison) {
        try report.validate()
    }
}

private func passCandidateReport() throws -> NativeAppShellReport {
    var report = try loadNativeAppShellFixture(named: "native-app-shell-partial")
    report.verdict = .pass
    report.smokeProbe.appTargetBuilds = true
    report.smokeProbe.runtimeSmokeProbed = true
    report.smokeProbe.comparedWithCLIMetrics = true
    return report
}

private func loadNativeAppShellFixture(named name: String) throws -> NativeAppShellReport {
    let url = try nativeAppShellTestFixtureURL(named: name)
    return try NativeAppShellReport.decode(from: Data(contentsOf: url))
}
