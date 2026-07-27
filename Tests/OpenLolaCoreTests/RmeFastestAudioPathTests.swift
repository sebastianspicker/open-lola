// Verifies that RME fastest audio path rejects invalid pass evidence.
import Foundation
import Testing

@testable import OpenLolaCore

@Test
func rmeFastestAudioPathRejectsInvalidPassEvidence() throws {
    try rejectInvalidRmeIdentityEvidence()
    try rejectInvalidRmeDriverEvidence()
    try rejectInvalidRmeDeviceCapabilityEvidence()
    try rejectInvalidRmeLoopbackModeEvidence()
    try rejectInvalidRmeLoopbackSampleRateEvidence()
    try rejectInvalidRmeReleaseEvidence()
}

private func rejectInvalidRmeIdentityEvidence() throws {
    try expectRmeFastestAudioPathError(.passWithoutRmeMadiDevice) {
        $0.rmeDevice = builtInFullDuplexDevice(uid: "built-in-uid")
    }
    try expectRmeFastestAudioPathError(.passWithPlaceholderField(
        "driverEvidence.totalMixSnapshot"
    )) {
        $0.driverEvidence.totalMixSnapshot = "TODO(human): export TotalMix snapshot"
    }
    try expectRmeFastestAudioPathError(.passWithAggregateDevice) {
        $0.rmeDevice = rmeMadiDevice(
            uid: "rme-madi-uid",
            overrides: .init(isAggregate: true)
        )
    }
    try expectRmeFastestAudioPathError(.passWithAggregateRouting(
        "aggregate Core Audio routing"
    )) {
        $0.loopbackReport.route = RouteIdentity(
            label: "rme-madi-loopback",
            topology: "aggregate Core Audio routing"
        )
    }
}

private func rejectInvalidRmeDriverEvidence() throws {
    try expectRmeFastestAudioPathError(.passWithoutDedicatedRmeDriver) {
        $0.driverEvidence.driverMode = .classCompliant
    }
    try expectRmeFastestAudioPathError(.passWithSampleRateConversion(.unknown)) {
        $0.driverEvidence.sampleRateConversion = .unknown
    }
}

private func rejectInvalidRmeDeviceCapabilityEvidence() throws {
    try expectRmeFastestAudioPathError(.passWithoutClockDomain) {
        $0.rmeDevice = rmeMadiDevice(
            uid: "rme-madi-uid",
            overrides: .init(clockDomain: nil)
        )
    }
try expectRmeFastestAudioPathError(.passSampleRateOutsideRanges(48_000)) {
        $0.rmeDevice = rmeMadiDevice(
            uid: "rme-madi-uid",
            overrides: .init(availableSampleRateRanges: [
                AudioValueRangeSnapshot(minimum: 96_000, maximum: 96_000)
            ])
        )
    }
try expectRmeFastestAudioPathError(.passBufferFramesOutsideCandidates(32)) {
        $0.rmeDevice = rmeMadiDevice(
            uid: "rme-madi-uid",
            overrides: .init(candidateBufferFrames: BufferFrameCandidates(
                inReportedRange: [64, 128],
                outsideReportedRange: [16, 32],
                note: "test"
            ))
        )
    }
try expectRmeFastestAudioPathError(.passChannelCountExceedsDeviceChannels(
        channelCount: 2,
        inputChannels: 1,
        outputChannels: 1
    )) {
        $0.rmeDevice = rmeMadiDevice(
            uid: "rme-madi-uid",
            overrides: .init(inputChannelCount: 1, outputChannelCount: 1)
        )
    }
    try expectRmeFastestAudioPathError(.passWithoutThunderboltRmePath) {
        $0.rmeDevice = rmeMadiDevice(
            uid: "rme-madi-uid",
            overrides: .init(name: "RME MADIface USB", transportType: "USB")
        )
        $0.loopbackReport = rmeEndpointLoopbackReport(
            selectedMode: $0.loopbackReport.selectedMode,
            audioInterface: "RME MADIface USB",
            driverVersion: "RME USB Series Driver 4.08",
            deviceName: "RME MADIface USB",
            transportType: "USB"
        )
        $0.driverEvidence.driverPackage = "RME USB Series Driver"
        $0.driverEvidence.routingNotes = "USB RME MADI output 1/2 looped to input 1/2"
    }
}

private func rejectInvalidRmeLoopbackModeEvidence() throws {
    try expectRmeFastestAudioPathError(.passWithoutLoopbackPass) {
        $0.loopbackReport.verdict = .partial
    }
    try expectRmeFastestAudioPathError(.passSelectedModeIsNotFastestStable(
        selected: AudioMode(
            sampleRateHertz: 48_000,
            framesPerBuffer: 64,
            channelCount: 2,
            sampleFormat: "int16"
        ),
        fastest: AudioMode(
            sampleRateHertz: 48_000,
            framesPerBuffer: 32,
            channelCount: 2,
            sampleFormat: "int16"
        )
    )) {
        $0.loopbackReport.selectedMode = AudioMode(
            sampleRateHertz: 48_000,
            framesPerBuffer: 64,
            channelCount: 2,
            sampleFormat: "int16"
        )
        $0.loopbackReport.stabilityRun.mode = $0.loopbackReport.selectedMode
    }
}

