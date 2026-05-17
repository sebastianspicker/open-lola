import Foundation
import Testing

@testable import OpenLolaCore


@Test
func nativeAppShellOperatorStateDoesNotCommitInvalidRemoteInventoryImport() throws {
    var state = artifactOperatorState()
    let originalRemoteInventory = state.remoteInventory
    var invalidRemote = testInventory(hostName: "invalid-remote", audioUID: "remote-rme", videoID: "remote-atem")
    invalidRemote.selection.audioInputUID = "missing-remote-input"

    #expect(throws: NativeAppShellSurfaceValidationError.selectedRemoteAudioInputUnavailable("missing-remote-input")) {
        try state.importRemoteInventoryJSON(from: try invalidRemote.prettyJSONString())
    }

    #expect(state.remoteInventory == originalRemoteInventory)
}

@Test
func nativeAppShellPlanArtifactStateIsCopyableJSON() throws {
    let state = artifactOperatorState()
    let artifact = try state.twoPeerRunPlanArtifactState(
        outputPath: "/tmp/open-lola-artifact-tests/plan.json",
        runDirectory: "/tmp/open-lola-artifact-tests",
        generatedAt: "2026-05-09T12:00:00Z"
    )
    let report = try DirectPeerTwoPeerRunPlanReport.decode(from: Data(artifact.clipboardText.utf8))

    try report.validate()
    #expect(artifact.kind == .twoPeerRunPlan)
    #expect(artifact.path == "/tmp/open-lola-artifact-tests/plan.json")
    #expect(artifact.validationSummary == "m06-direct-p2p-two-peer-plan: partial")
    #expect(report.commands.count == 2)
}

private func artifactOperatorState() -> NativeAppShellOperatorPrototypeState {
    NativeAppShellOperatorPrototypeState(
        inventory: testInventory(hostName: "local-mac", audioUID: "local-rme", videoID: "local-atem"),
        remoteInventory: testInventory(hostName: "remote-mac", audioUID: "remote-rme", videoID: "remote-atem"),
        commandIntent: .runRequested,
        remoteOrchestrationEnabled: false,
        startsLongRunningProcess: false,
        directPeerCommandFields: NativeAppShellDirectPeerCommandFields(
            role: .initiator,
            localPeer: "mac-a",
            remotePeer: "mac-b",
            localHost: "192.0.2.10",
            remoteHost: "192.0.2.20",
            controlPort: 57_000,
            remoteControlPort: 57_010,
            audioPort: 57_001,
            videoPort: 57_002,
            metricsPort: 57_003,
            outputPath: "/tmp/open-lola-app/direct-p2p-session-local.json",
            durationSeconds: 30,
            channelCount: 64,
            sampleRateHertz: 48_000,
            framesPerPacket: 32,
            sampleFormat: "float32",
            videoWidth: 1_280,
            videoHeight: 720,
            videoPixelFormat: "bgra8",
            videoFrameRate: 30,
            videoStreamID: 101,
            avProfile: .fastest,
            preview: .on,
            timeoutSeconds: 30
        )
    )
}

private func testInventory(
    hostName: String,
    audioUID: String,
    videoID: String
) -> NativeAppShellLocalMediaInventory {
    NativeAppShellLocalMediaInventory(
        capturedAt: "2026-05-09T00:00:00Z",
        hostName: hostName,
        audioDevices: [
            NativeAppShellAudioDeviceOption(
                name: "RME MADI",
                uid: audioUID,
                inputChannelCount: 64,
                outputChannelCount: 64,
                nominalSampleRateHertz: 48_000,
                currentBufferFrameSize: 32
            ),
        ],
        videoDevices: [
            NativeAppShellVideoDeviceOption(
                label: "ATEM",
                uniqueId: videoID,
                manufacturer: "Blackmagic Design",
                transport: "USB",
                sourcePolicy: .blackmagicFirstAvFoundationFallback,
                formatCount: 2
            ),
        ],
        selection: NativeAppShellLocalMediaSelection(
            audioInputUID: audioUID,
            audioOutputUID: audioUID,
            videoDeviceID: videoID
        ),
        inventoryErrors: []
    )
}

private func temporaryDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("open-lola-native-app-artifacts")
        .appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}
