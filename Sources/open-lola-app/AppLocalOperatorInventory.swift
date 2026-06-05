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
            let nextSurface = await AppLocalOperatorInventory.captureAsync(AppLocalOperatorInventoryCaptureRequest(
                sessionMode: sessionMode,
                controlMode: controlMode,
                commandIntent: commandIntent,
                localSelection: localSelection,
                remoteInventory: remoteInventory,
                directPeerCommandFields: directPeerCommandFields,
                windowsLoLaPeerFields: windowsLoLaPeerFields,
                jackTripPeerFields: jackTripPeerFields,
                ultraGridPeerFields: ultraGridPeerFields
            ))
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
        _ request: AppLocalOperatorInventoryCaptureRequest
    ) async -> NativeAppShellOperatorPrototypeState {
        await Task.detached(priority: .utility) {
            capture(request)
        }.value
    }

    static func capture(
        _ request: AppLocalOperatorInventoryCaptureRequest = AppLocalOperatorInventoryCaptureRequest()
    ) -> NativeAppShellOperatorPrototypeState {
        let capturedAt = ISO8601DateFormatter().string(from: Date())
        let audioInventory = captureAudioInventory()
        let videoReport = AVFoundationVideoDeviceInventoryReader().capture()
        let videoDevices = videoReport.devices.map(NativeAppShellVideoDeviceOption.init)
        let selectedVideo = videoDevices.first {
            $0.sourcePolicy == .blackmagicFirstAvFoundationFallback
        } ?? videoDevices.first

        return NativeAppShellOperatorPrototypeState(
            sessionMode: request.sessionMode,
            controlMode: request.controlMode,
            inventory: NativeAppShellLocalMediaInventory(
                capturedAt: capturedAt,
                hostName: audioInventory.hostName,
                audioDevices: audioInventory.audioDevices,
                videoDevices: videoDevices,
                selection: selectedLocalMediaSelection(
                    request: request,
                    audioDevices: audioInventory.audioDevices,
                    videoDevices: videoDevices,
                    selectedVideo: selectedVideo
                ),
                inventoryErrors: audioInventory.inventoryErrors
            ),
            remoteInventory: request.remoteInventory,
            commandIntent: request.commandIntent,
            remoteOrchestrationEnabled: false,
            startsLongRunningProcess: false,
            directPeerCommandFields: request.directPeerCommandFields,
            windowsLoLaPeerFields: request.windowsLoLaPeerFields,
            jackTripPeerFields: request.jackTripPeerFields,
            ultraGridPeerFields: request.ultraGridPeerFields
        )
    }

    private static func captureAudioInventory() -> AppLocalOperatorCapturedAudioInventory {
        do {
            let report = try CoreAudioInventoryReader().capture()
            return AppLocalOperatorCapturedAudioInventory(
                hostName: report.hostName,
                audioDevices: report.devices.map(NativeAppShellAudioDeviceOption.init),
                inventoryErrors: []
            )
        } catch {
            return AppLocalOperatorCapturedAudioInventory(
                hostName: Host.current().localizedName ?? "unknown-host",
                audioDevices: [],
                inventoryErrors: ["Core Audio inventory unavailable: \(error)"]
            )
        }
    }

    private static func selectedLocalMediaSelection(
        request: AppLocalOperatorInventoryCaptureRequest,
        audioDevices: [NativeAppShellAudioDeviceOption],
        videoDevices: [NativeAppShellVideoDeviceOption],
        selectedVideo: NativeAppShellVideoDeviceOption?
    ) -> NativeAppShellLocalMediaSelection {
        NativeAppShellLocalMediaSelection(
            audioInputUID: preservedAudioUID(
                request.localSelection.audioInputUID,
                in: audioDevices,
                supports: \.supportsInput
            ) ?? audioDevices.first(where: \.supportsInput)?.uid,
            audioOutputUID: preservedAudioUID(
                request.localSelection.audioOutputUID,
                in: audioDevices,
                supports: \.supportsOutput
            ) ?? audioDevices.first(where: \.supportsOutput)?.uid,
            videoDeviceID: preservedVideoID(request.localSelection.videoDeviceID, in: videoDevices)
                ?? selectedVideo?.uniqueId
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

private struct AppLocalOperatorCapturedAudioInventory {
    var hostName: String
    var audioDevices: [NativeAppShellAudioDeviceOption]
    var inventoryErrors: [String]
}

struct AppLocalOperatorInventoryCaptureRequest {
    var sessionMode: NativeAppShellSessionMode = .directMacPeer
    var controlMode: NativeAppShellControlMode = .normal
    var commandIntent: NativeAppShellOperatorCommandIntent = .idle
    var localSelection = NativeAppShellLocalMediaSelection(
        audioInputUID: nil,
        audioOutputUID: nil,
        videoDeviceID: nil
    )
    var remoteInventory: NativeAppShellLocalMediaInventory = .editableRemotePlaceholder()
    var directPeerCommandFields: NativeAppShellDirectPeerCommandFields = .appDefault
    var windowsLoLaPeerFields: NativeAppShellWindowsLoLaPeerFields = .appDefault
    var jackTripPeerFields: NativeAppShellExternalConnectorPeerFields = .jackTripAppDefault
    var ultraGridPeerFields: NativeAppShellExternalConnectorPeerFields = .ultraGridAppDefault
}
