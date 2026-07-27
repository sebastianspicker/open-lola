// Validates NativeAppShellReportValidation acceptance rules, keeping failure policy close to its contract rather than the runtime path.
import Foundation

extension NativeAppShellReport {
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
        try validatePassSmokeProbe()
        try validatePassConfigurationBoundary()
        try validatePassMetricsObserver()
        try validatePassRealtimeBoundary()
    }

    private func validatePassSmokeProbe() throws {
        guard smokeProbe.appTargetBuilds else {
            throw NativeAppShellValidationError.passWithoutAppTargetBuild
        }
        guard smokeProbe.runtimeSmokeProbed else {
            throw NativeAppShellValidationError.passWithoutRuntimeSmoke
        }
        guard smokeProbe.comparedWithCLIMetrics else {
            throw NativeAppShellValidationError.passWithoutCLIMetricsComparison
        }
    }

    private func validatePassConfigurationBoundary() throws {
        guard configuration.immutableHandoff, realtimeBoundary.usesImmutableConfigSnapshots else {
            throw NativeAppShellValidationError.passWithoutImmutableConfigSnapshot
        }
    }

    private func validatePassMetricsObserver() throws {
        guard metricsObserver.readOnly else {
            throw NativeAppShellValidationError.passWithoutReadOnlyMetricsObserver
        }
        guard !metricsObserver.blocksRealtimePaths else {
            throw NativeAppShellValidationError.passWithBlockingMetricsObserver
        }
    }

    private func validatePassRealtimeBoundary() throws {
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
