// Maps application settings to UserDefaults, isolating persistence keys from operator-facing configuration.
import Foundation
import OpenLolaCore
import OSLog

enum AppShellStoredDefaults {
    // Default parameters intentionally read from UserDefaults.standard.
    static let logger = Logger(subsystem: "org.openlola.app", category: "stored-defaults")

    static func positivePreviewStreamValue(_ value: Int) -> Int {
        max(1, value)
    }

    static func placeholderOperatorSurface(
        commandIntent: NativeAppShellOperatorCommandIntent = .idle,
        remoteInventory: NativeAppShellLocalMediaInventory = .editableRemotePlaceholder()
    ) -> NativeAppShellOperatorPrototypeState {
        NativeAppShellOperatorPrototypeState(
            workflow: NativeAppShellOperatorWorkflow(sessionMode: sessionMode(), controlMode: controlMode(), commandIntent: commandIntent, remoteOrchestrationEnabled: false, startsLongRunningProcess: false),
            inventories: NativeAppShellOperatorInventories(local: NativeAppShellLocalMediaInventory(
                capturedAt: "launch-inventory-pending",
                hostName: "local-peer",
                audioDevices: [],
                videoDevices: [],
                selection: NativeAppShellLocalMediaSelection(
                    audioInputUID: nil,
                    audioOutputUID: nil,
                    videoDeviceID: nil
                ),
                inventoryErrors: ["Local media inventory refresh pending."]
            ), remote: remoteInventory),
            peerFields: NativeAppShellOperatorPeerFields(directPeer: directPeerCommandFields(), windowsLoLa: windowsLoLaPeerFields(), jackTrip: jackTripPeerFields(), ultraGrid: ultraGridPeerFields())
        )
    }

    static func hydratedOperatorSurface(
        commandIntent: NativeAppShellOperatorCommandIntent = .idle,
        remoteInventory: NativeAppShellLocalMediaInventory = .editableRemotePlaceholder()
    ) -> NativeAppShellOperatorPrototypeState {
        AppLocalOperatorInventory.capture(AppLocalOperatorInventoryCaptureRequest(
            sessionMode: sessionMode(),
            controlMode: controlMode(),
            commandIntent: commandIntent,
            remoteInventory: remoteInventory,
            directPeerCommandFields: directPeerCommandFields(),
            windowsLoLaPeerFields: windowsLoLaPeerFields(),
            jackTripPeerFields: jackTripPeerFields(),
            ultraGridPeerFields: ultraGridPeerFields()
        ))
    }

    static func sessionMode(defaults: UserDefaults = .standard) -> NativeAppShellSessionMode {
        NativeAppShellSessionMode(rawValue: defaults.string(forKey: AppStorageKeys.sessionMode) ?? "")
            ?? .directMacPeer
    }

    static func controlMode(defaults: UserDefaults = .standard) -> NativeAppShellControlMode {
        NativeAppShellControlMode(rawValue: defaults.string(forKey: AppStorageKeys.controlMode) ?? "")
            ?? .normal
    }

    static func executionSettings(defaults: UserDefaults = .standard) -> NativeAppShellExecutionSettings {
        var settings = NativeAppShellExecutionSettings()
        settings.planPath = defaults.string(forKey: AppStorageKeys.planPath) ?? settings.planPath
        settings.supervisorReportPath = defaults.string(forKey: AppStorageKeys.supervisorReportPath)
            ?? settings.supervisorReportPath
        settings.executionMode = DirectPeerTwoPeerRunExecutionMode(
            rawValue: defaults.string(forKey: AppStorageKeys.executionMode) ?? ""
        ) ?? settings.executionMode
        settings.requirePreflight = boolDefault(
            AppStorageKeys.requirePreflight,
            fallback: settings.requirePreflight,
            defaults: defaults
        )
        settings.macASSH = defaults.string(forKey: AppStorageKeys.executionMacASSH) ?? settings.macASSH
        settings.macBSSH = defaults.string(forKey: AppStorageKeys.executionMacBSSH) ?? settings.macBSSH
        settings.macAWorkingDirectory = defaults.string(forKey: AppStorageKeys.executionMacAWorkingDirectory)
            ?? settings.macAWorkingDirectory
        settings.macBWorkingDirectory = defaults.string(forKey: AppStorageKeys.executionMacBWorkingDirectory)
            ?? settings.macBWorkingDirectory
        settings.sshExecutable = defaults.string(forKey: AppStorageKeys.executionSSHExecutable)
            ?? settings.sshExecutable
        settings.scpExecutable = defaults.string(forKey: AppStorageKeys.executionSCPExecutable)
            ?? settings.scpExecutable
        return settings
    }

