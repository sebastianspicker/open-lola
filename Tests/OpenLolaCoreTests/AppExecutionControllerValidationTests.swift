// Verifies that app execution validation rejects second launch while validation is in flight.
import Testing

@testable import OpenLolaAppSupport

@MainActor
@Test
func appExecutionValidationRejectsSecondLaunchWhileValidationIsInFlight() {
    let controller = AppExecutionController()
    controller.phase = .validationRunning

    controller.validateReport(executablePath: "/private/tmp/open-lola")

    #expect(controller.lastCommand.isEmpty)
    #expect(controller.phase == .validationRunning)
    #expect(controller.lastError == "Cannot validate while a run is active.")
}
