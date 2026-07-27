// Builds deterministic native-shell artifacts and verifies report and surface validation paths.
import Foundation
import OpenLolaContracts

/// Builds deterministic native-shell artifacts and verifies report and surface validation paths.
public enum NativeAppShellSyntheticSmoke {
    public static func run() -> NativeAppShellReport {
        report(
            id: "m13-native-app-shell-synthetic-smoke",
            title: "Synthetic M13 native app shell",
            capturedAt: "2026-05-02T00:00:00Z",
            notes: "Synthetic app-shell source validation only; runtime app launch, "
                + "permission prompts, and CLI metric comparison remain open."
        )
    }

    public static func placeholder() -> NativeAppShellReport {
        report(
            id: "m13-native-app-shell-placeholder",
            title: "Native app shell placeholder",
            capturedAt: "1970-01-01T00:00:00Z",
            notes: "Placeholder report used while the app refreshes "
                + "synthetic metrics asynchronously."
        )
    }

    private static func report(
        id: String,
        title: String,
        capturedAt: String,
        notes: String
) -> NativeAppShellReport {
    NativeAppShellReport(
        metadata: .init(id: id, title: title, capturedAt: capturedAt, runMode: .synthetic),
        evidence: .init(
            configuration: syntheticConfiguration(),
            metricsObserver: syntheticMetricsObserver(),
            realtimeBoundary: syntheticRealtimeBoundary(),
            permissions: syntheticPermissions(),
            smokeProbe: syntheticSmokeProbe()
        ),
        outcome: .init(verdict: .partial, notes: notes)
    )
}

private static func syntheticConfiguration() -> NativeAppConfigurationSnapshot {
    NativeAppConfigurationSnapshot(
        profile: .init(
            name: "Synthetic Headless Profile",
            audioDeviceSelection: "system-default",
            outputDeviceUID: nil
        ),
        audio: .init(sampleRateHertz: 48_000, framesPerBuffer: 32, requestedPlayoutTargetFrames: 32),
        features: .init(
            videoEnabled: true,
            showControlEnabled: true,
            lightingEnabled: false,
            createdByUI: true,
            immutableHandoff: true
        )
    )
}

private static func syntheticMetricsObserver() -> NativeMetricsObserverProfile {
    NativeMetricsObserverProfile(
        streamName: "synthetic-headless-metrics",
        readOnly: true,
        blocksRealtimePaths: false,
        publishesOnMainActor: true,
        pollingIntervalMilliseconds: 250
    )
}

private static func syntheticRealtimeBoundary() -> NativeRealtimeBoundaryReport {
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

private static func syntheticPermissions() -> NativePermissionReadiness {
    NativePermissionReadiness(
        microphoneUsageDescriptionPlanned: true,
        cameraUsageDescriptionPlanned: true,
        localNetworkUsageDescriptionPlanned: true,
        networkClientEntitlementPlanned: true
    )
}

private static func syntheticSmokeProbe() -> NativeAppShellSmokeProbe {
    NativeAppShellSmokeProbe(
        appTargetName: "open-lola-app",
        appTargetBuilds: true,
        runtimeSmokeProbed: false,
        cliMetricsReportId: "m10-integrated-av-partial-fixture",
        comparedWithCLIMetrics: false
    )
}
}
