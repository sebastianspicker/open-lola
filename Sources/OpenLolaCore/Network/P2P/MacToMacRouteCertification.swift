import Foundation

public enum MacToMacRouteCertificationRunMode: String, Codable, Equatable, Sendable {
    case synthetic
    case measured
}

public struct MacToMacRouteCertificationCandidate: Codable, Equatable, Sendable {
    public var routeKind: UdpPcmRouteKind
    public var label: String
    public var routeReport: UdpPcmRouteReport?
    public var packetCaptureArtifact: String?
    public var notTestedReason: String?
    public var notes: String

    public init(
        routeKind: UdpPcmRouteKind,
        label: String,
        routeReport: UdpPcmRouteReport?,
        packetCaptureArtifact: String?,
        notTestedReason: String?,
        notes: String
    ) {
        self.routeKind = routeKind
        self.label = label
        self.routeReport = routeReport
        self.packetCaptureArtifact = packetCaptureArtifact
        self.notTestedReason = notTestedReason
        self.notes = notes
    }
}

public enum MacToMacRouteCertificationValidationError: Error, Equatable, Sendable {
    case emptyField(String)
    case nonPositiveField(String)
    case noRoutes
    case duplicateRouteKind(UdpPcmRouteKind)
    case candidateWithoutReportOrReason(UdpPcmRouteKind)
    case routeKindMismatch(candidate: UdpPcmRouteKind, report: UdpPcmRouteKind)
    case passWithoutMeasuredRun
    case passWithRouteOrderMismatch(index: Int, expected: UdpPcmRouteKind, actual: UdpPcmRouteKind)
    case passWithoutDirectLinkPass
    case passWithLocalhostRoute
    case passWithPacketModeMismatch(routeKind: UdpPcmRouteKind)
    case passWithoutCaptureArtifact(routeKind: UdpPcmRouteKind)
    case passWithPlaceholderField(String)
}

public struct MacToMacRouteCertificationReport: ReportValidatingArtifact, Codable, Equatable, Sendable {
    public var id: String
    public var title: String
    public var capturedAt: String
    public var runMode: MacToMacRouteCertificationRunMode
    public var packetMode: UdpPcmPacketMode
    public var sourceRealtimeEngineReportId: String
    public var routes: [MacToMacRouteCertificationCandidate]
    public var verdict: MeasurementVerdict
    public var notes: String

    public init(
        id: String,
        title: String,
        capturedAt: String,
        runMode: MacToMacRouteCertificationRunMode,
        packetMode: UdpPcmPacketMode,
        sourceRealtimeEngineReportId: String,
        routes: [MacToMacRouteCertificationCandidate],
        verdict: MeasurementVerdict,
        notes: String
    ) {
        self.id = id
        self.title = title
        self.capturedAt = capturedAt
        self.runMode = runMode
        self.packetMode = packetMode
        self.sourceRealtimeEngineReportId = sourceRealtimeEngineReportId
        self.routes = routes
        self.verdict = verdict
        self.notes = notes
    }

    public static func decode(from data: Data) throws -> MacToMacRouteCertificationReport {
        try JSONDecoder().decode(MacToMacRouteCertificationReport.self, from: data)
    }

    public func validate() throws {
        try validateIdentity()
        try validatePacketMode()
        try validateRoutes()
        try validatePassVerdict()
    }

    private func validateIdentity() throws {
        try requireMacToMacNonEmpty(id, "id")
        try requireMacToMacNonEmpty(title, "title")
        try requireMacToMacNonEmpty(capturedAt, "capturedAt")
        try requireMacToMacNonEmpty(sourceRealtimeEngineReportId, "sourceRealtimeEngineReportId")
        try requireMacToMacNonEmpty(notes, "notes")
    }

    private func validatePacketMode() throws {
        try requireMacToMacPositive(packetMode.sampleRateHertz, "packetMode.sampleRateHertz")
        try requireMacToMacPositive(packetMode.framesPerPacket, "packetMode.framesPerPacket")
        try requireMacToMacPositive(packetMode.channelCount, "packetMode.channelCount")
    }

