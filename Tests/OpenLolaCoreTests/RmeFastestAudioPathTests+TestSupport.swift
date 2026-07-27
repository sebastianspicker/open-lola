// Shared RME fastest audio path tests helpers keep multi-file test scenarios deterministic.
import Foundation
import Testing

@testable import OpenLolaCore

func makeRmeFastestPassCandidate(
    selectedMode: AudioMode = AudioMode(
        sampleRateHertz: 48_000,
        framesPerBuffer: 32,
        channelCount: 2,
        sampleFormat: "int16"
    )
) -> RmeFastestAudioPathReport {
    return RmeFastestAudioPathReport(
        identity: .init(
            id: "g02-rme-fastest-pass-candidate",
            title: "G02 RME fastest audio pass candidate",
            capturedAt: "2026-05-02T00:00:00Z"
        ),
        inventory: .init(
            capturedAt: "2026-05-02T00:00:00Z",
            hostName: "reference-mac",
            device: rmeMadiDevice(uid: "rme-madi-uid")
        ),
        evidence: .init(
            driver: .init(
                driver: .init(
                    package: "RME Thunderbolt Driver",
                    version: "4.08",
                    firmwareVersion: "230",
                    mode: .driverKit
                ),
                totalMix: .init(
                    version: "1.94",
                    snapshot: "snapshots/g02-rme-totalmix.tmx",
                    routingNotes: "Thunderbolt RME MADI output 1/2 looped to input 1/2"
                ),
                clocking: .init(
                    clockSource: "internal clock with MADI loopback locked",
                    sampleRateSource: "Core Audio nominal sample rate",
                    sampleRateConversion: .absent
                )
            ),
            loopback: rmeEndpointLoopbackReport(selectedMode: selectedMode)
        ),
        verdict: .pass,
        notes: "Synthetic pass candidate for validator tests only."
    )
}

func expectRmeFastestAudioPathError(
    _ expected: RmeFastestAudioPathValidationError,
    mutate: (inout RmeFastestAudioPathReport) throws -> Void
) throws {
    var report = makeRmeFastestPassCandidate()
    try mutate(&report)

    #expect(throws: expected) {
        try report.validate()
    }
}
func rmeEndpointLoopbackReport(
    selectedMode: AudioMode,
    audioInterface: String = "RME Fireface UFX+ MADI Thunderbolt",
    driverVersion: String = "RME Thunderbolt Driver 4.08",
    deviceName: String = "RME Fireface UFX+ MADI Thunderbolt",
    transportType: String = "thunderbolt"
) -> EndpointLoopbackReport {
    EndpointLoopbackReport(identity: .init(id: "m03-rme-loopback-pass-candidate", title: "RME MADI loopback pass candidate", capturedAt: "2026-05-02T00:00:00Z"), context: .init(hardware: HardwareIdentity(
            referenceMac: "reference-mac",
            audioInterface: audioInterface,
            osVersion: "macOS 15.4.1 24E263",
            driverVersion: driverVersion
        ), route: RouteIdentity(
            label: "rme-madi-loopback",
            topology: "single-mac-rme-madi-output-to-input"
        ), device: EndpointLoopbackDevice(
            name: deviceName,
            uid: "rme-madi-uid",
            transportType: transportType,
            clockDomain: 1
        ), selectedMode: selectedMode, sampleRates: rmeEndpointLoopbackSampleRates(), stabilityRun: rmeEndpointStabilityRun(selectedMode: selectedMode)), outcome: .init(verdict: .pass, notes: "Synthetic RME loopback pass candidate for validator tests only."))
}
func rmeEndpointLoopbackSampleRates() -> [SampleRateLoopbackResult] {
    [
        rmeEndpointLoopback48kResult(),
        rmeEndpointLoopback96kResult(),
        SampleRateLoopbackResult(
            sampleRateHertz: 192_000,
            supported: false,
            unsupportedReason: "device did not report 192 kHz support",
            modeResults: []
        )
    ]
}

func rmeEndpointLoopback48kResult() -> SampleRateLoopbackResult {
    SampleRateLoopbackResult(
        sampleRateHertz: 48_000,
        supported: true,
        unsupportedReason: nil,
        modeResults: [
            rejectedMode(48_000, 8, reason: "experimental 8-frame mode requires separate long-run evidence"),
            acceptedMode(
                .init(sampleRate: 48_000, frames: 16, stable: false, oneWayMilliseconds: 2.1, p99: 420, max: 900, missed: 3, underruns: 1)
            ),
            acceptedMode(.init(sampleRate: 48_000, frames: 32, stable: true, oneWayMilliseconds: 2.55, p99: 240, max: 380)),
            acceptedMode(.init(sampleRate: 48_000, frames: 64, stable: true, oneWayMilliseconds: 3.2, p99: 210, max: 320)),
            acceptedMode(.init(sampleRate: 48_000, frames: 128, stable: true, oneWayMilliseconds: 4.0, p99: 190, max: 260))
        ]
    )
}

func rmeEndpointLoopback96kResult() -> SampleRateLoopbackResult {
    SampleRateLoopbackResult(
        sampleRateHertz: 96_000,
        supported: true,
        unsupportedReason: nil,
        modeResults: [
            rejectedMode(96_000, 8, reason: "experimental 8-frame mode requires separate long-run evidence"),
            rejectedMode(96_000, 16, reason: "device rejected 16-frame mode at 96 kHz"),
            acceptedMode(
                .init(sampleRate: 96_000, frames: 32, stable: false, oneWayMilliseconds: 2.35, p99: 500, max: 1_100, missed: 2, underruns: 1)
            ),
            acceptedMode(.init(sampleRate: 96_000, frames: 64, stable: true, oneWayMilliseconds: 2.8, p99: 220, max: 340)),
            acceptedMode(.init(sampleRate: 96_000, frames: 128, stable: true, oneWayMilliseconds: 3.55, p99: 200, max: 290))
        ]
    )
}

func rmeEndpointStabilityRun(selectedMode: AudioMode) -> EndpointStabilityRun {
    measuredFixtureEndpointStabilityRun(
        selectedMode: selectedMode,
        notes: "30-minute fixed-target run"
    )
}

func acceptedMode(
    _ fixture: MeasuredFixtureAcceptedMode
) -> EndpointModeResult {
    var result = realtimeAudioEngineAcceptedMode(fixture)
    if !fixture.stable {
        result.notes = "accepted but unstable measured row"
    }
    return result
}

func rejectedMode(_ sampleRate: Int, _ frames: Int, reason: String) -> EndpointModeResult {
    measuredFixtureRejectedMode(sampleRate, frames, reason: reason)
}

func loadRmeFastestAudioPathFixture(named name: String) throws -> RmeFastestAudioPathReport {
    let url = try rmeFastestAudioPathFixtureURL(named: name)
    return try RmeFastestAudioPathReport.decode(from: Data(contentsOf: url))
}

func rmeFastestAudioPathFixtureURL(named name: String) throws -> URL {
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
