import OpenLolaContracts
import OpenLolaSessionDomain
import OpenLolaEvidenceModels
import OpenLolaTransport
import OpenLolaMediaPlatform

/// Resolves the child artifacts a two-peer supervisor must use for aggregation and PASS validation.
///
/// Local children write directly to their planned report path and may choose an explicit receive-proof
/// output. SSH children are different: their artifacts must be SCP-collected before the supervisor
/// accepts them, so local paths never substitute for missing collected paths.
package enum DirectPeerTwoPeerChildArtifactResolver {
    package struct ResolvedArtifacts: Equatable, Sendable {
        package var reportPath: String
        package var receiveProofPath: String
        package var reportField: String
        package var receiveProofField: String

        package init(
            reportPath: String,
            receiveProofPath: String,
            reportField: String,
            receiveProofField: String
        ) {
            self.reportPath = reportPath
            self.receiveProofPath = receiveProofPath
            self.reportField = reportField
            self.receiveProofField = receiveProofField
        }
    }

    package static func resolve(
        _ result: DirectPeerTwoPeerLocalRunProcessResult
    ) throws -> ResolvedArtifacts {
        switch result.executionMode {
        case .local:
            return try resolveLocal(result)
        case .ssh:
            return try resolveCollected(result)
        }
    }

    package static func hasCompleteArtifacts(
        for result: DirectPeerTwoPeerLocalRunProcessResult
    ) -> Bool {
        (try? resolve(result)) != nil
    }

    private static func resolveLocal(
        _ result: DirectPeerTwoPeerLocalRunProcessResult
    ) throws -> ResolvedArtifacts {
        let reportPath = try nonEmpty(
            result.reportPath,
            otherwise: .passRequiresCollectedReports
        )
        let explicitProofPath = argumentValue("--rx-proof-output", in: result.command)
        let receiveProofPath = try nonEmpty(
            explicitProofPath ?? legacyReceiveProofPath(for: reportPath),
            otherwise: .passRequiresReceiveProofs
        )
        return ResolvedArtifacts(
            reportPath: reportPath,
            receiveProofPath: receiveProofPath,
            reportField: "processResults.\(result.peerID).reportPath",
            receiveProofField: explicitProofPath == nil
                ? "processResults.\(result.peerID).reportPath"
                : "processResults.\(result.peerID).command.--rx-proof-output"
        )
    }

    private static func resolveCollected(
        _ result: DirectPeerTwoPeerLocalRunProcessResult
    ) throws -> ResolvedArtifacts {
        let reportPath = try nonEmpty(
            result.collectedReportPath,
            otherwise: .passRequiresCollectedReports
        )
        let receiveProofPath = try nonEmpty(
            result.collectedReceiveProofPath,
            otherwise: .passRequiresReceiveProofs
        )
        return ResolvedArtifacts(
            reportPath: reportPath,
            receiveProofPath: receiveProofPath,
            reportField: "processResults.\(result.peerID).collectedReportPath",
            receiveProofField: "processResults.\(result.peerID).collectedReceiveProofPath"
        )
    }

    private static func nonEmpty(
        _ value: String?,
        otherwise error: DirectPeerTwoPeerLocalRunError
    ) throws -> String {
        guard let value, !value.isEmpty else {
            throw error
        }
        return value
    }

    private static func argumentValue(_ name: String, in arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: name), index + 1 < arguments.count else {
            return nil
        }
        let value = arguments[index + 1]
        return value.hasPrefix("--") || value.isEmpty ? nil : value
    }

    private static func legacyReceiveProofPath(for reportPath: String) -> String {
        if reportPath.hasSuffix(".json") {
            return String(reportPath.dropLast(5)) + "-rx-proof.json"
        }
        return reportPath + "-rx-proof.json"
    }
}
