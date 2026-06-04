import Foundation
import Observation
import OpenLolaCore

@MainActor
@Observable
final class AppLocalOperatorInventoryController: @unchecked Sendable {
    var isRefreshingInventory = false
    var lastRefreshWarning: String?

    @ObservationIgnored private var refreshTask: Task<Void, Never>?

    deinit {
        refreshTask?.cancel()
    }

    func refresh(
        currentSurface: NativeAppShellOperatorPrototypeState,
        apply: @escaping @MainActor @Sendable (NativeAppShellOperatorPrototypeState) -> Void
    ) {
        refreshTask?.cancel()
        let commandIntent = currentSurface.commandIntent
        let sessionMode = currentSurface.sessionMode
        let controlMode = currentSurface.controlMode
        let localSelection = currentSurface.inventory.selection
        let remoteInventory = currentSurface.remoteInventory
        let directPeerCommandFields = currentSurface.directPeerCommandFields
        let windowsLoLaPeerFields = currentSurface.windowsLoLaPeerFields
        let jackTripPeerFields = currentSurface.jackTripPeerFields
        let ultraGridPeerFields = currentSurface.ultraGridPeerFields
        isRefreshingInventory = true
        lastRefreshWarning = nil

        let task = Task { @MainActor [weak self] in
            let nextSurface = await AppLocalOperatorInventory.captureAsync(
                sessionMode: sessionMode,
                controlMode: controlMode,
                commandIntent: commandIntent,
                localSelection: localSelection,
                remoteInventory: remoteInventory,
                directPeerCommandFields: directPeerCommandFields,
                windowsLoLaPeerFields: windowsLoLaPeerFields,
                jackTripPeerFields: jackTripPeerFields,
                ultraGridPeerFields: ultraGridPeerFields
            )
            guard !Task.isCancelled, let self else {
                return
            }
            apply(nextSurface)
            self.lastRefreshWarning = inventoryWarning(from: nextSurface.inventory.inventoryErrors)
            self.isRefreshingInventory = false
            self.refreshTask = nil
        }
        refreshTask = task
    }

    private func inventoryWarning(from errors: [String]) -> String? {
        errors.isEmpty ? nil : errors.joined(separator: "\n")
    }
}

enum AppLocalOperatorInventoryRefreshMergePolicy {
    static func merge(
        current: NativeAppShellOperatorPrototypeState,
        refreshResult: NativeAppShellOperatorPrototypeState
    ) -> NativeAppShellOperatorPrototypeState {
        var merged = current
        var inventory = refreshResult.inventory
        inventory.selection = NativeAppShellLocalMediaSelection(
            audioInputUID: preservedAudioUID(
                current.inventory.selection.audioInputUID,
                in: inventory.audioDevices,
                supports: \.supportsInput
            ) ?? inventory.selection.audioInputUID,
            audioOutputUID: preservedAudioUID(
                current.inventory.selection.audioOutputUID,
                in: inventory.audioDevices,
                supports: \.supportsOutput
            ) ?? inventory.selection.audioOutputUID,
            videoDeviceID: preservedVideoID(
                current.inventory.selection.videoDeviceID,
                in: inventory.videoDevices
            ) ?? inventory.selection.videoDeviceID
        )
        merged.inventory = inventory
        return merged
    }

    private static func preservedAudioUID(
        _ uid: String?,
        in devices: [NativeAppShellAudioDeviceOption],
        supports keyPath: KeyPath<NativeAppShellAudioDeviceOption, Bool>
    ) -> String? {
        guard let uid, devices.contains(where: { $0.uid == uid && $0[keyPath: keyPath] }) else {
            return nil
        }
        return uid
    }

    private static func preservedVideoID(
        _ id: String?,
        in devices: [NativeAppShellVideoDeviceOption]
    ) -> String? {
        guard let id, devices.contains(where: { $0.uniqueId == id }) else {
            return nil
        }
        return id
    }
}

enum AppLocalOperatorInventory {
    static func captureAsync(
        sessionMode: NativeAppShellSessionMode,
        controlMode: NativeAppShellControlMode,
        commandIntent: NativeAppShellOperatorCommandIntent,
        localSelection: NativeAppShellLocalMediaSelection,
        remoteInventory: NativeAppShellLocalMediaInventory,
        directPeerCommandFields: NativeAppShellDirectPeerCommandFields,
        windowsLoLaPeerFields: NativeAppShellWindowsLoLaPeerFields,
        jackTripPeerFields: NativeAppShellExternalConnectorPeerFields,
        ultraGridPeerFields: NativeAppShellExternalConnectorPeerFields
    ) async -> NativeAppShellOperatorPrototypeState {
        await Task.detached(priority: .utility) {
            capture(
                sessionMode: sessionMode,
                controlMode: controlMode,
                commandIntent: commandIntent,
                localSelection: localSelection,
                remoteInventory: remoteInventory,
                directPeerCommandFields: directPeerCommandFields,
                windowsLoLaPeerFields: windowsLoLaPeerFields,
                jackTripPeerFields: jackTripPeerFields,
                ultraGridPeerFields: ultraGridPeerFields
            )
        }.value
    }

