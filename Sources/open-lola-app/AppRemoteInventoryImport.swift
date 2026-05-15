import Foundation
import OpenLolaCore

extension NativeAppShellOperatorPrototypeState {
    mutating func importRemoteInventorySelection(
        keyPath: WritableKeyPath<NativeAppShellLocalMediaSelection, String?>,
        value: String
    ) {
        let importedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        var nextSelection = remoteInventory.selection
        nextSelection[keyPath: keyPath] = importedValue.isEmpty ? nil : importedValue
        remoteInventory = remoteInventory.operatorImported(
            selection: nextSelection,
            channelCount: directPeerCommandFields.channelCount,
            sampleRateHertz: directPeerCommandFields.sampleRateHertz,
            framesPerPacket: directPeerCommandFields.framesPerPacket,
            capturedAt: ISO8601DateFormatter().string(from: Date())
        )
    }
}

private extension NativeAppShellLocalMediaInventory {
    func operatorImported(
        selection: NativeAppShellLocalMediaSelection,
        channelCount: Int,
        sampleRateHertz: Int,
        framesPerPacket: Int,
        capturedAt: String
    ) -> NativeAppShellLocalMediaInventory {
        NativeAppShellLocalMediaInventory(
            capturedAt: capturedAt,
            hostName: hostName,
            audioDevices: Self.remoteAudioDevices(
                selection: selection,
                channelCount: channelCount,
                sampleRateHertz: sampleRateHertz,
                framesPerPacket: framesPerPacket
            ),
            videoDevices: Self.remoteVideoDevices(selection: selection),
            selection: selection,
            inventoryErrors: []
        )
    }

    private static func remoteAudioDevices(
        selection: NativeAppShellLocalMediaSelection,
        channelCount: Int,
        sampleRateHertz: Int,
        framesPerPacket: Int
    ) -> [NativeAppShellAudioDeviceOption] {
        var devices: [NativeAppShellAudioDeviceOption] = []
        if let inputUID = nonEmptyUID(selection.audioInputUID) {
            devices.append(remoteAudioDevice(
                name: "Remote input",
                uid: inputUID,
                inputChannels: channelCount,
                outputChannels: 0,
                sampleRateHertz: sampleRateHertz,
                framesPerPacket: framesPerPacket
            ))
        }
        if let outputUID = nonEmptyUID(selection.audioOutputUID) {
            if let existingIndex = devices.firstIndex(where: { $0.uid == outputUID }) {
                devices[existingIndex] = remoteAudioDevice(
                    name: "Remote duplex",
                    uid: outputUID,
                    inputChannels: devices[existingIndex].inputChannelCount,
                    outputChannels: channelCount,
                    sampleRateHertz: sampleRateHertz,
                    framesPerPacket: framesPerPacket
                )
            } else {
                devices.append(remoteAudioDevice(
                    name: "Remote output",
                    uid: outputUID,
                    inputChannels: 0,
                    outputChannels: channelCount,
                    sampleRateHertz: sampleRateHertz,
                    framesPerPacket: framesPerPacket
                ))
            }
        }
        return devices
    }

    private static func nonEmptyUID(_ uid: String?) -> String? {
        guard let trimmed = uid?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }

    private static func remoteAudioDevice(
        name: String,
        uid: String,
        inputChannels: Int,
        outputChannels: Int,
        sampleRateHertz: Int,
        framesPerPacket: Int
    ) -> NativeAppShellAudioDeviceOption {
        NativeAppShellAudioDeviceOption(
            name: name,
            uid: uid,
            inputChannelCount: inputChannels,
            outputChannelCount: outputChannels,
            nominalSampleRateHertz: Double(sampleRateHertz),
            currentBufferFrameSize: UInt32(exactly: framesPerPacket) ?? UInt32.max
        )
    }

    private static func remoteVideoDevices(selection: NativeAppShellLocalMediaSelection) -> [NativeAppShellVideoDeviceOption] {
        guard let videoDeviceID = selection.videoDeviceID else { return [] }
        return [
            NativeAppShellVideoDeviceOption(
                label: "Remote video",
                uniqueId: videoDeviceID,
                manufacturer: "operator-imported",
                transport: "operator",
                sourcePolicy: .genericAvFoundation,
                formatCount: 0
            ),
        ]
    }
}
