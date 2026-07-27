// Models direct-versus-fallback route selection and validates the resulting Mac-to-Mac establishment evidence before certification.
import Foundation

/// Selects how two Macs establish the route used by a direct-peer session.
public enum MacToMacConnectionSetupMode: String, Codable, Equatable, Sendable {
    case ipNatProbe
    case manualDirect
    case sshAdvancedFallback
}

/// Describes MacToMacConnectionSelectedRoute values used to plan and verify direct peer sessions.
public enum MacToMacConnectionSelectedRoute: String, Codable, Equatable, Sendable {
    case none
    case directUdpIp
    case relayForwarder
    case sshAdvancedFallback
}

// swiftlint:disable:next type_name
/// Enumerates failures that callers must handle when working with direct peer sessions.
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

/// Captures MacToMacConnectionEstablishmentReport evidence in a stable form for validation and serialized reporting.
public struct MacToMacConnectionEstablishmentReport: ReportValidatingArtifact, Codable, Equatable, Sendable {
    public struct Identity: Equatable, Sendable {
        public var id: String
        public var capturedAt: String
        public var localPeerID: String
        public var remotePeerID: String

        public init(id: String, capturedAt: String, localPeerID: String, remotePeerID: String) {
            self.id = id
            self.capturedAt = capturedAt
            self.localPeerID = localPeerID
            self.remotePeerID = remotePeerID
        }
    }

    public struct RouteEvidence: Equatable, Sendable {
        public var setupMode: MacToMacConnectionSetupMode
        public var selectedRoute: MacToMacConnectionSelectedRoute
        public var networkDiagnostics: NetworkDiagnosticsReport?
        public var natRoute: NatFriendlyRouteReport?
        public var routeCertification: MacToMacRouteCertificationReport?

        public init(
            setupMode: MacToMacConnectionSetupMode,
            selectedRoute: MacToMacConnectionSelectedRoute,
            networkDiagnostics: NetworkDiagnosticsReport? = nil,
            natRoute: NatFriendlyRouteReport? = nil,
            routeCertification: MacToMacRouteCertificationReport? = nil
        ) {
            self.setupMode = setupMode
            self.selectedRoute = selectedRoute
            self.networkDiagnostics = networkDiagnostics
            self.natRoute = natRoute
            self.routeCertification = routeCertification
        }
    }

    public struct Fallback: Equatable, Sendable {
        public var explicitlySelected: Bool
        public var reason: String?

        public init(explicitlySelected: Bool = false, reason: String? = nil) {
            self.explicitlySelected = explicitlySelected
            self.reason = reason
        }
    }

    public struct Outcome: Equatable, Sendable {
        public var blockers: [String]
        public var verdict: MeasurementVerdict
        public var notes: String

        public init(blockers: [String], verdict: MeasurementVerdict, notes: String) {
            self.blockers = blockers
            self.verdict = verdict
            self.notes = notes
        }
    }
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

    public init(identity: Identity, routeEvidence: RouteEvidence, fallback: Fallback = .init(), outcome: Outcome) {
        self.id = identity.id
        self.capturedAt = identity.capturedAt
        self.localPeerID = identity.localPeerID
        self.remotePeerID = identity.remotePeerID
        self.setupMode = routeEvidence.setupMode
        self.selectedRoute = routeEvidence.selectedRoute
        self.networkDiagnostics = routeEvidence.networkDiagnostics
        self.natRoute = routeEvidence.natRoute
        self.routeCertification = routeEvidence.routeCertification
        self.sshFallbackExplicitlySelected = fallback.explicitlySelected
        self.sshFallbackReason = fallback.reason
        self.blockers = outcome.blockers
        self.verdict = outcome.verdict
        self.notes = outcome.notes
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

// swiftlint:disable:next type_name
/// Configures MacToMacConnectionEstablishmentRunConfiguration so callers supply explicit inputs before starting direct peer sessions.
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
                "--output"
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
