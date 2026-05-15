import Foundation
import Testing

@testable import OpenLolaCore

@Test
func rmeFastestAudioPathPartialFixtureDecodesAndValidates() throws {
    let report = try loadRmeFastestAudioPathFixture(named: "rme-fastest-audio-partial")

    try report.validate()

    #expect(report.verdict == .partial)
    #expect(report.loopbackReport.verdict == .partial)
    #expect(report.driverEvidence.driverMode == .unknown)
}

@Test
func rmeFastestAudioPathRejectsPassWithoutRmeDevice() throws {
    var report = makeRmeFastestPassCandidate()
    report.rmeDevice = builtInFullDuplexDevice(uid: "built-in-uid")

    #expect(throws: RmeFastestAudioPathValidationError.passWithoutRmeMadiDevice) {
        try report.validate()
    }
}

@Test
func rmeFastestAudioPathRejectsPassWithPlaceholderDriverEvidence() throws {
    var report = makeRmeFastestPassCandidate()
    report.driverEvidence.totalMixSnapshot = "TODO(human): export TotalMix snapshot"

    #expect(throws: RmeFastestAudioPathValidationError.passWithPlaceholderField(
        "driverEvidence.totalMixSnapshot"
    )) {
        try report.validate()
    }
}

@Test
func rmeFastestAudioPathRejectsPassWithAggregateDevice() throws {
    var report = makeRmeFastestPassCandidate()
    report.rmeDevice = rmeMadiDevice(uid: "rme-madi-uid", isAggregate: true)

    #expect(throws: RmeFastestAudioPathValidationError.passWithAggregateDevice) {
        try report.validate()
    }
}

@Test
func rmeFastestAudioPathRejectsPassWithAggregateRouting() throws {
    var report = makeRmeFastestPassCandidate()
    report.loopbackReport.route = RouteIdentity(
        label: "rme-madi-loopback",
        topology: "aggregate Core Audio routing"
    )

    #expect(throws: RmeFastestAudioPathValidationError.passWithAggregateRouting(
        "aggregate Core Audio routing"
    )) {
        try report.validate()
    }
}

@Test
func rmeFastestAudioPathRejectsPassWithClassCompliantDriver() throws {
    var report = makeRmeFastestPassCandidate()
    report.driverEvidence.driverMode = .classCompliant

    #expect(throws: RmeFastestAudioPathValidationError.passWithoutDedicatedRmeDriver) {
        try report.validate()
    }
}

@Test
func rmeFastestAudioPathRejectsPassWithUnresolvedSampleRateConversion() throws {
    var report = makeRmeFastestPassCandidate()
    report.driverEvidence.sampleRateConversion = .unknown

    #expect(throws: RmeFastestAudioPathValidationError.passWithSampleRateConversion(.unknown)) {
        try report.validate()
    }
}

@Test
func rmeFastestAudioPathRejectsPassWithoutClockDomain() throws {
    var report = makeRmeFastestPassCandidate()
    report.rmeDevice = rmeMadiDevice(uid: "rme-madi-uid", clockDomain: nil)

    #expect(throws: RmeFastestAudioPathValidationError.passWithoutClockDomain) {
        try report.validate()
    }
}

@Test
func rmeFastestAudioPathRejectsPassWhenSelectedRateIsOutsideInventoryRanges() throws {
    var report = makeRmeFastestPassCandidate()
    report.rmeDevice = rmeMadiDevice(
        uid: "rme-madi-uid",
        availableSampleRateRanges: [
            AudioValueRangeSnapshot(minimum: 96_000, maximum: 96_000)
        ]
    )

    #expect(throws: RmeFastestAudioPathValidationError
        .passSelectedSampleRateOutsideInventoryRanges(48_000)) {
        try report.validate()
    }
}

@Test
func rmeFastestAudioPathRejectsPassWhenSelectedFramesAreOutsideInventoryCandidates() throws {
    var report = makeRmeFastestPassCandidate()
    report.rmeDevice = rmeMadiDevice(
        uid: "rme-madi-uid",
        candidateBufferFrames: BufferFrameCandidates(
            inReportedRange: [64, 128],
            outsideReportedRange: [16, 32],
            note: "test"
        )
    )

    #expect(throws: RmeFastestAudioPathValidationError
        .passSelectedBufferFramesOutsideInventoryCandidates(32)) {
        try report.validate()
    }
}

@Test
func rmeFastestAudioPathRejectsPassWhenSelectedChannelsExceedInventory() throws {
    var report = makeRmeFastestPassCandidate()
    report.rmeDevice = rmeMadiDevice(
        uid: "rme-madi-uid",
        inputChannelCount: 1,
        outputChannelCount: 1
    )

    #expect(throws: RmeFastestAudioPathValidationError
        .passSelectedChannelCountExceedsDeviceChannels(
            channelCount: 2,
            inputChannels: 1,
            outputChannels: 1
        )) {
        try report.validate()
    }
}

