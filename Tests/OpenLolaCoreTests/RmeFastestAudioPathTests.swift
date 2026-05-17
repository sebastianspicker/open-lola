import Foundation
import Testing

@testable import OpenLolaCore

@Test
func rmeFastestAudioPathRejectsInvalidPassEvidence() throws {
    try expectRmeFastestAudioPathError(.passWithoutRmeMadiDevice) {
        $0.rmeDevice = builtInFullDuplexDevice(uid: "built-in-uid")
    }
    try expectRmeFastestAudioPathError(.passWithPlaceholderField(
        "driverEvidence.totalMixSnapshot"
    )) {
        $0.driverEvidence.totalMixSnapshot = "TODO(human): export TotalMix snapshot"
    }
    try expectRmeFastestAudioPathError(.passWithAggregateDevice) {
        $0.rmeDevice = rmeMadiDevice(uid: "rme-madi-uid", isAggregate: true)
    }
    try expectRmeFastestAudioPathError(.passWithAggregateRouting(
        "aggregate Core Audio routing"
    )) {
        $0.loopbackReport.route = RouteIdentity(
            label: "rme-madi-loopback",
            topology: "aggregate Core Audio routing"
        )
    }
    try expectRmeFastestAudioPathError(.passWithoutDedicatedRmeDriver) {
        $0.driverEvidence.driverMode = .classCompliant
    }
    try expectRmeFastestAudioPathError(.passWithSampleRateConversion(.unknown)) {
        $0.driverEvidence.sampleRateConversion = .unknown
    }
    try expectRmeFastestAudioPathError(.passWithoutClockDomain) {
        $0.rmeDevice = rmeMadiDevice(uid: "rme-madi-uid", clockDomain: nil)
    }
    try expectRmeFastestAudioPathError(.passSelectedSampleRateOutsideInventoryRanges(48_000)) {
        $0.rmeDevice = rmeMadiDevice(
            uid: "rme-madi-uid",
            availableSampleRateRanges: [
                AudioValueRangeSnapshot(minimum: 96_000, maximum: 96_000)
            ]
        )
    }
    try expectRmeFastestAudioPathError(.passSelectedBufferFramesOutsideInventoryCandidates(32)) {
        $0.rmeDevice = rmeMadiDevice(
            uid: "rme-madi-uid",
            candidateBufferFrames: BufferFrameCandidates(
                inReportedRange: [64, 128],
                outsideReportedRange: [16, 32],
                note: "test"
            )
        )
    }
    try expectRmeFastestAudioPathError(.passSelectedChannelCountExceedsDeviceChannels(
        channelCount: 2,
        inputChannels: 1,
        outputChannels: 1
    )) {
        $0.rmeDevice = rmeMadiDevice(
            uid: "rme-madi-uid",
            inputChannelCount: 1,
            outputChannelCount: 1
        )
    }
    try expectRmeFastestAudioPathError(.passWithoutThunderboltRmePath) {
        $0.rmeDevice = rmeMadiDevice(
            uid: "rme-madi-uid",
            name: "RME MADIface USB",
            transportType: "USB"
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
                        44_100,
                        32,
                        stable: false,
                        oneWayMilliseconds: 2.9,
                        p99: 700,
                        max: 1_200,
                        missed: 1,
                        underruns: 1
                    ),
                ]
            )
        )
    }
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
    report.loopbackReport.sampleRates[0].modeResults[0].callback = EndpointCallbackMetrics(
        p50Microseconds: 120,
        p95Microseconds: 210,
        p99Microseconds: 320,
        maxMicroseconds: 520,
        missedDeadlines: 0,
        underruns: 0,
        overruns: 0
    )
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

private func makeRmeFastestPassCandidate(
    selectedMode: AudioMode = AudioMode(
        sampleRateHertz: 48_000,
        framesPerBuffer: 32,
        channelCount: 2,
        sampleFormat: "int16"
    )
) -> RmeFastestAudioPathReport {
    return RmeFastestAudioPathReport(
        id: "g02-rme-fastest-pass-candidate",
        title: "G02 RME fastest audio pass candidate",
        capturedAt: "2026-05-02T00:00:00Z",
        inventoryCapturedAt: "2026-05-02T00:00:00Z",
        inventoryHostName: "reference-mac",
        rmeDevice: rmeMadiDevice(uid: "rme-madi-uid"),
        driverEvidence: RmeMadiDriverEvidence(
            driverPackage: "RME Thunderbolt Driver",
            driverVersion: "4.08",
            firmwareVersion: "230",
            driverMode: .driverKit,
            totalMixVersion: "1.94",
            totalMixSnapshot: "snapshots/g02-rme-totalmix.tmx",
            clockSource: "internal clock with MADI loopback locked",
            sampleRateSource: "Core Audio nominal sample rate",
            sampleRateConversion: .absent,
            routingNotes: "Thunderbolt RME MADI output 1/2 looped to input 1/2"
        ),
        loopbackReport: rmeEndpointLoopbackReport(selectedMode: selectedMode),
        verdict: .pass,
        notes: "Synthetic pass candidate for validator tests only."
    )
}

private func expectRmeFastestAudioPathError(
    _ expected: RmeFastestAudioPathValidationError,
    mutate: (inout RmeFastestAudioPathReport) throws -> Void
) throws {
    var report = makeRmeFastestPassCandidate()
    try mutate(&report)

    #expect(throws: expected) {
        try report.validate()
    }
}

