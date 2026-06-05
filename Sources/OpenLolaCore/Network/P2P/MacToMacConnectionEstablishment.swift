import Foundation

public enum MacToMacConnectionSetupMode: String, Codable, Equatable, Sendable {
    case ipNatProbe
    case manualDirect
    case sshAdvancedFallback
}

public enum MacToMacConnectionSelectedRoute: String, Codable, Equatable, Sendable {
    case none
    case directUdpIp
    case relayForwarder
    case sshAdvancedFallback
}

public enum MacToMacConnectionEstablishmentValidationError: Error, Equatable, Sendable {
    case emptyField(String)
    case nonPositiveField(String)
    case passWithoutIPNatProbe
    case passWithoutNetworkDiagnostics
    case passWithNonPassNetworkDiagnostics
    case passWithoutNatRoute
    case passWithNonPassNatRoute
    case passWithoutDirectUdpIPRoute
    case passWithRelayFallback
    case passWithSSHFallback
    case passWithBlockers
    case silentSSHFallback
    case sshFallbackWithoutReason
}

public struct MacToMacConnectionEstablishmentReport: ReportValidatingArtifact, Codable, Equatable, Sendable {
    public var id: String
    public var capturedAt: String
    public var localPeerID: String
    public var remotePeerID: String
    public var setupMode: MacToMacConnectionSetupMode
    public var selectedRoute: MacToMacConnectionSelectedRoute
    public var networkDiagnostics: NetworkDiagnosticsReport?
    public var natRoute: NatFriendlyRouteReport?
    public var routeCertification: MacToMacRouteCertificationReport?
    public var sshFallbackExplicitlySelected: Bool
    public var sshFallbackReason: String?
    public var blockers: [String]
    public var verdict: MeasurementVerdict
    public var notes: String

    public init(
        id: String,
        capturedAt: String,
        localPeerID: String,
        remotePeerID: String,
        setupMode: MacToMacConnectionSetupMode,
        selectedRoute: MacToMacConnectionSelectedRoute,
        networkDiagnostics: NetworkDiagnosticsReport?,
        natRoute: NatFriendlyRouteReport?,
        routeCertification: MacToMacRouteCertificationReport? = nil,
        sshFallbackExplicitlySelected: Bool = false,
        sshFallbackReason: String? = nil,
        blockers: [String],
        verdict: MeasurementVerdict,
        notes: String
    ) {
        self.id = id
        self.capturedAt = capturedAt
        self.localPeerID = localPeerID
        self.remotePeerID = remotePeerID
        self.setupMode = setupMode
        self.selectedRoute = selectedRoute
        self.networkDiagnostics = networkDiagnostics
        self.natRoute = natRoute
        self.routeCertification = routeCertification
        self.sshFallbackExplicitlySelected = sshFallbackExplicitlySelected
        self.sshFallbackReason = sshFallbackReason
        self.blockers = blockers
        self.verdict = verdict
        self.notes = notes
    }

    public static func decode(from data: Data) throws -> MacToMacConnectionEstablishmentReport {
        try JSONDecoder().decode(MacToMacConnectionEstablishmentReport.self, from: data)
    }

    public func validate() throws {
        try validateIdentity()
        try validateSSHFallbackIntent()
        try validateSubordinateReports()
        try validatePassVerdict()
    }

    private func validateIdentity() throws {
        try requireMacToMacConnectionNonEmpty(id, "id")
        try requireMacToMacConnectionNonEmpty(capturedAt, "capturedAt")
        try requireMacToMacConnectionNonEmpty(localPeerID, "localPeerID")
        try requireMacToMacConnectionNonEmpty(remotePeerID, "remotePeerID")
        try requireMacToMacConnectionNonEmpty(notes, "notes")
        for blocker in blockers {
            try requireMacToMacConnectionNonEmpty(blocker, "blockers")
        }
        if let sshFallbackReason {
            try requireMacToMacConnectionNonEmpty(sshFallbackReason, "sshFallbackReason")
        }
    }

