import Foundation
import Testing

@testable import OpenLolaAppSupport
@testable import OpenLolaCore

@MainActor
@Test
func appSettingsDraftDoesNotPersistOrMutateRuntimeUntilSave() throws {
    let suiteName = "open-lola-settings-draft-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defer { defaults.removePersistentDomain(forName: suiteName) }

    defaults.set("original-peer", forKey: AppStorageKeys.localPeer)
    defaults.set(true, forKey: AppStorageKeys.requirePreflight)
    defaults.set(true, forKey: AppStorageKeys.audioPreviewEnabled)

    let settings = AppSettings(defaults: defaults)
    let draft = AppSettingsDraft(settings: settings)
    var surface = AppShellStoredDefaults.placeholderOperatorSurface()
    let controller = AppExecutionController()
    let previewState = AppPreviewReceiverState()

    draft.localPeer = "draft-peer"
    draft.requirePreflight = false
    draft.audioPreviewEnabled = false

    #expect(defaults.string(forKey: AppStorageKeys.localPeer) == "original-peer")
    #expect(settings.localPeer == "original-peer")
    #expect(surface.directPeerCommandFields.localPeer != "draft-peer")
    #expect(controller.settings.requirePreflight)
    #expect(previewState.audioPreviewEnabled)

    draft.commit(
        to: settings,
        operatorSurface: &surface,
        executionController: controller,
        previewState: previewState
    )

    #expect(defaults.string(forKey: AppStorageKeys.localPeer) == "draft-peer")
    #expect(settings.localPeer == "draft-peer")
    #expect(surface.directPeerCommandFields.localPeer == "draft-peer")
    #expect(!controller.settings.requirePreflight)
    #expect(!previewState.audioPreviewEnabled)

    draft.localPeer = "discarded-peer"
    draft.load(from: settings)

    #expect(draft.localPeer == "draft-peer")
    #expect(defaults.string(forKey: AppStorageKeys.localPeer) == "draft-peer")
}

@Test
func appExecutablePathResolverClassifiesRunnableAndUnavailablePaths() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("open-lola-app-executable-paths-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let missingExecutable = directory.appendingPathComponent("missing-open-lola")
    let nonExecutableFile = directory.appendingPathComponent("not-executable")
    let executableFile = directory.appendingPathComponent("open-lola")
    try Data("#!/bin/sh\nexit 0\n".utf8).write(to: nonExecutableFile)
    try Data("#!/bin/sh\nexit 0\n".utf8).write(to: executableFile)
    try FileManager.default.setAttributes(
        [.posixPermissions: NSNumber(value: Int16(0o755))],
        ofItemAtPath: executableFile.path
    )

    #expect(AppExecutablePathResolver.resolve(missingExecutable.path) == .unavailable(
        path: missingExecutable.path,
        reason: "file does not exist"
    ))
    #expect(AppExecutablePathResolver.resolve(nonExecutableFile.path) == .unverified(
        path: nonExecutableFile.path,
        reason: "file is not executable"
    ))
    #expect(AppExecutablePathResolver.resolve(executableFile.path) == .verified(path: executableFile.path))

    do {
        _ = try AppExecutablePathResolver.verifiedPath(nonExecutableFile.path)
        Issue.record("Expected non-executable file to fail executable verification")
    } catch {
        #expect(String(describing: error).contains("Executable path unverified"))
    }
}
