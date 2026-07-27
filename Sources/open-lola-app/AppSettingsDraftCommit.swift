// Commits validated draft values, keeping persistence separate from transient form edits.
import OpenLolaCore

extension AppSettingsDraft {
    func load(from settings: AppSettings) {
        let next = AppSettingsDraft(settings: settings)
        copy(from: next)
        sourceFingerprint = next.sourceFingerprint
    }

    @discardableResult
    func commit(
        to settings: AppSettings,
        operatorSurface: inout NativeAppShellOperatorPrototypeState,
        executionController: AppExecutionController,
        previewState: AppPreviewReceiverState
    ) -> AppSettingsDraftCommitResult {
        guard !hasSourceConflict(comparedTo: settings) else {
            load(from: settings)
            return .conflict(AppSettingsDraftCommitResult.conflictMessage)
        }
        let runtimeConfigurationChanged = changesRuntimeConfiguration(comparedTo: settings)
        apply(to: settings)
        apply(to: &operatorSurface)
        apply(to: &executionController.settings)
        apply(to: previewState)
        if runtimeConfigurationChanged {
            executionController.invalidateRuntimeEvidenceAfterConfigurationChange()
        }
        sourceFingerprint = AppSettingsDraft(settings: settings).sourceFingerprint
        return .saved
    }

    func hasSourceConflict(comparedTo settings: AppSettings) -> Bool {
        AppSettingsDraft(settings: settings).sourceFingerprint != sourceFingerprint
    }
}