    private func validateRoutes() throws {
        guard !routes.isEmpty else {
            throw MacToMacRouteCertificationValidationError.noRoutes
        }

        var seenKinds: Set<UdpPcmRouteKind> = []
        for (index, route) in routes.enumerated() {
            guard seenKinds.insert(route.routeKind).inserted else {
                throw MacToMacRouteCertificationValidationError.duplicateRouteKind(route.routeKind)
            }
            try requireMacToMacNonEmpty(route.label, "routes[\(index)].label")
            try requireMacToMacNonEmpty(route.notes, "routes[\(index)].notes")
            if let artifact = route.packetCaptureArtifact {
                try requireMacToMacNonEmpty(artifact, "routes[\(index)].packetCaptureArtifact")
            }
            guard let routeReport = route.routeReport else {
                if route.notTestedReason?.isEmpty != false {
                    throw MacToMacRouteCertificationValidationError.candidateWithoutReportOrReason(
                        route.routeKind
                    )
                }
                continue
            }
            try routeReport.validate()
            if routeReport.routeKind != route.routeKind {
                throw MacToMacRouteCertificationValidationError.routeKindMismatch(
                    candidate: route.routeKind,
                    report: routeReport.routeKind
                )
            }
        }
    }

    private func validatePassVerdict() throws {
        guard verdict == .pass else {
            return
        }
        guard runMode == .measured else {
            throw MacToMacRouteCertificationValidationError.passWithoutMeasuredRun
        }
        try validatePassRouteOrder()

        guard let directLink = routes.first(where: { $0.routeKind == .directLink }),
              directLink.routeReport?.verdict == .pass else {
            throw MacToMacRouteCertificationValidationError.passWithoutDirectLinkPass
        }

        for (index, route) in routes.enumerated() {
            guard let routeReport = route.routeReport, routeReport.verdict == .pass else {
                continue
            }
            try validatePassRoute(route, report: routeReport, index: index)
        }
    }

    private func validatePassRouteOrder() throws {
        let expectedOrder: [UdpPcmRouteKind] = [.directLink, .dedicatedSwitch, .campusPath]
        for index in routes.indices {
            guard index < expectedOrder.count else {
                return
            }
            let actual = routes[index].routeKind
            let expected = expectedOrder[index]
            guard actual == expected else {
                throw MacToMacRouteCertificationValidationError.passWithRouteOrderMismatch(
                    index: index,
                    expected: expected,
                    actual: actual
                )
            }
        }
    }

    private func validatePassRoute(
        _ route: MacToMacRouteCertificationCandidate,
        report: UdpPcmRouteReport,
        index: Int
    ) throws {
        guard route.routeKind != .localhostSmoke,
              report.routeKind != .localhostSmoke,
              !isLocalhost(report.sender.ipAddress),
              !isLocalhost(report.receiver.ipAddress) else {
            throw MacToMacRouteCertificationValidationError.passWithLocalhostRoute
        }

        guard report.packetMode == packetMode else {
            throw MacToMacRouteCertificationValidationError.passWithPacketModeMismatch(
                routeKind: route.routeKind
            )
        }
        guard route.packetCaptureArtifact?.isEmpty == false else {
            throw MacToMacRouteCertificationValidationError.passWithoutCaptureArtifact(
                routeKind: route.routeKind
            )
        }

        for field in placeholderSensitiveFields(route: route, report: report, index: index)
            where isMacToMacPlaceholder(field.value) {
            throw MacToMacRouteCertificationValidationError.passWithPlaceholderField(field.name)
        }
    }

