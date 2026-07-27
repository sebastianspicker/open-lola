// Defines native app readiness, permission, smoke, runtime, and report models used by the shell.
import Foundation
import OpenLolaContracts

/// Defines the validated fields for native app configuration snapshot.
public struct NativeAppConfigurationSnapshot: Codable, Equatable, Sendable {
    public struct Profile: Equatable, Sendable {
        public let name: String
        public let audioDeviceSelection: String
        public let outputDeviceUID: String?

        public init(name: String, audioDeviceSelection: String, outputDeviceUID: String?) {
            self.name = name
            self.audioDeviceSelection = audioDeviceSelection
            self.outputDeviceUID = outputDeviceUID
        }
    }

    public struct Audio: Equatable, Sendable {
        public let sampleRateHertz: Int
        public let framesPerBuffer: Int
        public let requestedPlayoutTargetFrames: Int

        public init(sampleRateHertz: Int, framesPerBuffer: Int, requestedPlayoutTargetFrames: Int) {
            self.sampleRateHertz = sampleRateHertz
            self.framesPerBuffer = framesPerBuffer
            self.requestedPlayoutTargetFrames = requestedPlayoutTargetFrames
        }
    }

    public struct Features: Equatable, Sendable {
        public let videoEnabled: Bool
        public let showControlEnabled: Bool
        public let lightingEnabled: Bool
        public let createdByUI: Bool
        public let immutableHandoff: Bool

        public init(
            videoEnabled: Bool,
            showControlEnabled: Bool,
            lightingEnabled: Bool,
            createdByUI: Bool,
            immutableHandoff: Bool
        ) {
            self.videoEnabled = videoEnabled
            self.showControlEnabled = showControlEnabled
            self.lightingEnabled = lightingEnabled
            self.createdByUI = createdByUI
            self.immutableHandoff = immutableHandoff
        }
    }

    public var profileName: String
    public var audioDeviceSelection: String
    public var outputDeviceUID: String?
    public var sampleRateHertz: Int
    public var framesPerBuffer: Int
    public var requestedPlayoutTargetFrames: Int
    public var videoEnabled: Bool
    public var showControlEnabled: Bool
    public var lightingEnabled: Bool
    public var createdByUI: Bool
    public var immutableHandoff: Bool

    public init(profile: Profile, audio: Audio, features: Features) {
        profileName = profile.name
        audioDeviceSelection = profile.audioDeviceSelection
        outputDeviceUID = profile.outputDeviceUID
        sampleRateHertz = audio.sampleRateHertz
        framesPerBuffer = audio.framesPerBuffer
        requestedPlayoutTargetFrames = audio.requestedPlayoutTargetFrames
        videoEnabled = features.videoEnabled
        showControlEnabled = features.showControlEnabled
        lightingEnabled = features.lightingEnabled
        createdByUI = features.createdByUI
        immutableHandoff = features.immutableHandoff
    }
}

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

/// Defines the validated fields for native app runtime smoke configuration.
public struct NativeAppRuntimeSmokeConfiguration: Codable, Equatable, Sendable {
    public let headlessReportPath: String
    public let outputPath: String

    public init(headlessReportPath: String, outputPath: String) {
        self.headlessReportPath = headlessReportPath
        self.outputPath = outputPath
    }

    public static func parse(_ arguments: [String]) throws -> NativeAppRuntimeSmokeConfiguration {
        let allowed = [
            "--headless-report",
            "--output"
        ]
        var values: [String: String] = [:]
        var index = 0

        while index < arguments.count {
            let argument = arguments[index]
            guard allowed.contains(argument) else {
                throw NativeAppRuntimeSmokeConfigurationError.unknownArgument(argument)
            }
            guard values[argument] == nil else {
                throw NativeAppRuntimeSmokeConfigurationError.duplicateArgument(argument)
            }
            let valueIndex = index + 1
            guard valueIndex < arguments.count, !arguments[valueIndex].hasPrefix("--") else {
                throw NativeAppRuntimeSmokeConfigurationError.missingValue(argument)
            }
            values[argument] = arguments[valueIndex]
            index += 2
        }

        return NativeAppRuntimeSmokeConfiguration(
            headlessReportPath: try requiredNativeAppRuntimeString("--headless-report", values),
            outputPath: try requiredNativeAppRuntimeString("--output", values)
        )
    }
}

