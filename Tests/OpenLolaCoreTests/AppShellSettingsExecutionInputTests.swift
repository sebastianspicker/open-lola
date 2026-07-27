// Verifies that app settings draft does not persist or mutate runtime before save.
import Foundation
import Testing

@testable import OpenLolaAppSupport
@testable import OpenLolaCore

@MainActor
@Test
func appSettingsDraftDoesNotPersistOrMutateRuntimeBeforeSave() throws {
    let suiteName = "open-lola-settings-draft-\(UUID().uuidString)"
    let context = try makeAppSettingsDraftTestContext(
        suiteName: suiteName,
        requirePreflight: true,
        audioPreviewEnabled: true
    )
    defer { context.defaults.removePersistentDomain(forName: suiteName) }
    let defaults = context.defaults
    let settings = context.settings
    let draft = context.draft
    let surface = context.surface
    let controller = context.controller
    let previewState = context.previewState

    draft.localPeer = "draft-peer"
    draft.requirePreflight = false
    draft.audioPreviewEnabled = false

    #expect(defaults.string(forKey: AppStorageKeys.localPeer) == "original-peer")
    #expect(settings.localPeer == "original-peer")
    #expect(surface.directPeerCommandFields.localPeer != "draft-peer")
    #expect(controller.settings.requirePreflight)
    #expect(previewState.audioPreviewEnabled)
}

@MainActor
@Test
func appSettingsDraftReloadsPersistedSettingsAfterDiscardedEdits() throws {
    let suiteName = "open-lola-settings-draft-\(UUID().uuidString)"
    var context = try makeAppSettingsDraftTestContext(suiteName: suiteName)
    defer { context.defaults.removePersistentDomain(forName: suiteName) }

    context.draft.localPeer = "draft-peer"
    context.draft.commit(
        to: context.settings,
        operatorSurface: &context.surface,
        executionController: context.controller,
        previewState: context.previewState
    )

    context.draft.localPeer = "discarded-peer"
    context.draft.load(from: context.settings)

    #expect(context.draft.localPeer == "draft-peer")
    #expect(context.defaults.string(forKey: AppStorageKeys.localPeer) == "draft-peer")
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
