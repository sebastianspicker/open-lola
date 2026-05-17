import Foundation
import Testing

@testable import OpenLolaCore

@Test
func integratedAvReportRejectsSyntheticPassFixture() throws {
    let report = try loadIntegratedAvFixture(named: "integrated-av-synthetic-pass")

    #expect(throws: IntegratedAvValidationError.passWithoutMeasuredRun) {
        try report.validate()
    }
}

@Test
func integratedAvRunConfigurationParsesRequiredArguments() throws {
    let configuration = try IntegratedAvRunConfiguration.parse([
        "--audio-baseline", "m05-route-baseline-required",
        "--video-capture", "on",
        "--video-transport", "on",
        "--video-preview", "off",
        "--osc-control", "on",
        "--atem-readonly", "192.0.2.10",
        "--duration-seconds", "60",
        "--output", "reports/m10-integrated-av-run.json",
    ])

    #expect(configuration.audioBaselineReportId == "m05-route-baseline-required")
    #expect(configuration.videoCaptureEnabled == true)
    #expect(configuration.videoTransportEnabled == true)
    #expect(configuration.videoPreviewEnabled == false)
    #expect(configuration.oscControlEnabled == true)
    #expect(configuration.atemReadOnlyHost == "192.0.2.10")
    #expect(configuration.durationSeconds == 60)
    #expect(configuration.videoTransportReportPath == nil)
    #expect(configuration.outputPath == "reports/m10-integrated-av-run.json")
}

@Test
func integratedAvRunConfigurationRejectsInvalidArguments() {
    #expect(throws: IntegratedAvRunConfigurationError.invalidSwitch(
        argument: "--video-capture",
        value: "maybe"
    )) {
        _ = try IntegratedAvRunConfiguration.parse([
            "--audio-baseline", "m05-route-baseline-required",
            "--video-capture", "maybe",
            "--video-transport", "on",
            "--osc-control", "off",
            "--atem-readonly", "off",
            "--duration-seconds", "60",
            "--output", "reports/m10-integrated-av-run.json",
        ])
    }
    #expect(throws: IntegratedAvRunConfigurationError.missingValue("--audio-baseline")) {
        try IntegratedAvRunConfiguration.parse(integratedAvArguments(replacing: [
            "--audio-baseline": "--video-capture",
        ]))
    }

    #expect(throws: IntegratedAvRunConfigurationError.duplicateArgument("--output")) {
        try IntegratedAvRunConfiguration.parse(integratedAvArguments() + ["--output", "reports/other.json"])
    }

    #expect(throws: IntegratedAvRunConfigurationError.missingValue("--output")) {
        try IntegratedAvRunConfiguration.parse(Array(integratedAvArguments().dropLast()))
    }

    #expect(throws: IntegratedAvRunConfigurationError.unknownArgument("--unexpected")) {
        try IntegratedAvRunConfiguration.parse(integratedAvArguments() + ["--unexpected", "value"])
    }

    #expect(throws: IntegratedAvRunConfigurationError.invalidInteger(
        argument: "--duration-seconds",
        value: "not-a-number"
    )) {
        try IntegratedAvRunConfiguration.parse(integratedAvArguments(replacing: [
            "--duration-seconds": "not-a-number",
        ]))
    }

    #expect(throws: IntegratedAvRunConfigurationError.nonPositiveArgument("--duration-seconds")) {
        try IntegratedAvRunConfiguration.parse(integratedAvArguments(replacing: ["--duration-seconds": "0"]))
    }
}

@Test
func integratedAvRunBuildsPartialP04Report() throws {
    let configuration = IntegratedAvRunConfiguration(
        audioBaselineReportId: "m05-route-baseline-required",
        videoCaptureEnabled: true,
        videoTransportEnabled: true,
        videoPreviewEnabled: false,
        oscControlEnabled: true,
        atemReadOnlyHost: "192.0.2.10",
        durationSeconds: 60,
        outputPath: "reports/m10-integrated-av-run.json"
    )

    let report = IntegratedAvRunner.run(configuration: configuration)

    try report.validate()

    #expect(report.id == "m10-integrated-av-run")
    #expect(report.runMode == .synthetic)
    #expect(report.durationSeconds == 60)
    #expect(report.sync.masterClock == .audio)
    #expect(report.sync.audioMayBlockForVideo == false)
    #expect(report.sync.videoMayChangeAudioPlayoutTarget == false)
    #expect(report.video.frameTiming.lastFrameId == 1_800)
    #expect(report.video.renderSync.selectionPolicy == .nearestUseful)
    #expect(report.video.renderSync.staleFrameLimitMicroseconds == 100_000)
    #expect(report.video.renderSync.renderedFrameAge.maxMicroseconds <= 100_000)
    #expect(report.proof?.closureGate == .p04IntegratedAvProof)
    #expect(report.proof?.audioOnlyBaselineReportId == "m05-route-baseline-required")
    #expect(report.proof?.integratedRunReportId == "m10-integrated-av-run")
    #expect(report.proof?.videoCaptureEnabled == true)
    #expect(report.proof?.videoTransportEnabled == true)
    #expect(report.proof?.videoPreviewEnabled == false)
    #expect(report.proof?.oscPollingEnabled == true)
    #expect(report.proof?.oscControlReportId == "osc-enabled-no-live-report")
    #expect(report.proof?.atemReadOnlyPollingEnabled == true)
    #expect(report.proof?.atemControlReportId == "atem-readonly-192.0.2.10")
    #expect(report.proof?.atemArmedCommandsAllowed == false)
    #expect(report.proof?.videoCaptureReportId == "m08-video-capture-synthetic-smoke")
    #expect(report.proof?.videoTransportReportId == "m09-video-transport-run")
    #expect(report.proof?.videoTransportPacketCapturePoint == "integrated-av-run-loopback")
    #expect(report.runWindow?.audioVideoOverlapSeconds == 60)
    #expect(report.verdict == .partial)
}

