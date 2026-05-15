import Foundation
import Testing

@testable import OpenLolaCore

@Test
func macToMacRouteCertificationPartialFixtureDecodesAndValidates() throws {
    let report = try loadMacToMacRouteCertificationFixture(named: "g04-route-certification-partial")

    try report.validate()

    #expect(report.verdict == .partial)
    #expect(report.runMode == .synthetic)
    #expect(report.routes.count == 3)
    #expect(report.routes.first?.routeReport == nil)
}

@Test
func macToMacRouteCertificationSyntheticSmokeEmitsPartialReport() throws {
    let report = MacToMacRouteCertificationSyntheticSmoke.run()

    try report.validate()

    #expect(report.verdict == .partial)
    #expect(report.routes.map(\.routeKind) == [.directLink, .dedicatedSwitch, .campusPath])
}

@Test
func macToMacRouteCertificationRejectsPassWithoutDirectLinkPass() throws {
    var report = makeRouteCertificationPassCandidate()
    report.routes[0].routeReport?.verdict = .partial

    #expect(throws: MacToMacRouteCertificationValidationError.passWithoutDirectLinkPass) {
        try report.validate()
    }
}

@Test
func macToMacRouteCertificationRejectsPassWhenDirectLinkIsNotFirst() throws {
    var report = makeRouteCertificationPassCandidate()
    report.routes.swapAt(0, 1)

    #expect(throws: MacToMacRouteCertificationValidationError.passWithRouteOrderMismatch(
        index: 0,
        expected: .directLink,
        actual: .dedicatedSwitch
    )) {
        try report.validate()
    }
}

@Test
func macToMacRouteCertificationRejectsPassWithLocalhostRoute() throws {
    var report = makeRouteCertificationPassCandidate()
    report.routes[0].routeReport?.sender.ipAddress = "127.0.0.1"

    #expect(throws: MacToMacRouteCertificationValidationError.passWithLocalhostRoute) {
        try report.validate()
    }
}

@Test
func macToMacRouteCertificationRejectsPassWithPacketModeMismatch() throws {
    var report = makeRouteCertificationPassCandidate()
    report.routes[0].routeReport?.packetMode.framesPerPacket = 64
    report.routes[0].routeReport?.metrics.packetsSent = 1_500
    report.routes[0].routeReport?.metrics.packetsReceived = 1_500
    report.routes[0].routeReport?.metrics.playoutTargetMicroseconds = 1_333

    #expect(throws: MacToMacRouteCertificationValidationError.passWithPacketModeMismatch(
        routeKind: .directLink
    )) {
        try report.validate()
    }
}

@Test
func macToMacRouteCertificationRejectsPassWithoutCaptureArtifact() throws {
    var report = makeRouteCertificationPassCandidate()
    report.routes[0].packetCaptureArtifact = nil

    #expect(throws: MacToMacRouteCertificationValidationError.passWithoutCaptureArtifact(
        routeKind: .directLink
    )) {
        try report.validate()
    }
}

@Test
func macToMacRouteCertificationRejectsPassWithPlaceholderEvidence() throws {
    var report = makeRouteCertificationPassCandidate()
    report.routes[0].packetCaptureArtifact = "docs/mac-port/reports/captures/fixture-direct-link.pcapng"

    #expect(throws: MacToMacRouteCertificationValidationError.passWithPlaceholderField(
        "routes[0].packetCaptureArtifact"
    )) {
        try report.validate()
    }
}

@Test
func macToMacPlaceholderTokensAreNamedConstants() throws {
    let source = try readRepositoryText("Sources/OpenLolaCore/Network/P2P/MacToMacRouteCertification.swift")

    #expect(source.contains("private let macToMacPlaceholderContainingTokens = [\"todo(human)\", \"placeholder\", \"fixture\"]"))
    #expect(source.contains("private let macToMacPlaceholderExactTokens = [\"unknown\", \"tbd\"]"))
    #expect(source.contains("containing: macToMacPlaceholderContainingTokens"))
    #expect(source.contains("exactly: macToMacPlaceholderExactTokens"))
}

@Test
func macToMacRouteCertificationRejectsDuplicateRouteKind() throws {
    var report = try loadMacToMacRouteCertificationFixture(named: "g04-route-certification-partial")
    report.routes[1].routeKind = .directLink

    #expect(throws: MacToMacRouteCertificationValidationError.duplicateRouteKind(.directLink)) {
        try report.validate()
    }
}

@Test
func macToMacRouteCertificationPassCandidateValidates() throws {
    let report = makeRouteCertificationPassCandidate()

    try report.validate()

    #expect(report.verdict == .pass)
    #expect(report.routes[0].routeKind == .directLink)
}

@Test
func macToMacRouteCertificationJSONRoundTripPreservesReport() throws {
    let report = try loadMacToMacRouteCertificationFixture(named: "g04-route-certification-partial")
    let jsonData = try report.prettyJSONData()
    let decoded = try MacToMacRouteCertificationReport.decode(from: jsonData)

    #expect(decoded == report)
}

