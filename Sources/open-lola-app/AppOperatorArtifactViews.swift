// Renders operator artifact actions and status panels while leaving file writes and inventory imports to controller services.
import AppKit
import OpenLolaCore
import SwiftUI

struct AppOperatorArtifactsView: View {
    @Binding var operatorSurface: NativeAppShellOperatorPrototypeState
    @Bindable var appSettings: AppSettings
    let inputsLocked: Bool
    @State private var remoteInventoryJSON = ""
    @State private var panelState = AppOperatorArtifactPanelState()

    var body: some View {
        DesignPanel(title: "Inventory import / export", systemImage: "arrow.up.arrow.down") {
            VStack(alignment: .leading, spacing: AppSpacing.s) {
                HStack {
                    Button("Copy Local Inventory JSON") {
                        generateLocalInventoryExport()
                    }
                    Button("Paste Remote Inventory JSON") {
                        pasteRemoteInventoryJSON()
                    }
                    .disabled(inputsLocked)
                    Button("Import Remote Inventory JSON") {
                        importRemoteInventory()
                    }
                    .disabled(inputsLocked)
                }

                TextEditor(text: $remoteInventoryJSON)
                    .font(.system(.caption, design: .monospaced))
                    .frame(minHeight: 180)
                    .padding(AppSpacing.xs)
                    .background(AppDesignSystem.elevatedBackground, in: RoundedRectangle(cornerRadius: 8))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(AppDesignSystem.panelBorder, lineWidth: 1)
                    }
                    .disabled(inputsLocked)
            }
            .help(inputsLocked ? AppRuntimeInputLock.lockedHelp : "")
        }

