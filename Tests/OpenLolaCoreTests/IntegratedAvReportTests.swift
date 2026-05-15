import Foundation
import Testing

@testable import OpenLolaCore

@Test
func integratedAvReportFixtureDecodesAndValidates() throws {
    let report = try loadIntegratedAvFixture(named: "integrated-av-partial")

    try report.validate()

    #expect(report.runMode == .synthetic)
    #expect(report.verdict == .partial)
    #expect(report.sync.masterClock == .audio)
    #expect(report.sync.audioMayBlockForVideo == false)
    #expect(report.video.frameTiming.timestampClock == .continuousMonotonic)
    #expect(report.video.frameTiming.frameIdentity == .monotonicFrameCounter)
    #expect(report.video.renderSync.selectionPolicy == .nearestUseful)
    #expect(report.video.renderSync.audioHoldEvents == 0)
    #expect(report.video.transportMode == .raw)
    #expect(report.video.degradation.actions == [.dropFrame, .disableVideo])
}

@Test
func integratedHeadlessAvSyntheticSmokeEmitsPartialReport() throws {
    let report = IntegratedHeadlessAvSyntheticSmoke.run()

    try report.validate()

    #expect(report.runMode == .synthetic)
    #expect(report.headless.uiOwnsRealtimePaths == false)
    #expect(report.sync.masterClock == .audio)
    #expect(report.video.frameTiming.nonMonotonicTimestampCount == 0)
    #expect(report.video.frameTiming.duplicateFrameIdentityCount == 0)
    #expect(report.video.renderSync.staleFramesRendered == 0)
    #expect(report.video.receiverDroppedFrames == 2)
    #expect(report.proof?.closureGate == .p04IntegratedAvProof)
    #expect(report.proof?.rmeAudioDeviceVisible == false)
    #expect(report.verdict == .partial)
}

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
func integratedAvRunConfigurationRejectsInvalidSwitch() {
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
}

@Test
func integratedAvRunConfigurationDelegatesKeyValueParsing() throws {
    let source = try readIntegratedAvRunSource()

    #expect(source.contains("KeyValueArgumentParser.parseValues"))
    #expect(source.contains("allowsDashPrefixedValues: false"))
    #expect(!source.contains("while index < arguments.count"))

    #expect(throws: IntegratedAvRunConfigurationError.missingValue("--audio-baseline")) {
        _ = try IntegratedAvRunConfiguration.parse([
            "--audio-baseline", "--video-capture",
        ])
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
func integratedAvReportRejectsPassRunShorterThanThirtyMinutes() throws {
    var report = try passCandidateReport()
    report.durationSeconds = 1_799

    #expect(throws: IntegratedAvValidationError.passRunTooShort(
        seconds: 1_799,
        minimumSeconds: 1_800
    )) {
        try report.validate()
    }
}

@Test
func integratedAvReportRejectsPassWithoutRunWindow() throws {
    var report = try passCandidateReport()
    report.runWindow = nil

    #expect(throws: IntegratedAvValidationError.passWithoutRunWindow) {
        try report.validate()
    }
}

@Test
func integratedAvReportRejectsPassWithInsufficientAudioVideoOverlap() throws {
    var report = try passCandidateReport()
    report.runWindow?.audioVideoOverlapSeconds = 1_799

    #expect(throws: IntegratedAvValidationError.passWithInsufficientAudioVideoOverlap(
        seconds: 1_799,
        minimumSeconds: 1_800
    )) {
        try report.validate()
    }
}

@Test
func integratedAvReportRejectsPassWithAudioBaselineMismatch() throws {
    var report = try passCandidateReport()
    report.proof?.audioOnlyBaselineReportId = "different-audio-baseline"

    #expect(throws: IntegratedAvValidationError.passWithAudioBaselineReportMismatch(
        expected: "m05-rme-audio-only-pass",
        actual: "different-audio-baseline"
    )) {
        try report.validate()
    }
}

@Test
func integratedAvReportRejectsPassWithIntegratedReportMismatch() throws {
    var report = try passCandidateReport()
    report.proof?.integratedRunReportId = "different-integrated-run"

    #expect(throws: IntegratedAvValidationError.passWithIntegratedRunReportMismatch(
        expected: "m10-p04-integrated-pass",
        actual: "different-integrated-run"
    )) {
        try report.validate()
    }
}