    private func validateSSHFallbackIntent() throws {
        if setupMode == .sshAdvancedFallback || selectedRoute == .sshAdvancedFallback {
            guard sshFallbackExplicitlySelected else {
                throw MacToMacConnectionEstablishmentValidationError.silentSSHFallback
            }
            if sshFallbackReason?.isEmpty != false {
                throw MacToMacConnectionEstablishmentValidationError.sshFallbackWithoutReason
            }
        } else if sshFallbackExplicitlySelected {
            throw MacToMacConnectionEstablishmentValidationError.silentSSHFallback
        }
    }

    private func validateSubordinateReports() throws {
        try networkDiagnostics?.validate()
        try natRoute?.validate()
        try routeCertification?.validate()
    }

    private func validatePassVerdict() throws {
        guard verdict == .pass else {
            return
        }
        try validatePassRouteSelection()
        try validatePassSubordinateEvidence()
        try validatePassExcludesFallbacksAndBlockers()
    }

    private func validatePassRouteSelection() throws {
        guard setupMode == .ipNatProbe else {
            throw MacToMacConnectionEstablishmentValidationError.passWithoutIPNatProbe
        }
        guard selectedRoute == .directUdpIp else {
            throw MacToMacConnectionEstablishmentValidationError.passWithoutDirectUdpIPRoute
        }
    }

    private func validatePassSubordinateEvidence() throws {
        guard let networkDiagnostics else {
            throw MacToMacConnectionEstablishmentValidationError.passWithoutNetworkDiagnostics
        }
        guard networkDiagnostics.verdict == .pass else {
            throw MacToMacConnectionEstablishmentValidationError.passWithNonPassNetworkDiagnostics
        }
        guard let natRoute else {
            throw MacToMacConnectionEstablishmentValidationError.passWithoutNatRoute
        }
        guard natRoute.verdict == .pass else {
            throw MacToMacConnectionEstablishmentValidationError.passWithNonPassNatRoute
        }
        if natRoute.compatibilityMode == .relayFallback || natRoute.traversal.relayUsed {
            throw MacToMacConnectionEstablishmentValidationError.passWithRelayFallback
        }
    }

    private func validatePassExcludesFallbacksAndBlockers() throws {
        if selectedRoute == .sshAdvancedFallback || sshFallbackExplicitlySelected {
            throw MacToMacConnectionEstablishmentValidationError.passWithSSHFallback
        }
        if !blockers.isEmpty {
            throw MacToMacConnectionEstablishmentValidationError.passWithBlockers
        }
    }
}

public struct MacToMacConnectionEstablishmentRunConfiguration: Codable, Equatable, Sendable {
    public var localPeerID: String
    public var remotePeerID: String
    public var peer: String
    public var pingCount: Int
    public var maxHops: Int
    public var natRouteReportPath: String?
    public var routeCertificationReportPath: String?
    public var outputPath: String

    public init(
        localPeerID: String,
        remotePeerID: String,
        peer: String,
        pingCount: Int = 3,
        maxHops: Int = 8,
        natRouteReportPath: String? = nil,
        routeCertificationReportPath: String? = nil,
        outputPath: String
    ) {
        self.localPeerID = localPeerID
        self.remotePeerID = remotePeerID
        self.peer = peer
        self.pingCount = pingCount
        self.maxHops = maxHops
        self.natRouteReportPath = natRouteReportPath
        self.routeCertificationReportPath = routeCertificationReportPath
        self.outputPath = outputPath
    }