private func rejectInvalidRmeLoopbackSampleRateEvidence() throws {
    try expectRmeFastestAudioPathError(.passWithoutSupportedSampleRate(96_000)) {
        $0.loopbackReport.sampleRates[1].supported = false
        $0.loopbackReport.sampleRates[1].unsupportedReason = "not tested"
        $0.loopbackReport.sampleRates[1].modeResults = []
    }
    try expectRmeFastestAudioPathError(.passWithoutAcceptedStableMode(
        sampleRateHertz: 44_100
    )) {
        $0.loopbackReport.sampleRates.append(
            SampleRateLoopbackResult(
                sampleRateHertz: 44_100,
                supported: true,
                unsupportedReason: nil,
                modeResults: [
                    acceptedMode(
                        .init(
                            sampleRate: 44_100,
                            frames: 32,
                            stable: false,
                            oneWayMilliseconds: 2.9,
                            p99: 700,
                            max: 1_200,
                            missed: 1,
                            underruns: 1
                        )
                    )
                ]
            )
        )
    }
}

private func rejectInvalidRmeReleaseEvidence() throws {
    try expectRmeFastestAudioPathError(.passWithPlaceholderField("notes")) {
        $0.notes = "placeholder release note"
    }
    try expectRmeFastestAudioPathError(.passWithPlaceholderField(
        "loopbackReport.sampleRates[2].unsupportedReason"
    )) {
        $0.loopbackReport.sampleRates[2].unsupportedReason =
            "TODO(human): confirm 192 kHz support"
    }
}

@Test
func rmeFastestAudioPathThunderboltDetectionRejectsBroadThunSubstring() {
    #expect(isThunderboltPerformancePath(["RME Thunderbolt Driver"]))
    #expect(isThunderboltPerformancePath(["RME MADIface TB3"]))
    #expect(isThunderboltPerformancePath(["RME MADIface TB4"]))
    #expect(!isThunderboltPerformancePath(["RME MADIface thun adapter"]))
    #expect(!isThunderboltPerformancePath(["RME MADIface USB"]))
}

@Test
func rmeFastestAudioPathRejectsPassWithHiddenBufferGrowthInMatrix() throws {
    var report = makeRmeFastestPassCandidate()
    report.loopbackReport.sampleRates[0].modeResults[1].loopback?.hiddenBufferGrowthDetected = true

    #expect(throws: EndpointLoopbackValidationError.hiddenBufferGrowthDetected) {
        try report.validate()
    }
}

@Test
func rmeFastestAudioPathAcceptsSixteenFrameSelectedModeWhenItIsFastestStable() throws {
    let selectedMode = AudioMode(
        sampleRateHertz: 48_000,
        framesPerBuffer: 16,
        channelCount: 2,
        sampleFormat: "int16"
    )
    var report = makeRmeFastestPassCandidate(selectedMode: selectedMode)
    report.loopbackReport.sampleRates[0].modeResults[1].stable = true
    report.loopbackReport.sampleRates[0].modeResults[1].callback?.missedDeadlines = 0
    report.loopbackReport.sampleRates[0].modeResults[1].callback?.underruns = 0

    try report.validate()

    #expect(report.fastestStableMode == selectedMode)
}

@Test
func rmeFastestAudioPathRejectsEightFramePassWithoutLongRunEvidence() throws {
    let selectedMode = AudioMode(
        sampleRateHertz: 48_000,
        framesPerBuffer: 8,
        channelCount: 2,
        sampleFormat: "int16"
    )
    var report = makeRmeFastestPassCandidate(selectedMode: selectedMode)
    report.loopbackReport.sampleRates[0].modeResults[0].accepted = true
    report.loopbackReport.sampleRates[0].modeResults[0].stable = true
    report.loopbackReport.sampleRates[0].modeResults[0].rejectionReason = nil
    report.loopbackReport.sampleRates[0].modeResults[0].callback = EndpointCallbackMetrics(latency: .init(p50Microseconds: 120, p95Microseconds: 210, p99Microseconds: 320, maxMicroseconds: 520), events: .init(missedDeadlines: 0, underruns: 0, overruns: 0))
    report.loopbackReport.sampleRates[0].modeResults[0].loopback = EndpointLoopbackMetrics(
        reportedInputLatencyFrames: 12,
        reportedOutputLatencyFrames: 12,
        inputSafetyOffsetFrames: 0,
        outputSafetyOffsetFrames: 0,
        measuredAnalogRoundTripMilliseconds: 3.2,
        correctedOneWayMilliseconds: 1.6,
        hiddenBufferGrowthDetected: false
    )
    report.loopbackReport.stabilityRun.mode = selectedMode
    report.loopbackReport.stabilityRun.durationSeconds = 1_800

    #expect(throws: EndpointLoopbackValidationError.eightFrameStabilityRunTooShort(
        seconds: 1_800,
        minimumSeconds: EndpointLoopbackReport.minimumExtremeLowLatencyDurationSeconds
    )) {
        try report.validate()
    }
}

@Test
func rmeFastestAudioPathPassCandidateValidates() throws {
    let report = makeRmeFastestPassCandidate()

    try report.validate()

    #expect(report.verdict == .pass)
    #expect(report.fastestStableMode == report.loopbackReport.selectedMode)
}