@Test
func integratedAvReportRejectsPassWithoutAudioRoutePacketCapturePoint() throws {
    var report = try passCandidateReport()
    report.proof?.audioRoutePacketCapturePoint = nil

    #expect(throws: IntegratedAvValidationError.passWithoutAudioRoutePacketCapturePoint) {
        try report.validate()
    }
}

@Test
func integratedAvReportRejectsPassWithoutVideoCaptureReportId() throws {
    var report = try passCandidateReport()
    report.proof?.videoCaptureReportId = nil

    #expect(throws: IntegratedAvValidationError.passWithoutVideoCaptureReportId) {
        try report.validate()
    }
}

@Test
func integratedAvReportRejectsPassWithoutVideoTransportReportId() throws {
    var report = try passCandidateReport()
    report.proof?.videoTransportReportId = nil

    #expect(throws: IntegratedAvValidationError.passWithoutVideoTransportReportId) {
        try report.validate()
    }
}

@Test
func integratedAvReportRejectsPassWithoutVideoTransportPacketCapturePoint() throws {
    var report = try passCandidateReport()
    report.proof?.videoTransportPacketCapturePoint = nil

    #expect(throws: IntegratedAvValidationError.passWithoutVideoTransportPacketCapturePoint) {
        try report.validate()
    }
}

@Test
func integratedAvReportRejectsPassWithPlaceholderProofField() throws {
    var report = try passCandidateReport()
    report.proof?.videoTransportPacketCapturePoint = "not-captured"

    #expect(throws: IntegratedAvValidationError.passWithPlaceholderProofField(
        "proof.videoTransportPacketCapturePoint"
    )) {
        try report.validate()
    }
}

@Test
func integratedAvReportRejectsPassWithoutP04Proof() throws {
    var report = try passCandidateReport()
    report.proof = nil

    #expect(throws: IntegratedAvValidationError.passWithoutP04Proof) {
        try report.validate()
    }
}

@Test
func integratedAvReportRejectsPassWithoutAudioOnlyBaselineFirst() throws {
    var report = try passCandidateReport()
    report.proof?.audioOnlyBaselineFirst = false

    #expect(throws: IntegratedAvValidationError.passWithoutAudioOnlyBaselineFirst) {
        try report.validate()
    }
}

@Test
func integratedAvReportRejectsPassWithoutRmeAudioDevice() throws {
    var report = try passCandidateReport()
    report.proof?.rmeAudioDeviceVisible = false

    #expect(throws: IntegratedAvValidationError.passWithoutRmeAudioDevice) {
        try report.validate()
    }
}

@Test
func integratedAvReportRejectsPassWithoutVideoCapture() throws {
    var report = try passCandidateReport()
    report.proof?.videoCaptureEnabled = false

    #expect(throws: IntegratedAvValidationError.passWithoutVideoCapture) {
        try report.validate()
    }
}

@Test
func integratedAvReportRejectsPassWithoutVideoTransportOrPreview() throws {
    var report = try passCandidateReport()
    report.proof?.videoTransportEnabled = false
    report.proof?.videoPreviewEnabled = false

    #expect(throws: IntegratedAvValidationError.passWithoutVideoTransportOrPreview) {
        try report.validate()
    }
}

@Test
func integratedAvReportRejectsPassWithoutOscPolling() throws {
    var report = try passCandidateReport()
    report.proof?.oscPollingEnabled = false

    #expect(throws: IntegratedAvValidationError.passWithoutOscPolling) {
        try report.validate()
    }
}

@Test
func integratedAvReportRejectsPassWithoutAtemReadOnlyPolling() throws {
    var report = try passCandidateReport()
    report.proof?.atemReadOnlyPollingEnabled = false

    #expect(throws: IntegratedAvValidationError.passWithoutAtemReadOnlyPolling) {
        try report.validate()
    }
}

@Test
func integratedAvReportRejectsPassWithAtemCommandsArmed() throws {
    var report = try passCandidateReport()
    report.proof?.atemArmedCommandsAllowed = true

    #expect(throws: IntegratedAvValidationError.passWithAtemCommandsArmed) {
        try report.validate()
    }
}

@Test
func integratedAvReportRejectsPassWithChangedRouteVerdict() throws {
    var report = try passCandidateReport()
    report.proof?.integratedRouteVerdict = .partial

    #expect(throws: IntegratedAvValidationError.passChangesAudioRouteVerdict(
        baseline: .pass,
        integrated: .partial
    )) {
        try report.validate()
    }
}

