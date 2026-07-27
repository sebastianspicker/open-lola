// Renders AppTransportView in the operator interface, keeping SwiftUI presentation distinct from execution and persistence state.
import OpenLolaCore
import SwiftUI

/// The single persistent operator transport for the main window.
struct AppTransportView: View {
    @Binding var operatorSurface: NativeAppShellOperatorPrototypeState
    let executionController: AppExecutionController
    let plan: AppOperatorPrototypePlan
    let sessionState: AppSessionState

    @State var showStopConfirmation = false

    var body: some View {
        ViewThatFits(in: .horizontal) {
            expandedTransport
            compactTransport
        }
        .padding(.horizontal, AppSpacing.m)
        .padding(.vertical, AppSpacing.s)
        .frame(minHeight: 60)
        .modifier(AppTransportSurfaceModifier())
        .confirmationDialog(
            AppTransportStopConfirmationPolicy.stopConfirmationTitle,
            isPresented: $showStopConfirmation,
            titleVisibility: .visible
        ) {
            Button(
                AppTransportStopConfirmationPolicy.stopConfirmationButtonTitle,
                role: .destructive,
                action: requestStop
            )
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(AppTransportStopConfirmationPolicy.stopConfirmationMessage)
        }
    }

    private var expandedTransport: some View {
        HStack(spacing: AppSpacing.m) {
            sessionIdentity
                .frame(minWidth: 176, alignment: .leading)
                .layoutPriority(1)

            Spacer(minLength: AppSpacing.s)

            HStack(spacing: AppSpacing.xs) {
                armButton
                dryRunButton
                startButton
                stopButton
                validateButton
            }
            .fixedSize()

            Divider()
                .frame(height: 28)

            evidenceIdentity
                .frame(minWidth: 132, alignment: .trailing)
        }
    }

    private var compactTransport: some View {
        HStack(spacing: AppSpacing.s) {
            sessionStatusBadge
            Text(sessionState.rawValue)
                .font(.callout.weight(.semibold))
                .lineLimit(1)

            Spacer(minLength: AppSpacing.xs)

            HStack(spacing: AppSpacing.xs) {
                armButton
                startButton
                stopButton
            }
            .labelStyle(.iconOnly)
            .fixedSize()

            Menu {
                Button("Dry Run", systemImage: "play.slash.fill", action: performDryRun)
                    .disabled(!dryRunAvailable)
                Button("Validate Report", systemImage: "checkmark.seal", action: validateReport)
                    .disabled(!validateAvailable)
            } label: {
                Label("More Session Actions", systemImage: "ellipsis.circle")
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .help("Dry run and report validation")
        }
        .accessibilityElement(children: .contain)
    }

    private var sessionIdentity: some View {
        HStack(spacing: AppSpacing.s) {
            sessionStatusBadge
            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Text(sessionState.rawValue)
                    .font(.callout.weight(.semibold))
                    .lineLimit(1)
                Text(routeSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Session state \(sessionState.rawValue), \(routeSummary)")
    }

    private var sessionStatusBadge: some View {
        Image(systemName: sessionState.systemImage)
            .font(.caption.weight(.bold))
            .foregroundStyle(sessionState.color)
            .frame(width: 28, height: 28)
            .background(sessionState.color.opacity(0.18), in: Circle())
            .accessibilityHidden(true)
    }

    private var evidenceIdentity: some View {
        VStack(alignment: .trailing, spacing: AppSpacing.xxs) {
            Text(evidenceStatusTitle)
                .font(.caption.weight(.semibold))
                .foregroundStyle(evidenceStatusTone)
                .lineLimit(1)
            Text(executionController.status)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(evidenceStatusTitle). \(executionController.status)")
    }
}

private struct AppTransportSurfaceModifier: ViewModifier {
    @Environment(\.appDocumentationRendering) private var appDocumentationRendering

    @ViewBuilder
    func body(content: Content) -> some View {
        content
            .background(
                AppDesignSystem.panelBackground,
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(AppDesignSystem.panelBorder, lineWidth: 1)
            }
    }
}

private struct AppDocumentationRenderingKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var appDocumentationRendering: Bool {
        get { self[AppDocumentationRenderingKey.self] }
        set { self[AppDocumentationRenderingKey.self] = newValue }
    }
}