    static func capture(
        sessionMode: NativeAppShellSessionMode = .directMacPeer,
        controlMode: NativeAppShellControlMode = .normal,
        commandIntent: NativeAppShellOperatorCommandIntent = .idle,
        localSelection: NativeAppShellLocalMediaSelection = NativeAppShellLocalMediaSelection(
            audioInputUID: nil,
            audioOutputUID: nil,
            videoDeviceID: nil
        ),
        remoteInventory: NativeAppShellLocalMediaInventory = .editableRemotePlaceholder(),
        directPeerCommandFields: NativeAppShellDirectPeerCommandFields = .appDefault,
        windowsLoLaPeerFields: NativeAppShellWindowsLoLaPeerFields = .appDefault,
        jackTripPeerFields: NativeAppShellExternalConnectorPeerFields = .jackTripAppDefault,
        ultraGridPeerFields: NativeAppShellExternalConnectorPeerFields = .ultraGridAppDefault
    ) -> NativeAppShellOperatorPrototypeState {
        let capturedAt = ISO8601DateFormatter().string(from: Date())
        var audioDevices: [NativeAppShellAudioDeviceOption] = []
        var inventoryErrors: [String] = []
        var hostName = Host.current().localizedName ?? "unknown-host"

        do {
            let report = try CoreAudioInventoryReader().capture()
            hostName = report.hostName
            audioDevices = report.devices.map(NativeAppShellAudioDeviceOption.init)
        } catch {
            inventoryErrors.append("Core Audio inventory unavailable: \(error)")
        }

        let videoReport = AVFoundationVideoDeviceInventoryReader().capture()
        let videoDevices = videoReport.devices.map(NativeAppShellVideoDeviceOption.init)
        let selectedVideo = videoDevices.first {
            $0.sourcePolicy == .blackmagicFirstAvFoundationFallback
        } ?? videoDevices.first
        let selectedInputUID = preservedAudioUID(
            localSelection.audioInputUID,
            in: audioDevices,
            supports: \.supportsInput
        ) ?? audioDevices.first(where: \.supportsInput)?.uid
        let selectedOutputUID = preservedAudioUID(
            localSelection.audioOutputUID,
            in: audioDevices,
            supports: \.supportsOutput
        ) ?? audioDevices.first(where: \.supportsOutput)?.uid
        let selectedVideoID = preservedVideoID(localSelection.videoDeviceID, in: videoDevices)
            ?? selectedVideo?.uniqueId

        return NativeAppShellOperatorPrototypeState(
            sessionMode: sessionMode,
            controlMode: controlMode,
            inventory: NativeAppShellLocalMediaInventory(
                capturedAt: capturedAt,
                hostName: hostName,
                audioDevices: audioDevices,
                videoDevices: videoDevices,
                selection: NativeAppShellLocalMediaSelection(
                    audioInputUID: selectedInputUID,
                    audioOutputUID: selectedOutputUID,
                    videoDeviceID: selectedVideoID
                ),
                inventoryErrors: inventoryErrors
            ),
            remoteInventory: remoteInventory,
            commandIntent: commandIntent,
            remoteOrchestrationEnabled: false,
            startsLongRunningProcess: false,
            directPeerCommandFields: directPeerCommandFields,
            windowsLoLaPeerFields: windowsLoLaPeerFields,
            jackTripPeerFields: jackTripPeerFields,
            ultraGridPeerFields: ultraGridPeerFields
        )
    }

    private static func preservedAudioUID(
        _ uid: String?,
        in devices: [NativeAppShellAudioDeviceOption],
        supports keyPath: KeyPath<NativeAppShellAudioDeviceOption, Bool>
    ) -> String? {
        guard let uid, devices.contains(where: { $0.uid == uid && $0[keyPath: keyPath] }) else {
            return nil
        }
        return uid
    }

    private static func preservedVideoID(
        _ id: String?,
        in devices: [NativeAppShellVideoDeviceOption]
    ) -> String? {
        guard let id, devices.contains(where: { $0.uniqueId == id }) else {
            return nil
        }
        return id
    }
}
