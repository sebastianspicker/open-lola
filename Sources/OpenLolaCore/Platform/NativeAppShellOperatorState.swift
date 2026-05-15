import Foundation

/// Value-semantic operator-surface snapshot.
///
/// `Sendable` is for transferring complete snapshots between actors or tasks.
/// Shared mutable access is not supported; UI mutation must stay on the
/// MainActor-owned `@State`/`Binding` instance, and background work must receive
/// a copy captured before the task starts.
public struct NativeAppShellOperatorPrototypeState: Codable, Equatable, Sendable {
    public var sessionMode: NativeAppShellSessionMode
    public var inventory: NativeAppShellLocalMediaInventory
    public var remoteInventory: NativeAppShellLocalMediaInventory
    public var commandIntent: NativeAppShellOperatorCommandIntent
    public var remoteOrchestrationEnabled: Bool
    public var startsLongRunningProcess: Bool
    public var directPeerCommandFields: NativeAppShellDirectPeerCommandFields
    public var windowsLoLaPeerFields: NativeAppShellWindowsLoLaPeerFields

    public init(
        sessionMode: NativeAppShellSessionMode = .directMacPeer,
        inventory: NativeAppShellLocalMediaInventory,
        remoteInventory: NativeAppShellLocalMediaInventory = .editableRemotePlaceholder(),
        commandIntent: NativeAppShellOperatorCommandIntent,
        remoteOrchestrationEnabled: Bool,
        startsLongRunningProcess: Bool,
        directPeerCommandFields: NativeAppShellDirectPeerCommandFields = .appDefault,
        windowsLoLaPeerFields: NativeAppShellWindowsLoLaPeerFields = .appDefault
    ) {
        self.sessionMode = sessionMode
        self.inventory = inventory
        self.remoteInventory = remoteInventory
        self.commandIntent = commandIntent
        self.remoteOrchestrationEnabled = remoteOrchestrationEnabled
        self.startsLongRunningProcess = startsLongRunningProcess
        self.directPeerCommandFields = directPeerCommandFields
        self.windowsLoLaPeerFields = windowsLoLaPeerFields
    }
}
