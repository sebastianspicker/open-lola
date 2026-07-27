// Focused pure-policy tests for Session phase rail mapping and step ordering.
import Testing

@testable import OpenLolaAppSupport

@Test
func appSessionPhaseRailCurrentPhaseMapsSessionState() {
    #expect(
        AppSessionPhaseRailPolicy.currentPhase(sessionState: .unconfigured) == .setup
    )
    #expect(
        AppSessionPhaseRailPolicy.currentPhase(sessionState: .ready) == .ready
    )
    #expect(
        AppSessionPhaseRailPolicy.currentPhase(sessionState: .armed) == .ready
    )
    #expect(
        AppSessionPhaseRailPolicy.currentPhase(sessionState: .supervisorRunning) == .live
    )
    #expect(
        AppSessionPhaseRailPolicy.currentPhase(sessionState: .validated) == .review
    )
    #expect(
        AppSessionPhaseRailPolicy.currentPhase(
            sessionState: .error,
            lastExitCode: 1
        ) == .review
    )
    #expect(
        AppSessionPhaseRailPolicy.currentPhase(
            sessionState: .error,
            lastExitCode: nil
        ) == .live
    )
}

@Test
func appSessionPhaseRailStepStateOrdersDoneCurrentUpcoming() {
    let current = AppSessionPhase.live

    #expect(AppSessionPhaseRailPolicy.stepState(for: .setup, current: current) == .done)
    #expect(AppSessionPhaseRailPolicy.stepState(for: .ready, current: current) == .done)
    #expect(AppSessionPhaseRailPolicy.stepState(for: .live, current: current) == .current)
    #expect(AppSessionPhaseRailPolicy.stepState(for: .review, current: current) == .upcoming)
}
