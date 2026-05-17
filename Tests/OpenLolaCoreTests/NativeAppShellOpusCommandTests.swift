import Foundation
import Testing

@testable import OpenLolaAppSupport
@testable import OpenLolaCore

@Test
func nativeAppShellDirectPeerCommandsIncludeOpusAudioCompression() throws {
    var state = opusOperatorPrototypeState()
    state.directPeerCommandFields.audioTransport = .openLolaOpusCeltLowDelay
    let handoff = try state.localDirectPeerCommandHandoff()
    let plan = try state.twoPeerRunPlanConfiguration()
    let report = try DirectPeerTwoPeerRunPlanner.makeReport(configuration: plan)

    #expect(handoff.command.arguments.contains("mac-to-mac-connection-preflight-run"))
    #expect(!handoff.command.arguments.contains("--audio-transport"))
    #expect(!handoff.command.arguments.contains("openlola-opus-celt-ld"))
    #expect(plan.audioTransport == .openLolaOpusCeltLowDelay)
    #expect(report.commands.flatMap(\.arguments).contains("--audio-transport"))
    #expect(report.commands.flatMap(\.arguments).contains("openlola-opus-celt-ld"))
}

@Test
func nativeAppShellDefaultsPersistAndMigrateOpusAudioTransport() throws {
    let suiteName = "open-lola-opus-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defer {
        defaults.removePersistentDomain(forName: suiteName)
    }

    defaults.set(
        DirectPeerSessionAudioTransport.openLolaOpusCeltLowDelay.rawValue,
        forKey: AppStorageKeys.audioTransport
    )
    persistOpusCompatibleAudioShape(defaults)
    let persisted = AppShellStoredDefaults.directPeerCommandFields(defaults: defaults)
    #expect(persisted.audioTransport == .openLolaOpusCeltLowDelay)

    defaults.removePersistentDomain(forName: suiteName)
    defaults.set(
        DirectPeerSessionAudioCompression.opusCELTLowDelay.rawValue,
        forKey: AppStorageKeys.audioCompression
    )
    persistOpusCompatibleAudioShape(defaults)
    let migrated = AppShellStoredDefaults.directPeerCommandFields(defaults: defaults)
    #expect(migrated.audioTransport == .openLolaOpusCeltLowDelay)
    #expect(defaults.string(forKey: AppStorageKeys.audioTransport) == "openlola-opus-celt-ld")
    #expect(defaults.object(forKey: AppStorageKeys.audioCompression) == nil)
}

private func persistOpusCompatibleAudioShape(_ defaults: UserDefaults) {
    defaults.set(2, forKey: AppStorageKeys.channelCount)
    defaults.set(48_000, forKey: AppStorageKeys.sampleRate)
    defaults.set(120, forKey: AppStorageKeys.frames)
    defaults.set("float32", forKey: AppStorageKeys.sampleFormat)
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
