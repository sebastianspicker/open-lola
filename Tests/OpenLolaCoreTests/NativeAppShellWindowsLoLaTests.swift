import Testing

@testable import OpenLolaCore

@Test
func nativeAppShellWindowsLoLaDefaultsMatchExplicitPeerMode() throws {
    let fields = NativeAppShellWindowsLoLaPeerFields.appDefault

    try fields.validateAppSettings()

    #expect(fields.role == .txRx)
    #expect(fields.controlPort == 7_000)
    #expect(fields.audioPort == 19_788)
    #expect(fields.videoPort == 19_798)
    #expect(fields.sampleRateHertz == 44_100)
    #expect(fields.framesPerPacket == 64)
    #expect(fields.channelCount == 2)
    #expect(fields.videoWidth == 640)
    #expect(fields.videoHeight == 480)
    #expect(fields.videoFrameRate == 25)
    #expect(fields.videoBitsPerPixel == 8)
    #expect(fields.durationSeconds == 20)
    #expect(try fields.mediaPacketCount() == 500)
    #expect(fields.payloadMode == .generated)
}

@Test
func nativeAppShellWindowsLoLaBuildsDryRunAndRunConnectorCommands() throws {
    let fields = NativeAppShellWindowsLoLaPeerFields.appDefault
    let dryRun = try fields.sessionArguments(executablePath: "/tmp/open-lola", dryRun: true)
    let run = try fields.sessionArguments(executablePath: "/tmp/open-lola", dryRun: false)

    #expect(dryRun.starts(with: [
        "/tmp/open-lola",
        "external-connector-session-run",
        "--connector",
        "lola",
        "--role",
        "tx-rx",
    ]))
    #expect(dryRun.contains("--control-transport"))
    #expect(dryRun.contains("udp"))
    #expect(dryRun.contains("--dry-run"))
    #expect(dryRun.contains("true"))
    #expect(dryRun.contains("--media"))
    #expect(dryRun.contains("audio-video"))
    #expect(dryRun.contains("--lola-video-payload"))
    #expect(dryRun.contains("generated"))
    #expect(dryRun.contains("--media-packets"))
    #expect(dryRun.contains("500"))
    #expect(run.contains("--dry-run"))
    #expect(run.contains("false"))
}

@Test
func nativeAppShellWindowsLoLaBuildsExternalConnectorValidatorCommand() throws {
    let fields = NativeAppShellWindowsLoLaPeerFields.appDefault
    let arguments = try fields.validatorArguments(executablePath: "/tmp/open-lola")

    #expect(arguments == [
        "/tmp/open-lola",
        "validate-external-connector-session-report",
        fields.outputPath,
    ])
}

@Test
func nativeAppShellWindowsLoLaModeDoesNotRequireRemoteInventory() throws {
    let state = NativeAppShellOperatorPrototypeState(
        sessionMode: .windowsLoLa,
        inventory: NativeAppShellLocalMediaInventory(
            capturedAt: "2026-05-12T00:00:00Z",
            hostName: "local-test-host",
            audioDevices: [],
            videoDevices: [],
            selection: NativeAppShellLocalMediaSelection(
                audioInputUID: nil,
                audioOutputUID: nil,
                videoDeviceID: nil
            ),
            inventoryErrors: []
        ),
        remoteInventory: .editableRemotePlaceholder(),
        commandIntent: .runRequested,
        remoteOrchestrationEnabled: false,
        startsLongRunningProcess: false
    )

    let arguments = try state.windowsLoLaSessionArguments(executablePath: "/tmp/open-lola", dryRun: true)

    #expect(arguments.contains("external-connector-session-run"))
    #expect(arguments.contains("--connector"))
    #expect(arguments.contains("lola"))
}
