// Persists local device selections and the operator-imported remote inventory, validating stored identifiers on load.
import Foundation
import OpenLolaCore

extension AppShellStoredDefaults {
    /// Reads the persisted local device selection; identifiers are checked against the live inventory after refresh.
    static func localMediaSelection(defaults: UserDefaults = .standard) -> NativeAppShellLocalMediaSelection {
        NativeAppShellLocalMediaSelection(
            audioInputUID: nonEmptyString(AppStorageKeys.localAudioInputUID, defaults: defaults),
            audioOutputUID: nonEmptyString(AppStorageKeys.localAudioOutputUID, defaults: defaults),
            videoDeviceID: nonEmptyString(AppStorageKeys.localVideoDeviceID, defaults: defaults)
        )
    }

    static func persistLocalMediaSelection(
        _ selection: NativeAppShellLocalMediaSelection,
        defaults: UserDefaults = .standard
    ) {
        let entries = [
            (AppStorageKeys.localAudioInputUID, selection.audioInputUID),
            (AppStorageKeys.localAudioOutputUID, selection.audioOutputUID),
            (AppStorageKeys.localVideoDeviceID, selection.videoDeviceID)
        ]
        for (key, value) in entries {
            if let value {
                defaults.set(value, forKey: key)
            } else {
                defaults.removeObject(forKey: key)
            }
        }
    }

    /// Reads the persisted remote inventory, dropping selections that its own device list does not contain.
    static func remoteInventoryLoad(
        defaults: UserDefaults = .standard
    ) -> AppStoredSettingsLoad<NativeAppShellLocalMediaInventory> {
        let placeholder = NativeAppShellLocalMediaInventory.editableRemotePlaceholder()
        guard let text = defaults.string(forKey: AppStorageKeys.remoteInventory), !text.isEmpty else {
            return AppStoredSettingsLoad(fields: placeholder, notices: [])
        }
        guard let stored = try? JSONDecoder().decode(NativeAppShellLocalMediaInventory.self, from: Data(text.utf8)) else {
            return AppStoredSettingsLoad(
                fields: placeholder,
                notices: ["The stored remote device inventory could not be read and was cleared."]
            )
        }
        var inventory = stored
        var notices: [String] = []
        let audioKeyPaths: [(String, WritableKeyPath<NativeAppShellLocalMediaSelection, String?>)] = [
            ("audio input", \.audioInputUID),
            ("audio output", \.audioOutputUID)
        ]
        for (label, keyPath) in audioKeyPaths {
            guard let uid = inventory.selection[keyPath: keyPath],
                  !inventory.audioDevices.contains(where: { $0.uid == uid }) else { continue }
            inventory.selection[keyPath: keyPath] = nil
            notices.append("Stored remote \(label) \"\(uid)\" is not in the remote inventory and was dropped.")
        }
        if let videoID = inventory.selection.videoDeviceID,
           !inventory.videoDevices.contains(where: { $0.uniqueId == videoID }) {
            inventory.selection.videoDeviceID = nil
            notices.append("Stored remote video device \"\(videoID)\" is not in the remote inventory and was dropped.")
        }
        return AppStoredSettingsLoad(fields: inventory, notices: notices)
    }

    static func persistRemoteInventory(_ inventory: NativeAppShellLocalMediaInventory, defaults: UserDefaults = .standard) {
        guard let data = try? JSONEncoder().encode(inventory), let text = String(data: data, encoding: .utf8) else {
            logger.warning("Remote inventory could not be encoded for persistence.")
            return
        }
        defaults.set(text, forKey: AppStorageKeys.remoteInventory)
    }

    /// Lists previously selected local devices that the refreshed inventory no longer offers.
    static func droppedLocalSelectionNotices(
        previous: NativeAppShellLocalMediaSelection,
        refreshed: NativeAppShellLocalMediaInventory
    ) -> [String] {
        guard refreshed.inventoryErrors.isEmpty else { return [] }
        var notices: [String] = []
        if let uid = previous.audioInputUID,
           !refreshed.audioDevices.contains(where: { $0.uid == uid && $0.supportsInput }) {
            notices.append("Selected audio input \"\(uid)\" is not available; another device was selected.")
        }
        if let uid = previous.audioOutputUID,
           !refreshed.audioDevices.contains(where: { $0.uid == uid && $0.supportsOutput }) {
            notices.append("Selected audio output \"\(uid)\" is not available; another device was selected.")
        }
        if let id = previous.videoDeviceID, !refreshed.videoDevices.contains(where: { $0.uniqueId == id }) {
            notices.append("Selected video device \"\(id)\" is not available; another device was selected.")
        }
        return notices
    }

    private static func nonEmptyString(_ key: String, defaults: UserDefaults) -> String? {
        guard let value = defaults.string(forKey: key), !value.isEmpty else { return nil }
        return value
    }
}