@Test
func integratedAvReportRejectsInvalidPassEvidence() throws {
    try expectIntegratedAvError(.passRunTooShort(seconds: 1_799, minimumSeconds: 1_800)) {
        $0.durationSeconds = 1_799
    }
    try expectIntegratedAvError(.passWithoutRunWindow) {
        $0.runWindow = nil
    }
    try expectIntegratedAvError(.passWithInsufficientAudioVideoOverlap(seconds: 1_799, minimumSeconds: 1_800)) {
        $0.runWindow?.audioVideoOverlapSeconds = 1_799
    }
    try expectIntegratedAvError(.passWithAudioBaselineReportMismatch(
        expected: "m05-rme-audio-only-pass",
        actual: "different-audio-baseline"
    )) {
        $0.proof?.audioOnlyBaselineReportId = "different-audio-baseline"
    }
    try expectIntegratedAvError(.passWithIntegratedRunReportMismatch(
        expected: "m10-p04-integrated-pass",
        actual: "different-integrated-run"
    )) {
        $0.proof?.integratedRunReportId = "different-integrated-run"
    }
    try expectIntegratedAvError(.passWithoutAudioRoutePacketCapturePoint) {
        $0.proof?.audioRoutePacketCapturePoint = nil
    }
    try expectIntegratedAvError(.passWithoutVideoCaptureReportId) {
        $0.proof?.videoCaptureReportId = nil
    }
    try expectIntegratedAvError(.passWithoutVideoTransportReportId) {
        $0.proof?.videoTransportReportId = nil
    }
    try expectIntegratedAvError(.passWithoutVideoTransportPacketCapturePoint) {
        $0.proof?.videoTransportPacketCapturePoint = nil
    }
    try expectIntegratedAvError(.passWithPlaceholderProofField("proof.videoTransportPacketCapturePoint")) {
        $0.proof?.videoTransportPacketCapturePoint = "not-captured"
    }
    try expectIntegratedAvError(.passWithoutP04Proof) {
        $0.proof = nil
    }
    try expectIntegratedAvError(.passWithoutAudioOnlyBaselineFirst) {
        $0.proof?.audioOnlyBaselineFirst = false
    }
    try expectIntegratedAvError(.passWithoutRmeAudioDevice) {
        $0.proof?.rmeAudioDeviceVisible = false
    }
    try expectIntegratedAvError(.passWithoutVideoCapture) {
        $0.proof?.videoCaptureEnabled = false
    }
    try expectIntegratedAvError(.passWithoutVideoTransportOrPreview) {
        $0.proof?.videoTransportEnabled = false
        $0.proof?.videoPreviewEnabled = false
    }
    try expectIntegratedAvError(.passWithoutOscPolling) {
        $0.proof?.oscPollingEnabled = false
    }
    try expectIntegratedAvError(.passWithoutAtemReadOnlyPolling) {
        $0.proof?.atemReadOnlyPollingEnabled = false
    }
    try expectIntegratedAvError(.passWithAtemCommandsArmed) {
        $0.proof?.atemArmedCommandsAllowed = true
    }
    try expectIntegratedAvError(.passChangesAudioRouteVerdict(baseline: .pass, integrated: .partial)) {
        $0.proof?.integratedRouteVerdict = .partial
    }
    try expectIntegratedAvError(.audioMasterClockViolation(.video)) {
        $0.sync.masterClock = .video
    }
    try expectIntegratedAvError(.audioMayBlockForVideo) {
        $0.sync.audioMayBlockForVideo = true
    }
    try expectIntegratedAvError(.passWithNonMonotonicVideoFrameTiming(1)) {
        $0.video.frameTiming.nonMonotonicTimestampCount = 1
    }
    try expectIntegratedAvError(.passWithDuplicateVideoFrameIdentities(1)) {
        $0.video.frameTiming.duplicateFrameIdentityCount = 1
    }
    try expectIntegratedAvError(.passWithStaleVideoRendered(
        maxAgeMicroseconds: 100_001,
        limitMicroseconds: 100_000
    )) {
        $0.video.renderSync.renderedFrameAge.maxMicroseconds = 100_001
    }
    try expectIntegratedAvError(.passWithAudioHoldForVideoEvents(1)) {
        $0.video.renderSync.audioHoldEvents = 1
    }
    try expectIntegratedAvError(.passIncreasesAudioP99(baseline: 80, integrated: 81)) {
        $0.audio.integratedCallbackP99Microseconds = 81
    }
    try expectIntegratedAvError(.passChangesAudioPlayoutTarget(baseline: 32, integrated: 48)) {
        $0.audio.integratedPlayoutTargetFrames = 48
    }
    try expectIntegratedAvError(.passWithoutPreAudioDegradation) {
        $0.video.degradation.triggeredBeforeAudioTargetChange = false
    }
    try expectIntegratedAvError(.passWithUiRealtimeOwnership) {
        $0.headless.uiOwnsRealtimePaths = true
    }
    try expectIntegratedAvError(.passWithNonPassAudioBaseline(.partial)) {
        $0.audio.baselineVerdict = .partial
    }
}

