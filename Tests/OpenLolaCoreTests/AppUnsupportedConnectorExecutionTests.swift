import Testing

@testable import OpenLolaAppSupport
@testable import OpenLolaCore

@Test
func nativeAppSessionModeExecutionRouteOwnsPlanningOnlyConnectorModes() throws {
    #expect(NativeAppShellSessionMode.directMacPeer.appExecutionRoute == .directMacPeer)
    #expect(NativeAppShellSessionMode.windowsLoLa.appExecutionRoute == .windowsLoLa)
    #expect(NativeAppShellSessionMode.directMacPeer.supportsAppExecution)
    #expect(NativeAppShellSessionMode.windowsLoLa.supportsAppExecution)

    for mode in [NativeAppShellSessionMode.jackTrip, .ultraGrid] {
        let reason = try #require(mode.unavailableAppReason)
        #expect(mode.appExecutionRoute == .unsupportedExternalConnector(reason: reason))
        #expect(!mode.supportsAppExecution)
        #expect(reason.contains(mode.displayName))
        #expect(reason.contains("operator planning"))
        #expect(reason.contains("no wired runtime launcher"))
    }
}

@MainActor
@Test
func unsupportedConnectorModesDoNotPrepareAppExecutionOrValidationCommands() {
    let controller = AppExecutionController()
    var windowsSurface = AppShellStoredDefaults.placeholderOperatorSurface()
    windowsSurface.sessionMode = .windowsLoLa
    #expect(controller.prepareExecution(from: windowsSurface))

    for mode in [NativeAppShellSessionMode.jackTrip, .ultraGrid] {
        var surface = AppShellStoredDefaults.placeholderOperatorSurface()
        surface.sessionMode = mode

        #expect(!controller.prepareExecution(from: surface))

        let readiness = controller.validationReadiness(operatorSurface: surface)
        #expect(!readiness.isReady)
        #expect(readiness.unavailableMessage == mode.unavailableAppReason)

        #expect(throws: NativeAppShellSurfaceValidationError.invalidCommandField("sessionMode")) {
            try controller.executionCommand(
                executablePath: ".build/debug/open-lola",
                operatorSurface: surface,
                dryRun: true
            ).get()
        }
        #expect(throws: NativeAppShellSurfaceValidationError.invalidCommandField("sessionMode")) {
            try controller.validatorCommand(
                executablePath: ".build/debug/open-lola",
                operatorSurface: surface
            ).get()
        }
    }
}
