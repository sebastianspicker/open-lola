import Foundation
import OpenLolaContracts

public struct NativeAppConfigurationSnapshot: Codable, Equatable, Sendable {
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

    public init(
        profileName: String,
        audioDeviceSelection: String,
        outputDeviceUID: String?,
        sampleRateHertz: Int,
        framesPerBuffer: Int,
        requestedPlayoutTargetFrames: Int,
        videoEnabled: Bool,
        showControlEnabled: Bool,
        lightingEnabled: Bool,
        createdByUI: Bool,
        immutableHandoff: Bool
    ) {
        self.profileName = profileName
        self.audioDeviceSelection = audioDeviceSelection
        self.outputDeviceUID = outputDeviceUID
        self.sampleRateHertz = sampleRateHertz
        self.framesPerBuffer = framesPerBuffer
        self.requestedPlayoutTargetFrames = requestedPlayoutTargetFrames
        self.videoEnabled = videoEnabled
        self.showControlEnabled = showControlEnabled
        self.lightingEnabled = lightingEnabled
        self.createdByUI = createdByUI
        self.immutableHandoff = immutableHandoff
    }
}

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

public struct NativeAppShellReport: ReportValidatingArtifact, Codable, Equatable, Sendable {
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

    public init(
        id: String,
        title: String,
        capturedAt: String,
        runMode: ReportRunMode,
        configuration: NativeAppConfigurationSnapshot,
        metricsObserver: NativeMetricsObserverProfile,
        realtimeBoundary: NativeRealtimeBoundaryReport,
        permissions: NativePermissionReadiness,
        smokeProbe: NativeAppShellSmokeProbe,
        verdict: MeasurementVerdict,
        notes: String
    ) {
        self.id = id
        self.title = title
        self.capturedAt = capturedAt
        self.runMode = runMode
        self.configuration = configuration
        self.metricsObserver = metricsObserver
        self.realtimeBoundary = realtimeBoundary
        self.permissions = permissions
        self.smokeProbe = smokeProbe
        self.verdict = verdict
        self.notes = notes
    }

    public static func decode(from data: Data) throws -> NativeAppShellReport {
        try JSONDecoder().decode(NativeAppShellReport.self, from: data)
    }

    public static func placeholder() -> NativeAppShellReport {
        NativeAppShellSyntheticSmoke.placeholder()
    }

    public func validate() throws {
        try validateIdentity()
        try validateConfiguration()
        try validateMetricsObserver()
        try validateSmokeProbe()
        try validatePassVerdict()
    }

    private func validateIdentity() throws {
        try requireNativeAppNonEmpty(id, "id")
        try requireNativeAppNonEmpty(title, "title")
        try requireNativeAppNonEmpty(capturedAt, "capturedAt")
        try requireNativeAppNonEmpty(notes, "notes")
    }

    private func validateConfiguration() throws {
        try requireNativeAppNonEmpty(configuration.profileName, "configuration.profileName")
        try requireNativeAppNonEmpty(configuration.audioDeviceSelection, "configuration.audioDeviceSelection")
        if let outputDeviceUID = configuration.outputDeviceUID {
            try requireNativeAppNonEmpty(outputDeviceUID, "configuration.outputDeviceUID")
        }
        try requireNativeAppPositive(configuration.sampleRateHertz, "configuration.sampleRateHertz")
        try requireNativeAppPositive(configuration.framesPerBuffer, "configuration.framesPerBuffer")
        try requireNativeAppPositive(
            configuration.requestedPlayoutTargetFrames,
            "configuration.requestedPlayoutTargetFrames"
        )
    }

    private func validateMetricsObserver() throws {
        try requireNativeAppNonEmpty(metricsObserver.streamName, "metricsObserver.streamName")
        try requireNativeAppNonNegative(
            metricsObserver.pollingIntervalMilliseconds,
            "metricsObserver.pollingIntervalMilliseconds"
        )
    }

    private func validateSmokeProbe() throws {
        try requireNativeAppNonEmpty(smokeProbe.appTargetName, "smokeProbe.appTargetName")
        try requireNativeAppNonEmpty(smokeProbe.cliMetricsReportId, "smokeProbe.cliMetricsReportId")
    }