        DesignPanel(title: "Plan artifact", systemImage: "doc.badge.gearshape") {
            VStack(alignment: .leading, spacing: AppSpacing.s) {
                TextField("Plan artifact path", text: $appSettings.operatorPlanArtifactPath)
                    .font(.system(.caption, design: .monospaced))
                    .disabled(inputsLocked)

                HStack {
                    Button("Generate Copyable Plan JSON") {
                        generatePlanArtifact()
                    }
                    .disabled(inputsLocked)
                    Button("Write Plan Artifact") {
                        writePlanArtifact()
                    }
                    .disabled(inputsLocked)
                    Button("Reload Plan Artifact") {
                        reloadPlanArtifact()
                    }
                    .disabled(inputsLocked)
                }

                TextField("Supervisor report path", text: $appSettings.operatorSupervisorReportPath)
                    .font(.system(.caption, design: .monospaced))
                    .disabled(inputsLocked)
                HStack {
                    TextField("Mac A SSH target", text: $appSettings.operatorMacASSH)
                        .disabled(inputsLocked)
                    TextField("Mac B SSH target", text: $appSettings.operatorMacBSSH)
                        .disabled(inputsLocked)
                    Button("Copy SSH Supervisor Command") {
                        generateSupervisorCommand()
                    }
                    .disabled(inputsLocked)
                }

                LabeledContent("Status", value: panelState.status)
                if let generatedArtifact = panelState.generatedArtifact {
                    LabeledContent("Artifact", value: generatedArtifact.validationSummary)
                    LabeledContent("Generated", value: generatedArtifact.generatedAt)
                    if let path = generatedArtifact.path {
                        AppReadableMetric(label: "Path", value: path, monospaced: true)
                    }
                    Text(generatedArtifact.clipboardText)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .lineLimit(12)
                }
            }
            .help(inputsLocked ? AppRuntimeInputLock.lockedHelp : "")
        }
        .alert("Artifact Error", isPresented: fileErrorPresented) {
            Button("OK") {
                panelState.fileError = nil
            }
        } message: {
            Text(panelState.fileError ?? "Unknown artifact error.")
        }
        .onChange(of: appSettings.operatorPlanArtifactPath) { _, _ in
            clearPlanArtifactAfterContextChange()
        }
        .onChange(of: appSettings.operatorSupervisorReportPath) { _, _ in
            clearSupervisorArtifactAfterContextChange()
        }
        .onChange(of: appSettings.operatorMacASSH) { _, _ in
            clearSupervisorArtifactAfterContextChange()
        }
        .onChange(of: appSettings.operatorMacBSSH) { _, _ in
            clearSupervisorArtifactAfterContextChange()
        }
    }

    private func generateLocalInventoryExport() {
        do {
            let artifact = try operatorSurface.localInventoryArtifactState()
            panelState.recordGeneratedArtifact(
                artifact,
                status: AppPasteboardCopyStatus.message(
                    copied: copy(artifact.clipboardText),
                    success: "Copied local inventory JSON.",
                    failure: "Copy failed for local inventory JSON."
                )
            )
        } catch {
            setFailureStatus("Local inventory export failed", error)
        }
    }

    private func pasteRemoteInventoryJSON() {
        guard let json = NSPasteboard.general.string(forType: .string),
              !json.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            panelState.clearGeneratedArtifact(status: "Pasteboard does not contain remote inventory JSON.")
            return
        }
        remoteInventoryJSON = json
        panelState.clearGeneratedArtifact(status: "Pasted remote inventory JSON. Review and import to validate IDs.")
    }

    private func importRemoteInventory() {
        do {
            try operatorSurface.importRemoteInventoryJSON(from: remoteInventoryJSON)
            panelState.clearGeneratedArtifact(
                status: AppRemoteInventoryImportStatus.summary(for: operatorSurface.remoteInventory)
            )
        } catch {
            setFailureStatus("Remote inventory import failed", error)
        }
    }

    private func generatePlanArtifact() {
        do {
            let artifact = try operatorSurface.twoPeerRunPlanArtifactState(
                outputPath: appSettings.operatorPlanArtifactPath
            )
            panelState.recordGeneratedArtifact(
                artifact,
                status: AppPasteboardCopyStatus.message(
                    copied: copy(artifact.clipboardText),
                    success: "Generated copyable plan JSON.",
                    failure: "Generated plan JSON, but pasteboard copy failed."
                )
            )
        } catch {
            setFailureStatus("Plan generation failed", error)
        }
    }

    private func writePlanArtifact() {
        do {
            let planArtifactURL = URL(fileURLWithPath: appSettings.operatorPlanArtifactPath)
            let result = try operatorSurface.writeTwoPeerRunPlanArtifactResult(
                to: planArtifactURL,
                runDirectory: planArtifactURL.deletingLastPathComponent().path,
                mode: .writeTimestampedIfExists
            )
            if result.writtenPath != appSettings.operatorPlanArtifactPath {
                appSettings.operatorPlanArtifactPath = result.writtenPath
            }
            panelState.recordGeneratedArtifact(
                result.artifact,
                status: AppArtifactWriteStatus.message(
                    result: result,
                    copied: copy(result.artifact.clipboardText)
                )
            )
        } catch {
            setFailureStatus("Plan artifact write failed", error)
        }
    }

    private func reloadPlanArtifact() {
        do {
            let report = try NativeAppShellOperatorPrototypeState.readTwoPeerRunPlanArtifact(
                from: URL(fileURLWithPath: appSettings.operatorPlanArtifactPath)
            )
            let clipboardText = try report.prettyJSONString()
            let artifact = NativeAppShellGeneratedArtifactState(
                kind: .twoPeerRunPlan,
                generatedAt: report.capturedAt,
                path: appSettings.operatorPlanArtifactPath,
                clipboardText: clipboardText,
                validationSummary: "\(report.id): \(report.verdict.rawValue)"
            )
            panelState.recordGeneratedArtifact(
                artifact,
                status: AppPasteboardCopyStatus.message(
                    copied: copy(clipboardText),
                    success: "Reloaded plan artifact from \(appSettings.operatorPlanArtifactPath).",
                    failure: "Reloaded plan artifact, but pasteboard copy failed."
                )
            )
        } catch {
            setFailureStatus("Plan artifact reload failed", error)
        }
    }

    private func generateSupervisorCommand() {
        do {
            let artifact = try operatorSurface.twoPeerSupervisorCommandArtifactState(
                planPath: appSettings.operatorPlanArtifactPath,
                outputPath: appSettings.operatorSupervisorReportPath,
                macASSH: appSettings.operatorMacASSH,
                macBSSH: appSettings.operatorMacBSSH
            )
            panelState.recordGeneratedArtifact(
                artifact,
                status: AppPasteboardCopyStatus.message(
                    copied: copy(artifact.clipboardText),
                    success: "Copied SSH supervisor command.",
                    failure: "Copy failed for SSH supervisor command."
                )
            )
        } catch {
            setFailureStatus("Supervisor command generation failed", error)
        }
    }

    private var fileErrorPresented: Binding<Bool> {
        Binding(
            get: { panelState.fileError != nil },
            set: { isPresented in
                if !isPresented {
                    panelState.fileError = nil
                }
            }
        )
    }

    private func setFailureStatus(_ prefix: String, _ error: Error) {
        panelState.setFailureStatus(prefix, error)
    }

    private func copy(_ text: String) -> Bool {
        AppPasteboard.copyString(text)
    }

    private func clearPlanArtifactAfterContextChange() {
        guard let generatedArtifact = panelState.generatedArtifact,
              generatedArtifact.kind == .twoPeerRunPlan || generatedArtifact.kind == .twoPeerSupervisorCommand,
              generatedArtifact.path != appSettings.operatorPlanArtifactPath
        else {
            return
        }
        panelState.clearGeneratedArtifact(
            status: "Artifact path changed. Generate, write, or reload an artifact for current values."
        )
    }

    private func clearSupervisorArtifactAfterContextChange() {
        guard panelState.generatedArtifact?.kind == .twoPeerSupervisorCommand else {
            return
        }
        panelState.clearGeneratedArtifact(
            status: "Supervisor command inputs changed. Copy the command again for current values."
        )
    }
}

