// Covers pure recovery contracts for native execution, MADI drift, and latency profiles.
import Foundation
import Testing

@testable import OpenLolaCore

@Test
func wave12NativeExecutionSettingsDefaultAndGroupedInitializersPreserveFields() throws {
    let defaults = NativeAppShellExecutionSettings()
    #expect(defaults.executionMode == .local)
    #expect(defaults.readinessDelayMilliseconds == 300)
    #expect(defaults.requirePreflight)

    let settings = NativeAppShellExecutionSettings(
        paths: .init(plan: "/tmp/plan.json", supervisorReport: "/tmp/supervisor.json", connectionPreflightReport: "/tmp/preflight.json"),
        behavior: .init(executionMode: .local, execute: true, requirePreflight: false, sshFallbackExplicitlySelected: false, sshFallbackReason: "", readinessDelayMilliseconds: 7),
        ssh: .init(macAHost: "mac-a", macBHost: "mac-b", macAWorkingDirectory: "/a", macBWorkingDirectory: "/b", executable: "/usr/bin/ssh", scpExecutable: "/usr/bin/scp")
    )

    try settings.validate()
    #expect(settings.planPath == "/tmp/plan.json")
    #expect(settings.supervisorReportPath == "/tmp/supervisor.json")
    #expect(settings.connectionPreflightReportPath == "/tmp/preflight.json")
    #expect(settings.readinessDelayMilliseconds == 7)
}

@Test
func wave12NativeExecutionSettingsRejectsBlankPathsAndNonPositiveDelay() {
    var settings = NativeAppShellExecutionSettings()
    settings.planPath = " \n"
    #expect(throws: NativeAppShellExecutionValidationError.emptyField("planPath")) {
        try settings.validate()
    }

    settings = NativeAppShellExecutionSettings()
    settings.supervisorReportPath = "\t"
    #expect(throws: NativeAppShellExecutionValidationError.emptyField("supervisorReportPath")) {
        try settings.validate()
    }

    settings = NativeAppShellExecutionSettings()
    settings.readinessDelayMilliseconds = 0
    #expect(throws: NativeAppShellExecutionValidationError.nonPositiveField("readinessDelayMilliseconds")) {
        try settings.validate()
    }
}

@Test
func wave12NativeExecutionSettingsSkipsPreflightPathWhenDisabled() throws {
    var settings = NativeAppShellExecutionSettings()
    settings.requirePreflight = false
    settings.connectionPreflightReportPath = "  "

    try settings.validate()
    let arguments = try settings.supervisorArguments(executablePath: "/tmp/open-lola")
    #expect(!arguments.contains("--connection-preflight-report"))
}

@Test
func wave12NativeExecutionSettingsRequiresCompleteSshFallback() {
    var settings = NativeAppShellExecutionSettings()
    settings.executionMode = .ssh

    #expect(throws: NativeAppShellExecutionValidationError.sshFallbackRequiresExplicitSelection) {
        try settings.validate()
    }

    settings.sshFallbackExplicitlySelected = true
    #expect(throws: NativeAppShellExecutionValidationError.sshFallbackMissingReason) {
        try settings.validate()
    }

    settings.sshFallbackReason = "operator fallback"
    settings.macASSH = " "
    #expect(throws: NativeAppShellExecutionValidationError.emptyField("macASSH")) {
        try settings.validate()
    }
}

