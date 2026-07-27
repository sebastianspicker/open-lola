// Renders AppShellDetailView in the operator interface, keeping SwiftUI presentation distinct from execution and persistence state.
import OpenLolaCore
import SwiftUI

struct AppShellDetailView: View {
    let section: NativeAppShellSurfaceSectionID
    let report: NativeAppShellReport
    @Binding var operatorSurface: NativeAppShellOperatorPrototypeState
    let executionController: AppExecutionController
    let previewState: AppPreviewReceiverState
    let inventoryController: AppLocalOperatorInventoryController
    let appSettings: AppSettings
    let contract: NativeAppShellSurfaceContract
    let captureReport: LoLaCompatibilityCaptureReport?
    let operatorPlan: AppOperatorPrototypePlan
    let surfaceProbe: NativeAppShellSurfaceProbeReport
    let sessionState: AppSessionState
    let inputsLocked: Bool
    let navigateToSection: (NativeAppShellSurfaceSectionID) -> Void

    var body: some View {
        AppOperatorSectionLayout(title: sectionTitle) {
            pageHeader
                .padding(.bottom, AppSpacing.xs)

            switch section {
            case .overview:
                AppOverviewSectionView(
                    report: report,
                    operatorPlan: operatorPlan,
                    executionController: executionController,
                    latencyMetrics: executionController.lastLatencyMetrics,
                    hasValidatedRuntimeEvidence: executionController.hasValidatedRuntimeEvidence,
                    sessionState: sessionState,
                    captureReport: captureReport,
                    navigateToSection: navigateToSection
                )
            case .session:
                AppSessionSectionView(
                    report: report,
                    operatorSurface: $operatorSurface,
                    executionController: executionController,
                    operatorPlan: operatorPlan,
                    captureReport: captureReport,
                    sessionState: sessionState,
                    inputsLocked: inputsLocked,
                    navigateToSection: navigateToSection
                )
            case .streams:
                AppStreamsSectionView(
                    operatorSurface: $operatorSurface,
                    previewState: previewState,
                    operatorPlan: operatorPlan,
                    captureReport: captureReport
                )
            case .routing:
                AppRoutingSectionView(
                    operatorSurface: $operatorSurface,
                    operatorPlan: operatorPlan,
                    appSettings: appSettings,
                    inputsLocked: inputsLocked
                )
            case .devices:
                AppDevicesSectionView(
                    operatorSurface: $operatorSurface,
                    inventoryController: inventoryController,
                    appSettings: appSettings,
                    inputsLocked: inputsLocked,
                    onOpenDiagnostics: { navigateToSection(.diagnostics) }
                )
            case .diagnostics:
                AppDiagnosticsSectionView(
                    report: report,
                    operatorPlan: operatorPlan,
                    executionController: executionController
                )
            case .validation:
                AppValidationSectionView(
                    operatorSurface: $operatorSurface,
                    report: report,
                    operatorPlan: operatorPlan,
                    executionController: executionController,
                    surfaceProbe: surfaceProbe,
                    launchProbePlan: contract.launchProbePlan,
                    appSettings: appSettings,
                    navigateToSection: navigateToSection
                )
            case .packetMonitor:
                AppPacketMonitorView(
                    captureReport: captureReport,
                    emptyState: AppPacketMonitorEmptyState.make(
                        plan: operatorPlan,
                        executionSettings: executionController.settings
                    ),
                    navigateToSection: navigateToSection
                )
            case .settings:
                AppShellSettingsSummaryView(
                    operatorSurface: operatorSurface,
                    executionSettings: executionController.settings,
                    executionController: executionController,
                    appSettings: appSettings
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var sectionTitle: String {
        AppSignalDeskSectionCopy.title(for: section)
    }

    private var showsPhaseRail: Bool {
        section == .session || section == .overview
    }

    @ViewBuilder
    private var pageHeader: some View {
        let titleStack = VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text(sectionTitle)
                .font(.largeTitle.weight(.semibold))
            Text(AppSignalDeskSectionCopy.detail(for: section))
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }

        if showsPhaseRail {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: AppSpacing.s) {
                    titleStack
                    Spacer(minLength: AppSpacing.s)
                    phaseRail
                }
                VStack(alignment: .leading, spacing: AppSpacing.s) {
                    titleStack
                    phaseRail
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
        } else {
            titleStack
        }
    }

    private var phaseRail: some View {
        AppSessionPhaseRail(
            sessionState: sessionState,
            hasValidatedRuntimeEvidence: executionController.hasValidatedRuntimeEvidence,
            lastExitCode: executionController.lastExitCode
        )
    }
}

struct AppOperatorSectionLayout<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.m) {
            content
        }
        .frame(maxWidth: 1180, alignment: .topLeading)
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

@MainActor
func appOverviewOperatorSummary(
    report: NativeAppShellReport,
    operatorPlan: AppOperatorPrototypePlan,
    executionController: AppExecutionController,
    sessionState: AppSessionState,
    captureReport: LoLaCompatibilityCaptureReport?
) -> AppOverviewOperatorSummary {
    AppOverviewOperatorSummary.make(
        report: report,
        plan: operatorPlan,
        executionController: executionController,
        sessionState: sessionState,
        captureReport: captureReport
    )
}
