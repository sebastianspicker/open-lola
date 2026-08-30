// Matches connector report kinds to app execution modes so artifacts from one connector workflow cannot validate another.
import OpenLolaCore

extension AppRuntimeEvidenceScope {
 static func externalConnectorReportMatchesExecutionKind(
 _ report: ExternalConnectorSessionReport,
 executionKind: AppExecutionKind
 ) -> Bool {
 switch executionKind {
 case .windowsLoLa:
 return report.connector == .lola
 case .externalConnector(let connector):
 return report.connector == connector
 case .directMacPeer, .unsupportedExternalConnector:
 return false
 }
 }

 static func externalConnectorReportMismatchMessage(
 _ report: ExternalConnectorSessionReport,
 executionKind: AppExecutionKind
 ) -> String? {
 switch executionKind {
 case .windowsLoLa:
 return report.connector == .lola ? nil : "Expected lola report, got \(report.connector.rawValue)"
 case .externalConnector(let connector):
 return report.connector == connector
 ? nil
 : "Expected \(connector.rawValue) report, got \(report.connector.rawValue)"
 case .directMacPeer, .unsupportedExternalConnector:
 return nil
 }
 }

 static func supportsExternalConnectorEvidence(executionKind: AppExecutionKind) -> Bool {
 switch executionKind {
 case .windowsLoLa, .externalConnector:
 return true
 case .directMacPeer, .unsupportedExternalConnector:
 return false
 }
 }

 static func allowsDirectPeerCaptureEvidence(executionKind: AppExecutionKind) -> Bool {
 executionKind == .directMacPeer
 }
}
