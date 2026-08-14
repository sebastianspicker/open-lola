// Verifies live external connector commands use the operator-selected local devices.
import Testing

@testable import OpenLolaCore

@Test
func nativeAppShellJackTripLiveArgumentsFollowRole() throws {
    for role in [ExternalConnectorSessionRole.tx, .rx, .txRx] {
        var state = operatorPrototypeState()
        state.sessionMode = .jackTrip
        state.jackTripPeerFields.role = role

        let arguments = try state.externalConnectorSessionArguments(
            connector: .jackTrip,
            executablePath: "/tmp/open-lola",
            dryRun: false
        )

        #expect(argumentValue(arguments, "--audio-capture") ==
            (role.transmits ? "coreaudio:rme-madi-uid" : nil))
        #expect(argumentValue(arguments, "--audio-playback") ==
            (role.receives ? "coreaudio:rme-madi-uid" : nil))
        #expect(argumentValue(arguments, "--video-capture") == nil)
        #expect(argumentValue(arguments, "--dry-run") == "false")
        #expect(argumentValue(arguments, "--duration-bounded-runtime") == "true")
    }
}

@Test
func nativeAppShellUltraGridLiveArgumentsFollowMediaModeAndRole() throws {
    let cases: [(ExternalConnectorMediaMode, ExternalConnectorSessionRole, String?, String?, String?, String?)] = [
        (.audio, .txRx, "coreaudio:rme-madi-uid", "coreaudio:rme-madi-uid", nil, nil),
        (.video, .tx, nil, nil, "avfoundation:atem-uid", nil),
        (.video, .rx, nil, nil, nil, "appkit"),
        (.audioVideo, .txRx, "coreaudio:rme-madi-uid", "coreaudio:rme-madi-uid", "avfoundation:atem-uid", "appkit")
    ]
    for (mediaMode, role, capture, playback, video, display) in cases {
        var state = operatorPrototypeState()
        state.sessionMode = .ultraGrid
        state.ultraGridPeerFields.mediaMode = mediaMode
        state.ultraGridPeerFields.role = role

        let arguments = try state.externalConnectorSessionArguments(
            connector: .mvtpUltraGrid,
            executablePath: "/tmp/open-lola",
            dryRun: false
        )

        #expect(argumentValue(arguments, "--audio-capture") == capture)
        #expect(argumentValue(arguments, "--audio-playback") == playback)
        #expect(argumentValue(arguments, "--video-capture") == video)
        #expect(argumentValue(arguments, "--video-display") == display)
        #expect(argumentValue(arguments, "--duration-bounded-runtime") == "true")
    }
}

@Test
func nativeAppShellExternalConnectorLiveArgumentsRejectMissingAndUnavailableDevices() {
    var missingInput = operatorPrototypeState()
    missingInput.sessionMode = .jackTrip
    missingInput.jackTripPeerFields.role = .tx
    missingInput.inventory.selection.audioInputUID = nil
    #expect(throws: NativeAppShellSurfaceValidationError.missingLocalCommandSelection("audioInputUID")) {
        _ = try missingInput.externalConnectorSessionArguments(
            connector: .jackTrip,
            executablePath: "/tmp/open-lola",
            dryRun: false
        )
    }

    var missingOutput = operatorPrototypeState()
    missingOutput.sessionMode = .jackTrip
    missingOutput.jackTripPeerFields.role = .rx
    missingOutput.inventory.selection.audioOutputUID = nil
    #expect(throws: NativeAppShellSurfaceValidationError.missingLocalCommandSelection("audioOutputUID")) {
        _ = try missingOutput.externalConnectorSessionArguments(
            connector: .jackTrip,
            executablePath: "/tmp/open-lola",
            dryRun: false
        )
    }

    var missingVideo = operatorPrototypeState()
    missingVideo.sessionMode = .ultraGrid
    missingVideo.ultraGridPeerFields.mediaMode = .video
    missingVideo.ultraGridPeerFields.role = .tx
    missingVideo.inventory.selection.videoDeviceID = nil
    #expect(throws: NativeAppShellSurfaceValidationError.missingLocalCommandSelection("videoDeviceID")) {
        _ = try missingVideo.externalConnectorSessionArguments(
            connector: .mvtpUltraGrid,
            executablePath: "/tmp/open-lola",
            dryRun: false
        )
    }

    var unavailableInput = operatorPrototypeState()
    unavailableInput.sessionMode = .jackTrip
    unavailableInput.jackTripPeerFields.role = .tx
    unavailableInput.inventory.selection.audioInputUID = "missing-input"
    #expect(throws: NativeAppShellSurfaceValidationError.selectedAudioInputUnavailable("missing-input")) {
        _ = try unavailableInput.externalConnectorSessionArguments(
            connector: .jackTrip,
            executablePath: "/tmp/open-lola",
            dryRun: false
        )
    }

    var unavailableVideo = operatorPrototypeState()
    unavailableVideo.sessionMode = .ultraGrid
    unavailableVideo.ultraGridPeerFields.mediaMode = .video
    unavailableVideo.ultraGridPeerFields.role = .tx
    unavailableVideo.inventory.selection.videoDeviceID = "missing-video"
    #expect(throws: NativeAppShellSurfaceValidationError.selectedVideoDeviceUnavailable("missing-video")) {
        _ = try unavailableVideo.externalConnectorSessionArguments(
            connector: .mvtpUltraGrid,
            executablePath: "/tmp/open-lola",
            dryRun: false
        )
    }
}

@Test
func nativeAppShellExternalConnectorDryRunsRemainSyntheticWithoutSelections() throws {
    var state = operatorPrototypeState()
    state.sessionMode = .ultraGrid
    state.ultraGridPeerFields.mediaMode = .audioVideo
    state.inventory.selection = .init(audioInputUID: nil, audioOutputUID: nil, videoDeviceID: nil)

    let arguments = try state.externalConnectorSessionArguments(
        connector: .mvtpUltraGrid,
        executablePath: "/tmp/open-lola",
        dryRun: true
    )

    #expect(argumentValue(arguments, "--dry-run") == "true")
    #expect(argumentValue(arguments, "--audio-capture") == nil)
    #expect(argumentValue(arguments, "--audio-playback") == nil)
    #expect(argumentValue(arguments, "--video-capture") == nil)
    #expect(argumentValue(arguments, "--video-display") == nil)
    #expect(argumentValue(arguments, "--duration-bounded-runtime") == "false")
}

@Test
func nativeAppShellWindowsLoLaArgumentsDoNotUseTheConnectorDurationRuntimeFlag() throws {
    var state = operatorPrototypeState()
    state.sessionMode = .windowsLoLa

    let arguments = try state.externalConnectorSessionArguments(
        connector: .lola,
        executablePath: "/tmp/open-lola",
        dryRun: false
    )

    #expect(argumentValue(arguments, "--duration-bounded-runtime") == nil)
}
