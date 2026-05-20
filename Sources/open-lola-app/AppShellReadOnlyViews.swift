import OpenLolaCore
import SwiftUI

struct AppShellOverviewView: View {
    let report: NativeAppShellReport

    var body: some View {
        GroupBox("Static checks") {
            VStack(alignment: .leading, spacing: AppSpacing.s) {
                MetricsGrid {
                    LabeledContent("Verdict", value: report.verdict.rawValue)
                    LabeledContent("Run mode", value: report.runMode.rawValue)
                    LabeledContent("App target", value: report.smokeProbe.appTargetName)
                    AppReadableMetric(label: "CLI baseline", value: report.smokeProbe.cliMetricsReportId, monospaced: true)
                }
                Text("Confirms app components are correctly assembled. Does not test network or audio devices.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }

        GroupBox("Build smoke") {
            MetricsGrid {
                LabeledContent("Target builds", value: yesNo(report.smokeProbe.appTargetBuilds))
                LabeledContent("Runtime smoke", value: yesNo(report.smokeProbe.runtimeSmokeProbed))
                LabeledContent("CLI comparison", value: yesNo(report.smokeProbe.comparedWithCLIMetrics))
            }
        }
    }
}

struct AppShellConfigurationView: View {
    let configuration: NativeAppConfigurationSnapshot

    var body: some View {
        GroupBox("Snapshot") {
            MetricsGrid {
                LabeledContent("Profile", value: configuration.profileName)
                AppReadableMetric(label: "Audio device", value: configuration.audioDeviceSelection, monospaced: true)
                LabeledContent("Sample rate", value: "\(configuration.sampleRateHertz) Hz")
                LabeledContent("Frames", value: "\(configuration.framesPerBuffer)")
                LabeledContent("Playout target", value: "\(configuration.requestedPlayoutTargetFrames)")
                LabeledContent("Immutable handoff", value: yesNo(configuration.immutableHandoff))
            }
        }

        GroupBox("Lanes") {
            MetricsGrid {
                LabeledContent("Video", value: yesNo(configuration.videoEnabled))
                LabeledContent("Show control", value: yesNo(configuration.showControlEnabled))
                LabeledContent("Lighting", value: yesNo(configuration.lightingEnabled))
            }
        }
    }
}

struct AppShellMetricsView: View {
    let observer: NativeMetricsObserverProfile

    var body: some View {
        GroupBox("Metrics observer") {
            MetricsGrid {
                LabeledContent("Stream", value: observer.streamName)
                LabeledContent("Read only", value: yesNo(observer.readOnly))
                LabeledContent("Blocks realtime", value: yesNo(observer.blocksRealtimePaths))
                LabeledContent("Main actor publish", value: yesNo(observer.publishesOnMainActor))
                LabeledContent("Polling", value: "\(observer.pollingIntervalMilliseconds) ms")
            }
        }
    }
}

struct AppShellBoundariesView: View {
    let boundary: NativeRealtimeBoundaryReport

    var body: some View {
        GroupBox("Lane ownership") {
            MetricsGrid {
                LabeledContent("UI owns audio", value: yesNo(boundary.uiOwnsAudioLane))
                LabeledContent("UI owns video", value: yesNo(boundary.uiOwnsVideoLane))
                LabeledContent("UI owns control", value: yesNo(boundary.uiOwnsControlLane))
                LabeledContent("SwiftUI lifecycle", value: yesNo(boundary.realtimeDependsOnSwiftUILifecycle))
            }
        }

        GroupBox("Safety guarantees") {
            MetricsGrid {
                LabeledContent("Immutable snapshots", value: yesNo(boundary.usesImmutableConfigSnapshots))
                LabeledContent("Explicit latency change", value: yesNo(boundary.latencyChangeRequiresExplicitUserAction))
                LabeledContent("Settings outside callback", value: yesNo(boundary.settingsPersistedOutsideCallback))
            }
        }
    }
}

struct AppShellPermissionsView: View {
    let permissions: NativePermissionReadiness

    var body: some View {
        GroupBox("Permission entitlements") {
            MetricsGrid {
                LabeledContent("Microphone", value: yesNo(permissions.microphoneUsageDescriptionPlanned))
                LabeledContent("Camera", value: yesNo(permissions.cameraUsageDescriptionPlanned))
                LabeledContent("Local network", value: yesNo(permissions.localNetworkUsageDescriptionPlanned))
                LabeledContent("Network client", value: yesNo(permissions.networkClientEntitlementPlanned))
            }
        }
    }
}

struct AppShellProbeView: View {
    let report: NativeAppShellReport
    let plan: NativeAppShellLaunchProbePlan

    var body: some View {
        GroupBox("Surface Probe") {
            MetricsGrid {
                AppReadableMetric(label: "Source report", value: report.id, monospaced: true)
                AppReadableMetric(label: "Build", value: plan.buildCommand, monospaced: true)
                AppReadableMetric(label: "Launch", value: plan.launchCommand, monospaced: true)
                LabeledContent("Visible window required", value: yesNo(plan.requiresHumanVisibleWindow))
                LabeledContent("Screenshot/log recorded", value: yesNo(plan.recordsScreenshotOrLog))
                LabeledContent("Blocks field-ready PASS", value: yesNo(plan.blocksFieldReadyPass))
            }
        }
    }
}
