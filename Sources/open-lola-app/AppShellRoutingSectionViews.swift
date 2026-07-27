// Renders AppShellRoutingSectionViews in the operator interface, keeping SwiftUI presentation distinct from execution and persistence state.
import OpenLolaCore
import SwiftUI

struct AppStreamsSectionView: View {
    @Binding var operatorSurface: NativeAppShellOperatorPrototypeState
    let previewState: AppPreviewReceiverState
    let operatorPlan: AppOperatorPrototypePlan
    let captureReport: LoLaCompatibilityCaptureReport?

    var body: some View {
        let remoteEvidence = AppRemoteEvidenceStatusPolicy.make(
            plan: operatorPlan,
            captureReport: captureReport
        )
        LazyVGrid(columns: appShellTwoColumns, alignment: .leading, spacing: AppSpacing.m) {
            AppPreviewReceiverView(operatorSurface: $operatorSurface, previewState: previewState)
            DesignPanel(title: "Remote Evidence", systemImage: "video.badge.ellipsis") {
                MetricsGrid {
                    AppReadableMetric(label: "Runtime state", value: remoteEvidence.runtimeState)
                    AppReadableMetric(label: "Evidence", value: remoteEvidence.evidence)
                    LabeledContent("Packets", value: remoteEvidence.packetCount)
                }
            }
        }
    }
}

struct AppRemoteEvidenceStatusModel: Equatable {
    let runtimeState: String
    let evidence: String
    let packetCount: String
}

enum AppRemoteEvidenceStatusPolicy {
    static func make(
        plan: AppOperatorPrototypePlan,
        captureReport: LoLaCompatibilityCaptureReport?
    ) -> AppRemoteEvidenceStatusModel {
        let runtimeState: String
        switch plan.sessionMode {
        case .windowsLoLa:
            runtimeState = "Windows LoLa connector report only"
        case .jackTrip, .ultraGrid:
            runtimeState = "\(plan.sessionMode.displayName) connector report only"
        case .directMacPeer:
            runtimeState = plan.macB == nil
                ? AppCopyVocabulary.remotePlanUnavailable
                : AppCopyVocabulary.remotePlanOnlyNoReceivedMedia
        }
        return AppRemoteEvidenceStatusModel(
            runtimeState: runtimeState,
            evidence: captureReport == nil
                ? AppCopyVocabulary.noRemotePacketEvidenceMeasured
                : AppCopyVocabulary.packetCaptureReportLoaded,
            packetCount: captureReport.map { "\($0.summary.packetCount)" } ?? "Not measured"
        )
    }
}

struct AppRoutingSectionView: View {
    @Binding var operatorSurface: NativeAppShellOperatorPrototypeState
    let operatorPlan: AppOperatorPrototypePlan
    let appSettings: AppSettings
    let inputsLocked: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.m) {
            if operatorSurface.sessionMode == .windowsLoLa {
                AppWindowsLoLaRoutingSummary(operatorSurface: $operatorSurface)
            } else if operatorSurface.sessionMode.externalConnectorKind != nil {
                AppExternalConnectorRoutingSummary(operatorSurface: $operatorSurface)
            } else {
                AppPeerNetworkFieldsView(operatorSurface: $operatorSurface, appSettings: appSettings)
                    .disabled(inputsLocked)
                    .help(inputsLocked ? AppRuntimeInputLock.lockedHelp : "")
                AppOperatorArtifactsView(
                    operatorSurface: $operatorSurface,
                    appSettings: appSettings,
                    inputsLocked: inputsLocked
                )
            }
        }
    }
}

private struct AppExternalConnectorRoutingSummary: View {
    @Binding var operatorSurface: NativeAppShellOperatorPrototypeState

    var body: some View {
        let fields = externalFields
        DesignPanel(
            title: "\(operatorSurface.sessionMode.displayName) connector",
            systemImage: "antenna.radiowaves.left.and.right"
        ) {
            MetricsGrid {
                AppReadableMetric(label: "Local host", value: fields.localHost, monospaced: true)
                AppReadableMetric(label: "Peer host", value: fields.peerHost, monospaced: true)
                LabeledContent("Role", value: fields.role.rawValue)
                LabeledContent("Media", value: fields.mediaMode.cliValue)
                AppReadableMetric(label: "Report", value: fields.outputPath, monospaced: true)
            }
        }
    }