    public static func parse(_ arguments: [String]) throws -> MacToMacConnectionEstablishmentRunConfiguration {
        let values = try parseMacToMacConnectionArguments(
            arguments,
            allowed: [
                "--local-peer-id",
                "--remote-peer-id",
                "--peer",
                "--ping-count",
                "--max-hops",
                "--nat-route-report",
                "--route-certification-report",
                "--output",
            ]
        )
        return MacToMacConnectionEstablishmentRunConfiguration(
            localPeerID: try requiredMacToMacConnectionString("--local-peer-id", values),
            remotePeerID: try requiredMacToMacConnectionString("--remote-peer-id", values),
            peer: try requiredMacToMacConnectionString("--peer", values),
            pingCount: try optionalMacToMacConnectionPositiveInteger("--ping-count", values) ?? 3,
            maxHops: try optionalMacToMacConnectionPositiveInteger("--max-hops", values) ?? 8,
            natRouteReportPath: values["--nat-route-report"],
            routeCertificationReportPath: values["--route-certification-report"],
            outputPath: try requiredMacToMacConnectionString("--output", values)
        )
    }
}

public enum MacToMacConnectionEstablishmentRunConfigurationError: Error, Equatable, Sendable {
    case missingRequiredArgument(String)
    case missingValue(String)
    case unknownArgument(String)
    case duplicateArgument(String)
    case invalidInteger(argument: String, value: String)
    case nonPositiveArgument(String)
}

public enum MacToMacConnectionEstablishmentRunner {
    public static func run(
        configuration: MacToMacConnectionEstablishmentRunConfiguration
    ) throws -> MacToMacConnectionEstablishmentReport {
        let diagnostics = NetworkDiagnosticsRunner.run(
            configuration: NetworkDiagnosticsRunConfiguration(
                peer: configuration.peer,
                pingCount: configuration.pingCount,
                maxHops: configuration.maxHops,
                outputPath: configuration.outputPath
            )
        )
        let natRoute = try configuration.natRouteReportPath.map {
            try NatFriendlyRouteReport.readValidated(fromPath: $0)
        }
        let routeCertification = try configuration.routeCertificationReportPath.map {
            try MacToMacRouteCertificationReport.readValidated(fromPath: $0)
        }
        return try makeReport(
            configuration: configuration,
            diagnostics: diagnostics,
            natRoute: natRoute,
            routeCertification: routeCertification
        )
    }

    public static func makeReport(
        configuration: MacToMacConnectionEstablishmentRunConfiguration,
        diagnostics: NetworkDiagnosticsReport,
        natRoute: NatFriendlyRouteReport?,
        routeCertification: MacToMacRouteCertificationReport? = nil
    ) throws -> MacToMacConnectionEstablishmentReport {
        let selectedRoute = selectedRoute(from: natRoute)
        let blockers = blockersFor(
            diagnostics: diagnostics,
            natRoute: natRoute,
            selectedRoute: selectedRoute
        )
        let report = MacToMacConnectionEstablishmentReport(
            id: "mac-to-mac-connection-\(configuration.localPeerID)-\(Int(Date().timeIntervalSince1970))",
            capturedAt: ISO8601DateFormatter().string(from: Date()),
            localPeerID: configuration.localPeerID,
            remotePeerID: configuration.remotePeerID,
            setupMode: .ipNatProbe,
            selectedRoute: selectedRoute,
            networkDiagnostics: diagnostics,
            natRoute: natRoute,
            routeCertification: routeCertification,
            blockers: blockers,
            verdict: blockers.isEmpty && selectedRoute == .directUdpIp ? .pass : .partial,
            notes: blockers.isEmpty
                ? "IP/NAT preflight selected direct UDP/IP from diagnostics and NAT route evidence."
                : "IP/NAT preflight is incomplete or blocked; do not report connected, ready, healthy, streaming, or PASS."
        )
        try report.validate()
        return report
    }

    public static func selectedRoute(
        from natRoute: NatFriendlyRouteReport?
    ) -> MacToMacConnectionSelectedRoute {
        guard let natRoute else {
            return .none
        }
        if natRoute.compatibilityMode == .relayFallback || natRoute.traversal.relayUsed {
            return .relayForwarder
        }
        if natRoute.traversal.directTraversalSucceeded {
            return .directUdpIp
        }
        return .none
    }

