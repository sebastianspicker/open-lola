// Captures local Core Audio and AVFoundation device inventory and selected device identifiers.
import Foundation

/// Defines the validated fields for native app shell local media selection.
public struct NativeAppShellLocalMediaSelection: Codable, Equatable, Sendable {
    public var audioInputUID: String?
    public var audioOutputUID: String?
    public var videoDeviceID: String?

    public init(
        audioInputUID: String?,
        audioOutputUID: String?,
        videoDeviceID: String?
    ) {
        self.audioInputUID = audioInputUID
        self.audioOutputUID = audioOutputUID
        self.videoDeviceID = videoDeviceID
    }
}

/// Defines the validated fields for native app shell local media inventory.
public struct NativeAppShellLocalMediaInventory: PrettyJSONCodable, Equatable, Sendable {
    public var capturedAt: String
    public var hostName: String
    public var audioDevices: [NativeAppShellAudioDeviceOption]
    public var videoDevices: [NativeAppShellVideoDeviceOption]
    public var selection: NativeAppShellLocalMediaSelection
    public var inventoryErrors: [String]

    public init(
        capturedAt: String,
        hostName: String,
        audioDevices: [NativeAppShellAudioDeviceOption],
        videoDevices: [NativeAppShellVideoDeviceOption],
        selection: NativeAppShellLocalMediaSelection,
        inventoryErrors: [String]
    ) {
        self.capturedAt = capturedAt
        self.hostName = hostName
        self.audioDevices = audioDevices
        self.videoDevices = videoDevices
        self.selection = selection
        self.inventoryErrors = inventoryErrors
    }

    public static func editableRemotePlaceholder(
        peerName: String = "remote-peer"
    ) -> NativeAppShellLocalMediaInventory {
        NativeAppShellLocalMediaInventory(
            capturedAt: "operator-import-pending",
            hostName: peerName,
            audioDevices: [],
            videoDevices: [],
            selection: NativeAppShellLocalMediaSelection(
                audioInputUID: nil,
                audioOutputUID: nil,
                videoDeviceID: nil
            ),
            inventoryErrors: ["Remote media inventory must be imported from the remote Mac operator."]
        )
    }
}
