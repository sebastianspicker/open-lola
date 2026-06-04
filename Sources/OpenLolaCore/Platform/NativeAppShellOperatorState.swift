import Foundation

/// Value-semantic operator-surface snapshot.
///
/// `Sendable` is for transferring complete snapshots between actors or tasks.
/// Shared mutable access is not supported; UI mutation must stay on the
/// MainActor-owned `@State`/`Binding` instance, and background work must receive
/// a copy captured before the task starts.
public struct NativeAppShellOperatorPrototypeState: Codable, Equatable, Sendable {
    public var sessionMode: NativeAppShellSessionMode
    public var controlMode: NativeAppShellControlMode
    public var inventory: NativeAppShellLocalMediaInventory
    public var remoteInventory: NativeAppShellLocalMediaInventory
    public var commandIntent: NativeAppShellOperatorCommandIntent
    public var remoteOrchestrationEnabled: Bool
    public var startsLongRunningProcess: Bool
    public var directPeerCommandFields: NativeAppShellDirectPeerCommandFields
    public var windowsLoLaPeerFields: NativeAppShellWindowsLoLaPeerFields
    public var jackTripPeerFields: NativeAppShellExternalConnectorPeerFields
    public var ultraGridPeerFields: NativeAppShellExternalConnectorPeerFields

    public init(
        sessionMode: NativeAppShellSessionMode = .directMacPeer,
        controlMode: NativeAppShellControlMode = .normal,
        inventory: NativeAppShellLocalMediaInventory,
        remoteInventory: NativeAppShellLocalMediaInventory = .editableRemotePlaceholder(),
        commandIntent: NativeAppShellOperatorCommandIntent,
        remoteOrchestrationEnabled: Bool,
        startsLongRunningProcess: Bool,
        directPeerCommandFields: NativeAppShellDirectPeerCommandFields = .appDefault,
        windowsLoLaPeerFields: NativeAppShellWindowsLoLaPeerFields = .appDefault,
        jackTripPeerFields: NativeAppShellExternalConnectorPeerFields = .jackTripAppDefault,
        ultraGridPeerFields: NativeAppShellExternalConnectorPeerFields = .ultraGridAppDefault
    ) {
        self.sessionMode = sessionMode
        self.controlMode = controlMode
        self.inventory = inventory
        self.remoteInventory = remoteInventory
        self.commandIntent = commandIntent
        self.remoteOrchestrationEnabled = remoteOrchestrationEnabled
        self.startsLongRunningProcess = startsLongRunningProcess
        self.directPeerCommandFields = directPeerCommandFields
        self.windowsLoLaPeerFields = windowsLoLaPeerFields
        self.jackTripPeerFields = jackTripPeerFields
        self.ultraGridPeerFields = ultraGridPeerFields
    }

    enum CodingKeys: String, CodingKey {
        case sessionMode
        case controlMode
        case inventory
        case remoteInventory
        case commandIntent
        case remoteOrchestrationEnabled
        case startsLongRunningProcess
        case directPeerCommandFields
        case windowsLoLaPeerFields
        case jackTripPeerFields
        case ultraGridPeerFields
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        sessionMode = try container.decode(NativeAppShellSessionMode.self, forKey: .sessionMode)
        controlMode = try container.decode(NativeAppShellControlMode.self, forKey: .controlMode)
        inventory = try container.decode(NativeAppShellLocalMediaInventory.self, forKey: .inventory)
        remoteInventory = try container.decode(NativeAppShellLocalMediaInventory.self, forKey: .remoteInventory)
        commandIntent = try container.decode(NativeAppShellOperatorCommandIntent.self, forKey: .commandIntent)
        remoteOrchestrationEnabled = try container.decode(Bool.self, forKey: .remoteOrchestrationEnabled)
        startsLongRunningProcess = try container.decode(Bool.self, forKey: .startsLongRunningProcess)
        directPeerCommandFields = try container.decode(
            NativeAppShellDirectPeerCommandFields.self,
            forKey: .directPeerCommandFields
        )
        windowsLoLaPeerFields = try container.decode(
            NativeAppShellWindowsLoLaPeerFields.self,
            forKey: .windowsLoLaPeerFields
        )
        jackTripPeerFields = try container.decodeIfPresent(
            NativeAppShellExternalConnectorPeerFields.self,
            forKey: .jackTripPeerFields
        ) ?? .jackTripAppDefault
        ultraGridPeerFields = try container.decodeIfPresent(
            NativeAppShellExternalConnectorPeerFields.self,
            forKey: .ultraGridPeerFields
        ) ?? .ultraGridAppDefault
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(sessionMode, forKey: .sessionMode)
        try container.encode(controlMode, forKey: .controlMode)
        try container.encode(inventory, forKey: .inventory)
        try container.encode(remoteInventory, forKey: .remoteInventory)
        try container.encode(commandIntent, forKey: .commandIntent)
        try container.encode(remoteOrchestrationEnabled, forKey: .remoteOrchestrationEnabled)
        try container.encode(startsLongRunningProcess, forKey: .startsLongRunningProcess)
        try container.encode(directPeerCommandFields, forKey: .directPeerCommandFields)
        try container.encode(windowsLoLaPeerFields, forKey: .windowsLoLaPeerFields)
        try container.encode(jackTripPeerFields, forKey: .jackTripPeerFields)
        try container.encode(ultraGridPeerFields, forKey: .ultraGridPeerFields)
    }
}