    private static func blockersFor(
        diagnostics: NetworkDiagnosticsReport,
        natRoute: NatFriendlyRouteReport?,
        selectedRoute: MacToMacConnectionSelectedRoute
    ) -> [String] {
        var blockers: [String] = []
        appendNetworkDiagnosticBlockers(diagnostics, to: &blockers)
        appendNatRouteBlockers(
            natRoute,
            selectedRoute: selectedRoute,
            to: &blockers
        )
        return blockers
    }

    private static func appendNetworkDiagnosticBlockers(
        _ diagnostics: NetworkDiagnosticsReport,
        to blockers: inout [String]
    ) {
        if diagnostics.verdict != .pass {
            blockers.append("network diagnostics did not pass")
        }
        if let pingError = diagnostics.pingError {
            blockers.append("ping failed: \(pingError)")
        }
        if diagnostics.ping?.packetLossPercent ?? 0 > 0 {
            blockers.append("ping packet loss observed: \(diagnostics.ping?.packetLossPercent ?? 0)%")
        }
        if diagnostics.traceroute.blocked {
            blockers.append(
                "traceroute blocked: \(diagnostics.traceroute.blockedReason ?? "unknown policy or permission blocker")"
            )
        }
        if let tracerouteError = diagnostics.tracerouteError {
            blockers.append("traceroute failed: \(tracerouteError)")
        }
    }

    private static func appendNatRouteBlockers(
        _ natRoute: NatFriendlyRouteReport?,
        selectedRoute: MacToMacConnectionSelectedRoute,
        to blockers: inout [String]
    ) {
        guard let natRoute else {
            blockers.append("missing NAT-friendly route evidence")
            return
        }
        if natRoute.verdict != .pass {
            blockers.append("NAT-friendly route did not pass")
        }
        if natRoute.compatibilityMode == .relayFallback || natRoute.traversal.relayUsed {
            blockers.append("relay fallback selected; direct UDP/IP is not proven")
        }
        if !natRoute.traversal.directCandidateDiscovered {
            blockers.append("no direct NAT traversal candidate discovered")
        }
        if !natRoute.traversal.directTraversalSucceeded {
            blockers.append("direct NAT traversal did not succeed")
        }
        if selectedRoute != .directUdpIp {
            blockers.append("no direct UDP/IP route selected")
        }
    }
}

private func parseMacToMacConnectionArguments(
    _ arguments: [String],
    allowed: Set<String>
) throws -> [String: String] {
    var values: [String: String] = [:]
    var index = 0
    while index < arguments.count {
        let argument = arguments[index]
        guard allowed.contains(argument) else {
            throw MacToMacConnectionEstablishmentRunConfigurationError.unknownArgument(argument)
        }
        guard values[argument] == nil else {
            throw MacToMacConnectionEstablishmentRunConfigurationError.duplicateArgument(argument)
        }
        let valueIndex = index + 1
        guard valueIndex < arguments.count, !arguments[valueIndex].hasPrefix("--") else {
            throw MacToMacConnectionEstablishmentRunConfigurationError.missingValue(argument)
        }
        values[argument] = arguments[valueIndex]
        index += 2
    }
    return values
}

private func requiredMacToMacConnectionString(
    _ argument: String,
    _ values: [String: String]
) throws -> String {
    guard let value = values[argument], !value.isEmpty else {
        throw MacToMacConnectionEstablishmentRunConfigurationError.missingRequiredArgument(argument)
    }
    return value
}

private func optionalMacToMacConnectionPositiveInteger(
    _ argument: String,
    _ values: [String: String]
) throws -> Int? {
    guard let value = values[argument] else {
        return nil
    }
    guard let integer = Int(value) else {
        throw MacToMacConnectionEstablishmentRunConfigurationError.invalidInteger(
            argument: argument,
            value: value
        )
    }
    guard integer > 0 else {
        throw MacToMacConnectionEstablishmentRunConfigurationError.nonPositiveArgument(argument)
    }
    return integer
}

private func requireMacToMacConnectionNonEmpty(_ value: String, _ field: String) throws {
    if value.isEmpty {
        throw MacToMacConnectionEstablishmentValidationError.emptyField(field)
    }
}
