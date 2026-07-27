// Verifies that Mac-to-Mac connection establishment rejects invalid pass states.
import Foundation
import Testing

@testable import OpenLolaCore

@Test
func macToMacConnectionEstablishmentRejectsFalsePassStates() throws {
    try expectMacToMacConnectionError(.passWithoutIPNatProbe) {
        $0.setupMode = .manualDirect
    }
    try expectMacToMacConnectionError(.passWithoutDirectUdpIPRoute) {
        $0.selectedRoute = .none
    }
    try expectMacToMacConnectionError(.passWithoutNetworkDiagnostics) {
        $0.networkDiagnostics = nil
    }
    try expectMacToMacConnectionError(.passWithNonPassNetworkDiagnostics) {
        $0.networkDiagnostics?.verdict = .partial
    }
    try expectMacToMacConnectionError(.passWithoutNatRoute) {
        $0.natRoute = nil
    }
    try expectMacToMacConnectionError(.passWithNonPassNatRoute) {
        $0.natRoute?.verdict = .partial
    }
    try expectMacToMacConnectionError(.passWithoutDirectUdpIPRoute) {
        $0.selectedRoute = .relayForwarder
    }
    try expectMacToMacConnectionError(.passWithBlockers) {
        $0.blockers = ["institutional firewall blocked UDP traversal"]
    }
}

@Test
func macToMacConnectionEstablishmentRequiresExplicitSSHFallbackIntent() throws {
    var report = partialReport()
    report.setupMode = .sshAdvancedFallback
    report.selectedRoute = .sshAdvancedFallback
    report.sshFallbackExplicitlySelected = false

    #expect(throws: MacToMacConnectionEstablishmentValidationError.silentSSHFallback) {
        try report.validate()
    }

    report.sshFallbackExplicitlySelected = true
    report.sshFallbackReason = nil

    #expect(throws: MacToMacConnectionEstablishmentValidationError.sshFallbackWithoutReason) {
        try report.validate()
    }

    report.sshFallbackReason = "operator selected lab SSH launch after policy-approved route failure"

    try report.validate()
    #expect(report.verdict == .partial)
}

@Test
func macToMacConnectionEstablishmentConfigurationParsesDefaultsAndRejectsInvalidShapes() throws {
    let configuration = try MacToMacConnectionEstablishmentRunConfiguration.parse([
        "--local-peer-id", "mac-a",
        "--remote-peer-id", "mac-b",
        "--peer", "203.0.113.7",
        "--nat-route-report", "reports/nat.json",
        "--route-certification-report", "reports/route.json",
        "--output", "reports/preflight.json"
    ])

    #expect(configuration.localPeerID == "mac-a")
    #expect(configuration.remotePeerID == "mac-b")
    #expect(configuration.peer == "203.0.113.7")
    #expect(configuration.pingCount == 3)
    #expect(configuration.maxHops == 8)
    #expect(configuration.natRouteReportPath == "reports/nat.json")
    #expect(configuration.routeCertificationReportPath == "reports/route.json")
    #expect(configuration.outputPath == "reports/preflight.json")

    let tuned = try MacToMacConnectionEstablishmentRunConfiguration.parse([
        "--local-peer-id", "mac-a",
        "--remote-peer-id", "mac-b",
        "--peer", "203.0.113.7",
        "--ping-count", "5",
        "--max-hops", "12",
        "--output", "reports/preflight.json"
    ])

    #expect(tuned.pingCount == 5)
    #expect(tuned.maxHops == 12)

    #expect(throws: MacToMacConnectionEstablishmentRunConfigurationError.missingRequiredArgument("--peer")) {
        _ = try MacToMacConnectionEstablishmentRunConfiguration.parse([
            "--local-peer-id", "mac-a",
            "--remote-peer-id", "mac-b",
            "--output", "reports/preflight.json"
        ])
    }
    #expect(throws: MacToMacConnectionEstablishmentRunConfigurationError.nonPositiveArgument("--ping-count")) {
        _ = try MacToMacConnectionEstablishmentRunConfiguration.parse([
            "--local-peer-id", "mac-a",
            "--remote-peer-id", "mac-b",
            "--peer", "203.0.113.7",
            "--ping-count", "0",
            "--output", "reports/preflight.json"
        ])
    }
}

