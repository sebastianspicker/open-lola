import Testing

@testable import OpenLolaAppSupport
@testable import OpenLolaCore

@Test
func appWorkflowModesAndControlVisibilityAreExplicit() {
    #expect(NativeAppShellSessionMode.allCases.map(\.displayName) == ["Mac-to-Mac", "Windows LoLa", "JackTrip", "UltraGrid"])
    #expect(NativeAppShellSessionMode.directMacPeer.supportsAppExecution)
    #expect(NativeAppShellSessionMode.windowsLoLa.externalConnectorKind == .lola)
    #expect(NativeAppShellSessionMode.jackTrip.externalConnectorKind == .jackTrip)
    #expect(NativeAppShellSessionMode.ultraGrid.externalConnectorKind == .mvtpUltraGrid)
    #expect(!NativeAppShellSessionMode.jackTrip.supportsAppExecution)
    #expect(!NativeAppShellSessionMode.ultraGrid.supportsAppExecution)
    #expect(AppTransportWorkflowPolicy.isWorkflowAvailable(sessionMode: .directMacPeer))
    #expect(AppTransportWorkflowPolicy.isWorkflowAvailable(sessionMode: .windowsLoLa))
    #expect(!AppTransportWorkflowPolicy.isWorkflowAvailable(sessionMode: .jackTrip))
    #expect(!AppTransportWorkflowPolicy.isWorkflowAvailable(sessionMode: .ultraGrid))
    #expect(NativeAppShellSessionMode.jackTrip.appStatusLabel == "External connector CLI only")
    #expect(NativeAppShellSessionMode.ultraGrid.appStatusLabel == "External connector CLI only")
    #expect(NativeAppShellSessionMode.jackTrip.unavailableAppReason?.contains("operator planning") == true)
    #expect(NativeAppShellSessionMode.ultraGrid.unavailableAppReason?.contains("operator planning") == true)
    #expect(NativeAppShellSessionMode.jackTrip.unavailableAppReason?.contains("external connector or NMP CLI contracts") == true)
    #expect(NativeAppShellSessionMode.ultraGrid.unavailableAppReason?.contains("external connector or NMP CLI contracts") == true)

    let normalDirect = Set(NativeAppShellSettingsVisibility.visibleGroups(
        sessionMode: .directMacPeer,
        controlMode: .normal
    ))
    #expect(normalDirect.contains(.workflow))
    #expect(normalDirect.contains(.connection))
    #expect(normalDirect.contains(.preview))
    #expect(normalDirect.contains(.snapshot))
    #expect(!normalDirect.contains(.ports))
    #expect(!normalDirect.contains(.audioCodec))
    #expect(!normalDirect.contains(.videoCodec))
    #expect(!normalDirect.contains(.sshFallback))

    let advancedDirect = Set(NativeAppShellSettingsVisibility.visibleGroups(
        sessionMode: .directMacPeer,
        controlMode: .advanced
    ))
    #expect(advancedDirect.contains(.ports))
    #expect(advancedDirect.contains(.audioCodec))
    #expect(advancedDirect.contains(.videoCodec))
    #expect(advancedDirect.contains(.sshFallback))

    let externalOnly = Set(NativeAppShellSettingsVisibility.visibleGroups(
        sessionMode: .jackTrip,
        controlMode: .advanced
    ))
    #expect(externalOnly.contains(.externalConnectorNotice))
    #expect(!externalOnly.contains(.execution))
    #expect(!externalOnly.contains(.ports))

    for mode in [NativeAppShellSessionMode.jackTrip, .ultraGrid] {
        #expect(
            NativeAppShellSettingsVisibility.visibleGroups(
                sessionMode: mode,
                controlMode: .normal
            ) == [.workflow, .externalConnectorNotice]
        )
        #expect(
            NativeAppShellSettingsVisibility.visibleGroups(
                sessionMode: mode,
                controlMode: .advanced
            ) == [.workflow, .externalConnectorNotice]
        )
    }
}
