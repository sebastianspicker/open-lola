// Writes optional, offline-only Quiet shell PNGs for visual review.
import AppKit
import Foundation
import OpenLolaCore
import SwiftUI
import XCTest
@testable import OpenLolaAppSupport

@MainActor
final class AppQuietShellScreenshotTests: XCTestCase {
    func testRenderQuietShellScreenshotsWhenExplicitlyRequested() throws {
        guard let outputDirectory = try screenshotOutputDirectory() else {
            throw XCTSkip("Set OPEN_LOLA_UI_RENDER_DIR to render synthetic offline UI screenshots.")
        }

        try render(
            name: "quiet-1440x940-light-check",
            size: CGSize(width: 1440, height: 940),
            scheme: .light,
            section: .session,
            phase: .ready,
            report: NativeAppShellSyntheticSmoke.placeholder(),
            outputDirectory: outputDirectory
        )
        try render(
            name: "quiet-1440x940-dark-run",
            size: CGSize(width: 1440, height: 940),
            scheme: .dark,
            section: .session,
            phase: .live,
            report: NativeAppShellSyntheticSmoke.run(),
            outputDirectory: outputDirectory
        )
        try render(
            name: "quiet-1440x940-dark-review",
            size: CGSize(width: 1440, height: 940),
            scheme: .dark,
            section: .session,
            phase: .review,
            report: NativeAppShellSyntheticSmoke.run(),
            outputDirectory: outputDirectory
        )
        try render(
            name: "quiet-1024x768-light-devices-configure",
            size: CGSize(width: 1024, height: 768),
            scheme: .light,
            section: .devices,
            phase: .setup,
            report: NativeAppShellSyntheticSmoke.placeholder(),
            outputDirectory: outputDirectory
        )
        try render(
            name: "quiet-1024x768-light-check",
            size: CGSize(width: 1024, height: 768),
            scheme: .light,
            section: .session,
            phase: .ready,
            report: NativeAppShellSyntheticSmoke.placeholder(),
            outputDirectory: outputDirectory
        )
        try render(
            name: "quiet-1024x768-dark-devices-configure",
            size: CGSize(width: 1024, height: 768),
            scheme: .dark,
            section: .devices,
            phase: .setup,
            report: NativeAppShellSyntheticSmoke.placeholder(),
            outputDirectory: outputDirectory
        )
    }

    private func render(
        name: String,
        size: CGSize,
        scheme: ColorScheme,
        section: NativeAppShellSurfaceSectionID,
        phase: AppSessionPhase,
        report: NativeAppShellReport,
        outputDirectory: URL
    ) throws {
        _ = NSApplication.shared
        let fixture = QuietShellFixture(review: phase == .review)
        defer { fixture.removeDefaults() }
        let root = AppShellRootView(
            report: report,
            operatorSurface: fixture.surfaceBinding,
            dependencies: fixture.dependencies,
            initialSelectedSection: section,
            initialPhase: phase
        )
        .environment(\.appDocumentationRendering, true)
        .defaultAppStorage(fixture.defaults)
        .preferredColorScheme(scheme)
        .frame(width: size.width, height: size.height)

        let appearance = NSAppearance(named: scheme == .dark ? .darkAqua : .aqua)
        let hostingView = NSHostingView(rootView: root)
        hostingView.frame = NSRect(origin: .zero, size: size)
        hostingView.appearance = appearance
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        window.appearance = appearance
        window.isReleasedWhenClosed = false
        window.contentView = hostingView
        defer {
            window.contentView = nil
            window.close()
        }
        window.layoutIfNeeded()
        hostingView.layoutSubtreeIfNeeded()
        RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        guard let image = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(size.width),
            pixelsHigh: Int(size.height),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            throw ScreenshotError.unavailableImage(name)
        }
        hostingView.cacheDisplay(in: hostingView.bounds, to: image)
        guard let data = image.representation(
            using: .png,
            properties: [:]
        ) else {
            throw ScreenshotError.unavailablePNG(name)
        }
        let output = outputDirectory.appendingPathComponent("\(name).png")
        try data.write(to: output, options: .atomic)
        print("SYNTHETIC_OFFLINE_UI_RENDER: \(output.path)")
    }
}

@MainActor
private final class QuietShellFixture {
    let defaults: UserDefaults
    private let suiteName = "org.openlola.tests.quiet-shell.\(UUID().uuidString)"
    private var surface = configuredOfflineSurface()
    let dependencies: AppShellRootDependencies

    init(review: Bool) {
        defaults = UserDefaults(suiteName: suiteName)!
        let previewState = AppPreviewReceiverState(
            audioPreviewEnabled: false,
            videoPreviewEnabled: false,
            showSafeFrame: false
        )
        previewState.previewPhase = .disabled
        let executionController = AppExecutionController()
        if review {
            executionController.phase = .runFinished
            executionController.lastExitCode = 0
            executionController.status = "Synthetic offline completion; runtime evidence remains partial."
        }
        dependencies = AppShellRootDependencies(
            executionController: executionController,
            previewState: previewState,
            inventoryController: AppLocalOperatorInventoryController(),
            appSettings: AppSettings(defaults: defaults),
            contract: .releaseReadiness,
            syntheticMetricsRefreshState: .idle,
            refreshReport: {},
            refreshInventory: {}
        )
    }

    func removeDefaults() {
        defaults.removePersistentDomain(forName: suiteName)
    }

    var surfaceBinding: Binding<NativeAppShellOperatorPrototypeState> {
        Binding(get: { self.surface }, set: { self.surface = $0 })
    }
}

private enum ScreenshotError: LocalizedError {
    case unavailableImage(String)
    case unavailablePNG(String)
    case invalidOutputDirectory(String)

    var errorDescription: String? {
        switch self {
        case .unavailableImage(let name):
            "Could not render synthetic offline screenshot: \(name)"
        case .unavailablePNG(let name):
            "Could not encode synthetic offline screenshot: \(name)"
        case .invalidOutputDirectory(let path):
            "OPEN_LOLA_UI_RENDER_DIR must be an absolute directory outside this repository: \(path)"
        }
    }
}

private func screenshotOutputDirectory() throws -> URL? {
    guard let rawPath = ProcessInfo.processInfo.environment["OPEN_LOLA_UI_RENDER_DIR"],
          !rawPath.isEmpty else {
        return nil
    }
    guard rawPath.hasPrefix("/") else {
        throw ScreenshotError.invalidOutputDirectory(rawPath)
    }
    let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .resolvingSymlinksInPath()
        .standardizedFileURL
    let output = URL(fileURLWithPath: rawPath, isDirectory: true)
        .resolvingSymlinksInPath()
        .standardizedFileURL
    let rootPath = root.path.hasSuffix("/") ? root.path : root.path + "/"
    guard output.path != root.path, !output.path.hasPrefix(rootPath) else {
        throw ScreenshotError.invalidOutputDirectory(rawPath)
    }
    try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
    return output
}