@Test
func wave12NativeExecutionSettingsBuildsLocalAndSshArguments() throws {
    var local = NativeAppShellExecutionSettings()
    local.requirePreflight = false
    let localArguments = try local.supervisorArguments(executablePath: "/tmp/open-lola")
    #expect(wave12ArgumentValue(localArguments, "--execution-mode") == "local")
    #expect(wave12ArgumentValue(localArguments, "--executable") == "/tmp/open-lola")
    #expect(!localArguments.contains("--mac-a-ssh"))

    var ssh = NativeAppShellExecutionSettings()
    ssh.executionMode = .ssh
    ssh.sshFallbackExplicitlySelected = true
    ssh.sshFallbackReason = "lab route is unavailable"
    ssh.macASSH = "operator@mac-a"
    ssh.macBSSH = "operator@mac-b"
    ssh.macAWorkingDirectory = "/opt/a"
    ssh.macBWorkingDirectory = "/opt/b"
    let sshArguments = try ssh.supervisorArguments(executablePath: "/tmp/open-lola")
    #expect(wave12ArgumentValue(sshArguments, "--execution-mode") == "ssh")
    #expect(wave12ArgumentValue(sshArguments, "--mac-a-workdir") == "/opt/a")
    #expect(wave12ArgumentValue(sshArguments, "--mac-b-workdir") == "/opt/b")
    #expect(!sshArguments.contains("--executable"))
}

@Test
func wave12NativeExecutionSettingsRejectsNonOpenLolaExecutable() {
    let settings = NativeAppShellExecutionSettings()
    #expect(throws: NativeAppShellExecutionValidationError.invalidSupervisorExecutable("/tmp/not-lola")) {
        _ = try settings.supervisorArguments(executablePath: "/tmp/not-lola")
    }
}

@Test
func wave12NativeExecutionReportAllowsPartialAndRejectsFalsePasses() throws {
    var report = wave12ExecutionReport(verdict: .partial, exitCode: nil, validationExitCode: nil)
    try report.validate()

    report.verdict = .pass
    #expect(throws: NativeAppShellExecutionValidationError.passWithoutSuccessfulExit) {
        try report.validate()
    }
    report.exitCode = 0
    #expect(throws: NativeAppShellExecutionValidationError.passWithoutValidatedReport) {
        try report.validate()
    }
    report.validationExitCode = 0
    try report.validate()
}

@Test
func wave12NativeExecutionReportRejectsRequiredBlankFields() {
    var report = wave12ExecutionReport(verdict: .partial, exitCode: nil, validationExitCode: nil)
    report.command = []
    #expect(throws: NativeAppShellExecutionValidationError.emptyField("command")) {
        try report.validate()
    }
    report = wave12ExecutionReport(verdict: .partial, exitCode: nil, validationExitCode: nil)
    report.stdoutPath = " "
    #expect(throws: NativeAppShellExecutionValidationError.emptyField("stdoutPath")) {
        try report.validate()
    }
}

@Test
func wave12MadiAudioPairRejectsPayloadAndDirection() {
    var payload = wave12Stream()
    payload.payloadType = .audioOpusCeltLowDelayFrame
    #expect(throws: MadiFullDuplexError.unsupportedPayloadType(.audioOpusCeltLowDelayFrame)) {
        _ = try MadiFullDuplexAudioPair(localToRemote: payload, remoteToLocal: wave12Stream(id: 2))
    }

    var disabled = wave12Stream()
    disabled.direction = .disabled
    #expect(throws: MadiFullDuplexError.disabledAudioStream(1)) {
        _ = try MadiFullDuplexAudioPair(localToRemote: disabled, remoteToLocal: wave12Stream(id: 2))
    }
}

@Test
func wave12MadiAudioPairRejectsCompatibilityMismatches() {
    #expect(throws: MadiFullDuplexError.sampleRateMismatch(local: 48_000, remote: 96_000)) {
        _ = try MadiFullDuplexAudioPair(localToRemote: wave12Stream(), remoteToLocal: wave12Stream(id: 2, sampleRate: 96_000))
    }
    #expect(throws: MadiFullDuplexError.sampleFormatMismatch(local: .float32LittleEndian, remote: .int16LittleEndian)) {
        _ = try MadiFullDuplexAudioPair(localToRemote: wave12Stream(), remoteToLocal: wave12Stream(id: 2, sampleFormat: .int16LittleEndian))
    }
    #expect(throws: MadiFullDuplexError.framesPerPacketMismatch(local: 32, remote: 16)) {
        _ = try MadiFullDuplexAudioPair(localToRemote: wave12Stream(), remoteToLocal: wave12Stream(id: 2, frames: 16))
    }
}