    private func validatePassVerdict() throws {
        guard verdict == .pass else {
            return
        }
        guard smokeProbe.appTargetBuilds else {
            throw NativeAppShellValidationError.passWithoutAppTargetBuild
        }
        guard smokeProbe.runtimeSmokeProbed else {
            throw NativeAppShellValidationError.passWithoutRuntimeSmoke
        }
        guard smokeProbe.comparedWithCLIMetrics else {
            throw NativeAppShellValidationError.passWithoutCLIMetricsComparison
        }
        guard configuration.immutableHandoff, realtimeBoundary.usesImmutableConfigSnapshots else {
            throw NativeAppShellValidationError.passWithoutImmutableConfigSnapshot
        }
        guard metricsObserver.readOnly else {
            throw NativeAppShellValidationError.passWithoutReadOnlyMetricsObserver
        }
        guard !metricsObserver.blocksRealtimePaths else {
            throw NativeAppShellValidationError.passWithBlockingMetricsObserver
        }
        if realtimeBoundary.uiOwnsAudioLane {
            throw NativeAppShellValidationError.passWithUIRealtimeOwnership("audio")
        }
        if realtimeBoundary.uiOwnsVideoLane {
            throw NativeAppShellValidationError.passWithUIRealtimeOwnership("video")
        }
        if realtimeBoundary.uiOwnsControlLane {
            throw NativeAppShellValidationError.passWithUIRealtimeOwnership("control")
        }
        guard !realtimeBoundary.realtimeDependsOnSwiftUILifecycle else {
            throw NativeAppShellValidationError.passWithSwiftUILifecycleDependency
        }
        guard realtimeBoundary.latencyChangeRequiresExplicitUserAction else {
            throw NativeAppShellValidationError.passAllowsSilentLatencyChange
        }
        guard realtimeBoundary.settingsPersistedOutsideCallback else {
            throw NativeAppShellValidationError.passPersistsSettingsInCallback
        }
    }
}

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
            "--output",
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

public enum NativeAppRuntimeSmokeConfigurationError: Error, Equatable, Sendable {
    case missingRequiredArgument(String)
    case missingValue(String)
    case unknownArgument(String)
    case duplicateArgument(String)
}

public enum NativeAppRuntimeSmoke {
    public static func run(
        configuration: NativeAppRuntimeSmokeConfiguration,
        headlessReport: IntegratedAvReport
    ) -> NativeAppShellReport {
        NativeAppShellReport(
            id: "m13-native-app-runtime-smoke",
            title: "M13 native app runtime smoke",
            capturedAt: ISO8601DateFormatter().string(from: Date()),
            runMode: .measured,
            configuration: nativeAppRuntimeConfiguration(from: headlessReport),
            metricsObserver: NativeMetricsObserverProfile(
                streamName: "app-runtime-\(headlessReport.id)-metrics",
                readOnly: true,
                blocksRealtimePaths: false,
                publishesOnMainActor: true,
                pollingIntervalMilliseconds: 250
            ),
            realtimeBoundary: NativeRealtimeBoundaryReport(
                uiOwnsAudioLane: false,
                uiOwnsVideoLane: false,
                uiOwnsControlLane: false,
                realtimeDependsOnSwiftUILifecycle: false,
                usesImmutableConfigSnapshots: true,
                latencyChangeRequiresExplicitUserAction: true,
                settingsPersistedOutsideCallback: true
            ),
            permissions: NativePermissionReadiness(
                microphoneUsageDescriptionPlanned: true,
                cameraUsageDescriptionPlanned: true,
                localNetworkUsageDescriptionPlanned: true,
                networkClientEntitlementPlanned: true
            ),
            smokeProbe: NativeAppShellSmokeProbe(
                appTargetName: "open-lola-app",
                appTargetBuilds: true,
                runtimeSmokeProbed: true,
                cliMetricsReportId: headlessReport.id,
                comparedWithCLIMetrics: true
            ),
            verdict: .partial,
            notes: "CLI-driven app runtime smoke from \(configuration.headlessReportPath); launched GUI process, permission prompts, and packaged app evidence remain open."
        )
    }
}

