// Builds isolated app settings drafts and dependencies for operator settings tests.
import Foundation
import Testing

@testable import OpenLolaAppSupport
@testable import OpenLolaCore

@MainActor
struct AppSettingsDraftTestContext {
    let defaults: UserDefaults
    let settings: AppSettings
    let draft: AppSettingsDraft
    var surface: NativeAppShellOperatorPrototypeState
    let controller: AppExecutionController
    let previewState: AppPreviewReceiverState
}

@MainActor
func makeAppSettingsDraftTestContext(
    suiteName: String,
    requirePreflight: Bool? = nil,
    audioPreviewEnabled: Bool? = nil
) throws -> AppSettingsDraftTestContext {
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defaults.set("original-peer", forKey: AppStorageKeys.localPeer)
    if let requirePreflight {
        defaults.set(requirePreflight, forKey: AppStorageKeys.requirePreflight)
    }
    if let audioPreviewEnabled {
        defaults.set(audioPreviewEnabled, forKey: AppStorageKeys.audioPreviewEnabled)
    }
    let settings = AppSettings(defaults: defaults)
    return AppSettingsDraftTestContext(
        defaults: defaults,
        settings: settings,
        draft: AppSettingsDraft(settings: settings),
        surface: AppShellStoredDefaults.placeholderOperatorSurface(),
        controller: AppExecutionController(),
        previewState: AppPreviewReceiverState()
    )
}
