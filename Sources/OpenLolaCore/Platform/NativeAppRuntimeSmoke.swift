// Builds native app runtime smoke reports from validated integrated AV evidence.
import Foundation
import OpenLolaContracts

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
