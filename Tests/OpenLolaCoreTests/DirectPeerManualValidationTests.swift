import Testing

@testable import OpenLolaCore

@Test
func directPeerSessionManualRunRejectsUnsupportedHostnameBeforeBind() throws {
    let manual = DirectPeerSessionManualRunConfiguration(
        role: .initiator,
        localPeerID: "peer-a",
        remotePeerID: "peer-b",
        localHost: "mac-a.local",
        remoteHost: "127.0.0.1",
        controlPort: 57_000,
        remoteControlPort: 57_010,
        audioPort: 57_001,
        videoPort: 57_002,
        metricsPort: 57_003,
        packetCount: 1,
        audioChannelCount: 2,
        timeoutSeconds: 1
    )

    #expect(throws: DirectPeerSessionSocketRunnerError.invalidManualHostParse("localHost", "mac-a.local", 0)) {
        _ = try DirectPeerSessionSocketRunner.runManualAddress(configuration: manual)
    }
}

@Test
func directPeerManualHostValidationPreservesInetPtonFailureStatus() throws {
    #expect(throws: DirectPeerSessionSocketRunnerError.invalidManualHostParse("remoteHost", "mac-a.local", 0)) {
        try DirectPeerManualEndpointValidator.requireAdvertisableHost("mac-a.local", field: "remoteHost")
    }
}

@Test
func nativeAppShellCommandSettingsUseSharedManualNetworkValidation() throws {
    var fields = NativeAppShellDirectPeerCommandFields.appDefault
    fields.localHost = "mac-a.local"

    #expect(throws: NativeAppShellSurfaceValidationError.invalidCommandField("localHost")) {
        try fields.validateAppSettings()
    }

    fields = NativeAppShellDirectPeerCommandFields.appDefault
    fields.remoteHost = fields.localHost
    fields.remoteControlPort = fields.audioPort

    #expect(throws: NativeAppShellSurfaceValidationError.duplicateCommandPort("remoteControlPort")) {
        try fields.validateAppSettings()
    }
}