public enum NativeAppShellSyntheticSmoke {
    public static func run() -> NativeAppShellReport {
        report(
            id: "m13-native-app-shell-synthetic-smoke",
            title: "Synthetic M13 native app shell",
            capturedAt: "2026-05-02T00:00:00Z",
            notes: "Synthetic app-shell source validation only; runtime app launch, permission prompts, and CLI metric comparison remain open."
        )
    }

    public static func placeholder() -> NativeAppShellReport {
        report(
            id: "m13-native-app-shell-placeholder",
            title: "Native app shell placeholder",
            capturedAt: "1970-01-01T00:00:00Z",
            notes: "Placeholder report used while the app refreshes synthetic metrics asynchronously."
        )
    }

    private static func report(
        id: String,
        title: String,
        capturedAt: String,
        notes: String
    ) -> NativeAppShellReport {
        NativeAppShellReport(
            id: id,
            title: title,
            capturedAt: capturedAt,
            runMode: .synthetic,
            configuration: NativeAppConfigurationSnapshot(
                profileName: "Synthetic Headless Profile",
                audioDeviceSelection: "system-default",
                outputDeviceUID: nil,
                sampleRateHertz: 48_000,
                framesPerBuffer: 32,
                requestedPlayoutTargetFrames: 32,
                videoEnabled: true,
                showControlEnabled: true,
                lightingEnabled: false,
                createdByUI: true,
                immutableHandoff: true
            ),
            metricsObserver: NativeMetricsObserverProfile(
                streamName: "synthetic-headless-metrics",
                readOnly: true,
                blocksRealtimePaths: false,
                publishesOnMainActor: true,
                pollingIntervalMilliseconds: 250
            ),
            realtimeBoundary: NativeRealtimeBoundaryReport(
                uiOwnsAudioLane: false,
                uiOwnsVideoLane: false,
                uiOwnsControlLane: false,
                realtimeDependsOnSwiftUILifecycle: false,
                usesImmutableConfigSnapshots: true,
                latencyChangeRequiresExplicitUserAction: true,
                settingsPersistedOutsideCallback: true
            ),
            permissions: NativePermissionReadiness(
                microphoneUsageDescriptionPlanned: true,
                cameraUsageDescriptionPlanned: true,
                localNetworkUsageDescriptionPlanned: true,
                networkClientEntitlementPlanned: true
            ),
            smokeProbe: NativeAppShellSmokeProbe(
                appTargetName: "open-lola-app",
                appTargetBuilds: true,
                runtimeSmokeProbed: false,
                cliMetricsReportId: "m10-integrated-av-partial-fixture",
                comparedWithCLIMetrics: false
            ),
            verdict: .partial,
            notes: notes
        )
    }
}

private func requireNativeAppNonEmpty(_ value: String, _ field: String) throws {
    if value.isEmpty {
        throw NativeAppShellValidationError.emptyField(field)
    }
}

private func requireNativeAppPositive(_ value: Int, _ field: String) throws {
    if value <= 0 {
        throw NativeAppShellValidationError.nonPositiveField(field)
    }
}

private func requireNativeAppNonNegative(_ value: Double, _ field: String) throws {
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
        profileName: "Runtime Smoke from \(headlessReport.id)",
        audioDeviceSelection: proof?.rmeAudioDeviceVisible == true ? "rme-madi" : "headless-baseline",
        outputDeviceUID: outputDeviceUID,
        sampleRateHertz: 48_000,
        framesPerBuffer: headlessReport.audio.integratedPlayoutTargetFrames,
        requestedPlayoutTargetFrames: headlessReport.audio.integratedPlayoutTargetFrames,
        videoEnabled: proof?.videoCaptureEnabled ?? true,
        showControlEnabled: proof?.oscPollingEnabled ?? false,
        lightingEnabled: false,
        createdByUI: true,
        immutableHandoff: true
    )
}
