// Verifies that local capabilities expose all implemented real-time packet quanta.
import Foundation
import Testing

@testable import OpenLolaCore

@Test
func localCapabilitiesExposeAllImplementedRealtimePacketQuanta() {
    let audio = OpenLolaCLI.localCapabilitySet().audio

    #expect(audio.framesPerPacketOptions == [6, 8, 16, 32, 48, 64, 120])
    #expect(audio.latencyProfiles == [.extremeLowLatency8, .ultraLowLatency16, .safeLowLatency])
}

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
// swiftlint:disable:next function_body_length
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
        selection: LatencyProfileEvidence.Selection(
            profile: .ultraLowLatency16,
            explicitOptIn: true,
            experimentalOptIn: false,
            warningAcknowledged: true
        ),
        physicalEvidence: LatencyProfileEvidence.PhysicalEvidence(
            rmeDirect: false,
            routeBenchmarkPassed: false,
            maxStableChannelCount: 64,
            longRunDurationSeconds: 1_800
        ),
        recovery: LatencyProfileEvidence.Recovery(
            rollbackProfile: .safeLowLatency,
            budget: .calculate(
                profile: .ultraLowLatency16,
                sampleRateHertz: 48_000,
                channelCount: 2,
                sampleFormat: .int16LittleEndian
            )
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
        selection: LatencyProfileEvidence.Selection(
            profile: .extremeLowLatency8,
            explicitOptIn: true,
            experimentalOptIn: true,
            warningAcknowledged: true
        ),
        physicalEvidence: LatencyProfileEvidence.PhysicalEvidence(
            rmeDirect: true,
            routeBenchmarkPassed: true,
            maxStableChannelCount: nil,
            longRunDurationSeconds: 1_800
        ),
        recovery: LatencyProfileEvidence.Recovery(
            rollbackProfile: .ultraLowLatency16,
            budget: .calculate(
                profile: .extremeLowLatency8,
                sampleRateHertz: 48_000,
                channelCount: 2,
                sampleFormat: .int16LittleEndian
            )
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
        optIns: LatencyProfileSelectionRequest.OptIns(
            explicitProfile: explicitOptIn,
            experimentalMode: experimentalOptIn,
            warningAcknowledged: warningAcknowledged
        )
    )
}

private func profileRmeDevice(supportedFrames: [Int]) -> CoreAudioDeviceInventory {
    let minimumFrameCount = supportedFrames.min() ?? 32
    var fixture = SyntheticFullDuplexDeviceFixture(
        id: 1,
        name: "RME MADIface Thunderbolt",
        uid: "rme-madi-uid",
        manufacturer: "RME",
        transportType: "thun",
        inputChannelCount: 64,
        outputChannelCount: 64,
        diagnosticNotes: ["test"]
    )
    fixture.availableSampleRateRanges = [.init(minimum: 48_000, maximum: 96_000)]
    fixture.currentBufferFrameSize = UInt32(minimumFrameCount)
    fixture.bufferFrameSizeRange = .init(
        minimum: Double(minimumFrameCount),
        maximum: Double(supportedFrames.max() ?? 32)
    )
    fixture.candidateBufferFrames = .init(
        inReportedRange: supportedFrames,
        outsideReportedRange: [],
        note: "test"
    )
    fixture.inputLatencyFrames = 12
    fixture.outputLatencyFrames = 12
    fixture.inputSafetyOffsetFrames = 0
    fixture.outputSafetyOffsetFrames = 0
    fixture.clockDomain = 1
    return syntheticFullDuplexDevice(fixture)
}

private func profileBuiltInDevice() -> CoreAudioDeviceInventory {
    var fixture = SyntheticFullDuplexDeviceFixture(
        id: 2,
        name: "Built-in Output",
        uid: "built-in",
        manufacturer: "Apple Inc.",
        transportType: "bltn",
        diagnosticNotes: ["test"]
    )
    fixture.candidateBufferFrames = .init(
        inReportedRange: [16, 32, 64],
        outsideReportedRange: [],
        note: "test"
    )
    fixture.bufferFrameSizeRange = .init(minimum: 16, maximum: 64)
    fixture.inputLatencyFrames = 12
    fixture.outputLatencyFrames = 12
    fixture.inputSafetyOffsetFrames = 0
    fixture.outputSafetyOffsetFrames = 0
    fixture.clockDomain = 1
    return syntheticFullDuplexDevice(fixture)
}

private func profileDirectRoute() -> RouteIdentity {
    RouteIdentity(label: "direct-wired-p2p", topology: "two-mac-direct-ethernet")
}
