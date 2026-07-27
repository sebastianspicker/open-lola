// Shared Drift PLC fixed target certification modes helpers keep multi-file test scenarios deterministic.
import Foundation
import Testing

@testable import OpenLolaCore

func driftCertification96kLoopbackResult() -> SampleRateLoopbackResult {
SampleRateLoopbackResult(
sampleRateHertz: 96_000,
supported: true,
unsupportedReason: nil,
modeResults: [
driftCertificationRejectedMode(
96_000, 8,
reason: "experimental 8-frame mode requires separate long-run evidence"
),
driftCertificationRejectedMode(96_000, 16, reason: "device rejected 16-frame mode at 96 kHz"),
driftCertificationAcceptedMode(.init(
96_000,
32,
stable: false,
oneWayMilliseconds: 2.35,
p99: 500,
max: 1_100,
missed: 2,
underruns: 1
)),
driftCertificationAcceptedMode(.init(96_000, 64, stable: true, oneWayMilliseconds: 2.8, p99: 220, max: 340)),
driftCertificationAcceptedMode(.init(96_000, 128, stable: true, oneWayMilliseconds: 3.55, p99: 200, max: 290))
]
)
}

func driftCertificationEndpointStabilityRun(selectedMode: AudioMode) -> EndpointStabilityRun {
measuredFixtureEndpointStabilityRun(
selectedMode: selectedMode,
notes: "30-minute fixed-target run"
)
}

struct DriftCertificationAcceptedModeFixture {
let sampleRate: Int
let frames: Int
let stable: Bool
let oneWayMilliseconds: Double
let p99: Double
let max: Double
let missed: Int
let underruns: Int

init(
_ sampleRate: Int,
_ frames: Int,
stable: Bool,
oneWayMilliseconds: Double,
p99: Double,
max: Double,
missed: Int = 0,
underruns: Int = 0
) {
self.sampleRate = sampleRate
self.frames = frames
self.stable = stable
self.oneWayMilliseconds = oneWayMilliseconds
self.p99 = p99
self.max = max
self.missed = missed
self.underruns = underruns
}
}

func driftCertificationAcceptedMode(
_ fixture: DriftCertificationAcceptedModeFixture
) -> EndpointModeResult {
    measuredFixtureAcceptedMode(MeasuredFixtureAcceptedMode(
        sampleRate: fixture.sampleRate,
        frames: fixture.frames,
        stable: fixture.stable,
        oneWayMilliseconds: fixture.oneWayMilliseconds,
        p99: fixture.p99,
        max: fixture.max,
        missed: fixture.missed,
        underruns: fixture.underruns
    ))
}

func driftCertificationRejectedMode(_ sampleRate: Int, _ frames: Int, reason: String) -> EndpointModeResult {
    measuredFixtureRejectedMode(sampleRate, frames, reason: reason)
}

func driftCertificationRmeMadiDevice(uid: String) -> CoreAudioDeviceInventory {
    measuredFixtureRmeMadiDevice(
        uid: uid,
        transportType: "thun",
        diagnosticNotes: ["measured RME MADI Thunderbolt path"]
    )
}

func driftCertificationRoutePacketMode() -> UdpPcmPacketMode {
    measuredFixturePacketMode()
}

func loadDriftPlcFixedTargetCertificationFixture(
    named name: String
) throws -> DriftPlcFixedTargetCertificationReport {
    let url = try driftPlcFixedTargetCertificationFixtureURL(named: name)
    return try DriftPlcFixedTargetCertificationReport.decode(from: Data(contentsOf: url))
}

func driftPlcFixedTargetCertificationFixtureURL(named name: String) throws -> URL {
    let validURL = Bundle.module.url(
        forResource: name,
        withExtension: "json",
        subdirectory: "DriftPlcFixedTargetCertificationReports/valid"
    )
    let invalidURL = Bundle.module.url(
        forResource: name,
        withExtension: "json",
        subdirectory: "DriftPlcFixedTargetCertificationReports/invalid"
    )
    let rootURL = Bundle.module.url(
        forResource: name,
        withExtension: "json",
        subdirectory: nil
    )

    return try #require(validURL ?? invalidURL ?? rootURL)
}
