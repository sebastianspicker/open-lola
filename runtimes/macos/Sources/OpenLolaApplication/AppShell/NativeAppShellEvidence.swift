import OpenLolaContracts
import OpenLolaSessionDomain
import OpenLolaEvidenceModels
import OpenLolaTransport
import OpenLolaMediaPlatform
// Defines the evidence models embedded in native app shell reports.
import Foundation

/// Records the evidence and outcome for native metrics observer profile.
public struct NativeMetricsObserverProfile: Codable, Equatable, Sendable {
    public var streamName: String
    public var readOnly: Bool
    public var blocksRealtimePaths: Bool
    public var publishesOnMainActor: Bool
    public var pollingIntervalMilliseconds: Double

    public init(
        streamName: String,
        readOnly: Bool,
        blocksRealtimePaths: Bool,
        publishesOnMainActor: Bool,
        pollingIntervalMilliseconds: Double
    ) {
        self.streamName = streamName
        self.readOnly = readOnly
        self.blocksRealtimePaths = blocksRealtimePaths
        self.publishesOnMainActor = publishesOnMainActor
        self.pollingIntervalMilliseconds = pollingIntervalMilliseconds
    }
}

/// Records the evidence and outcome for native realtime boundary report.
public struct NativeRealtimeBoundaryReport: Codable, Equatable, Sendable {
    public var uiOwnsAudioLane: Bool
    public var uiOwnsVideoLane: Bool
    public var uiOwnsControlLane: Bool
    public var realtimeDependsOnSwiftUILifecycle: Bool
    public var usesImmutableConfigSnapshots: Bool
    public var latencyChangeRequiresExplicitUserAction: Bool
    public var settingsPersistedOutsideCallback: Bool

    public init(
        uiOwnsAudioLane: Bool,
        uiOwnsVideoLane: Bool,
        uiOwnsControlLane: Bool,
        realtimeDependsOnSwiftUILifecycle: Bool,
        usesImmutableConfigSnapshots: Bool,
        latencyChangeRequiresExplicitUserAction: Bool,
        settingsPersistedOutsideCallback: Bool
    ) {
        self.uiOwnsAudioLane = uiOwnsAudioLane
        self.uiOwnsVideoLane = uiOwnsVideoLane
        self.uiOwnsControlLane = uiOwnsControlLane
        self.realtimeDependsOnSwiftUILifecycle = realtimeDependsOnSwiftUILifecycle
        self.usesImmutableConfigSnapshots = usesImmutableConfigSnapshots
        self.latencyChangeRequiresExplicitUserAction = latencyChangeRequiresExplicitUserAction
        self.settingsPersistedOutsideCallback = settingsPersistedOutsideCallback
    }
}

/// Defines the validated fields for native permission readiness.
public struct NativePermissionReadiness: Codable, Equatable, Sendable {
    public var microphoneUsageDescriptionPlanned: Bool
    public var cameraUsageDescriptionPlanned: Bool
    public var localNetworkUsageDescriptionPlanned: Bool
    public var networkClientEntitlementPlanned: Bool

    public init(
        microphoneUsageDescriptionPlanned: Bool,
        cameraUsageDescriptionPlanned: Bool,
        localNetworkUsageDescriptionPlanned: Bool,
        networkClientEntitlementPlanned: Bool
    ) {
        self.microphoneUsageDescriptionPlanned = microphoneUsageDescriptionPlanned
        self.cameraUsageDescriptionPlanned = cameraUsageDescriptionPlanned
        self.localNetworkUsageDescriptionPlanned = localNetworkUsageDescriptionPlanned
        self.networkClientEntitlementPlanned = networkClientEntitlementPlanned
    }
}

/// Defines the validated fields for native app shell smoke probe.
public struct NativeAppShellSmokeProbe: Codable, Equatable, Sendable {
    public var appTargetName: String
    public var appTargetBuilds: Bool
    public var runtimeSmokeProbed: Bool
    public var cliMetricsReportId: String
    public var comparedWithCLIMetrics: Bool

    public init(
        appTargetName: String,
        appTargetBuilds: Bool,
        runtimeSmokeProbed: Bool,
        cliMetricsReportId: String,
        comparedWithCLIMetrics: Bool
    ) {
        self.appTargetName = appTargetName
        self.appTargetBuilds = appTargetBuilds
        self.runtimeSmokeProbed = runtimeSmokeProbed
        self.cliMetricsReportId = cliMetricsReportId
        self.comparedWithCLIMetrics = comparedWithCLIMetrics
    }
}
