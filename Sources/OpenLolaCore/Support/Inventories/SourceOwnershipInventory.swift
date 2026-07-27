// Defines ownership groups, runtime roles, risks, and report summaries so source moves retain named maintainers and validation gates.
import Foundation

/// Defines the finite structured result values recorded by source-ownership inventory artifacts for deterministic validation and report interpretation.
public enum SourceOwnershipGroup: String, Codable, Sendable {
    case coreSupport
    case protocolSession
    case audioCoreAudio
    case audioMadiRme
    case audioRealtime
    case audioRouting
    case networkUdp
    case networkP2P
    case networkNat
    case networkDiagnosticsAoip
    case externalConnectors
    case timingLatencyBuffering
    case videoCaptureTransport
    case controlLightingAtemOsc
    case evidenceReportsValidation
    case benchmarksPerformance
    case releaseProofPackaging
    case platformAppShell
    case cliApplication
    case releaseReadinessInventories
    case thirdPartyVendoredCode
}

/// Defines the finite structured result values recorded by source-ownership inventory artifacts for deterministic validation and report interpretation.
public enum SourceOwnershipRuntimeRole: String, Codable, Sendable {
    case sharedSupport
    case protocolContract
    case platformInventory
    case realtimeAudioPath
    case mediaRouting
    case networkTransport
    case routeProof
    case compatibilityPath
    case diagnosticGate
    case timingAndBuffering
    case videoPath
    case externalControlGate
    case evidenceContract
    case benchmarkContract
    case releaseGate
    case appShellBoundary
    case commandSurface
    case reviewInventory
    case thirdPartyVendorFence
}

/// Defines the finite structured result values recorded by source-ownership inventory artifacts for deterministic validation and report interpretation.
public enum SourceOwnershipRisk: String, Codable, Sendable {
    case low
    case medium
    case high
}

/// Defines the finite structured result values recorded by source-ownership inventory artifacts for deterministic validation and report interpretation.
public enum SourceOwnershipStatus: String, Codable, Sendable {
    case active
    case partiallyActive
    case deferred
    case needsHumanReview
}

/// Defines the finite structured result values recorded by source-ownership inventory artifacts for deterministic validation and report interpretation.
public enum SourceOwnershipConfidence: String, Codable, Sendable {
    case confirmed
    case likely
    case inferred
    case unclear
}

/// Captures inventory entry required to validate, interpret, and reproduce a source-ownership inventory result.
public struct SourceOwnershipEntry: Codable, Equatable, Sendable {
    public let group: SourceOwnershipGroup
    public let purpose: String
    public let currentSourcePaths: [String]
    public let proposedSourcePath: String
    public let runtimeRole: SourceOwnershipRuntimeRole
    public let owner: String
    public let relatedTestFiles: [String]
    public let relatedFixturePaths: [String]
    public let relatedDocs: [String]
    public let refactorRisk: SourceOwnershipRisk
    public let firstMoveCandidate: Bool
    public let movedInC02: Bool
    public let status: SourceOwnershipStatus
    public let confidence: SourceOwnershipConfidence
    public let validationCommands: [String]
    public let improvementRecommendation: String
}

/// Captures summary statistics required to validate, interpret, and reproduce a source-ownership inventory result.
public struct SourceOwnershipInventorySummary: Codable, Equatable, Sendable {
    public let groupCount: Int
    public let lowRiskCount: Int
    public let mediumRiskCount: Int
    public let highRiskCount: Int
    public let firstMoveCandidateCount: Int
    public let movedInC02Count: Int
}

/// Captures report contents required to validate, interpret, and reproduce a source-ownership inventory result.
public struct SourceOwnershipInventoryReport: PrettyJSONCodable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let verdict: MeasurementVerdict
    public let summary: SourceOwnershipInventorySummary
    public let entries: [SourceOwnershipEntry]
    public let notes: String
}

/// Defines the finite classification values recorded by source-ownership inventory artifacts for deterministic validation and report interpretation.
public enum SourceOwnershipPathMatchKind: String, Codable, Equatable, Sendable {
    case exactPath
    case ownedDirectory
    case proposedRoot
}

/// Captures structured result required to validate, interpret, and reproduce a source-ownership inventory result.
public struct SourceOwnershipPathResolution: Codable, Equatable, Sendable {
    public let entry: SourceOwnershipEntry
    public let matchKind: SourceOwnershipPathMatchKind
    public let matchedPath: String
}

/// Captures report contents required to validate, interpret, and reproduce a source-ownership inventory result.
public struct SourceOwnershipCoverageReport: Codable, Equatable, Sendable {
    public let unmatched: [String]
    public let fallbackOnly: [String]
}