@Test
func integratedAvReportRejectsNonAudioMasterClock() throws {
    var report = try passCandidateReport()
    report.sync.masterClock = .video

    #expect(throws: IntegratedAvValidationError.audioMasterClockViolation(.video)) {
        try report.validate()
    }
}

@Test
func integratedAvReportRejectsAudioBlockingForVideo() throws {
    var report = try passCandidateReport()
    report.sync.audioMayBlockForVideo = true

    #expect(throws: IntegratedAvValidationError.audioMayBlockForVideo) {
        try report.validate()
    }
}

@Test
func integratedAvReportRejectsPassWithNonMonotonicVideoFrameTiming() throws {
    var report = try passCandidateReport()
    report.video.frameTiming.nonMonotonicTimestampCount = 1

    #expect(throws: IntegratedAvValidationError.passWithNonMonotonicVideoFrameTiming(1)) {
        try report.validate()
    }
}

@Test
func integratedAvReportRejectsPassWithDuplicateVideoFrameIdentities() throws {
    var report = try passCandidateReport()
    report.video.frameTiming.duplicateFrameIdentityCount = 1

    #expect(throws: IntegratedAvValidationError.passWithDuplicateVideoFrameIdentities(1)) {
        try report.validate()
    }
}

@Test
func integratedAvReportRejectsPassWithStaleVideoRenderedPastBoundary() throws {
    var report = try passCandidateReport()
    report.video.renderSync.renderedFrameAge.maxMicroseconds = 100_001

    #expect(throws: IntegratedAvValidationError.passWithStaleVideoRendered(
        maxAgeMicroseconds: 100_001,
        limitMicroseconds: 100_000
    )) {
        try report.validate()
    }
}

@Test
func integratedAvReportRejectsPassWhenVideoHoldsAudio() throws {
    var report = try passCandidateReport()
    report.video.renderSync.audioHoldEvents = 1

    #expect(throws: IntegratedAvValidationError.passWithAudioHoldForVideoEvents(1)) {
        try report.validate()
    }
}

@Test
func integratedAvReportRejectsInvalidFrameIdentityRange() throws {
    var report = try loadIntegratedAvFixture(named: "integrated-av-partial")
    report.video.frameTiming.firstFrameId = 10
    report.video.frameTiming.lastFrameId = 9

    #expect(throws: IntegratedAvValidationError.invalidVideoFrameIdentityRange(
        firstFrameId: 10,
        lastFrameId: 9
    )) {
        try report.validate()
    }
}

@Test
func integratedAvReportRejectsPassWithAudioP99Increase() throws {
    var report = try passCandidateReport()
    report.audio.integratedCallbackP99Microseconds = 81

    #expect(throws: IntegratedAvValidationError.passIncreasesAudioP99(
        baseline: 80,
        integrated: 81
    )) {
        try report.validate()
    }
}

@Test
func integratedAvReportRejectsPassWithPlayoutTargetChange() throws {
    var report = try passCandidateReport()
    report.audio.integratedPlayoutTargetFrames = 48

    #expect(throws: IntegratedAvValidationError.passChangesAudioPlayoutTarget(
        baseline: 32,
        integrated: 48
    )) {
        try report.validate()
    }
}

@Test
func integratedAvReportRejectsPassWithoutPreAudioDegradation() throws {
    var report = try passCandidateReport()
    report.video.degradation.triggeredBeforeAudioTargetChange = false

    #expect(throws: IntegratedAvValidationError.passWithoutPreAudioDegradation) {
        try report.validate()
    }
}

@Test
func integratedAvReportRejectsPassWhenUiOwnsRealtimePaths() throws {
    var report = try passCandidateReport()
    report.headless.uiOwnsRealtimePaths = true

    #expect(throws: IntegratedAvValidationError.passWithUiRealtimeOwnership) {
        try report.validate()
    }
}

@Test
func integratedAvReportRejectsPassWithNonPassAudioBaseline() throws {
    var report = try passCandidateReport()
    report.audio.baselineVerdict = .partial

    #expect(throws: IntegratedAvValidationError.passWithNonPassAudioBaseline(.partial)) {
        try report.validate()
    }
}

@Test
func integratedAvReportJSONRoundTripPreservesReport() throws {
    let report = try loadIntegratedAvFixture(named: "integrated-av-partial")
    let jsonData = try report.prettyJSONData()
    let decoded = try IntegratedAvReport.decode(from: jsonData)

    #expect(decoded == report)
}