struct AppOperatorArtifactPanelState: Equatable {
    var generatedArtifact: NativeAppShellGeneratedArtifactState?
    var status = "No artifact generated."
    var fileError: String?

    mutating func recordGeneratedArtifact(_ artifact: NativeAppShellGeneratedArtifactState, status: String) {
        generatedArtifact = artifact
        self.status = status
        fileError = nil
    }

    mutating func clearGeneratedArtifact(status: String) {
        generatedArtifact = nil
        self.status = status
    }

    mutating func setFailureStatus(_ prefix: String, _ error: Error) {
        let message = "\(prefix): \(error)"
        generatedArtifact = nil
        status = message
        fileError = message
    }
}

enum AppRemoteInventoryImportStatus {
    static func summary(for inventory: NativeAppShellLocalMediaInventory) -> String {
        [
            "Imported remote inventory JSON",
            "host \(nonEmpty(inventory.hostName, fallback: "unknown"))",
            "audio input \(nonEmpty(inventory.selection.audioInputUID, fallback: "missing"))",
            "audio output \(nonEmpty(inventory.selection.audioOutputUID, fallback: "missing"))",
            "video \(nonEmpty(inventory.selection.videoDeviceID, fallback: "missing"))"
        ].joined(separator: "; ") + "."
    }

    private static func nonEmpty(_ value: String?, fallback: String) -> String {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty
        else {
            return fallback
        }
        return value
    }
}

enum AppArtifactWriteStatus {
    static func message(result: NativeAppShellArtifactWriteResult, copied: Bool) -> String {
        var message = "Wrote \(result.writtenCount) plan artifact to \(result.writtenPath)."
        if result.skippedCount > 0 {
            message += " Skipped overwrite of existing target \(result.requestedPath)."
        }
        message += " Counts: written \(result.writtenCount), "
            + "skipped \(result.skippedCount), failed \(result.failedCount)."
        if !copied {
            message += " Pasteboard copy failed."
        }
        return message
    }
}
