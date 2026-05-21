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
    ) == nil)
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
        sourceIP: longSource,
        destinationIP: longDestination,
        sourcePort: 5_000,
        destinationPort: 5_002,
        payloadLength: 1_024,
        mediaEnvelopeValid: true,
        mediaPayloadCandidate: .videoFragment
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
    let emptyReport = LoLaCompatibilityCaptureReport(
        id: "empty-capture",
        title: "Empty capture",
        capturedAt: "2026-05-14T00:00:00Z",
        inputPath: "fixtures/empty.pcapng",
        inputFormat: .pcapng,
        summary: LoLaCompatibilityCaptureSummary(packets: []),
        packets: [],
        verdict: .partial,
        evidenceBoundary: "unit-test packet monitor",
        notes: "empty capture"
    )

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

    let sections = NativeAppShellSurfaceContract.releaseReadiness.sections
    let settingsOnly = NativeAppShellSectionSearch.visibleSections(sections, query: "settings")
    let packetOnly = NativeAppShellSectionSearch.visibleSections(sections, query: "packet")

    #expect(AppConsoleSectionSelection.resolvedSection(
        current: .packetMonitor,
        visibleSections: settingsOnly,
        sessionState: .live,
        captureReportAvailable: true
    ) == .settings)
    #expect(AppConsoleSectionSelection.resolvedSection(
        current: .packetMonitor,
        visibleSections: sections,
        sessionState: .unconfigured,
        captureReportAvailable: true
    ) == .overview)
    #expect(AppConsoleSectionSelection.resolvedSection(
        current: .packetMonitor,
        visibleSections: packetOnly,
        sessionState: .ready,
        captureReportAvailable: false
    ) == .packetMonitor)
    #expect(AppConsoleSectionSelection.activeSection(
        current: .packetMonitor,
        visibleSections: packetOnly,
        sessionState: .unconfigured,
        captureReportAvailable: true
    ) == nil)
    #expect(AppConsoleSectionSelection.resolvedSection(
        current: .packetMonitor,
        visibleSections: packetOnly,
        sessionState: .unconfigured,
        captureReportAvailable: true
    ) == nil)
    #expect(AppPacketMonitorSidebarPolicy.disabledReason(sessionState: .unconfigured) != nil)
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