@Test
func wave12MadiAudioPairAllowsExplicitAsymmetricChannels() throws {
    #expect(throws: MadiFullDuplexError.asymmetricChannelCount(local: 2, remote: 4)) {
        _ = try MadiFullDuplexAudioPair(localToRemote: wave12Stream(channels: 2), remoteToLocal: wave12Stream(id: 2, channels: 4))
    }

    let pair = try MadiFullDuplexAudioPair(
        localToRemote: wave12Stream(channels: 2),
        remoteToLocal: wave12Stream(id: 2, channels: 4),
        allowsAsymmetricChannelCounts: true
    )
    #expect(pair.allowsAsymmetricChannelCounts)
}

@Test
func wave12MadiAudioPairCreatesTransportModesAndRejectsUnsupportedFrames() throws {
    let pair = try MadiFullDuplexAudioPair(localToRemote: wave12Stream(), remoteToLocal: wave12Stream(id: 2))
    let local = try pair.localSendMode(maxTransmissionUnitBytes: 1_200, maxFragmentsPerDeadline: 8, metadataRevision: 1)
    let remote = try pair.remoteReceiveMode(maxTransmissionUnitBytes: 1_200, maxFragmentsPerDeadline: 8, metadataRevision: 1, rxBufferProfile: .small)
    #expect(local.protocolVersion == .udpPcmV2)
    #expect(local.latencyProfile == .safeLowLatency)
    #expect(!local.fragments.isEmpty)
    #expect(remote.rxBufferProfile == .small)

    let unsupported = try MadiFullDuplexAudioPair(localToRemote: wave12Stream(frames: 12), remoteToLocal: wave12Stream(id: 2, frames: 12))
    #expect(throws: MadiFullDuplexError.unsupportedFramesPerPacket(12)) {
        _ = try unsupported.localSendMode(maxTransmissionUnitBytes: 1_200, maxFragmentsPerDeadline: 8, metadataRevision: 1)
    }
}

@Test
func wave12MadiCorrectionPolicyValidatesEveryPositiveField() {
    #expect(throws: MadiFullDuplexError.nonPositiveField("driftThresholdPartsPerMillion")) {
        try MadiFullDuplexCorrectionPolicy(driftThresholdPartsPerMillion: 0).validate()
    }
    #expect(throws: MadiFullDuplexError.nonPositiveField("maxCorrectionFramesPerEvent")) {
        try MadiFullDuplexCorrectionPolicy(maxCorrectionFramesPerEvent: 0).validate()
    }
    #expect(throws: MadiFullDuplexError.nonPositiveField("maxEventsPerMinute")) {
        try MadiFullDuplexCorrectionPolicy(maxEventsPerMinute: 0).validate()
    }
}

@Test
func wave12MadiCorrectionPolicyBoundsDirectionAndFrameCount() {
    let policy = MadiFullDuplexCorrectionPolicy(driftThresholdPartsPerMillion: 100, maxCorrectionFramesPerEvent: 3)
    #expect(policy.correctionEvent(for: wave12Estimate(slope: 99), sequenceNumber: 1) == nil)

    let insert = policy.correctionEvent(for: wave12Estimate(slope: 250), sequenceNumber: 2)
    #expect(insert?.action == .insertFrame)
    #expect(insert?.correctionFrames == 3)

    let drop = policy.correctionEvent(for: wave12Estimate(slope: -101), sequenceNumber: 3)
    #expect(drop?.action == .dropFrame)
    #expect(drop?.correctionFrames == 2)
}

@Test
func wave12MadiClockDriftSimulatorValidatesInputsAndEmitsCorrection() throws {
    let policy = MadiFullDuplexCorrectionPolicy(driftThresholdPartsPerMillion: 1, maxCorrectionFramesPerEvent: 2)
    #expect(throws: MadiFullDuplexError.nonPositiveField("sampleCount")) {
        _ = try MadiFullDuplexClockDriftSimulator.run(sampleCount: 0, senderFrameStep: 32, receiverFrameStep: 33, correctionPolicy: policy)
    }

    let result = try MadiFullDuplexClockDriftSimulator.run(sampleCount: 3, senderFrameStep: 100, receiverFrameStep: 101, correctionPolicy: policy)
    #expect(result.samples.map(\.senderFrameIndex) == [0, 100, 200])
    #expect(result.estimate.driftSlopePartsPerMillion == 10_000)
    #expect(result.correctionEvents.count == 1)
    #expect(result.correctionEvents[0].action == .insertFrame)
    try result.validate()
}

