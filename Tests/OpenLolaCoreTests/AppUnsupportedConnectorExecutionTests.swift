// Verifies that native app session mode execution route supports native connector modes.
import Testing

@testable import OpenLolaAppSupport
@testable import OpenLolaCore

@Test
func nativeAppSessionModeExecutionRouteSupportsNativeConnectorModes() throws {
    #expect(NativeAppShellSessionMode.directMacPeer.appExecutionRoute == .directMacPeer)
    #expect(NativeAppShellSessionMode.windowsLoLa.appExecutionRoute == .windowsLoLa)
    #expect(NativeAppShellSessionMode.directMacPeer.supportsAppExecution)
    #expect(NativeAppShellSessionMode.windowsLoLa.supportsAppExecution)
    #expect(NativeAppShellSessionMode.jackTrip.appExecutionRoute == .externalConnector(.jackTrip))
    #expect(NativeAppShellSessionMode.ultraGrid.appExecutionRoute == .externalConnector(.mvtpUltraGrid))

    for mode in [NativeAppShellSessionMode.jackTrip, .ultraGrid] {
        #expect(mode.supportsAppExecution)
        #expect(mode.unavailableAppReason == nil)
        #expect(mode.usesPostRunValidationStart)
    }
}

@MainActor
@Test
func externalConnectorModesPrepareAppExecutionAndValidationCommands() throws {
    let controller = AppExecutionController()
    var windowsSurface = AppShellStoredDefaults.placeholderOperatorSurface()
    windowsSurface.sessionMode = .windowsLoLa
    #expect(controller.prepareExecution(from: windowsSurface))

    for (mode, connector, outputPath) in [
        (
            NativeAppShellSessionMode.jackTrip,
            ExternalConnectorKind.jackTrip,
            "/tmp/open-lola-app/jacktrip-session.json"
        ),
        (.ultraGrid, .mvtpUltraGrid, "/tmp/open-lola-app/ultragrid-session.json")
    ] {
        var surface = AppShellStoredDefaults.placeholderOperatorSurface()
        surface.sessionMode = mode

        #expect(controller.prepareExecution(from: surface))

        let readiness = controller.validationReadiness(operatorSurface: surface)
        #expect(!readiness.isReady)
        #expect(readiness.unavailableMessage?.contains(outputPath) == true)

        let executionCommand = try controller.executionCommand(
            executablePath: "/bin/echo",
            operatorSurface: surface,
            dryRun: true
        ).get()
        let configuration = try ExternalConnectorSessionConfiguration.parse(Array(executionCommand.dropFirst(2)))
        #expect(configuration.connector == connector)
        #expect(configuration.outputPath == outputPath)
        #expect(configuration.dryRun)
        if connector == .jackTrip {
            #expect(configuration.peerAudioPort == 4_464)
            #expect(configuration.mediaMode == .audio)
        }

        let validatorCommand = try controller.validatorCommand(
            executablePath: "/bin/echo",
            operatorSurface: surface
        ).get()
        #expect(validatorCommand == ["/bin/echo", "validate-external-connector-session-report", outputPath])
    }
}