    private func placeholderSensitiveFields(
        route: MacToMacRouteCertificationCandidate,
        report: UdpPcmRouteReport,
        index: Int
    ) -> [(name: String, value: String)] {
        [
            ("id", id),
            ("title", title),
            ("capturedAt", capturedAt),
            ("sourceRealtimeEngineReportId", sourceRealtimeEngineReportId),
            ("routes[\(index)].label", route.label),
            ("routes[\(index)].packetCaptureArtifact", route.packetCaptureArtifact ?? ""),
            ("routes[\(index)].notes", route.notes),
            ("routes[\(index)].routeReport.id", report.id),
            ("routes[\(index)].routeReport.title", report.title),
            ("routes[\(index)].routeReport.route.label", report.route.label),
            ("routes[\(index)].routeReport.route.topology", report.route.topology),
            ("routes[\(index)].routeReport.sender.label", report.sender.label),
            ("routes[\(index)].routeReport.sender.hostName", report.sender.hostName),
            ("routes[\(index)].routeReport.sender.interfaceName", report.sender.interfaceName),
            ("routes[\(index)].routeReport.sender.ipAddress", report.sender.ipAddress),
            ("routes[\(index)].routeReport.receiver.label", report.receiver.label),
            ("routes[\(index)].routeReport.receiver.hostName", report.receiver.hostName),
            ("routes[\(index)].routeReport.receiver.interfaceName", report.receiver.interfaceName),
            ("routes[\(index)].routeReport.receiver.ipAddress", report.receiver.ipAddress),
            ("routes[\(index)].routeReport.network.vlan", report.network.vlan),
            ("routes[\(index)].routeReport.network.multicastPolicy", report.network.multicastPolicy),
            (
                "routes[\(index)].routeReport.network.packetCapture.point",
                report.network.packetCapture.point ?? ""
            ),
            (
                "routes[\(index)].routeReport.network.packetCapture.notes",
                report.network.packetCapture.notes
            ),
            ("routes[\(index)].routeReport.notes", report.notes),
            ("notes", notes),
        ]
    }
}

public enum MacToMacRouteCertificationSyntheticSmoke {
    public static func run() -> MacToMacRouteCertificationReport {
        MacToMacRouteCertificationReport(
            id: "g04-route-certification-synthetic-smoke",
            title: "Synthetic G04 route certification",
            capturedAt: "2026-05-02T00:00:00Z",
            runMode: .synthetic,
            packetMode: UdpPcmPacketMode(
                sampleRateHertz: 48_000,
                framesPerPacket: 32,
                channelCount: 2,
                sampleFormat: .int16LittleEndian
            ),
            sourceRealtimeEngineReportId: "g03-realtime-audio-engine-synthetic-smoke",
            routes: [
                MacToMacRouteCertificationCandidate(
                    routeKind: .directLink,
                    label: "direct-link-reference",
                    routeReport: nil,
                    packetCaptureArtifact: nil,
                    notTestedReason: "Synthetic smoke only; direct-link route needs two Macs and packet capture.",
                    notes: "No physical direct-link route measured."
                ),
                MacToMacRouteCertificationCandidate(
                    routeKind: .dedicatedSwitch,
                    label: "dedicated-switch-reference",
                    routeReport: nil,
                    packetCaptureArtifact: nil,
                    notTestedReason: "Synthetic smoke only; dedicated switch route follows direct-link baseline.",
                    notes: "No physical dedicated-switch route measured."
                ),
                MacToMacRouteCertificationCandidate(
                    routeKind: .campusPath,
                    label: "campus-path-reference",
                    routeReport: nil,
                    packetCaptureArtifact: nil,
                    notTestedReason: "Synthetic smoke only; campus path requires Q004 capture permission.",
                    notes: "No physical campus route measured."
                ),
            ],
            verdict: .partial,
            notes: "Synthetic source validation only; G04 PASS requires measured two-Mac route reports and packet capture."
        )
    }
}

private func requireMacToMacNonEmpty(_ value: String, _ field: String) throws {
    if value.isEmpty {
        throw MacToMacRouteCertificationValidationError.emptyField(field)
    }
}

private func requireMacToMacPositive(_ value: Int, _ field: String) throws {
    if value <= 0 {
        throw MacToMacRouteCertificationValidationError.nonPositiveField(field)
    }
}

private func isLocalhost(_ ipAddress: String) -> Bool {
    ipAddress == "localhost"
        || ipAddress == "::1"
        || ipAddress.hasPrefix("127.")
}

private let macToMacPlaceholderContainingTokens = ["todo(human)", "placeholder", "fixture"]
private let macToMacPlaceholderExactTokens = ["unknown", "tbd"]

private func isMacToMacPlaceholder(_ value: String) -> Bool {
    PlaceholderDetection.matches(
        value,
        containing: macToMacPlaceholderContainingTokens,
        exactly: macToMacPlaceholderExactTokens
    )
}
