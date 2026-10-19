import OpenLolaContracts
import OpenLolaSessionDomain
import OpenLolaEvidenceModels
import OpenLolaTransport
import OpenLolaMediaPlatform
// Parses connection arguments and runs route establishment probes so configuration failures stay outside the report model.
import Foundation

// swiftlint:disable:next type_name
/// Enumerates failures that callers must handle when working with direct peer sessions.
public enum MacToMacConnectionEstablishmentRunConfigurationError: Error, Equatable, Sendable {
    case missingRequiredArgument(String)
    case missingValue(String)
    case unknownArgument(String)
    case duplicateArgument(String)
    case invalidInteger(argument: String, value: String)
    case nonPositiveArgument(String)
}

/// Runs MacToMacConnectionEstablishmentRunner while keeping its stateful execution separate from report validation.
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
        routeCertification: MacToMacRouteCertificationReport? = nil,
        localInterfaces: [LocalIPv4Interface] = DirectLANRoute.localInterfaces()
    ) throws -> MacToMacConnectionEstablishmentReport {
        // Without NAT route evidence, an on-link peer with a lossless ping may still pass as a direct LAN route.
        let lan = natRoute == nil
            ? DirectLANRoute.evaluate(peer: configuration.peer, diagnostics: diagnostics, interfaces: localInterfaces)
            : nil
        let lanBasis = lan?.basis
        let selectedRoute: MacToMacConnectionSelectedRoute = lanBasis != nil
            ? .directUdpIp
            : Self.selectedRoute(from: natRoute)
        var blockers: [String] = []
        if lanBasis == nil {
            blockers = blockersFor(diagnostics: diagnostics, natRoute: natRoute, selectedRoute: selectedRoute)
            blockers += lan?.blockers ?? []
        }
        let report = MacToMacConnectionEstablishmentReport(
            identity: .init(id: "mac-to-mac-connection-\(configuration.localPeerID)-\(Int(Date().timeIntervalSince1970))", capturedAt: ISO8601DateFormatter().string(from: Date()), localPeerID: configuration.localPeerID, remotePeerID: configuration.remotePeerID),
            routeEvidence: .init(
                setupMode: lanBasis != nil ? .manualDirect : .ipNatProbe,
                selectedRoute: selectedRoute,
                networkDiagnostics: diagnostics,
                natRoute: natRoute,
                routeCertification: routeCertification,
                directLANBasis: lanBasis
            ),
            provenance: .init(
                planFingerprint: configuration.planFingerprint,
                planCapturedAt: configuration.planCapturedAt
            ),
            outcome: .init(
                blockers: blockers,
                verdict: blockers.isEmpty && selectedRoute == .directUdpIp ? .pass : .partial,
                notes: outcomeNotes(blockers: blockers, lanBasis: lanBasis)
            )
        )
        try report.validate()
        return report
    }

    private static func outcomeNotes(blockers: [String], lanBasis: DirectLANRouteBasis?) -> String {
        if let lanBasis {
            return "Direct LAN route accepted without NAT route evidence: \(lanBasis.peerAddress) is on-link via "
                + "\(lanBasis.interfaceName) (\(lanBasis.localAddress)/\(lanBasis.prefixLength)), ping had 0% loss, "
                + "\(lanBasis.tracerouteBasis)."
        }
        return blockers.isEmpty
            ? "IP/NAT preflight selected direct UDP/IP from diagnostics and NAT route evidence."
            : "IP/NAT preflight is incomplete or blocked; do not report connected, ready, healthy, "
                + "streaming, or PASS."
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

func parseMacToMacConnectionArguments(
    _ arguments: [String],
    allowed: Set<String>
) throws -> [String: String] {
    try KeyValueArgumentParser.parseValuesCheckingDuplicatesFirst(
        arguments,
        allowed: allowed,
        unknown: MacToMacConnectionEstablishmentRunConfigurationError.unknownArgument,
        duplicate: MacToMacConnectionEstablishmentRunConfigurationError.duplicateArgument,
        missingValue: MacToMacConnectionEstablishmentRunConfigurationError.missingValue
    )
}

func requiredMacToMacConnectionString(
    _ argument: String,
    _ values: [String: String]
) throws -> String {
    guard let value = values[argument], !value.isEmpty else {
        throw MacToMacConnectionEstablishmentRunConfigurationError.missingRequiredArgument(argument)
    }
    return value
}

func optionalMacToMacConnectionPositiveInteger(
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

func requireMacToMacConnectionNonEmpty(_ value: String, _ field: String) throws {
    if value.isEmpty {
        throw MacToMacConnectionEstablishmentValidationError.emptyField(field)
    }
}