    @MainActor
    static func previewReceiverState(defaults: UserDefaults = .standard) -> AppPreviewReceiverState {
        let previewDefaults = previewDefaults(defaults: defaults)
        return AppPreviewReceiverState(
            audioPreviewEnabled: previewDefaults.audioPreviewEnabled,
            videoPreviewEnabled: previewDefaults.videoPreviewEnabled,
            showSafeFrame: previewDefaults.showSafeFrame,
            monitorGain: previewDefaults.monitorGain,
            remoteReturnBlend: previewDefaults.remoteReturnBlend,
            videoScale: previewDefaults.videoScale,
            visibleStreams: previewDefaults.visibleStreams,
            selectedVideoStream: previewDefaults.selectedVideoStream
        )
    }

    static func previewDefaults(defaults: UserDefaults = .standard) -> AppPreviewDefaults {
        AppPreviewDefaults(
            audioPreviewEnabled: boolDefault(
                AppStorageKeys.audioPreviewEnabled,
                fallback: true,
                defaults: defaults
            ),
            videoPreviewEnabled: boolDefault(
                AppStorageKeys.videoPreviewEnabled,
                fallback: true,
                defaults: defaults
            ),
            showSafeFrame: boolDefault(AppStorageKeys.showSafeFrame, fallback: true, defaults: defaults),
            monitorGain: doubleDefault(AppStorageKeys.monitorGain, fallback: 0.65, defaults: defaults),
            remoteReturnBlend: doubleDefault(AppStorageKeys.remoteReturnBlend, fallback: 0.25, defaults: defaults),
            videoScale: doubleDefault(AppStorageKeys.videoScale, fallback: 1.0, defaults: defaults),
            visibleStreams: positivePreviewStreamValue(
                intDefault(AppStorageKeys.visibleStreams, fallback: 1, defaults: defaults)
            ),
            selectedVideoStream: positivePreviewStreamValue(
                intDefault(AppStorageKeys.selectedVideoStream, fallback: 101, defaults: defaults)
            )
        )
    }

    @MainActor
    static func hydratePreviewState(_ previewState: AppPreviewReceiverState) {
        let storedDefaults = previewDefaults()
        previewState.audioPreviewEnabled = storedDefaults.audioPreviewEnabled
        previewState.videoPreviewEnabled = storedDefaults.videoPreviewEnabled
        previewState.showSafeFrame = storedDefaults.showSafeFrame
        previewState.monitorGain = storedDefaults.monitorGain
        previewState.remoteReturnBlend = storedDefaults.remoteReturnBlend
        previewState.videoScale = storedDefaults.videoScale
        previewState.visibleStreams = storedDefaults.visibleStreams
        previewState.selectedVideoStream = storedDefaults.selectedVideoStream
    }

    static func validatedOrDefault(
        _ fields: NativeAppShellDirectPeerCommandFields
    ) -> NativeAppShellDirectPeerCommandFields {
        do {
            try fields.validateAppSettings()
            return fields
        } catch {
            return .appDefault
        }
    }

    static func validatedOrDefault(
        _ fields: NativeAppShellWindowsLoLaPeerFields
    ) -> NativeAppShellWindowsLoLaPeerFields {
        do {
            try fields.validateAppSettings()
            return fields
        } catch {
            return .appDefault
        }
    }

    static func validatedOrDefault(
        _ fields: NativeAppShellExternalConnectorPeerFields,
        connector: ExternalConnectorKind,
        fallback: NativeAppShellExternalConnectorPeerFields
    ) -> NativeAppShellExternalConnectorPeerFields {
        do {
            try fields.validateAppSettings(connector: connector)
            return fields
        } catch {
            return fallback
        }
    }

    static func intDefault(_ key: String, fallback: Int, defaults: UserDefaults = .standard) -> Int {
        defaults.object(forKey: key) == nil ? fallback : defaults.integer(forKey: key)
    }

    static func uint16Default(_ key: String, fallback: UInt16, defaults: UserDefaults = .standard) -> UInt16 {
        guard defaults.object(forKey: key) != nil else { return fallback }

        let persistedValue = defaults.integer(forKey: key)
        guard let exactValue = UInt16(exactly: persistedValue) else {
            defaults.removeObject(forKey: key)
            logger.warning(
                """
                Invalid persisted UInt16 value \(persistedValue, privacy: .public) \
                for \(key, privacy: .public); reset to \(Int(fallback), privacy: .public)
                """
            )
            return fallback
        }
        return exactValue
    }

    static func boolDefault(_ key: String, fallback: Bool, defaults: UserDefaults = .standard) -> Bool {
        defaults.object(forKey: key) == nil ? fallback : defaults.bool(forKey: key)
    }

    static func doubleDefault(_ key: String, fallback: Double, defaults: UserDefaults = .standard) -> Double {
        defaults.object(forKey: key) == nil ? fallback : defaults.double(forKey: key)
    }
}
