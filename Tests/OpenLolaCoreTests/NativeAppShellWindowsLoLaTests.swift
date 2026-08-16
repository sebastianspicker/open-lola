// Covers the native app shell’s Windows LoLa compatibility contract for release validation.
import Foundation
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
    #expect(fields.compression == 0)
    #expect(fields.resolvedControlTransport == .udp)
    #expect(fields.resolvedAudioDeviceMode == .generated)
}

@Test
func nativeAppShellWindowsLoLaBuildsSelectedLiveMediaAndTCPArguments() throws {
    var fields = NativeAppShellWindowsLoLaPeerFields.appDefault
    fields.controlTransport = .tcp
    fields.audioDeviceMode = .coreAudio
    fields.payloadMode = .avFoundationRaw8
    let inventory = NativeAppShellLocalMediaInventory(
        capturedAt: "2026-08-13T00:00:00Z",
        hostName: "local-test-host",
        audioDevices: [
            NativeAppShellAudioDeviceOption(
                name: "Input",
                uid: "input-uid",
                inputChannelCount: 2,
                outputChannelCount: 0,
                nominalSampleRateHertz: 44_100,
                currentBufferFrameSize: 64
            ),
            NativeAppShellAudioDeviceOption(
                name: "Output",
                uid: "output-uid",
                inputChannelCount: 0,
                outputChannelCount: 2,
                nominalSampleRateHertz: 44_100,
                currentBufferFrameSize: 64
            )
        ],
        videoDevices: [
            NativeAppShellVideoDeviceOption(
                label: "Camera",
                uniqueId: "camera-id",
                manufacturer: "Test",
                transport: "built-in",
                sourcePolicy: .genericAvFoundation,
                formatCount: 1
            )
        ],
        selection: NativeAppShellLocalMediaSelection(
            audioInputUID: "input-uid",
            audioOutputUID: "output-uid",
            videoDeviceID: "camera-id"
        ),
        inventoryErrors: []
    )
    let state = NativeAppShellOperatorPrototypeState(
        workflow: NativeAppShellOperatorWorkflow(
            sessionMode: .windowsLoLa,
            commandIntent: .runRequested,
            remoteOrchestrationEnabled: false,
            startsLongRunningProcess: false
        ),
        inventories: NativeAppShellOperatorInventories(local: inventory),
        peerFields: NativeAppShellOperatorPeerFields(windowsLoLa: fields)
    )

    let arguments = try state.windowsLoLaSessionArguments(
        executablePath: "/tmp/open-lola",
        dryRun: false
    )

    #expect(argumentValue("--control-transport", in: arguments) == "tcp")
    #expect(argumentValue("--audio-capture", in: arguments) == "coreaudio:input-uid")
    #expect(argumentValue("--audio-playback", in: arguments) == "coreaudio:output-uid")
    #expect(argumentValue("--video-capture", in: arguments) == "camera-id")
}

@Test
func nativeAppShellWindowsLoLaLiveMediaRequiresExplicitLocalSelections() throws {
    var fields = NativeAppShellWindowsLoLaPeerFields.appDefault
    fields.audioDeviceMode = .coreAudio
    #expect(throws: NativeAppShellSurfaceValidationError.missingLocalCommandSelection("audioInputUID")) {
        _ = try fields.sessionArguments(
            executablePath: "/tmp/open-lola",
            dryRun: false,
            mediaSelection: nil
        )
    }

    fields.audioDeviceMode = .generated
    fields.payloadMode = .avFoundationRaw8
    #expect(throws: NativeAppShellSurfaceValidationError.missingLocalCommandSelection("videoDeviceID")) {
        _ = try fields.sessionArguments(
            executablePath: "/tmp/open-lola",
            dryRun: false,
            mediaSelection: .init(audioInputUID: nil, audioOutputUID: nil, videoDeviceID: nil)
        )
    }
}

