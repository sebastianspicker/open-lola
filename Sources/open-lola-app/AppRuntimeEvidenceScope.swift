import Foundation
import OpenLolaCore

enum AppRuntimeEvidenceScope {
    static let sessionTokenFileName = "session.token"

    enum TokenMatchResult: Equatable {
        case match
        case mismatch
        case absent
        case staleReport
        case readError(String)
    }

    enum EvidenceState: Equatable {
        case validated
        case missingEvidence
        case partialEvidence(String)
        case staleToken
        case staleReport
        case missingToken
        case tokenReadError(String)
    }

    static func directPeerSupervisorMetrics(
        executionKind: AppExecutionKind,
        validationExitCode: Int?,
        supervisorReportPath: String,
        currentSessionToken: String? = nil
    ) -> AppLatencyHeroMetrics? {
        guard executionKind == .directMacPeer, validationExitCode == 0 else {
            return nil
        }
        if currentSessionToken != nil,
           sessionTokenMatchResult(reportPath: supervisorReportPath, currentSessionToken: currentSessionToken) != .match {
            return nil
        }
        guard case .loaded(let metrics) = AppLatencyHeroMetrics.loadResult(fromSupervisorReportPath: supervisorReportPath) else {
            return nil
        }
        return metrics
    }

    static func hasValidatedRuntimeEvidence(
        executionKind: AppExecutionKind,
        validationExitCode: Int?,
        directPeerLatencyMetrics: AppLatencyHeroMetrics?,
        externalConnectorReport: ExternalConnectorSessionReport?,
        reportPath: String? = nil,
        currentSessionToken: String? = nil
    ) -> Bool {
        hasValidatedRuntimeEvidenceState(
            executionKind: executionKind,
            validationExitCode: validationExitCode,
            directPeerLatencyMetrics: directPeerLatencyMetrics,
            externalConnectorReport: externalConnectorReport,
            reportPath: reportPath,
            currentSessionToken: currentSessionToken
        ) == .validated
    }

    static func hasValidatedRuntimeEvidenceState(
        executionKind: AppExecutionKind,
        validationExitCode: Int?,
        directPeerLatencyMetrics: AppLatencyHeroMetrics?,
        externalConnectorReport: ExternalConnectorSessionReport?,
        reportPath: String? = nil,
        currentSessionToken: String? = nil
    ) -> EvidenceState {
        guard validationExitCode == 0 else {
            return .missingEvidence
        }
        if currentSessionToken != nil {
            guard let reportPath else {
                return .missingToken
            }
            switch sessionTokenMatchResult(reportPath: reportPath, currentSessionToken: currentSessionToken) {
            case .match:
                break
            case .mismatch:
                return .staleToken
            case .staleReport:
                return .staleReport
            case .absent:
                return .missingToken
            case .readError(let error):
                return .tokenReadError(error)
            }
        }
        switch executionKind {
        case .directMacPeer:
            guard let directPeerLatencyMetrics else {
                return .missingEvidence
            }
            return directPeerLatencyMetrics.isPartial
                ? .partialEvidence(directPeerLatencyMetrics.evidenceStatusMessage ?? "partial peer reports")
                : .validated
        case .windowsLoLa:
            guard let externalConnectorReport else {
                return .missingEvidence
            }
            return externalConnectorReport.verdict == .pass
                ? .validated
                : .partialEvidence("verdict \(externalConnectorReport.verdict.rawValue)")
        case .unsupportedExternalConnector:
            return .missingEvidence
        }
    }

    static func allowsDirectPeerCaptureEvidence(executionKind: AppExecutionKind) -> Bool {
        executionKind == .directMacPeer
    }

    static func writeSessionToken(_ token: String, reportPath: String) throws {
        let tokenURL = sessionTokenURL(reportPath: reportPath)
        try FileManager.default.createDirectory(
            at: tokenURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data(token.utf8).write(to: tokenURL, options: .atomic)
    }

    static func sessionTokenMatches(reportPath: String, currentSessionToken: String?) -> Bool {
        sessionTokenMatchResult(reportPath: reportPath, currentSessionToken: currentSessionToken) == .match
    }

    static func sessionTokenMatchResult(reportPath: String, currentSessionToken: String?) -> TokenMatchResult {
        guard let currentSessionToken,
              !currentSessionToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .mismatch
        }
        let tokenURL = sessionTokenURL(reportPath: reportPath)
        guard FileManager.default.fileExists(atPath: tokenURL.path) else {
            return .absent
        }
        let token: String
        do {
            token = try String(contentsOf: tokenURL, encoding: .utf8)
                .trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            return .readError(String(describing: error))
        }
        guard token == currentSessionToken else {
            return .mismatch
        }
        switch reportModificationIsCurrent(reportPath: reportPath, tokenURL: tokenURL) {
        case .current:
            return .match
        case .stale:
            return .staleReport
        case .unavailable(let error):
            return .readError(error)
        }
    }

    static func sessionTokenURL(reportPath: String) -> URL {
        URL(fileURLWithPath: reportPath)
            .deletingLastPathComponent()
            .appendingPathComponent(sessionTokenFileName)
    }

    private enum ReportFreshness {
        case current
        case stale
        case unavailable(String)
    }

    private static func reportModificationIsCurrent(reportPath: String, tokenURL: URL) -> ReportFreshness {
        let reportURL = URL(fileURLWithPath: reportPath)
        guard FileManager.default.fileExists(atPath: reportURL.path) else {
            return .current
        }
        do {
            let reportDate = try modificationDate(reportURL)
            let tokenDate = try modificationDate(tokenURL)
            return reportDate < tokenDate ? .stale : .current
        } catch {
            return .unavailable(String(describing: error))
        }
    }

    private static func modificationDate(_ url: URL) throws -> Date {
        let values = try url.resourceValues(forKeys: [.contentModificationDateKey])
        guard let date = values.contentModificationDate else {
            throw CocoaError(.fileReadUnknown)
        }
        return date
    }
}
