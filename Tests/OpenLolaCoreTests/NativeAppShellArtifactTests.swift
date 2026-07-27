// Verifies that native app shell operator state does not commit invalid remote inventory import.
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

@Test
func nativeAppShellPlanArtifactWriteUsesTimestampedPathWhenTargetExists() throws {
    let state = artifactOperatorState()
    let directory = try temporaryDirectory()
    let requestedURL = directory.appendingPathComponent("plan.json")
    try "existing plan\n".write(to: requestedURL, atomically: true, encoding: .utf8)

    let result = try state.writeTwoPeerRunPlanArtifactResult(
        to: requestedURL,
        runDirectory: directory.path,
        mode: .writeTimestampedIfExists,
        generatedAt: "2026-05-20T12:34:56Z"
    )

    #expect(result.requestedPath == requestedURL.path)
    #expect(result.writtenPath != requestedURL.path)
    #expect(result.writtenPath.hasSuffix("plan-2026-05-20T12-34-56Z.json"))
    #expect(result.writtenCount == 1)
    #expect(result.skippedCount == 1)
    #expect(result.failedCount == 0)
    #expect(result.artifact.path == result.writtenPath)
    #expect(try String(contentsOf: requestedURL, encoding: .utf8) == "existing plan\n")
    #expect(FileManager.default.fileExists(atPath: result.writtenPath))
}

private func artifactOperatorState() -> NativeAppShellOperatorPrototypeState {
    NativeAppShellOperatorPrototypeState(
        workflow: NativeAppShellOperatorWorkflow(commandIntent: .runRequested, remoteOrchestrationEnabled: false, startsLongRunningProcess: false),
        inventories: NativeAppShellOperatorInventories(local: testInventory(hostName: "local-mac", audioUID: "local-rme", videoID: "local-atem"), remote: testInventory(hostName: "remote-mac", audioUID: "remote-rme", videoID: "remote-atem")),
        peerFields: NativeAppShellOperatorPeerFields(
            directPeer: .appDefault
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
            )
        ],
        videoDevices: [
            NativeAppShellVideoDeviceOption(
                label: "ATEM",
                uniqueId: videoID,
                manufacturer: "Blackmagic Design",
                transport: "USB",
                sourcePolicy: .blackmagicFirstAvFoundationFallback,
                formatCount: 2
            )
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
