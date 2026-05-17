import Foundation
import Testing

@testable import OpenLolaCore


@Test
func latencyProfilesExposePolicyDefaultsAndWarnings() {
    let safe = LatencyProfilePolicy.policy(for: .safeLowLatency)
    let ultra = LatencyProfilePolicy.policy(for: .ultraLowLatency16)
    let extreme = LatencyProfilePolicy.policy(for: .extremeLowLatency8)

    #expect(safe.primaryFrames == 32)
    #expect(safe.fallbackFrames == [64])
    #expect(safe.defaultRxBufferProfile == .direct)
    #expect(!safe.requiresExplicitOptIn)

    #expect(ultra.primaryFrames == 16)
    #expect(ultra.requiresExplicitOptIn)
    #expect(!ultra.hiddenByDefault)
    #expect(ultra.rollbackProfiles == [.safeLowLatency])

    #expect(extreme.primaryFrames == 8)
    #expect(extreme.requiresExperimentalOptIn)
    #expect(extreme.hiddenByDefault)
    #expect(extreme.warning == .extremeLowLatencyDropoutRisk)
}

@Test
func sixteenFrameSelectionRequiresExplicitOptInSupportedRmeAndDirectRoute() throws {
    var request = latencyProfileRequest(
        profile: .ultraLowLatency16,
        framesPerBuffer: 16,
        explicitOptIn: false
    )

    #expect(throws: LatencyProfileValidationError.missingExplicitOptIn(.ultraLowLatency16)) {
        _ = try LatencyProfileSelection.validate(
            request: request,
            device: profileRmeDevice(supportedFrames: [16, 32, 64]),
            route: profileDirectRoute()
        )
    }

    request.explicitOptIn = true
    #expect(throws: LatencyProfileValidationError.missingWarningAcknowledgement(.ultraLowLatency16)) {
        _ = try LatencyProfileSelection.validate(
            request: request,
            device: profileRmeDevice(supportedFrames: [16, 32, 64]),
            route: profileDirectRoute()
        )
    }
    request.warningAcknowledged = true

    #expect(throws: LatencyProfileValidationError.unsupportedHardwareFrameSize(
        profile: .ultraLowLatency16,
        framesPerBuffer: 16
    )) {
        _ = try LatencyProfileSelection.validate(
            request: request,
            device: profileRmeDevice(supportedFrames: [32, 64]),
            route: profileDirectRoute()
        )
    }

    #expect(throws: LatencyProfileValidationError.rmeDirectHardwareRequired(.ultraLowLatency16)) {
        _ = try LatencyProfileSelection.validate(
            request: request,
            device: profileBuiltInDevice(),
            route: profileDirectRoute()
        )
    }

    #expect(throws: LatencyProfileValidationError.directRouteRequired(.ultraLowLatency16)) {
        _ = try LatencyProfileSelection.validate(
            request: request,
            device: profileRmeDevice(supportedFrames: [16, 32, 64]),
            route: RouteIdentity(label: "campus", topology: "managed-campus-network")
        )
    }

    let selection = try LatencyProfileSelection.validate(
        request: request,
        device: profileRmeDevice(supportedFrames: [16, 32, 64]),
        route: profileDirectRoute()
    )

    #expect(selection.profile == .ultraLowLatency16)
    #expect(selection.rxBufferProfile == .direct)
    #expect(selection.verdict == .partial)
}

@Test
func lowBufferEvidenceRecommendationStaysPartialWithoutPhysicalRouteProof() throws {
    let evidence = try LatencyProfileEvidence(
        profile: .ultraLowLatency16,
        explicitOptIn: true,
        experimentalOptIn: false,
        warningAcknowledged: true,
        rmeDirectPhysicalEvidence: false,
        routeBenchmarkPassed: false,
        maxStableChannelCount: 64,
        longRunDurationSeconds: 1_800,
        rollbackProfile: .safeLowLatency,
        budget: .calculate(
            profile: .ultraLowLatency16,
            sampleRateHertz: 48_000,
            channelCount: 2,
            sampleFormat: .int16LittleEndian
        )
    )

    #expect(evidence.recommendedVerdict == .partial)
    #expect(throws: LatencyProfileValidationError.physicalRmeDirectEvidenceRequired(.ultraLowLatency16)) {
        try evidence.validate(for: AudioMode(
            sampleRateHertz: 48_000,
            framesPerBuffer: 16,
            channelCount: 2,
            sampleFormat: "int16"
        ), verdict: .pass)
    }
}