@Test
func macToMacConnectionEstablishmentRunnerBuildsPartialReportWhenNatEvidenceIsMissing() throws {
    var diagnostics = NetworkDiagnosticsSyntheticSmoke.run()
    diagnostics.traceroute.blocked = true
    diagnostics.traceroute.blockedReason = "operation not permitted by institutional firewall"
    diagnostics.verdict = .partial

    let report = try MacToMacConnectionEstablishmentRunner.makeReport(
        configuration: runConfiguration(),
        diagnostics: diagnostics,
        natRoute: nil
    )

    try report.validate()

    #expect(report.setupMode == .ipNatProbe)
    #expect(report.selectedRoute == .none)
    #expect(report.verdict == .partial)
    #expect(report.blockers.contains("network diagnostics did not pass"))
    #expect(report.blockers.contains("missing NAT-friendly route evidence"))
    #expect(report.blockers.contains {
        $0.contains("institutional firewall")
    })
}

@Test
func macToMacConnectionEstablishmentRunnerSelectsDirectUdpOnlyAfterPassingNatEvidence() throws {
    let report = try MacToMacConnectionEstablishmentRunner.makeReport(
        configuration: runConfiguration(),
        diagnostics: passingDiagnostics(),
        natRoute: passingNatRoute()
    )

    try report.validate()

    #expect(report.setupMode == .ipNatProbe)
    #expect(report.selectedRoute == .directUdpIp)
    #expect(report.blockers.isEmpty)
    #expect(report.verdict == .pass)

    var relayRoute = passingNatRoute()
    relayRoute.verdict = .partial
    relayRoute.compatibilityMode = .relayFallback
    relayRoute.traversal.relayUsed = true
    relayRoute.traversal.directTraversalSucceeded = false

    let relayReport = try MacToMacConnectionEstablishmentRunner.makeReport(
        configuration: runConfiguration(),
        diagnostics: passingDiagnostics(),
        natRoute: relayRoute
    )

    try relayReport.validate()

    #expect(relayReport.selectedRoute == .relayForwarder)
    #expect(relayReport.verdict == .partial)
    #expect(relayReport.blockers.contains("relay fallback selected; direct UDP/IP is not proven"))
}

@Test
func macToMacConnectionEstablishmentReportRoundTrips() throws {
    let report = passReport()
    let decoded = try MacToMacConnectionEstablishmentReport.decode(from: try report.prettyJSONData())

    try decoded.validate()

    #expect(decoded == report)
}

private func expectMacToMacConnectionError(
    _ expected: MacToMacConnectionEstablishmentValidationError,
    mutate: (inout MacToMacConnectionEstablishmentReport) throws -> Void
) throws {
    var report = passReport()
    try mutate(&report)

    #expect(throws: expected) {
        try report.validate()
    }
}

private func runConfiguration() -> MacToMacConnectionEstablishmentRunConfiguration {
    MacToMacConnectionEstablishmentRunConfiguration(
        localPeerID: "mac-a",
        remotePeerID: "mac-b",
        peer: "203.0.113.7",
        outputPath: "reports/preflight.json"
    )
}

private func passReport() -> MacToMacConnectionEstablishmentReport {
    MacToMacConnectionEstablishmentReport(
        identity: .init(id: "mac-to-mac-connection-pass", capturedAt: "2026-05-16T00:00:00Z", localPeerID: "mac-a", remotePeerID: "mac-b"),
        routeEvidence: .init(setupMode: .ipNatProbe, selectedRoute: .directUdpIp, networkDiagnostics: passingDiagnostics(), natRoute: passingNatRoute(), routeCertification: nil),
        outcome: .init(blockers: [], verdict: .pass, notes: "Measured IP/NAT setup evidence selected direct UDP/IP.")
    )
}

private func partialReport() -> MacToMacConnectionEstablishmentReport {
    MacToMacConnectionEstablishmentReport(
        identity: .init(id: "mac-to-mac-connection-partial", capturedAt: "2026-05-16T00:00:00Z", localPeerID: "mac-a", remotePeerID: "mac-b"),
        routeEvidence: .init(setupMode: .ipNatProbe, selectedRoute: .none, networkDiagnostics: passingDiagnostics(), natRoute: nil, routeCertification: nil),
        outcome: .init(blockers: ["missing NAT-friendly route evidence"], verdict: .partial, notes: "No direct UDP/IP route selected.")
    )
}

private func passingNatRoute() -> NatFriendlyRouteReport {
    var route = NatFriendlyRouteSyntheticSmoke.run()
    route.verdict = .pass
    route.traversal.rawRouteRttMicroseconds = 80
    route.traversal.directTraversalRttMicroseconds = 100
    route.traversal.addedLatencyMicroseconds = 20
    route.loopback?.verdict = .pass
    return route
}

private func passingDiagnostics() -> NetworkDiagnosticsReport {
    var diagnostics = NetworkDiagnosticsSyntheticSmoke.run()
    diagnostics.verdict = .pass
    return diagnostics
}
