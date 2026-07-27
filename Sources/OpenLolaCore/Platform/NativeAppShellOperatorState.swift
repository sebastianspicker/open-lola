// Stores native operator workflow, peer, media, execution, artifact, and report state.
import Foundation

/// Value-semantic operator-surface snapshot.
///
/// `Sendable` is for transferring complete snapshots between actors or tasks.
/// Shared mutable access is not supported; UI mutation must stay on the
/// MainActor-owned `@State`/`Binding` instance, and background work must receive
/// a copy captured before the task starts.
public struct NativeAppShellOperatorWorkflow: Codable, Equatable, Sendable {
    public var sessionMode: NativeAppShellSessionMode
    public var controlMode: NativeAppShellControlMode
    public var commandIntent: NativeAppShellOperatorCommandIntent
    public var remoteOrchestrationEnabled: Bool
    public var startsLongRunningProcess: Bool
    public init(sessionMode: NativeAppShellSessionMode = .directMacPeer, controlMode: NativeAppShellControlMode = .normal, commandIntent: NativeAppShellOperatorCommandIntent, remoteOrchestrationEnabled: Bool, startsLongRunningProcess: Bool) { self.sessionMode = sessionMode; self.controlMode = controlMode; self.commandIntent = commandIntent; self.remoteOrchestrationEnabled = remoteOrchestrationEnabled; self.startsLongRunningProcess = startsLongRunningProcess }
}

/// Holds the local and remote media inventories shown in the operator interface.
public struct NativeAppShellOperatorInventories: Codable, Equatable, Sendable {
    public var local: NativeAppShellLocalMediaInventory
    public var remote: NativeAppShellLocalMediaInventory
    public init(local: NativeAppShellLocalMediaInventory, remote: NativeAppShellLocalMediaInventory = .editableRemotePlaceholder()) { self.local = local; self.remote = remote }
}

/// Holds editable peer connection fields for each supported operator workflow.
public struct NativeAppShellOperatorPeerFields: Codable, Equatable, Sendable {
    public var directPeer: NativeAppShellDirectPeerCommandFields
    public var windowsLoLa: NativeAppShellWindowsLoLaPeerFields
    public var jackTrip: NativeAppShellExternalConnectorPeerFields
    public var ultraGrid: NativeAppShellExternalConnectorPeerFields
    public init(directPeer: NativeAppShellDirectPeerCommandFields = .appDefault, windowsLoLa: NativeAppShellWindowsLoLaPeerFields = .appDefault, jackTrip: NativeAppShellExternalConnectorPeerFields = .jackTripAppDefault, ultraGrid: NativeAppShellExternalConnectorPeerFields = .ultraGridAppDefault) { self.directPeer = directPeer; self.windowsLoLa = windowsLoLa; self.jackTrip = jackTrip; self.ultraGrid = ultraGrid }
}

/// Stores the complete editable state shown by the native operator prototype.
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

    public init(workflow: NativeAppShellOperatorWorkflow, inventories: NativeAppShellOperatorInventories, peerFields: NativeAppShellOperatorPeerFields = .init()) {
        self.sessionMode = workflow.sessionMode
        self.controlMode = workflow.controlMode
        self.inventory = inventories.local
        self.remoteInventory = inventories.remote
        self.commandIntent = workflow.commandIntent
        self.remoteOrchestrationEnabled = workflow.remoteOrchestrationEnabled
        self.startsLongRunningProcess = workflow.startsLongRunningProcess
        self.directPeerCommandFields = peerFields.directPeer
        self.windowsLoLaPeerFields = peerFields.windowsLoLa
        self.jackTripPeerFields = peerFields.jackTrip
        self.ultraGridPeerFields = peerFields.ultraGrid
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