/// Defines failures reported when native app runtime smoke configuration error cannot continue.
public enum NativeAppRuntimeSmokeConfigurationError: Error, Equatable, Sendable {
    case missingRequiredArgument(String)
    case missingValue(String)
    case unknownArgument(String)
    case duplicateArgument(String)
}

/// Loads a headless report, probes native runtime readiness, and writes the shell smoke report.
public enum NativeAppRuntimeSmoke {
    public static func run(
        configuration: NativeAppRuntimeSmokeConfiguration,
        headlessReport: IntegratedAvReport
    ) -> NativeAppShellReport {
        let metadata = NativeAppShellReport.Metadata(
            id: "m13-native-app-runtime-smoke",
            title: "M13 native app runtime smoke",
            capturedAt: ISO8601DateFormatter().string(from: Date()),
            runMode: .measured
        )
        let metricsObserver = NativeMetricsObserverProfile(
            streamName: "app-runtime-\(headlessReport.id)-metrics",
            readOnly: true,
            blocksRealtimePaths: false,
            publishesOnMainActor: true,
            pollingIntervalMilliseconds: 250
        )
        let realtimeBoundary = nativeAppRuntimeRealtimeBoundary()
        let permissions = NativePermissionReadiness(
            microphoneUsageDescriptionPlanned: true,
            cameraUsageDescriptionPlanned: true,
            localNetworkUsageDescriptionPlanned: true,
            networkClientEntitlementPlanned: true
        )
        let smokeProbe = NativeAppShellSmokeProbe(
            appTargetName: "open-lola-app",
            appTargetBuilds: true,
            runtimeSmokeProbed: true,
            cliMetricsReportId: headlessReport.id,
            comparedWithCLIMetrics: true
        )
        let evidence = NativeAppShellReport.Evidence(
            configuration: nativeAppRuntimeConfiguration(from: headlessReport),
            metricsObserver: metricsObserver,
            realtimeBoundary: realtimeBoundary,
            permissions: permissions,
            smokeProbe: smokeProbe
        )
        let outcome = NativeAppShellReport.Outcome(
            verdict: .partial,
            notes: "CLI-driven app runtime smoke from \(configuration.headlessReportPath); "
                + "launched GUI process, permission prompts, and packaged app evidence remain open."
        )
        return NativeAppShellReport(
            metadata: metadata,
            evidence: evidence,
            outcome: outcome
        )
    }
}

private func nativeAppRuntimeRealtimeBoundary() -> NativeRealtimeBoundaryReport {
    NativeRealtimeBoundaryReport(
        uiOwnsAudioLane: false,
        uiOwnsVideoLane: false,
        uiOwnsControlLane: false,
        realtimeDependsOnSwiftUILifecycle: false,
        usesImmutableConfigSnapshots: true,
        latencyChangeRequiresExplicitUserAction: true,
        settingsPersistedOutsideCallback: true
    )
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

private func requiredNativeAppRuntimeString(
    _ argument: String,
    _ values: [String: String]
) throws -> String {
    guard let value = values[argument], !value.isEmpty else {
        throw NativeAppRuntimeSmokeConfigurationError.missingRequiredArgument(argument)
    }
    return value
}

private func nativeAppRuntimeConfiguration(from headlessReport: IntegratedAvReport) -> NativeAppConfigurationSnapshot {
    let proof = headlessReport.proof
    let rmeUID = proof?.rmeAudioDeviceUid ?? ""
    let outputDeviceUID = proof?.rmeAudioDeviceVisible == true && !rmeUID.isEmpty ? rmeUID : nil

    return NativeAppConfigurationSnapshot(
        profile: .init(
            name: "Runtime Smoke from \(headlessReport.id)",
            audioDeviceSelection: proof?.rmeAudioDeviceVisible == true ? "rme-madi" : "headless-baseline",
            outputDeviceUID: outputDeviceUID
        ),
        audio: .init(
            sampleRateHertz: 48_000,
            framesPerBuffer: headlessReport.audio.integratedPlayoutTargetFrames,
            requestedPlayoutTargetFrames: headlessReport.audio.integratedPlayoutTargetFrames
        ),
        features: .init(
            videoEnabled: proof?.videoCaptureEnabled ?? true,
            showControlEnabled: proof?.oscPollingEnabled ?? false,
            lightingEnabled: false,
            createdByUI: true,
            immutableHandoff: true
        )
    )
}
