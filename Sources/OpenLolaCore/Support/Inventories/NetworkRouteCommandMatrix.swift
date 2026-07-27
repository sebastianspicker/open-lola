// Builds the source-backed network-command inventory that distinguishes route evidence boundaries, ownership, and representative invocations.
import Foundation

/// Defines the finite operating mode values recorded by network route command matrix artifacts for deterministic validation and report interpretation.
public enum NetworkRouteMode: String, Codable, Sendable {
    case udpPcmPacketProbe
    case udpPcmRoute
    case udpPcmLoopback
    case networkDiagnostics
    case natFriendlyRoute
    case natRendezvous
    case natRelay
    case natForwarder
    case macToMacConnectionEstablishment
    case directPeerSession
}

/// Defines the finite evidence provenance values recorded by network route command matrix artifacts for deterministic validation and report interpretation.
public enum NetworkRouteEvidenceBoundary: String, Codable, Sendable {
    case packetContractOnly
    case directFastestCandidate
    case directCertificationGate
    case loopbackMeasurement
    case diagnosticOnly
    case natCompatibilityOnly
    case connectionPreflight
    case directPeerSessionPartialOnly
}

/// Captures inventory entry required to validate, interpret, and reproduce a network route command matrix result.
public struct NetworkRouteCommandMatrixEntry: Codable, Equatable, Sendable {
    public struct Command: Equatable, Sendable {
        public var name: String
        public var kind: CLICommandKind
        public var ownerSourceFile: String
        public var parser: String
        public var outputReport: String

        public init(
            name: String,
            kind: CLICommandKind,
            ownerSourceFile: String,
            parser: String,
            outputReport: String
        ) {
            self.name = name
            self.kind = kind
            self.ownerSourceFile = ownerSourceFile
            self.parser = parser
            self.outputReport = outputReport
        }
    }

    public struct Route: Equatable, Sendable {
        public var mode: NetworkRouteMode
        public var evidenceBoundary: NetworkRouteEvidenceBoundary
        public var canContributeToFastestDirectEvidence: Bool

        public init(
            mode: NetworkRouteMode,
            evidenceBoundary: NetworkRouteEvidenceBoundary,
            canContributeToFastestDirectEvidence: Bool
        ) {
            self.mode = mode
            self.evidenceBoundary = evidenceBoundary
            self.canContributeToFastestDirectEvidence = canContributeToFastestDirectEvidence
        }
    }

    public struct References: Equatable, Sendable {
        public var representativeCommand: String
        public var sourceFiles: [String]
        public var testFiles: [String]
        public var notes: String

        public init(
            representativeCommand: String,
            sourceFiles: [String],
            testFiles: [String],
            notes: String
        ) {
            self.representativeCommand = representativeCommand
            self.sourceFiles = sourceFiles
            self.testFiles = testFiles
            self.notes = notes
        }
    }

    public let command: String
    public let kind: CLICommandKind
    public let ownerSourceFile: String
    public let parser: String
    public let outputReport: String
    public let routeMode: NetworkRouteMode
    public let evidenceBoundary: NetworkRouteEvidenceBoundary
    public let canContributeToFastestDirectEvidence: Bool
    public let representativeCommand: String
    public let relatedSourceFiles: [String]
    public let relatedTestFiles: [String]
    public let notes: String

    public init(
        command: Command,
        route: Route,
        references: References
    ) {
        self.command = command.name
        kind = command.kind
        ownerSourceFile = command.ownerSourceFile
        parser = command.parser
        outputReport = command.outputReport
        routeMode = route.mode
        evidenceBoundary = route.evidenceBoundary
        canContributeToFastestDirectEvidence = route.canContributeToFastestDirectEvidence
        representativeCommand = references.representativeCommand
        relatedSourceFiles = references.sourceFiles
        relatedTestFiles = references.testFiles
        notes = references.notes
    }
}

/// Captures summary statistics required to validate, interpret, and reproduce a network route command matrix result.
public struct NetworkRouteCommandMatrixSummary: Codable, Equatable, Sendable {
    public let entryCount: Int
    public let validatorCount: Int
    public let runCount: Int
    public let localhostSmokeCount: Int
    public let probeCount: Int
    public let fastestDirectEvidenceCount: Int
    public let natCompatibilityOnlyCount: Int
    public let diagnosticOnlyCount: Int
    public let loopbackMeasurementCount: Int
    public let packetContractOnlyCount: Int
}

/// Captures report contents required to validate, interpret, and reproduce a network route command matrix result.
public struct NetworkRouteCommandMatrixReport: PrettyJSONCodable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let verdict: MeasurementVerdict
    public let summary: NetworkRouteCommandMatrixSummary
    public let entries: [NetworkRouteCommandMatrixEntry]
    public let notes: String
}

/// Builds the network route command matrix from source-backed entries so ownership and operational boundaries remain reviewable.
public enum NetworkRouteCommandMatrix {
    public static func report() -> NetworkRouteCommandMatrixReport {
        NetworkRouteCommandMatrixReport(
            id: "c05-network-route-command-matrix",
            title: "C05 network transport route and argument matrix",
            verdict: .partial,
            summary: summary(),
            entries: entries,
            notes: "Executable route-command crosswalk. It separates direct fastest-path " +
                "candidates from NAT, relay, diagnostics, loopback, and " +
                "localhost-only evidence."
        )
    }

    public static func summary() -> NetworkRouteCommandMatrixSummary {
        NetworkRouteCommandMatrixSummary(
            entryCount: entries.count,
            validatorCount: entries.filter { $0.kind == .validator }.count,
            runCount: entries.filter { $0.kind == .run }.count,
            localhostSmokeCount: entries.filter { $0.kind == .localhostSmoke }.count,
            probeCount: entries.filter { $0.kind == .probe }.count,
            fastestDirectEvidenceCount: entries
                .filter(\.canContributeToFastestDirectEvidence)
                .count,
            natCompatibilityOnlyCount: count(.natCompatibilityOnly),
            diagnosticOnlyCount: count(.diagnosticOnly),
            loopbackMeasurementCount: count(.loopbackMeasurement),
            packetContractOnlyCount: count(.packetContractOnly)
        )
    }

    public static let entries: [NetworkRouteCommandMatrixEntry] = [
        packetAndUdpRouteEntries,
        natAndPreflightEntries,
        directPeerValidationEntries,
        directPeerRunEntries
    ].flatMap { $0 }

    private static func count(_ boundary: NetworkRouteEvidenceBoundary) -> Int {
        entries.filter { $0.evidenceBoundary == boundary }.count
    }
}
