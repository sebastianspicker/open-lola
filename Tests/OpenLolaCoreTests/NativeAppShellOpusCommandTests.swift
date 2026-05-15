import Foundation
import Testing

@testable import OpenLolaCore

@Test
func nativeAppShellDirectPeerCommandsIncludeOpusAudioCompression() throws {
    var state = opusOperatorPrototypeState()
    state.directPeerCommandFields.audioTransport = .openLolaOpusCeltLowDelay
    let handoff = try state.localDirectPeerCommandHandoff()
    let plan = try state.twoPeerRunPlanConfiguration()
    let report = try DirectPeerTwoPeerRunPlanner.makeReport(configuration: plan)

    #expect(handoff.command.arguments.contains("--audio-transport"))
    #expect(handoff.command.arguments.contains("openlola-opus-celt-ld"))
    #expect(plan.audioTransport == .openLolaOpusCeltLowDelay)
    #expect(report.commands.flatMap(\.arguments).contains("--audio-transport"))
    #expect(report.commands.flatMap(\.arguments).contains("openlola-opus-celt-ld"))
}

@Test
func nativeAppShellSourcePersistsAudioCompressionSetting() throws {
    let appSettings = try readNativeAppOpusRepositoryText("Sources/open-lola-app/AppSettings.swift")
    let storedDefaults = try readNativeAppOpusRepositoryText("Sources/open-lola-app/AppShellStoredDefaults.swift")
    let settingsTabs = try readNativeAppOpusRepositoryText("Sources/open-lola-app/AppShellSettingsTabs.swift")
    let storageKeys = try readNativeAppOpusRepositoryText("Sources/open-lola-app/AppStorageKeys.swift")

    #expect(storageKeys.contains("audioTransport"))
    #expect(storageKeys.contains("audioCompression"))
    #expect(appSettings.contains("var audioTransport: String"))
    #expect(storedDefaults.contains("DirectPeerSessionAudioTransport("))
    #expect(storedDefaults.contains("DirectPeerSessionAudioCompression("))
    #expect(settingsTabs.contains("Picker(\"Audio transport\""))
    #expect(settingsTabs.contains("Opus CELT LD"))
}

private func opusOperatorPrototypeState() -> NativeAppShellOperatorPrototypeState {
    let local = opusInventory(
        hostName: "mac-a",
        audioInputUID: "local-input",
        audioOutputUID: "local-output",
        videoDeviceID: "local-video"
    )
    let remote = opusInventory(
        hostName: "mac-b",
        audioInputUID: "remote-input",
        audioOutputUID: "remote-output",
        videoDeviceID: "remote-video"
    )
    var fields = NativeAppShellDirectPeerCommandFields.appDefault
    fields.channelCount = 2
    fields.framesPerPacket = 120
    fields.sampleRateHertz = 48_000
    fields.sampleFormat = "float32"
    fields.avProfile = .balanced
    fields.rxBufferProfile = .small
    return NativeAppShellOperatorPrototypeState(
        inventory: local,
        remoteInventory: remote,
        commandIntent: .runRequested,
        remoteOrchestrationEnabled: false,
        startsLongRunningProcess: false,
        directPeerCommandFields: fields
    )
}

private func opusInventory(
    hostName: String,
    audioInputUID: String,
    audioOutputUID: String,
    videoDeviceID: String
) -> NativeAppShellLocalMediaInventory {
    NativeAppShellLocalMediaInventory(
        capturedAt: "2026-05-12T00:00:00Z",
        hostName: hostName,
        audioDevices: [
            NativeAppShellAudioDeviceOption(
                name: "Input",
                uid: audioInputUID,
                inputChannelCount: 2,
                outputChannelCount: 0,
                nominalSampleRateHertz: 48_000,
                currentBufferFrameSize: 120
            ),
            NativeAppShellAudioDeviceOption(
                name: "Output",
                uid: audioOutputUID,
                inputChannelCount: 0,
                outputChannelCount: 2,
                nominalSampleRateHertz: 48_000,
                currentBufferFrameSize: 120
            ),
        ],
        videoDevices: [
            NativeAppShellVideoDeviceOption(
                label: "Video",
                uniqueId: videoDeviceID,
                manufacturer: "Test",
                transport: "virtual",
                sourcePolicy: .genericAvFoundation,
                formatCount: 1
            ),
        ],
        selection: NativeAppShellLocalMediaSelection(
            audioInputUID: audioInputUID,
            audioOutputUID: audioOutputUID,
            videoDeviceID: videoDeviceID
        ),
        inventoryErrors: []
    )
}

private func readNativeAppOpusRepositoryText(_ relativePath: String) throws -> String {
    let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    return try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
}