@Test
func eightFrameEvidenceRemainsPartialWithoutLongRunAndStableChannelEvidence() throws {
    let evidence = try LatencyProfileEvidence(
        profile: .extremeLowLatency8,
        explicitOptIn: true,
        experimentalOptIn: true,
        warningAcknowledged: true,
        rmeDirectPhysicalEvidence: true,
        routeBenchmarkPassed: true,
        maxStableChannelCount: nil,
        longRunDurationSeconds: 1_800,
        rollbackProfile: .ultraLowLatency16,
        budget: .calculate(
            profile: .extremeLowLatency8,
            sampleRateHertz: 48_000,
            channelCount: 2,
            sampleFormat: .int16LittleEndian
        )
    )

    try evidence.validate(for: AudioMode(
        sampleRateHertz: 48_000,
        framesPerBuffer: 8,
        channelCount: 2,
        sampleFormat: "int16"
    ), verdict: .partial)

    #expect(evidence.recommendedVerdict == .partial)
    #expect(evidence.warnings.contains(.physicalLongRunEvidenceMissing))
    #expect(evidence.warnings.contains(.maxStableChannelCountMissing))
}

private func latencyProfileRequest(
    profile: LatencyProfile,
    framesPerBuffer: Int,
    explicitOptIn: Bool,
    experimentalOptIn: Bool = false,
    warningAcknowledged: Bool = false
) -> LatencyProfileSelectionRequest {
    LatencyProfileSelectionRequest(
        profile: profile,
        sampleRateHertz: 48_000,
        framesPerBuffer: framesPerBuffer,
        channelCount: 2,
        sampleFormat: .int16LittleEndian,
        rxBufferProfile: nil,
        explicitOptIn: explicitOptIn,
        experimentalOptIn: experimentalOptIn,
        warningAcknowledged: warningAcknowledged
    )
}

private func profileRmeDevice(supportedFrames: [Int]) -> CoreAudioDeviceInventory {
    CoreAudioDeviceInventory(
        id: 1,
        name: "RME MADIface Thunderbolt",
        uid: "rme-madi-uid",
        manufacturer: "RME",
        transportType: "thun",
        isAggregate: false,
        inputChannelCount: 64,
        outputChannelCount: 64,
        inputStreamCount: 1,
        outputStreamCount: 1,
        nominalSampleRateHertz: 48_000,
        availableSampleRateRanges: [
            AudioValueRangeSnapshot(minimum: 48_000, maximum: 96_000)
        ],
        currentBufferFrameSize: UInt32(supportedFrames.min() ?? 32),
        bufferFrameSizeRange: AudioValueRangeSnapshot(
            minimum: Double(supportedFrames.min() ?? 32),
            maximum: Double(supportedFrames.max() ?? 32)
        ),
        candidateBufferFrames: BufferFrameCandidates(
            inReportedRange: supportedFrames,
            outsideReportedRange: [],
            note: "test"
        ),
        inputLatencyFrames: 12,
        outputLatencyFrames: 12,
        inputSafetyOffsetFrames: 0,
        outputSafetyOffsetFrames: 0,
        clockDomain: 1,
        diagnosticNotes: ["test"]
    )
}

private func profileBuiltInDevice() -> CoreAudioDeviceInventory {
    CoreAudioDeviceInventory(
        id: 2,
        name: "Built-in Output",
        uid: "built-in",
        manufacturer: "Apple Inc.",
        transportType: "bltn",
        isAggregate: false,
        inputChannelCount: 2,
        outputChannelCount: 2,
        inputStreamCount: 1,
        outputStreamCount: 1,
        nominalSampleRateHertz: 48_000,
        availableSampleRateRanges: [
            AudioValueRangeSnapshot(minimum: 48_000, maximum: 48_000)
        ],
        currentBufferFrameSize: 32,
        bufferFrameSizeRange: AudioValueRangeSnapshot(minimum: 16, maximum: 64),
        candidateBufferFrames: BufferFrameCandidates(
            inReportedRange: [16, 32, 64],
            outsideReportedRange: [],
            note: "test"
        ),
        inputLatencyFrames: 12,
        outputLatencyFrames: 12,
        inputSafetyOffsetFrames: 0,
        outputSafetyOffsetFrames: 0,
        clockDomain: 1,
        diagnosticNotes: ["test"]
    )
}

private func profileDirectRoute() -> RouteIdentity {
    RouteIdentity(label: "direct-wired-p2p", topology: "two-mac-direct-ethernet")
}