private func rmeEndpointLoopbackReport(
    selectedMode: AudioMode,
    audioInterface: String = "RME Fireface UFX+ MADI Thunderbolt",
    driverVersion: String = "RME Thunderbolt Driver 4.08",
    deviceName: String = "RME Fireface UFX+ MADI Thunderbolt",
    transportType: String = "thunderbolt"
) -> EndpointLoopbackReport {
    EndpointLoopbackReport(
        id: "m03-rme-loopback-pass-candidate",
        title: "RME MADI loopback pass candidate",
        capturedAt: "2026-05-02T00:00:00Z",
        hardware: HardwareIdentity(
            referenceMac: "reference-mac",
            audioInterface: audioInterface,
            osVersion: "macOS 15.4.1 24E263",
            driverVersion: driverVersion
        ),
        route: RouteIdentity(
            label: "rme-madi-loopback",
            topology: "single-mac-rme-madi-output-to-input"
        ),
        device: EndpointLoopbackDevice(
            name: deviceName,
            uid: "rme-madi-uid",
            transportType: transportType,
            clockDomain: 1
        ),
        selectedMode: selectedMode,
        sampleRates: [
            SampleRateLoopbackResult(
                sampleRateHertz: 48_000,
                supported: true,
                unsupportedReason: nil,
                modeResults: [
                    rejectedMode(48_000, 8, reason: "experimental 8-frame mode requires separate long-run evidence"),
                    acceptedMode(48_000, 16, stable: false, oneWayMilliseconds: 2.1, p99: 420, max: 900, missed: 3, underruns: 1),
                    acceptedMode(48_000, 32, stable: true, oneWayMilliseconds: 2.55, p99: 240, max: 380),
                    acceptedMode(48_000, 64, stable: true, oneWayMilliseconds: 3.2, p99: 210, max: 320),
                    acceptedMode(48_000, 128, stable: true, oneWayMilliseconds: 4.0, p99: 190, max: 260),
                ]
            ),
            SampleRateLoopbackResult(
                sampleRateHertz: 96_000,
                supported: true,
                unsupportedReason: nil,
                modeResults: [
                    rejectedMode(96_000, 8, reason: "experimental 8-frame mode requires separate long-run evidence"),
                    rejectedMode(96_000, 16, reason: "device rejected 16-frame mode at 96 kHz"),
                    acceptedMode(96_000, 32, stable: false, oneWayMilliseconds: 2.35, p99: 500, max: 1_100, missed: 2, underruns: 1),
                    acceptedMode(96_000, 64, stable: true, oneWayMilliseconds: 2.8, p99: 220, max: 340),
                    acceptedMode(96_000, 128, stable: true, oneWayMilliseconds: 3.55, p99: 200, max: 290),
                ]
            ),
            SampleRateLoopbackResult(
                sampleRateHertz: 192_000,
                supported: false,
                unsupportedReason: "device did not report 192 kHz support",
                modeResults: []
            ),
        ],
        stabilityRun: EndpointStabilityRun(
            mode: selectedMode,
            durationSeconds: 1_800,
            callback: EndpointCallbackMetrics(
                p50Microseconds: 100,
                p95Microseconds: 185,
                p99Microseconds: 250,
                maxMicroseconds: 390,
                missedDeadlines: 0,
                underruns: 0,
                overruns: 0
            ),
            dropoutEvents: 0,
            hiddenBufferGrowthDetected: false,
            notes: "30-minute fixed-target run"
        ),
        verdict: .pass,
        notes: "Synthetic RME loopback pass candidate for validator tests only."
    )
}

private func acceptedMode(
    _ sampleRate: Int,
    _ frames: Int,
    stable: Bool,
    oneWayMilliseconds: Double,
    p99: Double,
    max: Double,
    missed: Int = 0,
    underruns: Int = 0
) -> EndpointModeResult {
    EndpointModeResult(
        mode: AudioMode(
            sampleRateHertz: sampleRate,
            framesPerBuffer: frames,
            channelCount: 2,
            sampleFormat: "int16"
        ),
        accepted: true,
        stable: stable,
        rejectionReason: nil,
        callback: EndpointCallbackMetrics(
            p50Microseconds: 100,
            p95Microseconds: 180,
            p99Microseconds: p99,
            maxMicroseconds: max,
            missedDeadlines: missed,
            underruns: underruns,
            overruns: 0
        ),
        loopback: EndpointLoopbackMetrics(
            reportedInputLatencyFrames: 12,
            reportedOutputLatencyFrames: 12,
            inputSafetyOffsetFrames: 0,
            outputSafetyOffsetFrames: 0,
            measuredAnalogRoundTripMilliseconds: oneWayMilliseconds * 2,
            correctedOneWayMilliseconds: oneWayMilliseconds,
            hiddenBufferGrowthDetected: false
        ),
        notes: stable ? "stable measured row" : "accepted but unstable measured row"
    )
}

private func rejectedMode(_ sampleRate: Int, _ frames: Int, reason: String) -> EndpointModeResult {
    EndpointModeResult(
        mode: AudioMode(
            sampleRateHertz: sampleRate,
            framesPerBuffer: frames,
            channelCount: 2,
            sampleFormat: "int16"
        ),
        accepted: false,
        stable: false,
        rejectionReason: reason,
        callback: nil,
        loopback: nil,
        notes: "rejected measured row"
    )
}

private func loadRmeFastestAudioPathFixture(named name: String) throws -> RmeFastestAudioPathReport {
    let url = try rmeFastestAudioPathFixtureURL(named: name)
    return try RmeFastestAudioPathReport.decode(from: Data(contentsOf: url))
}

private func rmeFastestAudioPathFixtureURL(named name: String) throws -> URL {
    let nestedURL = Bundle.module.url(
        forResource: name,
        withExtension: "json",
        subdirectory: "RmeFastestAudioPathReports/valid"
    )

    return try #require(
        nestedURL ?? Bundle.module.url(
            forResource: name,
            withExtension: "json",
            subdirectory: nil
        )
    )
}
