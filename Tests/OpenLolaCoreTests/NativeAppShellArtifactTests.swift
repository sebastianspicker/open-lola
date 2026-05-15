import Foundation
import Testing

@testable import OpenLolaCore

@Test
func nativeAppShellLocalMediaInventoryExportsAndImportsPrettyJSON() throws {
    let inventory = testInventory(hostName: "local-mac", audioUID: "local-rme", videoID: "local-atem")
    let json = try inventory.clipboardString()
    let decoded = try NativeAppShellLocalMediaInventory.readClipboardString(json)

    #expect(decoded == inventory)
    #expect(json.contains("\"hostName\" : \"local-mac\""))
    #expect(json.contains("\"audioInputUID\" : \"local-rme\""))
}

@Test
func nativeAppShellLocalMediaInventoryWritesAndReadsFileJSON() throws {
    let directory = try temporaryDirectory()
    let url = directory.appendingPathComponent("remote-inventory.json")
    let inventory = testInventory(hostName: "remote-mac", audioUID: "remote-rme", videoID: "remote-atem")

    try inventory.writeJSON(to: url)
    let decoded = try NativeAppShellLocalMediaInventory.readJSON(from: url)

    #expect(decoded == inventory)
}

@Test
func nativeAppShellOperatorStateImportsRemoteInventoryJSON() throws {
    var state = artifactOperatorState()
    let remote = testInventory(hostName: "imported-remote", audioUID: "remote-rme", videoID: "remote-atem")

    try state.importRemoteInventoryJSON(from: try remote.prettyJSONString())

    try state.validate()
    #expect(state.remoteInventory == remote)
    #expect(state.remoteInventory.selection.audioOutputUID == "remote-rme")
}

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
func nativeAppShellOperatorStateRejectsEmptyClipboardInventory() {
    #expect(throws: NativeAppShellArtifactError.emptyClipboardText) {
        _ = try NativeAppShellLocalMediaInventory.readClipboardString("  \n")
    }
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
func nativeAppShellPlanArtifactWritesAndReloadsReport() throws {
    let directory = try temporaryDirectory()
    let url = directory.appendingPathComponent("plan.json")
    let state = artifactOperatorState()

    let artifact = try state.writeTwoPeerRunPlanArtifact(to: url, runDirectory: directory.path)
    let reloaded = try NativeAppShellOperatorPrototypeState.readTwoPeerRunPlanArtifact(from: url)

    try reloaded.validate()
    #expect(artifact.path == url.path)
    #expect(reloaded.runDirectory == directory.path)
    #expect(reloaded.reportReferences.map(\.path) == reloaded.commands.map(\.outputReportPath))
}

@Test
func nativeAppShellSupervisorCommandArtifactIsCopyable() throws {
    let state = artifactOperatorState()
    let artifact = try state.twoPeerSupervisorCommandArtifactState(
        planPath: "/tmp/open-lola-mac-to-mac/plan.json",
        outputPath: "/tmp/open-lola-mac-to-mac/supervisor.json",
        macASSH: "mac-a.local",
        macBSSH: "mac-b.local"
    )

    #expect(artifact.kind == .twoPeerSupervisorCommand)
    #expect(artifact.clipboardText.contains(NativeAppShellExecutionPaths.installedCLIPlaceholder))
    #expect(!artifact.clipboardText.contains(".build/debug/open-lola"))
    #expect(artifact.clipboardText.contains("direct-p2p-two-peer-local-run"))
    #expect(artifact.clipboardText.contains("--execution-mode ssh"))
    #expect(artifact.clipboardText.contains("--require-preflight true"))
}

@Test
func openLolaAppExposesInventoryAndPlanArtifactControls() throws {
    let source = try readRepositoryText("Sources/open-lola-app/AppOperatorArtifactViews.swift")
    let operatorSource = try readRepositoryText("Sources/open-lola-app/AppLocalOperatorSurfaceView.swift")

    #expect(operatorSource.contains("AppOperatorArtifactsView("))
    #expect(operatorSource.contains("appSettings: appSettings"))
    #expect(source.contains("Copy Local Inventory JSON"))
    #expect(source.contains("pasteRemoteInventoryJSON()"))
    #expect(source.contains("guard let json = NSPasteboard.general.string(forType: .string),"))
    #expect(source.contains("!json.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty"))
    #expect(source.contains("Pasteboard does not contain remote inventory JSON."))
    #expect(source.contains("Import Remote Inventory JSON"))
    #expect(source.contains(".frame(minHeight: 180)"))
    #expect(source.contains(".border(AppDesignSystem.panelBorder)"))
    #expect(!source.contains(".border(.quaternary)"))
    #expect(source.contains("Generate Copyable Plan JSON"))
    #expect(source.contains("Write Plan Artifact"))
    #expect(source.contains("Reload Plan Artifact"))
    #expect(source.contains("Copy SSH Supervisor Command"))
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

private func readRepositoryText(_ relativePath: String) throws -> String {
    let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    return try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
}
