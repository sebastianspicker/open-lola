// Builds the Quiet signal worksheet and runtime surfaces from actual app state.
import OpenLolaCore
import SwiftUI

struct AppQuietColumns<Main: View, Aside: View>: View {
    @ViewBuilder let main: Main
    @ViewBuilder let aside: Aside

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: AppSpacing.xl) {
                main.frame(maxWidth: .infinity, alignment: .topLeading)
                Divider()
                aside.frame(width: 430, alignment: .topLeading)
            }
            .fixedSize(horizontal: false, vertical: true)
            .frame(minWidth: 1050)
            VStack(alignment: .leading, spacing: AppSpacing.l) {
                main
                Divider()
                aside
            }
        }
    }
}

struct AppQuietWorksheet: View {
    let title: String
    let rows: [AppQuietConfigurationRow]

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.m) {
            Text(title).font(.system(size: 20, weight: .semibold))
            VStack(spacing: 0) {
                ForEach(rows) { row in
                    HStack(alignment: .firstTextBaseline, spacing: AppSpacing.m) {
                        Text(row.label)
                            .foregroundStyle(.secondary)
                            .frame(width: 158, alignment: .leading)
                        Text(row.value)
                            .font(.system(size: 15, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .font(.system(size: 15))
                    .padding(.vertical, AppSpacing.m)
                    .accessibilityElement(children: .combine)
                    Divider()
                }
            }
        }
    }
}

struct AppQuietReadiness: View {
    let surface: NativeAppShellOperatorPrototypeState
    let plan: AppOperatorPrototypePlan
    let summary: AppQuietSessionSummary
    let navigate: (NativeAppShellSurfaceSectionID) -> Void

    private var devicesSelected: Bool {
        let requirement = AppRequiredDevicePolicy.requirements(for: surface)
        let selection = surface.inventory.selection
        return (!requirement.audioInput || hasText(selection.audioInputUID))
            && (!requirement.audioOutput || hasText(selection.audioOutputUID))
            && (!requirement.videoInput || hasText(selection.videoDeviceID))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.l) {
            Text("Before transmission").font(.system(size: 20, weight: .semibold))
            readiness("Required media devices selected", complete: devicesSelected)
            readiness("Configuration passes local checks", complete: plan.isConfigured)
            Label("Peer agreement is established during execution", systemImage: "info.circle")
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Divider()
            Text("Peer summary").font(.headline)
            LabeledContent("Local", value: summary.localPeer)
            LabeledContent("Remote", value: summary.remotePeer)
            DisclosureGroup("Endpoint details") {
                VStack(alignment: .leading, spacing: AppSpacing.s) {
                    Text("Local: \(summary.localHost)")
                    Text("Remote: \(summary.remoteHost)")
                    Text("Use trusted, isolated networks. Peer traffic is not authenticated or encrypted.")
                        .font(.caption)
                }
                .textSelection(.enabled)
                .padding(.top, AppSpacing.s)
            }
            Button("Edit configuration", systemImage: "arrow.left") { navigate(.devices) }
                .buttonStyle(.bordered)
            Button("Channel routing", systemImage: "point.3.connected.trianglepath.dotted") { navigate(.routing) }
                .buttonStyle(.borderless)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .font(.system(size: 15))
    }

    private func readiness(_ label: String, complete: Bool) -> some View {
        Label(label, systemImage: complete ? "checkmark.circle" : "circle")
            .font(.system(size: 15))
            .accessibilityLabel("\(label): \(complete ? "Complete" : "Required")")
    }

    private func hasText(_ value: String?) -> Bool {
        !(value?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
    }
}

struct AppQuietPreviewStatus: View {
    let previewState: AppPreviewReceiverState
    let navigate: (NativeAppShellSurfaceSectionID) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.m) {
            Text("Local device preview").font(.system(size: 20, weight: .semibold))
            ZStack {
                RoundedRectangle(cornerRadius: 8).fill(AppDesignSystem.elevatedBackground)
                if previewState.videoPreviewController.phase == .active {
                    AppVideoPreviewLayerView(controller: previewState.videoPreviewController)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    VStack(spacing: AppSpacing.s) {
                        Image(systemName: "video.slash").font(.system(size: 26, weight: .light))
                        Text("Preview inactive")
                            .fontWeight(.medium)
                        Text(previewState.verifiedReceiverStatus)
                            .font(.system(size: 15))
                            .multilineTextAlignment(.center)
                    }
                    .foregroundStyle(.secondary)
                    .padding(AppSpacing.l)
                }
            }
            .aspectRatio(4.0 / 3.0, contentMode: .fit)
            Text("Local capture only. This is not a received peer video feed.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Button("Media and preview controls", systemImage: "arrow.up.right") { navigate(.streams) }
                .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
