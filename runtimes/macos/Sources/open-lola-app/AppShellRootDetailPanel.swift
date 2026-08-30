// Renders AppShellRootDetailPanel in the operator UI, keeping presentation and user affordances separate from execution state.
import OpenLolaCore
import SwiftUI

struct AppShellRootDetailPanel: View {
    let report: NativeAppShellReport
    let selectedSection: NativeAppShellSurfaceSectionID?
    @Binding var operatorSurface: NativeAppShellOperatorPrototypeState
    let executionController: AppExecutionController
    let previewState: AppPreviewReceiverState
    let inventoryController: AppLocalOperatorInventoryController
    let appSettings: AppSettings
    let contract: NativeAppShellSurfaceContract
    let derivedSurface: AppShellDerivedSurface
    let inputsLocked: Bool
    let navigateToSection: (NativeAppShellSurfaceSectionID) -> Void

    var body: some View {
        VStack(spacing: 0) {
            if let selectedSection {
                ScrollView {
                    AppShellDetailView(
                        section: selectedSection,
                        report: report,
                        operatorSurface: $operatorSurface,
                        executionController: executionController,
                        previewState: previewState,
                        inventoryController: inventoryController,
                        appSettings: appSettings,
                        contract: contract,
                        captureReport: derivedSurface.captureReport,
                        operatorPlan: derivedSurface.operatorPlan,
                        surfaceProbe: derivedSurface.surfaceProbe,
                        sessionState: derivedSurface.sessionState,
                        inputsLocked: inputsLocked,
                        navigateToSection: navigateToSection
                    )
                    .padding(.horizontal, AppSpacing.l)
                    .padding(.top, AppSpacing.l)
                    .padding(.bottom, AppSpacing.xl)
                }
            } else {
                AppUnavailableSectionView(
                    searchText: "",
                    sessionState: derivedSurface.sessionState,
                    captureReportAvailable: derivedSurface.captureReport != nil,
                    onGoToSetup: { navigateToSection(.devices) }
                )
            }
        }
        .background(AppDesignSystem.appBackground)
    }
}

private struct AppUnavailableSectionView: View {
    let searchText: String
    let sessionState: AppSessionState
    let captureReportAvailable: Bool
    var onGoToSetup: (() -> Void)?

    private var isSearchActive: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(spacing: AppSpacing.m) {
            Image(systemName: icon)
                .font(.system(size: 48, weight: .thin))
                .foregroundStyle(.secondary)

            VStack(spacing: AppSpacing.xs) {
                Text(title)
                    .font(.title3.weight(.semibold))

                Text(detail)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .textSelection(.enabled)
                    .frame(maxWidth: 340)
            }

            if sessionState == .unconfigured, !isSearchActive, let onGoToSetup {
                Button(action: onGoToSetup) {
                    Label("Go to Devices Setup", systemImage: "gearshape")
                        .font(.callout.weight(.semibold))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppDesignSystem.appBackground)
    }

    private var icon: String {
        if isSearchActive { return "magnifyingglass" }
        if sessionState == .unconfigured { return "gearshape.2" }
        return "slash.circle"
    }

    private var title: String {
        if isSearchActive { return "No matching section" }
        if sessionState == .unconfigured { return "Not configured" }
        return "Section unavailable"
    }

    private var detail: String {
        AppUnavailableSectionCopy.detail(
            searchText: searchText,
            sessionState: sessionState,
            captureReportAvailable: captureReportAvailable
        )
    }
}

enum AppUnavailableSectionCopy {
    static func detail(
        searchText: String,
        sessionState: AppSessionState,
        captureReportAvailable: Bool
    ) -> String {
        let trimmedSearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedSearch.localizedCaseInsensitiveContains("packet"), !captureReportAvailable {
            return "No capture yet. Open Packet Monitor after configuring a session to see how to produce " +
                "packet evidence."
        }
        if !trimmedSearch.isEmpty {
            return "No section matches \"\(trimmedSearch)\"."
        }
        return sessionState == .unconfigured
            ? "Configure your audio devices and peer addresses to get started."
            : "This section is unavailable in the current session state."
    }
}

struct AppShellExecutionDerivedInputs: Equatable {
    let status: String
    let isRunning: Bool
    let armedForExecution: Bool
    let lastExitCode: Int?
    let lastValidationExitCode: Int?
    let phase: AppExecutionPhase
    let hasValidatedRuntimeEvidence: Bool
    let lastLatencyMetrics: AppLatencyHeroMetrics?
    let lastCaptureReport: LoLaCompatibilityCaptureReport?
    let lastExternalConnectorReport: ExternalConnectorSessionReport?
}

struct AppShellPreviewDerivedInputs: Equatable {
    let phase: AppPreviewReceiverState.Phase
    let audioPreviewEnabled: Bool
    let videoPreviewEnabled: Bool
    let receiverStatus: String
}

struct AppShellDerivedSurface {
    let operatorPlan: AppOperatorPrototypePlan
    let statusSnapshot: AppConsoleStatusSnapshot
    let sessionState: AppSessionState
    let surfaceProbe: NativeAppShellSurfaceProbeReport
    let captureReport: LoLaCompatibilityCaptureReport?

    @MainActor
    static func make(
        report: NativeAppShellReport,
        operatorSurface: NativeAppShellOperatorPrototypeState,
        executionController: AppExecutionController,
        previewState: AppPreviewReceiverState,
        contract: NativeAppShellSurfaceContract
    ) -> AppShellDerivedSurface {
        let operatorPlan = AppOperatorPrototypePlan.make(operatorSurface: operatorSurface)
        let baseSessionState = AppSessionState.derive(AppSessionStateDerivationInput(
            isRunning: executionController.isRunning,
            isArmed: executionController.armedForExecution,
            lastExitCode: executionController.lastExitCode,
            isConfigured: operatorPlan.isConfigured,
            commandIntent: operatorSurface.commandIntent,
            phase: executionController.phase,
            hasValidatedRuntimeEvidence: executionController.hasValidatedRuntimeEvidence
        ))
        let sessionState = AppPreviewReceiverWarningPolicy.showsMainBannerWarning(
            phase: previewState.previewPhase,
            audioPreviewEnabled: previewState.audioPreviewEnabled,
            videoPreviewEnabled: previewState.videoPreviewEnabled,
            sessionState: baseSessionState
        ) ? .receiverWarning : baseSessionState
        return AppShellDerivedSurface(
            operatorPlan: operatorPlan,
            statusSnapshot: AppConsoleStatusSnapshot.make(
                report: report,
                plan: operatorPlan,
                executionController: executionController,
                captureReport: executionController.lastCaptureReport
            ),
            sessionState: sessionState,
            surfaceProbe: NativeAppShellSurfaceProbe.run(sourceReport: report, contract: contract),
            captureReport: executionController.lastCaptureReport
        )
    }
}