@Test
func integratedAvSyncValidationDocumentsSubordinateClockStabilityEvidence() throws {
    let source = try readIntegratedAvValidationSource()

    #expect(source.contains("structural integrated-AV policy check"))
    #expect(source.contains("subordinate audio benchmark/report"))
    #expect(source.contains("sync.masterClock == .audio"))
}

@Test
func integratedAvAudioValidationUsesDescriptorTablesForScalarFields() throws {
    let source = try readIntegratedAvValidationSource()

    #expect(source.contains("positiveInts: audioPositiveIntFields()"))
    #expect(source.contains("nonNegativeDoubles: audioNonNegativeDoubleFields()"))
    #expect(source.contains("validateIntegratedFieldSet(nonNegativeInts: audioNonNegativeIntFields())"))
    #expect(source.contains("private func audioNonNegativeDoubleFields() -> [IntegratedValidationField<Double>]"))
    #expect(source.contains("private func audioPositiveIntFields() -> [IntegratedValidationField<Int>]"))
    #expect(source.contains("private func audioNonNegativeIntFields() -> [IntegratedValidationField<Int>]"))
}

@Test
func integratedAvValidationUsesTypedFieldSetsForMechanicalScalarChecks() throws {
    let validationSource = try readIntegratedAvValidationSource()
    let helperSource = try readIntegratedAvHelpersSource()

    #expect(helperSource.contains("struct IntegratedValidationField<Value>"))
    #expect(helperSource.contains("func validateIntegratedFieldSet("))
    #expect(validationSource.contains("identityNonEmptyFields()"))
    #expect(validationSource.contains("headlessNonEmptyFields()"))
    #expect(validationSource.contains("videoNonEmptyFields()"))
    #expect(validationSource.contains("videoReceiverNonNegativeIntFields()"))
    #expect(validationSource.contains("proofOptionalNonEmptyFields(proof)"))
    #expect(validationSource.components(separatedBy: "try requireIntegrated").count - 1 < 30)
}

@Test
func integratedAvScalarHelpersThrowWithoutDiscardedReturnValues() throws {
    let source = try readIntegratedAvHelpersSource()

    #expect(source.contains("func requireIntegratedPositive(_ value: Int, _ field: String) throws {"))
    #expect(source.contains("func requireIntegratedPositive(_ value: Double, _ field: String) throws {"))
    #expect(source.contains("func requireIntegratedPercent(_ value: Double, _ field: String) throws {"))
    #expect(!source.contains("func requireIntegratedPositive(_ value: Int, _ field: String) throws -> Bool"))
    #expect(!source.contains("func requireIntegratedPositive(_ value: Double, _ field: String) throws -> Bool"))
    #expect(!source.contains("func requireIntegratedPercent(_ value: Double, _ field: String) throws -> Bool"))
}

@Test
func integratedAvArgumentHelpersAreDiscardableWhenUsedForValidationOnly() throws {
    let source = try readIntegratedAvHelpersSource()

    for signature in [
        "func requiredIntegratedAvRunString(",
        "func requiredIntegratedAvRunPositiveInteger(",
        "func requiredIntegratedAvRunSwitch(",
        "func optionalIntegratedAvRunSwitch(",
        "func integratedAvRunSwitch(",
        "func requiredIntegratedAvRunAtemHost(",
    ] {
        let range = try #require(source.range(of: signature))
        let prefix = source[..<range.lowerBound].suffix(40)
        #expect(prefix.contains("@discardableResult"))
    }
}

private func passCandidateReport() throws -> IntegratedAvReport {
    try integratedAvPassCandidateReport()
}

private func readIntegratedAvValidationSource() throws -> String {
    let sourceURL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("Sources/OpenLolaCore/Integration/IntegratedAvReportValidation.swift")
    return try String(contentsOf: sourceURL, encoding: .utf8)
}

private func readIntegratedAvHelpersSource() throws -> String {
    let sourceURL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("Sources/OpenLolaCore/Integration/IntegratedAvHelpers.swift")
    return try String(contentsOf: sourceURL, encoding: .utf8)
}

private func readIntegratedAvRunSource() throws -> String {
    let sourceURL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("Sources/OpenLolaCore/Integration/IntegratedAvRun.swift")
    return try String(contentsOf: sourceURL, encoding: .utf8)
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