@Test
func integratedAvReportRejectsInvalidPartialFields() throws {
    var report = try loadIntegratedAvFixture(named: "integrated-av-partial")
    report.video.frameTiming.firstFrameId = 10
    report.video.frameTiming.lastFrameId = 9

    #expect(throws: IntegratedAvValidationError.invalidVideoFrameIdentityRange(
        firstFrameId: 10,
        lastFrameId: 9
    )) {
        try report.validate()
    }

    var videoChangesAudioTarget = try passCandidateReport()
    videoChangesAudioTarget.sync.videoMayChangeAudioPlayoutTarget = true
    #expect(throws: IntegratedAvValidationError.videoMayChangeAudioPlayoutTarget) {
        try videoChangesAudioTarget.validate()
    }

    var noPreAudioDegrade = try passCandidateReport()
    noPreAudioDegrade.sync.videoDegradesBeforeAudioImpact = false
    #expect(throws: IntegratedAvValidationError.videoWithoutPreAudioImpactDegradation) {
        try noPreAudioDegrade.validate()
    }

    var nonPositiveAudioTarget = try loadIntegratedAvFixture(named: "integrated-av-partial")
    nonPositiveAudioTarget.audio.baselinePlayoutTargetFrames = 0
    #expect(throws: IntegratedAvValidationError.nonPositiveField("audio.baselinePlayoutTargetFrames")) {
        try nonPositiveAudioTarget.validate()
    }

    var negativeAudioLoss = try loadIntegratedAvFixture(named: "integrated-av-partial")
    negativeAudioLoss.audio.lostPackets = -1
    #expect(throws: IntegratedAvValidationError.negativeField("audio.lostPackets")) {
        try negativeAudioLoss.validate()
    }

    var nonFiniteAudioCallback = try loadIntegratedAvFixture(named: "integrated-av-partial")
    nonFiniteAudioCallback.audio.baselineCallbackP99Microseconds = .nan
    #expect(throws: IntegratedAvValidationError.nonFiniteField("audio.baselineCallbackP99Microseconds")) {
        try nonFiniteAudioCallback.validate()
    }

    var emptyVideoSource = try loadIntegratedAvFixture(named: "integrated-av-partial")
    emptyVideoSource.video.source.label = ""
    #expect(throws: IntegratedAvValidationError.emptyField("video.source.label")) {
        try emptyVideoSource.validate()
    }
}

private func expectIntegratedAvError(
    _ expected: IntegratedAvValidationError,
    mutate: (inout IntegratedAvReport) throws -> Void
) throws {
    var report = try passCandidateReport()
    try mutate(&report)

    #expect(throws: expected) {
        try report.validate()
    }
}

private func passCandidateReport() throws -> IntegratedAvReport {
    try integratedAvPassCandidateReport()
}

private func integratedAvArguments(replacing replacements: [String: String] = [:]) -> [String] {
    [
        "--audio-baseline", replacements["--audio-baseline"] ?? "m05-route-baseline-required",
        "--video-capture", replacements["--video-capture"] ?? "on",
        "--video-transport", replacements["--video-transport"] ?? "on",
        "--video-preview", replacements["--video-preview"] ?? "off",
        "--osc-control", replacements["--osc-control"] ?? "on",
        "--atem-readonly", replacements["--atem-readonly"] ?? "192.0.2.10",
        "--duration-seconds", replacements["--duration-seconds"] ?? "60",
        "--output", replacements["--output"] ?? "reports/m10-integrated-av-run.json",
    ]
}

private func loadIntegratedAvFixture(named name: String) throws -> IntegratedAvReport {
    let url = try integratedAvFixtureURL(named: name)
    return try IntegratedAvReport.decode(from: Data(contentsOf: url))
}

private func integratedAvFixtureURL(named name: String) throws -> URL {
    let validURL = Bundle.module.url(
        forResource: name,
        withExtension: "json",
        subdirectory: "IntegratedAvReports/valid"
    )
    let invalidURL = Bundle.module.url(
        forResource: name,
        withExtension: "json",
        subdirectory: "IntegratedAvReports/invalid"
    )
    let rootURL = Bundle.module.url(
        forResource: name,
        withExtension: "json",
        subdirectory: nil
    )

    return try #require(validURL ?? invalidURL ?? rootURL)
}
