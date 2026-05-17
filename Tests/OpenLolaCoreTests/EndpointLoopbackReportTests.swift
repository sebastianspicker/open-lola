import Foundation
import Testing

@testable import OpenLolaCore

@Test
func endpointLoopbackReportRejectsInvalidCertificationEvidence() throws {
    var report = try loadEndpointLoopbackFixture(named: "endpoint-loopback-valid")
    report.sampleRates[0].modeResults.removeAll { result in
        result.mode.framesPerBuffer == 8
    }

    #expect(throws: EndpointLoopbackValidationError.missingRequiredFrameSize(
        sampleRateHertz: 48_000,
        framesPerBuffer: 8
    )) {
        try report.validate()
    }

    report = try loadEndpointLoopbackFixture(named: "missing-32-frame")

    #expect(throws: EndpointLoopbackValidationError.missingRequiredFrameSize(
        sampleRateHertz: 48_000,
        framesPerBuffer: 32
    )) {
        try report.validate()
    }

    report = try loadEndpointLoopbackFixture(named: "endpoint-loopback-valid")
    report.sampleRates[0].supported = false
    report.sampleRates[0].unsupportedReason = nil
    report.sampleRates[0].modeResults = []

    #expect(throws: EndpointLoopbackValidationError.unsupportedSampleRateMissingReason(
        report.sampleRates[0].sampleRateHertz
    )) {
        try report.validate()
    }

    report = try loadEndpointLoopbackFixture(named: "endpoint-loopback-valid")
    let modeIndex = try #require(report.sampleRates[0].modeResults.firstIndex {
        $0.mode.framesPerBuffer == 16
    })
    report.sampleRates[0].modeResults[modeIndex].loopback = nil

    #expect(throws: EndpointLoopbackValidationError.acceptedModeMissingLoopbackMetrics(
        sampleRateHertz: 48_000,
        framesPerBuffer: 16
    )) {
        try report.validate()
    }

    report = try loadEndpointLoopbackFixture(named: "endpoint-loopback-valid")
    report.stabilityRun.durationSeconds = 600

    #expect(throws: EndpointLoopbackValidationError.stabilityRunTooShort(seconds: 600)) {
        try report.validate()
    }

    report = try loadEndpointLoopbackFixture(named: "endpoint-loopback-valid")
    report.stabilityRun.hiddenBufferGrowthDetected = true

    #expect(throws: EndpointLoopbackValidationError.hiddenBufferGrowthDetected) {
        try report.validate()
    }

    report = try loadEndpointLoopbackFixture(named: "endpoint-loopback-valid")
    report.selectedMode = AudioMode(
        sampleRateHertz: 48_000,
        framesPerBuffer: 8,
        channelCount: 2,
        sampleFormat: "int16"
    )
    report.stabilityRun.mode = report.selectedMode
    report.stabilityRun.durationSeconds = 1_800
    let eightFrameIndex = try #require(report.sampleRates[0].modeResults.firstIndex {
        $0.mode.framesPerBuffer == 8
    })
    report.sampleRates[0].modeResults[eightFrameIndex].accepted = true
    report.sampleRates[0].modeResults[eightFrameIndex].stable = true
    report.sampleRates[0].modeResults[eightFrameIndex].rejectionReason = nil
    report.sampleRates[0].modeResults[eightFrameIndex].callback = EndpointCallbackMetrics(
        p50Microseconds: 110,
        p95Microseconds: 190,
        p99Microseconds: 260,
        maxMicroseconds: 410,
        missedDeadlines: 0,
        underruns: 0,
        overruns: 0
    )
    report.sampleRates[0].modeResults[eightFrameIndex].loopback = EndpointLoopbackMetrics(
        reportedInputLatencyFrames: 12,
        reportedOutputLatencyFrames: 12,
        inputSafetyOffsetFrames: 0,
        outputSafetyOffsetFrames: 0,
        measuredAnalogRoundTripMilliseconds: 3.8,
        correctedOneWayMilliseconds: 1.9,
        hiddenBufferGrowthDetected: false
    )

    #expect(throws: EndpointLoopbackValidationError.eightFrameStabilityRunTooShort(
        seconds: 1_800,
        minimumSeconds: EndpointLoopbackReport.minimumExtremeLowLatencyDurationSeconds
    )) {
        try report.validate()
    }
}

private func loadEndpointLoopbackFixture(named name: String) throws -> EndpointLoopbackReport {
    let url = try endpointLoopbackFixtureURL(named: name)
    return try EndpointLoopbackReport.decode(from: Data(contentsOf: url))
}

private func endpointLoopbackFixtureURL(named name: String) throws -> URL {
    let validURL = Bundle.module.url(
        forResource: name,
        withExtension: "json",
        subdirectory: "EndpointLoopback/valid"
    )
    let invalidURL = Bundle.module.url(
        forResource: name,
        withExtension: "json",
        subdirectory: "EndpointLoopback/invalid"
    )
    let rootURL = Bundle.module.url(
        forResource: name,
        withExtension: "json",
        subdirectory: nil
    )

    return try #require(validURL ?? invalidURL ?? rootURL)
}
