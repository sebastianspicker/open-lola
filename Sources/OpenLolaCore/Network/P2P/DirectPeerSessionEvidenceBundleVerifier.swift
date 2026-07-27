// Collects direct-peer session evidence, report values, and verdict context so serialized results retain the fields required for review and validation.
import CryptoKit
import Foundation

// swiftlint:disable:next type_name
/// Captures DirectPeerSessionVerifiedEvidenceArtifact evidence in a stable form for validation and serialized reporting.
public struct DirectPeerSessionVerifiedEvidenceArtifact: Equatable, Sendable {
    public let field: String
    public let path: String
    public let sha256: String

    public init(field: String, path: String, sha256: String) {
        self.field = field
        self.path = path
        self.sha256 = sha256
    }
}

// swiftlint:disable:next type_name
/// Represents DirectPeerSessionEvidenceBundleVerification values used by direct peer sessions.
public struct DirectPeerSessionEvidenceBundleVerification: Equatable, Sendable {
    public let reportID: String
    public let bundleRootPath: String
    public let verifiedArtifacts: [DirectPeerSessionVerifiedEvidenceArtifact]

    public init(
        reportID: String,
        bundleRootPath: String,
        verifiedArtifacts: [DirectPeerSessionVerifiedEvidenceArtifact]
    ) {
        self.reportID = reportID
        self.bundleRootPath = bundleRootPath
        self.verifiedArtifacts = verifiedArtifacts
    }
}

// swiftlint:disable:next type_name
/// Enumerates failures that callers must handle when working with direct peer sessions.
public enum DirectPeerSessionEvidenceBundleVerificationError: Error, Equatable, CustomStringConvertible, Sendable {
    case reportVerdictIsNotPass(MeasurementVerdict)
    case missingMeasuredEvidence
    case missingArtifact(field: String)
    case bundleRootNotFound(path: String)
    case artifactNotFound(field: String, path: String)
    case artifactReadFailed(field: String, path: String)
    case artifactHashMismatch(field: String, path: String, expected: String, actual: String)

    public var description: String {
        switch self {
        case .reportVerdictIsNotPass(let verdict):
            return "direct P2P evidence bundle verification requires PASS report, got \(verdict.rawValue)"
        case .missingMeasuredEvidence:
            return "direct P2P PASS report is missing measured evidence"
        case .missingArtifact(let field):
            return "direct P2P PASS report is missing artifact declaration for \(field)"
        case .bundleRootNotFound(let path):
            return "direct P2P evidence bundle root not found or not a directory: \(path)"
        case .artifactNotFound(let field, let path):
            return "direct P2P evidence artifact not found for \(field): \(path)"
        case .artifactReadFailed(let field, let path):
            return "direct P2P evidence artifact could not be read for \(field): \(path)"
        case .artifactHashMismatch(let field, let path, let expected, let actual):
            return "direct P2P evidence artifact hash mismatch for \(field) at \(path): " +
                "expected \(expected), got \(actual)"
        }
    }
}

/// Validates a passing session report and SHA-256 hashes its required evidence artifacts under the supplied bundle root.
public enum DirectPeerSessionEvidenceBundleVerifier {
    public static func verify(
        report: DirectPeerSessionReport,
        bundleRoot: URL
    ) throws -> DirectPeerSessionEvidenceBundleVerification {
        try report.validate()
        guard report.verdict == .pass else {
            throw DirectPeerSessionEvidenceBundleVerificationError.reportVerdictIsNotPass(report.verdict)
        }
        var isDirectory: ObjCBool = false
        let rootPath = bundleRoot.standardizedFileURL.path
        guard FileManager.default.fileExists(atPath: rootPath, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            throw DirectPeerSessionEvidenceBundleVerificationError.bundleRootNotFound(path: rootPath)
        }

        let verified = try passArtifactDeclarations(in: report).map {
            try verifyArtifactDeclaration($0, bundleRoot: bundleRoot)
        }

        return DirectPeerSessionEvidenceBundleVerification(
            reportID: report.id,
            bundleRootPath: rootPath,
            verifiedArtifacts: verified
        )
    }

    private static func passArtifactDeclarations(
        in report: DirectPeerSessionReport
    ) throws -> [(field: String, artifact: DirectPeerSessionEvidenceArtifact)] {
        guard let evidence = report.measuredEvidence else {
            throw DirectPeerSessionEvidenceBundleVerificationError.missingMeasuredEvidence
        }
        guard let packetCapture = evidence.packetCapture else {
            throw DirectPeerSessionEvidenceBundleVerificationError.missingArtifact(
                field: "measuredEvidence.packetCapture"
            )
        }
        guard let dscp = evidence.dscp else {
            throw DirectPeerSessionEvidenceBundleVerificationError.missingArtifact(
                field: "measuredEvidence.dscp"
            )
        }
        guard let clock = evidence.clock else {
            throw DirectPeerSessionEvidenceBundleVerificationError.missingArtifact(
                field: "measuredEvidence.clock"
            )
        }
        return [
            ("measuredEvidence.packetCapture", packetCapture),
            ("measuredEvidence.dscp.artifact", dscp.artifact),
            ("measuredEvidence.clock.artifact", clock.artifact)
        ]
    }

    private static func verifyArtifactDeclaration(
        _ declaration: (field: String, artifact: DirectPeerSessionEvidenceArtifact),
        bundleRoot: URL
    ) throws -> DirectPeerSessionVerifiedEvidenceArtifact {
        let artifactURL = artifactURL(for: declaration.artifact.path, bundleRoot: bundleRoot)
        let artifactPath = artifactURL.standardizedFileURL.path
        var artifactIsDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: artifactPath, isDirectory: &artifactIsDirectory),
              !artifactIsDirectory.boolValue else {
            throw DirectPeerSessionEvidenceBundleVerificationError.artifactNotFound(
                field: declaration.field,
                path: artifactPath
            )
        }
        let actual = try sha256Hex(
            at: artifactURL,
            field: declaration.field,
            path: artifactPath
        )
        let expected = declaration.artifact.sha256?.lowercased() ?? ""
        guard actual == expected else {
            throw DirectPeerSessionEvidenceBundleVerificationError.artifactHashMismatch(
                field: declaration.field,
                path: artifactPath,
                expected: expected,
                actual: actual
            )
        }
        return DirectPeerSessionVerifiedEvidenceArtifact(
            field: declaration.field,
            path: artifactPath,
            sha256: actual
        )
    }

    private static func artifactURL(for path: String, bundleRoot: URL) -> URL {
        if path.hasPrefix("/") {
            return URL(fileURLWithPath: path)
        }
        return bundleRoot.appendingPathComponent(path)
    }

    private static func sha256Hex(
        at url: URL,
        field: String,
        path: String
    ) throws -> String {
        let handle: FileHandle
        do {
            handle = try FileHandle(forReadingFrom: url)
        } catch {
            throw DirectPeerSessionEvidenceBundleVerificationError.artifactReadFailed(field: field, path: path)
        }
        defer {
            try? handle.close()
        }

        var hasher = SHA256()
        while true {
            let chunk: Data
            do {
                chunk = try handle.read(upToCount: 1_048_576) ?? Data()
            } catch {
                throw DirectPeerSessionEvidenceBundleVerificationError.artifactReadFailed(field: field, path: path)
            }
            if chunk.isEmpty {
                break
            }
            hasher.update(data: chunk)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }
}