@Test
func wave12MadiClockDriftEstimateRejectsEmptyAndZeroSenderDelta() {
    #expect(throws: MadiFullDuplexError.emptyField("samples")) {
        _ = try MadiFullDuplexClockDriftSimulator.estimate(from: [])
    }
    let flat = [
        MadiFullDuplexClockSample(senderFrameIndex: 4, receiverPlayoutFrameIndex: 4, localHostTimeNanoseconds: 1),
        MadiFullDuplexClockSample(senderFrameIndex: 4, receiverPlayoutFrameIndex: 5, localHostTimeNanoseconds: 2)
    ]
    #expect(throws: MadiFullDuplexError.nonPositiveField("senderFrameDelta")) {
        _ = try MadiFullDuplexClockDriftSimulator.estimate(from: flat)
    }
}

@Test
func wave12LatencyBudgetCalculatesPrimaryAndFallbackShapes() throws {
    let primary = try LatencyProfileBudget.calculate(profile: .safeLowLatency, sampleRateHertz: 48_000, channelCount: 2, sampleFormat: .int16LittleEndian)
    #expect(primary.framesPerBuffer == 32)
    #expect(primary.audioPayloadBytesPerPacket == 128)
    #expect(primary.packetsPerSecond == 1_500)

    let fallback = try LatencyProfileBudget.calculate(profile: .safeLowLatency, sampleRateHertz: 48_000, channelCount: 2, sampleFormat: .float32LittleEndian, framesPerBuffer: 64)
    #expect(fallback.framesPerBuffer == 64)
    #expect(fallback.audioPayloadBytesPerPacket == 512)
}

@Test
func wave12LatencyBudgetRejectsInvalidAndUnsupportedFrames() {
    #expect(throws: LatencyProfileValidationError.nonPositiveField("sampleRateHertz")) {
        _ = try LatencyProfileBudget.calculate(profile: .safeLowLatency, sampleRateHertz: 0, channelCount: 2, sampleFormat: .int16LittleEndian)
    }
    #expect(throws: LatencyProfileValidationError.unsupportedFrameSize(profile: .safeLowLatency, expected: 32, actual: 16)) {
        _ = try LatencyProfileBudget.calculate(profile: .safeLowLatency, sampleRateHertz: 48_000, channelCount: 2, sampleFormat: .int16LittleEndian, framesPerBuffer: 16)
    }
}

@Test
func wave12LatencySelectionUsesSafeDefaultsAndRejectsInvalidRxProfile() throws {
    let request = wave12LatencyRequest(profile: .safeLowLatency, frames: 32)
    let selection = try LatencyProfileSelection.validate(request: request, device: nil, route: nil)
    #expect(selection.rxBufferProfile == .direct)
    #expect(selection.warnings.isEmpty)
    #expect(selection.verdict == .partial)

    let invalid = wave12LatencyRequest(profile: .extremeLowLatency8, frames: 8, rxBuffer: .small, explicit: true, experimental: true, acknowledged: true)
    #expect(throws: LatencyProfileValidationError.unsupportedRxBufferProfile(profile: .extremeLowLatency8, rxBufferProfile: .small)) {
        _ = try LatencyProfileSelection.validate(request: invalid, device: nil, route: nil)
    }
}

