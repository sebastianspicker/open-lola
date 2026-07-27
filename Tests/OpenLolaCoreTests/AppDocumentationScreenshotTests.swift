// Verifies that the current signal desk renders in light and dark modes.
import AppKit
import Foundation
import ImageIO
import SwiftUI
import Testing

@testable import OpenLolaAppSupport
@testable import OpenLolaCore

@MainActor
@Suite(.serialized)
struct AppDocumentationScreenshotTests {
    private static let imageSize = CGSize(width: 1_586, height: 992)
    private static let pngSignature = Data([137, 80, 78, 71, 13, 10, 26, 10])

    @Test
    func renderCurrentSignalDeskInLightAndDarkModes() throws {
        let lightPNG = try renderSignalDesk(colorScheme: .light, section: .session)
        let darkPNG = try renderSignalDesk(colorScheme: .dark, section: .session)

        try assertMeaningfulPNG(lightPNG)
        try assertMeaningfulPNG(darkPNG)
        #expect(lightPNG != darkPNG, "Light and dark documentation renders must be visually distinct.")
        try writeDocumentationPNGsIfRequested(lightPNG: lightPNG, darkPNG: darkPNG)
    }

    @Test
    func renderEveryWorkspaceInLightMode() throws {
        for section in AppSignalDeskNavigationPolicy.visibleSectionIDs {
            let png = try renderSignalDesk(colorScheme: .light, section: section)
            try assertMeaningfulPNG(png)
        }
    }

