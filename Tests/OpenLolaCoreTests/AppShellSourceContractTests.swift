import Foundation
import Testing

@testable import OpenLolaAppSupport
@testable import OpenLolaCore

@MainActor
@Test
func appShellSourceContractHasImportableBehaviorCoverage() {
    _ = OpenLolaApp()
    #expect(NativeAppShellSurfaceContract.releaseReadiness.launchProbePlan.appTargetName == "open-lola-app")
    #expect(NativeAppShellActionInventory.menuActions.contains { $0.id == "open-local-preview-window" })
}

@Test
func appShellMainEntrypointPublishesForegroundActivationBeforeSwiftUIScenes() throws {
    let source = try readAppShellSource("Sources/open-lola-app-main/OpenLolaAppMain.swift")
    let mainAppRange = try #require(source.range(of: "@main"))
    let activationRange = try #require(source.range(of: "NSApplication.shared.setActivationPolicy(.regular)"))
    let activateRange = try #require(source.range(of: "NSApplication.shared.activate(ignoringOtherApps: true)"))
    let bodyRange = try #require(source.range(of: "OpenLolaAppScene()"))

    #expect(mainAppRange.lowerBound < activationRange.lowerBound)
    #expect(activationRange.lowerBound < bodyRange.lowerBound)
    #expect(activateRange.lowerBound < bodyRange.lowerBound)
}

@Test
func appShellUiSourceContractsCoverPlanUiRemediations() throws {
    let transport = try readAppShellSource("Sources/open-lola-app/AppTransportView.swift")
    let execution = try readAppShellSource("Sources/open-lola-app/AppExecutionView.swift")
    let packetMonitor = try readAppShellSource("Sources/open-lola-app/AppPacketMonitorView.swift")
    let preview = try readAppShellSource("Sources/open-lola-app/AppPreviewReceiverView.swift")
    let chrome = try readAppShellSource("Sources/open-lola-app/AppConsoleChromeView.swift")
    let root = try readAppShellSource("Sources/open-lola-app/AppShellRootView.swift")
    let support = try readAppShellSource("Sources/open-lola-app/AppShellSupportViews.swift")
    let topology = try readAppShellSource("Sources/open-lola-app/AppConnectionTopologyView.swift")
    let banner = try readAppShellSource("Sources/open-lola-app/AppSessionStateBanner.swift")
    let app = try readAppShellSource("Sources/open-lola-app/OpenLolaApp.swift")
    let design = try readAppShellSource("Sources/open-lola-app/AppDesignSystem.swift")

    #expect(transport.contains("AppDesignSystem.onStateFillText"))
    #expect(transport.contains(".disabled(!executionController.isRunning)"))
    #expect(execution.contains("AppCommandPreview.multilineDisplay"))
    #expect(execution.contains("AppExecutionErrorLogView(errors: executionController.errorLog)"))
    #expect(execution.contains("executionController.openLogFile(executionController.stdoutPath)"))
    #expect(execution.contains(".disabled(!executionController.canOpenLogFile(executionController.stdoutPath))"))
    #expect(execution.contains("AppReadableMetric(label: \"Plan\""))
    #expect(execution.contains("AppReadableMetric(label: \"Stdout\""))
    #expect(!execution.contains("NSWorkspace.shared.open"))
    #expect(!execution.contains("@State private var searchText"))
    #expect(packetMonitor.contains("Table(rows)"))
    #expect(packetMonitor.contains("Packet Row Error"))
    #expect(packetMonitor.contains("copyToPasteboard(row.accessibilityLabel)"))
    #expect(preview.contains("case disabled"))
    #expect(preview.contains("return .disabled"))
    #expect(preview.contains("AppReadableMetric("))
    #expect(!preview.contains("isLiveOrDisabledStatus"))
    #expect(support.contains("struct AppReadableMetric"))
    #expect(support.contains("struct AppReadableValue"))
    #expect(support.contains("ScrollView(.horizontal"))
    #expect(support.contains(".textSelection(.enabled)"))
    #expect(support.contains("copyReadableValueToPasteboard"))
    #expect(topology.contains(".truncationMode(.middle)"))
    #expect(topology.contains(".textSelection(.enabled)"))
    #expect(chrome.contains("let canStopExecution: Bool"))
    #expect(root.contains("canStopExecution: executionController.isRunning"))
    #expect(root.contains("AppReadableMetric(label: \"Status\""))
    #expect(!root.contains(".preferredColorScheme(.dark)"))
    #expect(banner.contains(".frame(minHeight: Layout.bannerMinHeight)"))
    #expect(banner.contains(".truncationMode(.middle)"))
    #expect(app.contains("Window(\"Open LoLa\", id: \"main\")"))
    #expect(app.contains("ForEach(surfaceContract.actions"))
    #expect(design.contains("AppColorEnvironment"))
    #expect(design.contains("accessibilityHighContrast"))
}

@Test
func appShellSettingsTabsAreSplitFromSettingsBindings() throws {
    let settingsView = try readAppShellSource("Sources/open-lola-app/AppShellSettingsView.swift")
    let settingsTabs = try readAppShellSource("Sources/open-lola-app/AppShellSettingsTabs.swift")
    let storedDefaults = try readAppShellSource("Sources/open-lola-app/AppShellStoredDefaults.swift")

    #expect(settingsView.split(separator: "\n", omittingEmptySubsequences: false).count < 500)
    #expect(settingsTabs.contains("struct AppExecutionSettingsTab"))
    #expect(settingsTabs.contains("struct AppWindowsLoLaSettingsTab"))
    #expect(settingsTabs.contains("Picker(\"Audio transport\""))
    #expect(settingsTabs.contains("UInt16Field(\"Control port\""))
    #expect(!settingsView.contains("UInt16(clamping:"))
    #expect(!storedDefaults.contains("UInt16(clamping:"))
    #expect(settingsView.contains("UInt16(exactly: storage.wrappedValue)"))
    #expect(storedDefaults.contains("UInt16(exactly: persistedValue)"))
}

@Test
func appReceiverPreviewAudioMeterPublishesCallbackStateBeforeStartAndKeepsIOProcLockFree() throws {
    let source = try readAppShellSource("Sources/open-lola-app/AppReceiverPreviewServices.swift")
    let startRange = try #require(source.range(of: "status = AudioDeviceStart(selectedDeviceID, createdIOProcID)"))
    let devicePublishRange = try #require(source.range(of: "deviceID = selectedDeviceID"))
    let activePublishRange = try #require(source.range(of: "open_lola_atomic_u64_store(&callbacksActive, 1)"))
    let callbackRange = try #require(source.range(of: "fileprivate func update(from input: UnsafePointer<AudioBufferList>)"))
    let callbackEndRange = try #require(source.range(of: "private func level(for buffer: AudioBuffer)"))
    let callbackBody = source[callbackRange.lowerBound..<callbackEndRange.lowerBound]

    #expect(devicePublishRange.lowerBound < startRange.lowerBound)
    #expect(activePublishRange.lowerBound < startRange.lowerBound)
    #expect(source.contains("open_lola_atomic_u64_store(&callbacksActive, 0)"))
    #expect(source.contains("AudioDeviceDestroyIOProcID(selectedDeviceID, createdIOProcID)"))
    #expect(!callbackBody.contains("os_unfair_lock_lock"))
    #expect(!callbackBody.contains("Array("))
    #expect(callbackBody.contains("open_lola_atomic_u64_load(&callbacksActive)"))
    #expect(callbackBody.contains("storeLevel(level, at: index)"))
}

private func readAppShellSource(_ relativePath: String) throws -> String {
    let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    return try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
}
