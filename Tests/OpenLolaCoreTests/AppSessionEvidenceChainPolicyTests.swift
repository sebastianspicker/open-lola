// Focused pure-policy tests for Session evidence-chain stage construction.
import Testing

@testable import OpenLolaAppSupport

@Test
func appSessionEvidenceChainStagesCountIsFour() {
    let stages = AppSessionEvidenceChainPolicy.stages(
        readinessConfigured: false,
        sessionState: .unconfigured,
        hasValidatedRuntimeEvidence: false,
        lastExitCode: nil,
        lastValidationExitCode: nil,
        isRunning: false,
        packetEvidenceAvailable: false
    )

    #expect(stages.count == 4)
    #expect(stages.map(\.id) == ["source", "planned", "observed", "validated"])
}

@Test
func appSessionEvidenceChainValidatedIsPassedWhenRuntimeEvidencePresent() {
    let stages = AppSessionEvidenceChainPolicy.stages(
        readinessConfigured: true,
        sessionState: .validated,
        hasValidatedRuntimeEvidence: true,
        lastExitCode: 0,
        lastValidationExitCode: 0,
        isRunning: false,
        packetEvidenceAvailable: true
    )

    let validated = stages.first { $0.id == "validated" }
    #expect(validated != nil)
    #expect(validated?.isPassed == true)
    #expect(validated?.state == "Passed")
    #expect(validated?.tone == .validated)
}

@Test
func appSessionEvidenceChainObservedIsRunningWhenIsRunning() {
    let stages = AppSessionEvidenceChainPolicy.stages(
        readinessConfigured: true,
        sessionState: .ready,
        hasValidatedRuntimeEvidence: false,
        lastExitCode: nil,
        lastValidationExitCode: nil,
        isRunning: true,
        packetEvidenceAvailable: false
    )

    let observed = stages.first { $0.id == "observed" }
    #expect(observed?.state == "Running")
    #expect(observed?.tone == .observed)
}

@Test
func appSessionEvidenceChainPlannedIsConfiguredWhenReadinessConfigured() {
    let stages = AppSessionEvidenceChainPolicy.stages(
        readinessConfigured: true,
        sessionState: .ready,
        hasValidatedRuntimeEvidence: false,
        lastExitCode: nil,
        lastValidationExitCode: nil,
        isRunning: false,
        packetEvidenceAvailable: false
    )

    let planned = stages.first { $0.id == "planned" }
    #expect(planned?.state == "Configured")
    #expect(planned?.tone == .planned)
}
