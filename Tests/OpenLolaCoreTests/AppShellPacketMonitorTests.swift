// Verifies that app packet monitor selection allows truthful empty evidence state.
import Testing

@testable import OpenLolaAppSupport
@testable import OpenLolaCore

@Test
func appPacketMonitorSelectionAllowsTruthfulEmptyEvidenceState() {
    let sections = NativeAppShellSurfaceContract.releaseReadiness.sections
    let packetOnly = NativeAppShellSectionSearch.visibleSections(sections, query: "packet")

    #expect(AppConsoleSectionSelection.activeSection(
        current: .packetMonitor,
        visibleSections: sections,
        sessionState: .ready,
        captureReportAvailable: false
    ) == .packetMonitor)
    #expect(AppConsoleSectionSelection.resolvedSection(
        current: .packetMonitor,
        visibleSections: sections,
        sessionState: .ready,
        captureReportAvailable: false
    ) == .packetMonitor)
    #expect(AppConsoleSectionSelection.resolvedSection(
        current: .packetMonitor,
        visibleSections: packetOnly,
        sessionState: .ready,
        captureReportAvailable: false
    ) == .packetMonitor)
    #expect(AppPacketMonitorSidebarPolicy.disabledReason(sessionState: .ready) == nil)
    #expect(AppPacketMonitorSidebarPolicy.dimmedReason(
        sessionState: .ready,
        captureReportAvailable: false
    )?.contains("No capture yet") == true)
    #expect(AppConsoleSectionSelection.activeSection(
        current: .packetMonitor,
        visibleSections: sections,
        sessionState: .unconfigured,
        captureReportAvailable: false
    ) == .packetMonitor)
    #expect(AppConsoleSectionSelection.activeSection(
        current: .packetMonitor,
        visibleSections: sections,
        sessionState: .ready,
        captureReportAvailable: true
    ) == .packetMonitor)
}

@Test
func appPacketMonitorRowDetailsExposeFullSelectableRowValues() {
    let longSource = "mac-studio-control-room-with-long-hostname.example.local"
    let longDestination = "windows-lola-peer-with-long-hostname.example.local"
    let row = NativeAppPacketMonitorRow(packet: LoLaCompatibilityCapturePacketReport(
        index: 42,
        capturedLength: 1_280,
        originalLength: 1_280,
        stream: .video,
        network: .init(
            sourceIP: longSource,
            destinationIP: longDestination,
            sourcePort: 5_000,
            destinationPort: 5_002,
            payloadLength: 1_024
        ),
        media: .init(envelopeValid: true, payloadCandidate: .videoFragment)
    ))

    #expect(AppPacketMonitorRowDetailState.selectedRow(rows: [row], selectedID: 42) == row)
    #expect(AppPacketMonitorRowDetailState.selectedRow(rows: [row], selectedID: 99) == nil)
    #expect(AppPacketMonitorRowDetailState.selectedRow(rows: [row], selectedID: nil) == nil)

    let copyText = AppPacketMonitorRowDetailState.copyText(row)
    #expect(copyText.contains("Packet 42"))
    #expect(copyText.contains(longSource))
    #expect(copyText.contains(longDestination))
    #expect(copyText.contains("videoFragment"))
}

@Test
func appPacketMonitorAndSectionSelectionKeepUnavailableViewsInactive() {
    let emptyReport = appEmptyCaptureReport(capturedAt: "2026-05-14T00:00:00Z")
    expectPacketMonitorRowsUnavailable(emptyReport)
    expectUnavailablePacketMonitorSectionSelection()
    expectPacketMonitorSidebarAvailability()
    expectPacketMonitorUnavailableCopy()
}

func appEmptyCaptureReport(capturedAt: String) -> LoLaCompatibilityCaptureReport {
    LoLaCompatibilityCaptureReport(
        identity: .init(
            id: "empty-capture",
            title: "Empty capture",
            capturedAt: capturedAt,
            inputPath: "fixtures/empty.pcapng",
            inputFormat: .pcapng
        ),
        content: .init(summary: LoLaCompatibilityCaptureSummary(packets: []), packets: []),
        outcome: .init(
            verdict: .partial,
            evidenceBoundary: "unit-test packet monitor",
            notes: "empty capture"
        )
    )
}

private func expectPacketMonitorRowsUnavailable(_ emptyReport: LoLaCompatibilityCaptureReport) {
    #expect(AppPacketMonitorRowsState.make(
        report: emptyReport,
        streamFilter: .all,
        searchText: "no-match"
    ) == .rows([]))

    let failureState = AppPacketMonitorRowsState.make(
        report: emptyReport,
        streamFilter: .all,
        searchText: "",
        limit: -1
    )
    guard case .failure(let message) = failureState else {
        Issue.record("Expected row-building failure state")
        return
    }
    #expect(message.contains("negativeLimit"))
}

private func expectUnavailablePacketMonitorSectionSelection() {
    let sections = NativeAppShellSurfaceContract.releaseReadiness.sections
    let settingsOnly = NativeAppShellSectionSearch.visibleSections(sections, query: "settings")
    let packetOnly = NativeAppShellSectionSearch.visibleSections(sections, query: "packet")

    #expect(AppConsoleSectionSelection.resolvedSection(
        current: .packetMonitor,
        visibleSections: settingsOnly,
        sessionState: .supervisorRunning,
        captureReportAvailable: true
    ) == .settings)
    #expect(AppConsoleSectionSelection.resolvedSection(
        current: .packetMonitor,
        visibleSections: sections,
        sessionState: .unconfigured,
        captureReportAvailable: true
    ) == .packetMonitor)
    #expect(AppConsoleSectionSelection.resolvedSection(
        current: .packetMonitor,
        visibleSections: sections,
        sessionState: .ready,
        captureReportAvailable: false
    ) == .packetMonitor)
    #expect(AppConsoleSectionSelection.activeSection(
        current: .packetMonitor,
        visibleSections: packetOnly,
        sessionState: .unconfigured,
        captureReportAvailable: true
    ) == .packetMonitor)
    #expect(AppConsoleSectionSelection.resolvedSection(
        current: .packetMonitor,
        visibleSections: packetOnly,
        sessionState: .unconfigured,
        captureReportAvailable: true
    ) == .packetMonitor)
}

private func expectPacketMonitorSidebarAvailability() {
    #expect(AppPacketMonitorSidebarPolicy.disabledReason(sessionState: .unconfigured) == nil)
    #expect(AppPacketMonitorSidebarPolicy.dimmedReason(
        sessionState: .ready,
        captureReportAvailable: false
    ) == AppPacketMonitorSidebarPolicy.missingCaptureHelp)
    #expect(AppPacketMonitorSidebarPolicy.missingCaptureHelp.contains("No capture yet"))
    #expect(AppPacketMonitorSidebarPolicy.disabledReason(sessionState: .ready) == nil)
    #expect(AppPacketMonitorSidebarPolicy.dimmedReason(
        sessionState: .ready,
        captureReportAvailable: true
    ) == nil)
}

private func expectPacketMonitorUnavailableCopy() {
    #expect(AppUnavailableSectionCopy.detail(
        searchText: "packet",
        sessionState: .ready,
        captureReportAvailable: false
    ).contains("No capture yet"))
    #expect(!AppUnavailableSectionCopy.detail(
        searchText: "packet",
        sessionState: .ready,
        captureReportAvailable: false
    ).contains("unavailable"))
}