    private func renderSignalDesk(
        colorScheme: ColorScheme,
        section: NativeAppShellSurfaceSectionID
    ) throws -> Data {
        let suiteName = "open-lola-doc-screenshot-\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            throw ScreenshotError.defaultsUnavailable
        }
        defer { defaults.removePersistentDomain(forName: suiteName) }
        return try renderPNG(
            rootView: signalDeskRoot(defaults: defaults, colorScheme: colorScheme, section: section),
            colorScheme: colorScheme
        )
    }

    private func signalDeskRoot(
        defaults: UserDefaults,
        colorScheme: ColorScheme,
        section: NativeAppShellSurfaceSectionID
    ) -> some View {
        let controller = AppExecutionController()
        controller.settings.supervisorReportPath = "/private/tmp/open-lola-docs/supervisor-report.json"
        seedValidatedRuntimeEvidence(controller)
        controller.lastLatencyMetrics = AppLatencyHeroMetrics(
            audioLatencyMs: 4.7,
            packetLossPercent: 0,
            jitterMs: 0.3,
            expectedPeerReportCount: 2,
            loadedPeerReportCount: 2,
            loadFailures: [],
            peerReportFailures: [],
            supervisorVerdict: .pass
        )
        controller.lastCaptureReport = lolaCompatibilityCaptureReportForAppShell()
        controller.status = "Recorded synthetic fixture. Not live evidence."
        let previewState = AppPreviewReceiverState(
            audioPreviewEnabled: true,
            videoPreviewEnabled: true,
            showSafeFrame: true,
            monitorGain: 0.65,
            remoteReturnBlend: 0.25,
            videoScale: 1,
            visibleStreams: 1,
            selectedVideoStream: 101
        )
        previewState.previewPhase = .active
        previewState.receiverStatus = "Synthetic preview state for documentation capture."

        let dependencies = AppShellRootDependencies(
            executionController: controller,
            previewState: previewState,
            inventoryController: AppLocalOperatorInventoryController(),
            appSettings: AppSettings(defaults: defaults),
            contract: .releaseReadiness,
            syntheticMetricsRefreshState: .idle,
            refreshReport: {},
            refreshInventory: {}
        )
        let rootView = AppShellRootView(
            report: NativeAppShellSyntheticSmoke.run(),
            operatorSurface: .constant(appOperatorState(remoteSelectionComplete: true)),
            dependencies: dependencies,
            initialSelectedSection: section,
            initiallyPresentsEvidenceInspector: true
        )
        return rootView
            .frame(width: Self.imageSize.width, height: Self.imageSize.height)
            .environment(\.colorScheme, colorScheme)
            .environment(\.appDocumentationRendering, true)
    }

    private func renderPNG<Content: View>(
        rootView: Content,
        colorScheme: ColorScheme
    ) throws -> Data {
        let hostingView = NSHostingView(rootView: rootView)
        hostingView.frame = CGRect(origin: .zero, size: Self.imageSize)
        hostingView.appearance = NSAppearance(
            named: colorScheme == .dark ? .darkAqua : .aqua
        )
        let window = NSWindow(
            contentRect: hostingView.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.appearance = hostingView.appearance
        window.contentView = hostingView
        hostingView.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))
        hostingView.layoutSubtreeIfNeeded()
        hostingView.displayIfNeeded()
        let bitmap = try makeBitmap()
        hostingView.cacheDisplay(in: hostingView.bounds, to: bitmap)
        guard let png = bitmap.representation(using: .png, properties: [:]) else {
            throw ScreenshotError.renderingFailed
        }
        return png
    }

    private func makeBitmap() throws -> NSBitmapImageRep {
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(Self.imageSize.width),
            pixelsHigh: Int(Self.imageSize.height),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            throw ScreenshotError.renderingFailed
        }
        bitmap.size = Self.imageSize
        return bitmap
    }

    private func assertMeaningfulPNG(_ data: Data) throws {
        #expect(data.starts(with: Self.pngSignature))
        #expect(data.count > 1_024, "Rendered screenshot must contain meaningful PNG data.")
        let image = try decodeScreenshot(data)
        #expect(image.width == Int(Self.imageSize.width))
        #expect(image.height == Int(Self.imageSize.height))
        let pixels = try renderPixels(image)
        let analysis = analyzePixels(pixels, width: image.width, height: image.height)
        #expect(analysis.sampledColorCount > 32, "Rendered screenshot must contain meaningful visual structure.")
        if analysis.yellowPixels > analysis.pixelCount / 2,
           analysis.redPixels > analysis.pixelCount / 20 {
            throw ScreenshotError.unsupportedRenderPlaceholder
        }
        if analysis.structuredUpperPixels < analysis.pixelCount / 20 {
            throw ScreenshotError.incompleteRender
        }
    }

    private func decodeScreenshot(_ data: Data) throws -> ScreenshotImage {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int,
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw ScreenshotError.invalidPNG
        }
        return ScreenshotImage(image: image, width: width, height: height)
    }

    private func renderPixels(_ screenshot: ScreenshotImage) throws -> [UInt8] {
        var pixels = [UInt8](repeating: 0, count: screenshot.width * screenshot.height * 4)
        guard let context = CGContext(
            data: &pixels,
            width: screenshot.width,
            height: screenshot.height,
            bitsPerComponent: 8,
            bytesPerRow: screenshot.width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw ScreenshotError.invalidPNG
        }
        context.draw(
            screenshot.image,
            in: CGRect(x: 0, y: 0, width: screenshot.width, height: screenshot.height)
        )
        return pixels
    }

    private func analyzePixels(
        _ pixels: [UInt8],
        width: Int,
        height: Int
    ) -> ScreenshotPixelAnalysis {
        var yellowPixels = 0
        var redPixels = 0
        var structuredUpperPixels = 0
        var sampledColors = Set<UInt32>()
        for index in stride(from: 0, to: pixels.count, by: 4) {
            let red = pixels[index]
            let green = pixels[index + 1]
            let blue = pixels[index + 2]
            if red > 240, green > 150, green < 230, blue < 80 { yellowPixels += 1 }
            if red > 230, green < 110, blue < 130 { redPixels += 1 }
            let pixelIndex = index / 4
            if pixelIndex / width < height / 2, Int(red) + Int(green) + Int(blue) > 90 {
                structuredUpperPixels += 1
            }
            if index % 64 == 0 {
                sampledColors.insert(UInt32(red) << 16 | UInt32(green) << 8 | UInt32(blue))
            }
        }
        return ScreenshotPixelAnalysis(
            pixelCount: width * height,
            yellowPixels: yellowPixels,
            redPixels: redPixels,
            structuredUpperPixels: structuredUpperPixels,
            sampledColorCount: sampledColors.count
        )
    }

    private func writeDocumentationPNGsIfRequested(lightPNG: Data, darkPNG: Data) throws {
        guard let outputPath = ProcessInfo.processInfo.environment["OPEN_LOLA_DOC_SCREENSHOT_DIR"],
              !outputPath.isEmpty else {
            return
        }
        let directory = URL(fileURLWithPath: outputPath, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try lightPNG.write(to: directory.appendingPathComponent("open-lola-signal-desk-light.png"), options: .atomic)
        try darkPNG.write(to: directory.appendingPathComponent("open-lola-signal-desk-dark.png"), options: .atomic)
    }

}

private struct ScreenshotImage {
    var image: CGImage
    var width: Int
    var height: Int
}

private struct ScreenshotPixelAnalysis {
    var pixelCount: Int
    var yellowPixels: Int
    var redPixels: Int
    var structuredUpperPixels: Int
    var sampledColorCount: Int
}

private enum ScreenshotError: Error {
    case defaultsUnavailable
    case renderingFailed
    case invalidPNG
    case unsupportedRenderPlaceholder
    case incompleteRender
}