private func makeRouteCertificationPassCandidate() -> MacToMacRouteCertificationReport {
    MacToMacRouteCertificationReport(
        id: "g04-direct-link-certification-pass-candidate",
        title: "G04 direct-link route certification pass candidate",
        capturedAt: "2026-05-02T00:00:00Z",
        runMode: .measured,
        packetMode: routePacketMode(),
        sourceRealtimeEngineReportId: "g03-measured-rme-engine-report",
        routes: [
            MacToMacRouteCertificationCandidate(
                routeKind: .directLink,
                label: "direct-link-reference",
                routeReport: makePhysicalRouteReport(kind: .directLink),
                packetCaptureArtifact: "docs/mac-port/reports/captures/direct-link-en5-2026-05-02.pcapng",
                notTestedReason: nil,
                notes: "Measured direct wired route with receiver packet capture."
            ),
            MacToMacRouteCertificationCandidate(
                routeKind: .dedicatedSwitch,
                label: "dedicated-switch-reference",
                routeReport: nil,
                packetCaptureArtifact: nil,
                notTestedReason: "Dedicated switch route not measured for this direct-link-only PASS candidate.",
                notes: "Deferred until direct link is accepted."
            ),
            MacToMacRouteCertificationCandidate(
                routeKind: .campusPath,
                label: "campus-path-reference",
                routeReport: nil,
                packetCaptureArtifact: nil,
                notTestedReason: "Campus path deferred until capture permission is recorded.",
                notes: "Deferred by Q004."
            ),
        ],
        verdict: .pass,
        notes: "Measured direct-link route certification pass candidate."
    )
}

private func makePhysicalRouteReport(kind: UdpPcmRouteKind) -> UdpPcmRouteReport {
    UdpPcmRouteReport(
        id: "m05-\(kind.rawValue)-measured-pass",
        title: "Measured \(kind.rawValue) UDP PCM route",
        capturedAt: "2026-05-02T00:00:00Z",
        route: RouteIdentity(
            label: "\(kind.rawValue)-reference",
            topology: kind == .directLink ? "mac-to-mac-direct-cable" : "measured-wired-route"
        ),
        routeKind: kind,
        sender: UdpPcmRouteEndpoint(
            label: "sender-mac",
            hostName: "sender-mac-mini-m2",
            interfaceName: "en5",
            ipAddress: "10.10.20.10"
        ),
        receiver: UdpPcmRouteEndpoint(
            label: "receiver-mac",
            hostName: "receiver-mac-mini-m2",
            interfaceName: "en5",
            ipAddress: "10.10.20.11"
        ),
        packetMode: routePacketMode(),
        measuredDurationSeconds: 2,
        network: UdpPcmNetworkProfile(
            linkRateMbps: 1_000,
            vlan: "none",
            multicastPolicy: "unicast-only",
            dscp: UdpPcmDscpObservation(
                requested: 46,
                observed: 46,
                classification: .honored,
                notTestedReason: nil
            ),
            packetCapture: UdpPcmPacketCapture(
                point: "receiver en5 tcpdump capture",
                receiverCorrelation: true,
                notes: "Receiver capture matched expected packet count and timestamp window."
            )
        ),
        metrics: UdpPcmRouteMetrics(
            packetsSent: 3_000,
            packetsReceived: 3_000,
            lostPackets: 0,
            latePackets: 0,
            reorderedPackets: 0,
            duplicatePackets: 0,
            packetAge: UdpPcmPacketAgeMetrics(
                p50Microseconds: 100,
                p95Microseconds: 180,
                p99Microseconds: 240,
                maxMicroseconds: 300
            ),
            jitterP99Microseconds: 40,
            playoutTargetMicroseconds: 666,
            hiddenPlayoutGrowthDetected: false
        ),
        verdict: .pass,
        notes: "Measured route report with fixed playout target and packet capture correlation."
    )
}

private func routePacketMode() -> UdpPcmPacketMode {
    UdpPcmPacketMode(
        sampleRateHertz: 48_000,
        framesPerPacket: 32,
        channelCount: 2,
        sampleFormat: .int16LittleEndian
    )
}

private func loadMacToMacRouteCertificationFixture(
    named name: String
) throws -> MacToMacRouteCertificationReport {
    let url = try macToMacRouteCertificationFixtureURL(named: name)
    return try MacToMacRouteCertificationReport.decode(from: Data(contentsOf: url))
}

private func macToMacRouteCertificationFixtureURL(named name: String) throws -> URL {
    let validURL = Bundle.module.url(
        forResource: name,
        withExtension: "json",
        subdirectory: "MacToMacRouteCertificationReports/valid"
    )
    let invalidURL = Bundle.module.url(
        forResource: name,
        withExtension: "json",
        subdirectory: "MacToMacRouteCertificationReports/invalid"
    )
    let rootURL = Bundle.module.url(
        forResource: name,
        withExtension: "json",
        subdirectory: nil
    )

    return try #require(validURL ?? invalidURL ?? rootURL)
}

private func readRepositoryText(_ relativePath: String) throws -> String {
    let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    return try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
}