@Test
func rmeFastestAudioPathRejectsPassWithoutThunderboltPath() throws {
    var report = makeRmeFastestPassCandidate()
    report.rmeDevice = rmeMadiDevice(
        uid: "rme-madi-uid",
        name: "RME MADIface USB",
        transportType: "USB"
    )
    report.loopbackReport = rmeEndpointLoopbackReport(
        selectedMode: report.loopbackReport.selectedMode,
        audioInterface: "RME MADIface USB",
        driverVersion: "RME USB Series Driver 4.08",
        deviceName: "RME MADIface USB",
        transportType: "USB"
    )
    report.driverEvidence.driverPackage = "RME USB Series Driver"
    report.driverEvidence.routingNotes = "USB RME MADI output 1/2 looped to input 1/2"

    #expect(throws: RmeFastestAudioPathValidationError.passWithoutThunderboltRmePath) {
        try report.validate()
    }
}

@Test
func rmeFastestAudioPathThunderboltDetectionRejectsBroadThunSubstring() throws {
    let source = try readOpenLolaCoreSource("Sources/OpenLolaCore/Audio/Routing/AudioBaselineEvidence.swift")

    #expect(source.contains("normalized.contains(\"thunderbolt\")"))
    #expect(source.contains("normalized.contains(\"tb3\")"))
    #expect(source.contains("normalized.contains(\"tb4\")"))
    #expect(!source.contains("normalized.contains(\"thun\")"))
}

@Test
func rmeFastestAudioPathRejectsPassWithoutLoopbackPass() throws {
    var report = makeRmeFastestPassCandidate()
    report.loopbackReport.verdict = .partial

    #expect(throws: RmeFastestAudioPathValidationError.passWithoutLoopbackPass) {
        try report.validate()
    }
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
func rmeFastestAudioPathRejectsPassWhenSelectedModeIsNotFastestStable() throws {
    var report = makeRmeFastestPassCandidate()
    report.loopbackReport.selectedMode = AudioMode(
        sampleRateHertz: 48_000,
        framesPerBuffer: 64,
        channelCount: 2,
        sampleFormat: "int16"
    )
    report.loopbackReport.stabilityRun.mode = report.loopbackReport.selectedMode

    #expect(throws: RmeFastestAudioPathValidationError.passSelectedModeIsNotFastestStable(
        selected: report.loopbackReport.selectedMode,
        fastest: AudioMode(
            sampleRateHertz: 48_000,
            framesPerBuffer: 32,
            channelCount: 2,
            sampleFormat: "int16"
        )
    )) {
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
func rmeFastestAudioPathRejectsPassWithoutSupportedNinetySixKilohertzMatrix() throws {
    var report = makeRmeFastestPassCandidate()
    report.loopbackReport.sampleRates[1].supported = false
    report.loopbackReport.sampleRates[1].unsupportedReason = "not tested"
    report.loopbackReport.sampleRates[1].modeResults = []

    #expect(throws: RmeFastestAudioPathValidationError.passWithoutSupportedSampleRate(96_000)) {
        try report.validate()
    }
}

@Test
func rmeFastestAudioPathRequiresStableModeForEverySupportedSampleRate() throws {
    var report = makeRmeFastestPassCandidate()
    let source = try readOpenLolaCoreSource("Sources/OpenLolaCore/Audio/MADI/RmeFastestAudioPath.swift")
    report.loopbackReport.sampleRates.append(
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

    #expect(source.contains("requiredStableSampleRatesForPass()"))
    #expect(source.contains("sampleRate.supported ? sampleRate.sampleRateHertz : nil"))
    #expect(!source.contains("for sampleRate in [48_000, 96_000]"))
    #expect(throws: RmeFastestAudioPathValidationError.passWithoutAcceptedStableMode(
        sampleRateHertz: 44_100
    )) {
        try report.validate()
    }
}

@Test
func rmeFastestAudioPathPlaceholderFieldsUseExplicitChecklist() throws {
    let source = try readOpenLolaCoreSource("Sources/OpenLolaCore/Audio/MADI/RmeFastestAudioPath.swift")

    #expect(source.contains("private static let requiredStaticPlaceholderFieldNames = ["))
    #expect(source.contains("\"driverEvidence.totalMixSnapshot\""))
    #expect(source.contains("\"loopbackReport.device.transportType\""))
    #expect(source.contains("RME fastest placeholder field checklist mismatch"))
    #expect(source.contains("Set(staticFields.map { $0.name }) == Set(Self.requiredStaticPlaceholderFieldNames)"))
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

private func readOpenLolaCoreSource(_ relativePath: String) throws -> String {
    let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    return try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
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
