// Derives evidence-chain and topology labels from the real operator plan and inventory, never from the synthetic smoke report.
import OpenLolaCore

enum AppSessionRunLabels {
    /// Inventory states the Source stage reports before any real capture exists.
    static let inventoryPendingState = "No inventory yet"
    static let inventoryCapturedState = "Capability"

    /// The two-peer plan always starts the remote Mac first as responder and runs this Mac as initiator.
    static let directPeerRoleSummary = "Initiator on this Mac (the remote Mac is started first as responder)"

    /// Camera authorization as shown in the inventory; "Not checked" before a local inventory was captured.
    static func cameraPermissionLabel(_ status: AVFoundationPermissionStatus?) -> String {
        guard let status else {
            return "Not checked"
        }
        switch status {
        case .authorized: return "Authorized"
        case .denied: return "Denied (allow in System Settings > Privacy & Security > Camera)"
        case .restricted: return "Restricted by system policy"
        case .notDetermined: return "Not decided (prompts on first capture)"
        case .requestTimedOut: return "Prompt not answered in time"
        case .unknown: return "Unknown"
        }
    }

    /// Describes the profile the next run will use, or nil when the mode has no named profile.
    static func profileCaption(plan: AppOperatorPrototypePlan) -> String? {
        switch plan.sessionMode {
        case .directMacPeer:
            return "\(plan.avProfile.rawValue) profile · RX \(plan.rxBufferProfile.rawValue)"
        case .windowsLoLa:
            return "Media \(plan.windowsLoLaFields.mediaMode.rawValue)"
        case .jackTrip, .ultraGrid:
            return "Media \(plan.externalConnectorFields.mediaMode.rawValue)"
        }
    }

    /// Names the selected local audio input, or nil when nothing is selected or the UID is not in the inventory.
    static func localDeviceLabel(inventory: NativeAppShellLocalMediaInventory) -> String? {
        guard let uid = inventory.selection.audioInputUID else {
            return nil
        }
        return inventory.audioDevices.first { $0.uid == uid }?.name
    }

    /// Reports whether the planned route carries video; direct peer sessions always do.
    static func videoEnabled(plan: AppOperatorPrototypePlan) -> Bool {
        switch plan.sessionMode {
        case .directMacPeer:
            return true
        case .windowsLoLa:
            return plan.windowsLoLaFields.mediaMode.hasVideo
        case .jackTrip, .ultraGrid:
            return plan.externalConnectorFields.mediaMode.hasVideo
        }
    }

    /// Source-stage state: capability once a local inventory was captured, otherwise an explicit "no inventory yet".
    static func sourceState(inventory: NativeAppShellLocalMediaInventory) -> String {
        inventory.capturedAt == "launch-inventory-pending" ? inventoryPendingState : inventoryCapturedState
    }

    /// Planned-route note built from the real mode and profile, or the mode alone when there is no profile.
    static func plannedRouteNote(plan: AppOperatorPrototypePlan) -> String {
        [plan.sessionMode.displayName, profileCaption(plan: plan)].compactMap { $0 }.joined(separator: " · ")
    }
}