    private var externalFields: NativeAppShellExternalConnectorPeerFields {
        switch operatorSurface.sessionMode.externalConnectorKind {
        case .jackTrip:
            return operatorSurface.jackTripPeerFields
        case .mvtpUltraGrid:
            return operatorSurface.ultraGridPeerFields
        case .lola, .none:
            return .jackTripAppDefault
        }
    }
}

private struct AppWindowsLoLaRoutingSummary: View {
    @Binding var operatorSurface: NativeAppShellOperatorPrototypeState

    var body: some View {
        DesignPanel(title: "Windows LoLa connector", systemImage: "display.and.arrow.down") {
            MetricsGrid {
                AppReadableMetric(
                    label: "Local host",
                    value: operatorSurface.windowsLoLaPeerFields.localHost,
                    monospaced: true
                )
                AppReadableMetric(
                    label: "Windows host",
                    value: operatorSurface.windowsLoLaPeerFields.windowsHost,
                    monospaced: true
                )
                LabeledContent("Role", value: operatorSurface.windowsLoLaPeerFields.role.rawValue)
                LabeledContent("Media", value: operatorSurface.windowsLoLaPeerFields.mediaMode.cliValue)
                LabeledContent("Payload", value: operatorSurface.windowsLoLaPeerFields.payloadMode.rawValue)
                AppReadableMetric(
                    label: "Report",
                    value: operatorSurface.windowsLoLaPeerFields.outputPath,
                    monospaced: true
                )
            }
        }
    }
}

struct AppShellSettingsSummaryView: View {
    @Environment(\.openSettings) private var openSettings

    let operatorSurface: NativeAppShellOperatorPrototypeState
    let executionSettings: NativeAppShellExecutionSettings
    let executionController: AppExecutionController
    let appSettings: AppSettings

    var body: some View {
        DesignPanel(title: "Settings", systemImage: "gearshape") {
            VStack(alignment: .leading, spacing: AppSpacing.s) {
                MetricsGrid {
                    LabeledContent("Workflow", value: operatorSurface.sessionMode.displayName)
                    LabeledContent("Controls", value: operatorSurface.controlMode.displayName)
                    LabeledContent("Running", value: yesNo(executionController.isRunning))
                    AppReadableMetric(label: "Executable", value: executablePath, monospaced: true)
                    AppReadableMetric(label: "Plan", value: executionSettings.planPath, monospaced: true)
                    AppReadableMetric(label: "Report", value: reportPath, monospaced: true)
                }

                Button {
                    openSettings()
                } label: {
                    Label("Open Settings", systemImage: "gearshape")
                }
                .buttonStyle(.borderedProminent)
                .help("Open the macOS Settings window")
            }
        }
    }

    private var executablePath: String {
        switch operatorSurface.sessionMode {
        case .directMacPeer:
            return operatorSurface.directPeerCommandFields.executablePath
        case .windowsLoLa:
            return operatorSurface.windowsLoLaPeerFields.executablePath
        case .jackTrip, .ultraGrid:
            return operatorSurface.sessionMode == .jackTrip
                ? operatorSurface.jackTripPeerFields.executablePath
                : operatorSurface.ultraGridPeerFields.executablePath
        }
    }

    private var reportPath: String {
        switch operatorSurface.sessionMode {
        case .windowsLoLa:
            return operatorSurface.windowsLoLaPeerFields.outputPath
        case .jackTrip:
            return operatorSurface.jackTripPeerFields.outputPath
        case .ultraGrid:
            return operatorSurface.ultraGridPeerFields.outputPath
        case .directMacPeer:
            return executionSettings.supervisorReportPath
        }
    }
}

struct AppDevicesSectionView: View {
    @Binding var operatorSurface: NativeAppShellOperatorPrototypeState
    let inventoryController: AppLocalOperatorInventoryController
    let appSettings: AppSettings
    let inputsLocked: Bool
    let onOpenDiagnostics: () -> Void

    var body: some View {
        AppLocalOperatorSurfaceView(
            operatorSurface: $operatorSurface,
            inventoryController: inventoryController,
            appSettings: appSettings,
            inputsLocked: inputsLocked,
            onOpenDiagnostics: onOpenDiagnostics
        )
    }
}
