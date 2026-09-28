import OpenLolaContracts
import OpenLolaSessionDomain
import OpenLolaEvidenceModels
import OpenLolaTransport
import OpenLolaMediaPlatform
// Defines the native app shell report contract and its validation errors.
import Foundation
import OpenLolaContracts

/// Defines failures reported when native app shell validation error cannot continue.
public enum NativeAppShellValidationError: Error, Equatable, Sendable {
    case emptyField(String)
    case nonPositiveField(String)
    case negativeField(String)
    case nonFiniteField(String)
    case passWithoutAppTargetBuild
    case passWithoutRuntimeSmoke
    case passWithoutCLIMetricsComparison
    case passWithoutImmutableConfigSnapshot
    case passWithoutReadOnlyMetricsObserver
    case passWithBlockingMetricsObserver
    case passWithUIRealtimeOwnership(String)
    case passWithSwiftUILifecycleDependency
    case passAllowsSilentLatencyChange
    case passPersistsSettingsInCallback
}

/// Records the evidence and outcome for native app shell report.
public struct NativeAppShellReport: ReportValidatingArtifact, Codable, Equatable, Sendable {
    public enum MetadataDomain {}
    public typealias Metadata = ImmutableReportIdentity<MetadataDomain>

    public struct Evidence: Equatable, Sendable {
        public let configuration: NativeAppConfigurationSnapshot
        public let metricsObserver: NativeMetricsObserverProfile
        public let realtimeBoundary: NativeRealtimeBoundaryReport
        public let permissions: NativePermissionReadiness
        public let smokeProbe: NativeAppShellSmokeProbe

        public init(
            configuration: NativeAppConfigurationSnapshot,
            metricsObserver: NativeMetricsObserverProfile,
            realtimeBoundary: NativeRealtimeBoundaryReport,
            permissions: NativePermissionReadiness,
            smokeProbe: NativeAppShellSmokeProbe
        ) {
            self.configuration = configuration
            self.metricsObserver = metricsObserver
            self.realtimeBoundary = realtimeBoundary
            self.permissions = permissions
            self.smokeProbe = smokeProbe
        }
    }

    public enum OutcomeDomain {}
    public typealias Outcome = ImmutableReportOutcome<OutcomeDomain>

    public var id: String
    public var title: String
    public var capturedAt: String
    public var runMode: ReportRunMode
    public var configuration: NativeAppConfigurationSnapshot
    public var metricsObserver: NativeMetricsObserverProfile
    public var realtimeBoundary: NativeRealtimeBoundaryReport
    public var permissions: NativePermissionReadiness
    public var smokeProbe: NativeAppShellSmokeProbe
    public var verdict: MeasurementVerdict
    public var notes: String

    public init(metadata: Metadata, evidence: Evidence, outcome: Outcome) {
        id = metadata.id
        title = metadata.title
        capturedAt = metadata.capturedAt
        runMode = metadata.runMode
        configuration = evidence.configuration
        metricsObserver = evidence.metricsObserver
        realtimeBoundary = evidence.realtimeBoundary
        permissions = evidence.permissions
        smokeProbe = evidence.smokeProbe
        verdict = outcome.verdict
        notes = outcome.notes
    }

    public static func decode(from data: Data) throws -> NativeAppShellReport {
        try JSONDecoder().decode(NativeAppShellReport.self, from: data)
    }

    public static func placeholder() -> NativeAppShellReport {
        NativeAppShellSyntheticSmoke.placeholder()
    }

}

func requireNativeAppNonEmpty(_ value: String, _ field: String) throws {
    if value.isEmpty {
        throw NativeAppShellValidationError.emptyField(field)
    }
}

func requireNativeAppPositive(_ value: Int, _ field: String) throws {
    if value <= 0 {
        throw NativeAppShellValidationError.nonPositiveField(field)
    }
}

func requireNativeAppNonNegative(_ value: Double, _ field: String) throws {
    try requireNativeAppFinite(value, field)
    if value < 0 {
        throw NativeAppShellValidationError.negativeField(field)
    }
}

private func requireNativeAppFinite(_ value: Double, _ field: String) throws {
    if !value.isFinite {
        throw NativeAppShellValidationError.nonFiniteField(field)
    }
}
