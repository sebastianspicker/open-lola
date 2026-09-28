// Hosts the operator settings surface, separating tab navigation from execution and persistence services.
import OpenLolaCore
import SwiftUI

struct AppShellSettingsView: View {
    let configuration: NativeAppConfigurationSnapshot
    @Binding var operatorSurface: NativeAppShellOperatorPrototypeState
    let executionController: AppExecutionController
    let previewState: AppPreviewReceiverState
    @Bindable var appSettings: AppSettings
    @State var settingsDraft = AppSettingsDraft()
    @State var settingsFeedback: AppSettingsCommitFeedback?
    @AppStorage(AppStorageKeys.selectedSettingsTab)
    var selectedSettingsTabRawValue = AppShellSettingsTabID.execution.rawValue

    var executionSettingsLocked: Bool {
        executionController.isRunning
    }

    var executionSettingsHelp: String {
        Self.executionSettingsHelp(phase: executionController.phase, isRunning: executionSettingsLocked)
    }

    static func executionSettingsHelp(isRunning: Bool) -> String {
        executionSettingsHelp(phase: .idle, isRunning: isRunning)
    }

    static func executionSettingsHelp(phase: AppExecutionPhase, isRunning: Bool) -> String {
        isRunning
            ? AppRuntimeInputLock.reason(phase: phase, isRunning: isRunning)
                ?? "Execution-affecting settings are locked while a process is active."
            : "Changes apply to the next generated command or validation."
    }
}