@Test
func wave12LatencySelectionRequiresOptInsAndDirectRoutes() {
    let missingOptIn = wave12LatencyRequest(profile: .extremeLowLatency8, frames: 8)
    #expect(throws: LatencyProfileValidationError.missingExplicitOptIn(.extremeLowLatency8)) {
        _ = try LatencyProfileSelection.validate(request: missingOptIn, device: nil, route: nil)
    }

    let routed = wave12LatencyRequest(profile: .ultraLowLatency16, frames: 16, explicit: true, acknowledged: true)
    #expect(throws: LatencyProfileValidationError.directRouteRequired(.ultraLowLatency16)) {
        _ = try LatencyProfileSelection.validate(request: routed, device: nil, route: RouteIdentity(label: "campus", topology: "shared network"))
    }
}

@Test
func wave12LatencyHelpersRecognizeFormatsDirectRoutesAndPositiveValues() throws {
    #expect(udpSampleFormat(for: AudioMode(sampleRateHertz: 48_000, framesPerBuffer: 32, channelCount: 2, sampleFormat: "int16")) == .int16LittleEndian)
    #expect(udpSampleFormat(for: AudioMode(sampleRateHertz: 48_000, framesPerBuffer: 32, channelCount: 2, sampleFormat: "FLOAT32LITTLEENDIAN")) == .float32LittleEndian)
    #expect(udpSampleFormat(for: AudioMode(sampleRateHertz: 48_000, framesPerBuffer: 32, channelCount: 2, sampleFormat: "opus")) == nil)
    #expect(isDirectRoute(RouteIdentity(label: "lab", topology: "RME loopback")))
    #expect(!isDirectRoute(RouteIdentity(label: "campus", topology: "managed network")))
    try requireLatencyProfilePositive(1, "count")
    #expect(throws: LatencyProfileValidationError.nonPositiveField("count")) {
        try requireLatencyProfilePositive(0, "count")
    }
}

private func wave12ArgumentValue(_ arguments: [String], _ flag: String) -> String? {
    guard let index = arguments.firstIndex(of: flag), arguments.indices.contains(index + 1) else {
        return nil
    }
    return arguments[index + 1]
}

private func wave12ExecutionReport(
    verdict: MeasurementVerdict,
    exitCode: Int?,
    validationExitCode: Int?
) -> NativeAppShellExecutionReport {
    NativeAppShellExecutionReport(
        lifecycle: .init(command: ["/tmp/open-lola"], startedAt: "2026-08-05T00:00:00Z", exitCode: exitCode),
        artifacts: .init(stdoutPath: "/tmp/stdout.log", stderrPath: "/tmp/stderr.log"),
        validation: .init(exitCode: validationExitCode),
        outcome: .init(verdict: verdict, notes: "deterministic fixture")
    )
}

private func wave12Stream(
    id: Int = 1,
    sampleRate: Int = 48_000,
    sampleFormat: UdpPcmSampleFormat = .float32LittleEndian,
    channels: Int = 2,
    frames: Int = 32
) -> AudioStreamDescription {
    AudioStreamDescription(
        identity: .init(id: id, direction: .bidirectional, clockDomain: "wave12-clock"),
        format: .init(sampleRateHertz: sampleRate, sampleFormat: sampleFormat, channelCount: channels, channelOrder: AudioChannelSet.defaultInput(count: channels).sortedByStableSourceIndex),
        packet: .init(framesPerPacket: frames, payloadType: .audioPcmV2)
    )
}

private func wave12Estimate(slope: Double) -> MadiFullDuplexDriftEstimate {
    MadiFullDuplexDriftEstimate(sampleCount: 2, senderFrameDelta: 100, receiverFrameDelta: 100, driftSlopePartsPerMillion: slope)
}

private func wave12LatencyRequest(
    profile: LatencyProfile,
    frames: Int,
    rxBuffer: RxBufferProfile? = nil,
    explicit: Bool = false,
    experimental: Bool = false,
    acknowledged: Bool = false
) -> LatencyProfileSelectionRequest {
    LatencyProfileSelectionRequest(
        profile: profile,
        sampleRateHertz: 48_000,
        framesPerBuffer: frames,
        channelCount: 2,
        sampleFormat: .int16LittleEndian,
        rxBufferProfile: rxBuffer,
        optIns: .init(explicitProfile: explicit, experimentalMode: experimental, warningAcknowledged: acknowledged)
    )
}
