// Adds deterministic AppKit rendering coverage for previously unhosted operator views.
import AppKit
import Foundation
import SwiftUI
import Testing

@testable import OpenLolaAppSupport
@testable import OpenLolaCore

@MainActor
struct AppHotspotWave16Tests {
    private static let renderSize = CGSize(width: 1_080, height: 760)

    @Test
    func wave16AppOverviewRendersValidatedRuntimeEvidence() throws {
        let controller = AppExecutionController()
        let metrics = try #require(AppLatencyHeroMetrics.make(from: [
            appMeasuredPassDirectPeerSessionReport(id: "wave16-validated", peerID: "peer-a")
        ]))

        renderOverview(
            controller: controller,
            metrics: metrics,
            validated: true,
            named: "overview-validated"
        )
    }

    @Test
    func wave16AppOverviewRendersLoadedButUnvalidatedEvidence() throws {
        let controller = AppExecutionController()
        let metrics = try #require(AppLatencyHeroMetrics.make(
            from: [],
            expectedPeerReportCount: 1,
            loadFailures: ["peer-a report unavailable"],
            supervisorVerdict: .partial
        ))

        renderOverview(
            controller: controller,
            metrics: metrics,
            validated: false,
            named: "overview-unvalidated"
        )
    }

    @Test
    func wave16AppOverviewStatusStripRendersEverySyntheticItem() {
        render(
            AppOverviewStatusStrip(items: [
                .init(id: "phase", title: "Phase", value: "Ready", systemImage: "checkmark.circle"),
                .init(id: "route", title: "Route", value: "Direct peer", systemImage: "arrow.left.and.right"),
                .init(id: "evidence", title: "Evidence", value: "Synthetic", systemImage: "doc.text")
            ])
            .padding(),
            named: "overview-status-strip"
        )
    }

    @Test
    func wave16AppOverviewActionAndEvidencePanelsRender() {
        let action = AppOverviewNextAction(
            title: "Review synthetic routing",
            detail: "This deterministic render does not initiate a route check.",
            targetSection: .routing,
            systemImage: "point.3.connected.trianglepath.dotted"
        )
        let summary = AppOverviewEvidenceSummary(
            sourceVerdict: "PARTIAL",
            runtimeEvidence: "Synthetic render only",
            latestReportPath: "/tmp/open-lola-wave16-report.json",
            freshness: "not live"
        )
        var requestedSection: NativeAppShellSurfaceSectionID?

        render(
            AppOverviewActionEvidenceLayout(
                action: action,
                evidenceSummary: summary,
                navigateToSection: { requestedSection = $0 }
            )
            .padding(),
            named: "overview-action-evidence"
        )
        #expect(requestedSection == nil)
    }

    @Test
    func wave16AppOverviewNextActionLabelsCoverEverySectionMapping() {
        let expected: [(NativeAppShellSurfaceSectionID, String)] = [
            (.overview, "Open Session"),
            (.session, "Open Session"),
            (.streams, "Open Media"),
            (.routing, "Open Routing"),
            (.devices, "Open Connection"),
            (.diagnostics, "Open Diagnostics"),
            (.validation, "Review Evidence"),
            (.packetMonitor, "Open Packets"),
            (.settings, "Open Settings")
        ]

        for (section, label) in expected {
            let action = AppOverviewNextAction(
                title: "Synthetic action",
                detail: "No action is invoked while hosting.",
                targetSection: section,
                systemImage: "arrow.right.circle"
            )
            #expect(action.targetSectionLabel == label)
            render(AppOverviewNextActionPanel(action: action, navigateToSection: { _ in }).padding(), named: label)
        }
    }

    @Test
    func wave16AppReportsRendersDirectPeerReportAndSessionDetails() {
        let controller = AppExecutionController()
        controller.lastReport = executionReport(id: "wave16-direct")
        render(
            AppReportsView(plan: plan(mode: .directMacPeer), executionController: controller).padding(),
            named: "reports-direct-peer"
        )
    }

    @Test
    func wave16AppReportsRendersWindowsLoLaLoadedEvidence() throws {
        let controller = AppExecutionController()
        controller.lastExternalConnectorReport = try appExternalConnectorSessionReport(
            verdict: .partial,
            outputPath: "/tmp/open-lola-wave16-windows.json"
        )
        render(
            AppReportsView(plan: plan(mode: .windowsLoLa), executionController: controller).padding(),
            named: "reports-windows-lola"
        )
    }

    @Test
    func wave16AppReportsRendersExternalConnectorWithoutLoadedReport() {
        render(
            AppReportsView(plan: plan(mode: .jackTrip), executionController: AppExecutionController()).padding(),
            named: "reports-external-connector-unavailable"
        )
    }

    @Test
    func wave16AppReportsRendersUnavailableSessionDetails() {
        render(
            AppReportsView(plan: plan(mode: .ultraGrid), executionController: AppExecutionController()).padding(),
            named: "reports-unavailable-session-details"
        )
    }

    @Test
    func wave16AppExecutionErrorLogRendersEmptyState() {
        render(AppExecutionErrorLogView(errors: []).padding(), named: "errors-empty")
    }

    @Test
    func wave16AppExecutionErrorLogRendersPopulatedState() {
        render(
            AppExecutionErrorLogView(errors: ["Synthetic failure one", "Synthetic failure two"]).padding(),
            named: "errors-populated"
        )
    }

    @Test
    func wave16AppLogsRendersEmptyState() {
        let controller = AppExecutionController()
        controller.lastCommand = []
        render(AppLogsView(executionController: controller).padding(), named: "logs-empty")
    }

    @Test
    func wave16AppLogsRendersPopulatedErrorAndCommandState() {
        let controller = AppExecutionController()
        controller.errorLog = ["Synthetic diagnostic"]
        controller.lastCommand = ["open-lola", "--synthetic", "wave16"]
        controller.lastError = "Synthetic error"
        controller.previousRunEvidence = [snapshot(1)]
        render(AppLogsView(executionController: controller).padding(), named: "logs-populated")
    }

    @Test
    func wave16AppPreviousRunEvidenceRendersOneSnapshot() {
        render(AppPreviousRunEvidenceView(snapshots: [snapshot(1)]).padding(), named: "previous-run-one")
    }

    @Test
    func wave16AppPreviousRunEvidenceRendersTwoSnapshots() {
        render(
            AppPreviousRunEvidenceView(snapshots: [snapshot(1), snapshot(2)]).padding(),
            named: "previous-run-two"
        )
    }

    @Test
    func wave16AppPreviousRunEvidenceRendersThreeSnapshots() {
        render(
            AppPreviousRunEvidenceView(snapshots: [snapshot(1), snapshot(2), snapshot(3)]).padding(),
            named: "previous-run-three"
        )
    }

    @Test
    func wave16AppReceiverWindowRendersDisabledWithoutDevices() {
        var surface = appOperatorState(remoteSelectionComplete: true)
        surface.inventory.selection = .init(audioInputUID: nil, audioOutputUID: nil, videoDeviceID: nil)
        let preview = AppPreviewReceiverState(audioPreviewEnabled: false, videoPreviewEnabled: false)

        render(
            AppReceiverWindowView(
                operatorSurface: Binding(get: { surface }, set: { surface = $0 }),
                previewState: preview,
                executionPhase: .idle
            ),
            named: "receiver-disabled-no-device"
        )
    }

    @Test
    func wave16AppReceiverWindowRendersEnabledWithMissingVideoDevice() {
        var surface = appOperatorState(remoteSelectionComplete: true)
        surface.inventory.selection = .init(audioInputUID: nil, audioOutputUID: nil, videoDeviceID: "missing-wave16-camera")
        let preview = AppPreviewReceiverState(audioPreviewEnabled: false, videoPreviewEnabled: true)

        render(
            AppReceiverWindowView(
                operatorSurface: Binding(get: { surface }, set: { surface = $0 }),
                previewState: preview,
                executionPhase: .runFinished
            ),
            named: "receiver-enabled-missing-device"
        )
    }

    @Test
    func wave16AppVideoOutputStatusUsesConstructedPhysicalEvidence() {
        let device = videoDevice(label: "Blackmagic Studio Camera", manufacturer: "Blackmagic Design")
        let status = AppPreviewVideoOutputStatusPolicy.status(
            boundary: boundary(hasPhysicalOutput: true),
            selectedVideoDevice: device
        )
        #expect(status == "DeckLink output hardware evidence present.")
    }

    @Test
    func wave16AppVideoOutputStatusMarksUnverifiedBlackmagicWithoutDetectingHardware() {
        let device = videoDevice(label: "Blackmagic Studio Camera", manufacturer: "Blackmagic Design")
        let status = AppPreviewVideoOutputStatusPolicy.status(
            boundary: boundary(hasPhysicalOutput: false),
            selectedVideoDevice: device
        )
        #expect(status.contains("Blackmagic video device selected"))
        #expect(status.contains("unverified"))
    }

    @Test
    func wave16AppVideoOutputStatusKeepsFallbackForMissingOrNonBlackmagicDevice() {
        let boundary = boundary(hasPhysicalOutput: false)
        #expect(
            AppPreviewVideoOutputStatusPolicy.status(boundary: boundary, selectedVideoDevice: nil)
                == boundary.outputLimitationSummary
        )
        #expect(
            AppPreviewVideoOutputStatusPolicy.status(
                boundary: boundary,
                selectedVideoDevice: videoDevice(label: "USB Camera", manufacturer: "Example")
            ) == boundary.outputLimitationSummary
        )
    }

    private func renderOverview(
        controller: AppExecutionController,
        metrics: AppLatencyHeroMetrics,
        validated: Bool,
        named: String
    ) {
        let surface = appOperatorState(remoteSelectionComplete: true)
        render(
            AppOverviewSectionView(
                report: NativeAppShellSyntheticSmoke.run(),
                operatorPlan: AppOperatorPrototypePlan.make(operatorSurface: surface),
                executionController: controller,
                latencyMetrics: metrics,
                hasValidatedRuntimeEvidence: validated,
                sessionState: validated ? .validated : .awaitingEvidence,
                captureReport: nil,
                navigateToSection: { _ in }
            )
            .padding(),
            named: named
        )
    }

    private func plan(mode: NativeAppShellSessionMode) -> AppOperatorPrototypePlan {
        var surface = appOperatorState(remoteSelectionComplete: true)
        surface.sessionMode = mode
        surface.windowsLoLaPeerFields.outputPath = "/tmp/open-lola-wave16-windows.json"
        surface.jackTripPeerFields.outputPath = "/tmp/open-lola-wave16-jacktrip.json"
        surface.ultraGridPeerFields.outputPath = "/tmp/open-lola-wave16-ultragrid.json"
        return AppOperatorPrototypePlan.make(operatorSurface: surface)
    }

    private func executionReport(id: String) -> NativeAppShellExecutionReport {
        NativeAppShellExecutionReport(
            lifecycle: .init(
                id: id,
                command: ["open-lola", "--synthetic", id],
                startedAt: "2026-08-05T12:00:00Z",
                finishedAt: "2026-08-05T12:00:01Z",
                exitCode: 0
            ),
            artifacts: .init(
                stdoutPath: "/tmp/open-lola-wave16-stdout.log",
                stderrPath: "/tmp/open-lola-wave16-stderr.log"
            ),
            validation: .init(command: ["open-lola", "validate"], exitCode: 0),
            outcome: .init(verdict: .pass, notes: "Synthetic rendering report.")
        )
    }

    private func snapshot(_ index: Int) -> AppRunEvidenceSnapshot {
        AppRunEvidenceSnapshot(
            id: UUID(),
            capturedAt: "2026-08-05T12:00:0\(index)Z",
            status: "Synthetic run \(index)",
            phase: .runFinished,
            commandLine: "open-lola --synthetic \(index)",
            exitCode: index,
            validationExitCode: 0,
            validationResult: .passed,
            lastError: index == 3 ? "Synthetic preserved error" : nil,
            errorCount: index,
            latencySummary: "\(index) ms audio latency",
            captureSummary: "synthetic capture",
            externalConnectorSummary: "partial",
            stdoutPath: "/tmp/open-lola-wave16-\(index)-stdout.log",
            stderrPath: "/tmp/open-lola-wave16-\(index)-stderr.log"
        )
    }

    private func videoDevice(label: String, manufacturer: String) -> NativeAppShellVideoDeviceOption {
        .init(
            label: label,
            uniqueId: "wave16-\(label.lowercased().replacingOccurrences(of: " ", with: "-"))",
            manufacturer: manufacturer,
            transport: "synthetic",
            sourcePolicy: .genericAvFoundation,
            formatCount: 1
        )
    }

    private func boundary(hasPhysicalOutput: Bool) -> BlackmagicOutputBoundaryReport {
        .init(
            backend: hasPhysicalOutput ? .blackmagicDeckLink : .localPreview,
            desktopVideoSDK: hasPhysicalOutput ? .linkedDeviceAvailable : .notLinked,
            compileTimeAvailable: hasPhysicalOutput,
            runtimeAvailable: hasPhysicalOutput,
            hardwareDetected: hasPhysicalOutput,
            notes: "Synthetic wave16 boundary report."
        )
    }

    private func render<Content: View>(_ content: Content, named name: String) {
        let hostingView = NSHostingView(rootView: content)
        hostingView.frame = CGRect(origin: .zero, size: Self.renderSize)
        hostingView.appearance = NSAppearance(named: .aqua)
        let window = NSWindow(
            contentRect: hostingView.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.appearance = hostingView.appearance
        window.contentView = hostingView
        defer {
            window.contentView = nil
            window.orderOut(nil)
        }

        hostingView.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
        hostingView.layoutSubtreeIfNeeded()
        hostingView.displayIfNeeded()

        #expect(hostingView.bounds.width > 0, "\(name) must receive a nonzero host width.")
        #expect(hostingView.bounds.height > 0, "\(name) must receive a nonzero host height.")
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(Self.renderSize.width),
            pixelsHigh: Int(Self.renderSize.height),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            Issue.record("\(name) could not allocate a local render bitmap.")
            return
        }
        hostingView.cacheDisplay(in: hostingView.bounds, to: bitmap)
        #expect(bitmap.pixelsWide > 0, "\(name) must produce a local render cache.")
        #expect(bitmap.pixelsHigh > 0, "\(name) must produce a local render cache.")
    }
}
