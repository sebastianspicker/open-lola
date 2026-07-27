// Verifies that direct peer session manual run rejects unsupported hostname before bind.
import Testing

@testable import OpenLolaCore

@Test
func directPeerSessionManualRunRejectsUnsupportedHostnameBeforeBind() throws {
    var fixture = DirectPeerManualTestFixture()
    fixture.localHost = "mac-a.local"
    let manual = fixture.configuration()

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

@Test
func directPeerManualAudioShapeEnforcesTransportSpecificSampleQuanta() throws {
    for sampleRateHertz in [48_000, 96_000] {
        for framesPerPacket in [8, 16, 32, 64] {
            try DirectPeerSessionAVMediaShape.validateAudioTransportShape(
                .openLolaRaw,
                sampleRateHertz: sampleRateHertz,
                framesPerPacket: framesPerPacket,
                sampleFormat: .float32LittleEndian,
                channelCount: 2
            )
        }
    }

    #expect(throws: DirectPeerSessionAVMediaShapeError.invalidAudioTransportShape(.openLolaRaw)) {
        try DirectPeerSessionAVMediaShape.validateAudioTransportShape(
            .openLolaRaw,
            sampleRateHertz: 48_000,
            framesPerPacket: 120,
            sampleFormat: .float32LittleEndian,
            channelCount: 2
        )
    }
}