@Test(arguments: [
    (ExternalConnectorSessionRole.tx, true, false),
    (.rx, false, true),
    (.txRx, true, true),
])
func nativeAppShellWindowsLoLaCoreAudioArgumentsFollowSessionRole(
    role: ExternalConnectorSessionRole,
    expectsCapture: Bool,
    expectsPlayback: Bool
) throws {
    var fields = NativeAppShellWindowsLoLaPeerFields.appDefault
    fields.role = role
    fields.audioDeviceMode = .coreAudio
    let arguments = try fields.sessionArguments(
        executablePath: "/tmp/open-lola",
        dryRun: false,
        mediaSelection: .init(
            audioInputUID: expectsCapture ? "input-uid" : nil,
            audioOutputUID: expectsPlayback ? "output-uid" : nil,
            videoDeviceID: nil
        )
    )

    #expect((argumentValue("--audio-capture", in: arguments) != nil) == expectsCapture)
    #expect((argumentValue("--audio-playback", in: arguments) != nil) == expectsPlayback)
}

@Test(arguments: [
    (LoLaVideoPayloadKind.generated, 1),
    (.avFoundationRaw8, 1),
    (.avFoundationMjpeg, 0),
    (.avFoundationJpegXS, 1)
])
func nativeAppShellWindowsLoLaRejectsIncompatibleVideoPayloadAndCompression(
    payloadMode: LoLaVideoPayloadKind,
    compression: Int
) {
    var fields = NativeAppShellWindowsLoLaPeerFields.appDefault
    fields.payloadMode = payloadMode
    fields.compression = compression
    #expect(throws: NativeAppShellSurfaceValidationError.invalidCommandField("payloadMode")) {
        try fields.validateAppSettings()
    }
}

@Test(arguments: [
    (LoLaVideoPayloadKind.generated, 0),
    (.avFoundationRaw8, 0),
    (.avFoundationMjpeg, 1)
])
func nativeAppShellWindowsLoLaAcceptsRecoveredVideoPayloadAndCompressionPairs(
    payloadMode: LoLaVideoPayloadKind,
    compression: Int
) throws {
    var fields = NativeAppShellWindowsLoLaPeerFields.appDefault
    fields.payloadMode = payloadMode
    fields.compression = compression
    try fields.validateAppSettings()
}

@Test
func nativeAppShellWindowsLoLaRejectsUnsupportedCompression() {
    var fields = NativeAppShellWindowsLoLaPeerFields.appDefault
    fields.compression = 2
    #expect(throws: NativeAppShellSurfaceValidationError.invalidCommandField("compression")) {
        try fields.validateAppSettings()
    }
}

@Test
func nativeAppShellWindowsLoLaDecodesLegacyFieldsWithSafeDefaults() throws {
    let encoded = try JSONEncoder().encode(NativeAppShellWindowsLoLaPeerFields.appDefault)
    var object = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
    object.removeValue(forKey: "controlTransport")
    object.removeValue(forKey: "audioDeviceMode")
    let legacy = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])

    let decoded = try JSONDecoder().decode(NativeAppShellWindowsLoLaPeerFields.self, from: legacy)

    #expect(decoded.resolvedControlTransport == .udp)
    #expect(decoded.resolvedAudioDeviceMode == .generated)
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
        "tx-rx"
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
        fields.outputPath
    ])
}

@Test
func nativeAppShellWindowsLoLaModeDoesNotRequireRemoteInventory() throws {
    let state = NativeAppShellOperatorPrototypeState(
        workflow: NativeAppShellOperatorWorkflow(sessionMode: .windowsLoLa, commandIntent: .runRequested, remoteOrchestrationEnabled: false, startsLongRunningProcess: false),
        inventories: NativeAppShellOperatorInventories(local: NativeAppShellLocalMediaInventory(
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
        ), remote: .editableRemotePlaceholder())
    )

    let arguments = try state.windowsLoLaSessionArguments(executablePath: "/tmp/open-lola", dryRun: true)

    #expect(arguments.contains("external-connector-session-run"))
    #expect(arguments.contains("--connector"))
    #expect(arguments.contains("lola"))
}

private func argumentValue(_ name: String, in arguments: [String]) -> String? {
    guard let index = arguments.firstIndex(of: name), arguments.indices.contains(index + 1) else {
        return nil
    }
    return arguments[index + 1]
}