/// Builds the source-ownership inventory from source-backed entries so ownership and operational boundaries remain reviewable.
public enum SourceOwnershipInventory {
    public static func report() -> SourceOwnershipInventoryReport {
        SourceOwnershipInventoryReport(
            id: "c02-source-ownership-inventory",
            title: "C02 core source ownership split inventory",
            verdict: .partial,
            summary: summary(),
            entries: entries,
            notes: "Executable source/test/doc ownership crosswalk. C02 moves only the low-risk Core support batch; " +
                "high-risk runtime groups remain explicitly deferred."
        )
    }

    public static func summary() -> SourceOwnershipInventorySummary {
        SourceOwnershipInventorySummary(
            groupCount: entries.count,
            lowRiskCount: count(.low),
            mediumRiskCount: count(.medium),
            highRiskCount: count(.high),
            firstMoveCandidateCount: entries.filter(\.firstMoveCandidate).count,
            movedInC02Count: entries.filter(\.movedInC02).count
        )
    }

    public static func entry(for group: SourceOwnershipGroup) -> SourceOwnershipEntry? {
        entries.first { $0.group == group }
    }

    public static func entry(forSourcePath path: String) -> SourceOwnershipEntry? {
        resolution(forSourcePath: path)?.entry
    }

    public static func resolution(forSourcePath path: String) -> SourceOwnershipPathResolution? {
        if let exact = entries.first(where: { $0.currentSourcePaths.contains(path) }) {
            return SourceOwnershipPathResolution(entry: exact, matchKind: .exactPath, matchedPath: path)
        }
        if let directory = entries.compactMap({ entry -> SourceOwnershipPathResolution? in
            guard let matchedPath = entry.currentSourcePaths.first(where: {
                $0.hasSuffix("/") && path.hasPrefix($0)
            }) else {
                return nil
            }
            return SourceOwnershipPathResolution(entry: entry, matchKind: .ownedDirectory, matchedPath: matchedPath)
        }).first {
            return directory
        }
        if let proposedRoot = entries.first(where: { path.hasPrefix($0.proposedSourcePath) }) {
            return SourceOwnershipPathResolution(
                entry: proposedRoot,
                matchKind: .proposedRoot,
                matchedPath: proposedRoot.proposedSourcePath
            )
        }
        return nil
    }

    public static func coverage(forSourcePaths paths: [String]) -> SourceOwnershipCoverageReport {
        var unmatched: [String] = []

        for path in paths.sorted() {
            guard resolution(forSourcePath: path) != nil else {
                unmatched.append(path)
                continue
            }
        }

        return SourceOwnershipCoverageReport(unmatched: unmatched, fallbackOnly: [])
    }

    private static func count(_ risk: SourceOwnershipRisk) -> Int {
        entries.filter { $0.refactorRisk == risk }.count
    }
}

/// Defines whether a source-ownership row is deferred or completed by the C02 move.
enum SourceOwnershipMoveState {
    case notSelected
    case completedC02

    var firstMoveCandidate: Bool {
        self == .completedC02
    }

    var movedInC02: Bool {
        self == .completedC02
    }
}

/// Holds the complete semantic input for one ownership-table row before it is materialized for reporting.
struct SourceOwnershipEntryInput {
    let group: SourceOwnershipGroup
    let purpose: String
    let currentSourcePaths: [String]
    let proposedSourcePath: String
    let runtimeRole: SourceOwnershipRuntimeRole
    let owner: String
    let relatedTestFiles: [String]
    let relatedFixturePaths: [String]
    let relatedDocs: [String]
    let refactorRisk: SourceOwnershipRisk
    let moveState: SourceOwnershipMoveState
    let status: SourceOwnershipStatus
    let confidence: SourceOwnershipConfidence
    let validationCommands: [String]
    let improvementRecommendation: String

    var entry: SourceOwnershipEntry {
        SourceOwnershipEntry(
            group: group,
            purpose: purpose,
            currentSourcePaths: currentSourcePaths,
            proposedSourcePath: proposedSourcePath,
            runtimeRole: runtimeRole,
            owner: owner,
            relatedTestFiles: relatedTestFiles,
            relatedFixturePaths: relatedFixturePaths,
            relatedDocs: relatedDocs,
            refactorRisk: refactorRisk,
            firstMoveCandidate: moveState.firstMoveCandidate,
            movedInC02: moveState.movedInC02,
            status: status,
            confidence: confidence,
            validationCommands: validationCommands,
            improvementRecommendation: improvementRecommendation
        )
    }
}

func own(_ input: SourceOwnershipEntryInput) -> SourceOwnershipEntry {
    input.entry
}
