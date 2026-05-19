import AppKit
import OpenLolaCore
import SwiftUI

struct AppOperatorArtifactsView: View {
    @Binding var operatorSurface: NativeAppShellOperatorPrototypeState
    @Bindable var appSettings: AppSettings
    let inputsLocked: Bool
    @State private var remoteInventoryJSON = ""
    @State private var generatedArtifact: NativeAppShellGeneratedArtifactState?
    @State private var status = "No artifact generated."
    @State private var fileError: String?

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
                    .border(AppDesignSystem.panelBorder)
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

                LabeledContent("Status", value: status)
                if let generatedArtifact {
                    LabeledContent("Artifact", value: generatedArtifact.validationSummary)
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
                fileError = nil
            }
        } message: {
            Text(fileError ?? "Unknown artifact error.")
        }
    }

    private func generateLocalInventoryExport() {
        do {
            let artifact = try operatorSurface.localInventoryArtifactState()
            generatedArtifact = artifact
            status = AppPasteboardCopyStatus.message(
                copied: copy(artifact.clipboardText),
                success: "Copied local inventory JSON.",
                failure: "Copy failed for local inventory JSON."
            )
        } catch {
            setFailureStatus("Local inventory export failed", error)
        }
    }

    private func pasteRemoteInventoryJSON() {
        guard let json = NSPasteboard.general.string(forType: .string),
              !json.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            status = "Pasteboard does not contain remote inventory JSON."
            return
        }
        remoteInventoryJSON = json
        status = "Pasted remote inventory JSON."
    }

    private func importRemoteInventory() {
        do {
            try operatorSurface.importRemoteInventoryJSON(from: remoteInventoryJSON)
            status = "Imported remote inventory JSON."
        } catch {
            setFailureStatus("Remote inventory import failed", error)
        }
    }

    private func generatePlanArtifact() {
        do {
            let artifact = try operatorSurface.twoPeerRunPlanArtifactState(outputPath: appSettings.operatorPlanArtifactPath)
            generatedArtifact = artifact
            status = AppPasteboardCopyStatus.message(
                copied: copy(artifact.clipboardText),
                success: "Generated copyable plan JSON.",
                failure: "Generated plan JSON, but pasteboard copy failed."
            )
        } catch {
            setFailureStatus("Plan generation failed", error)
        }
    }

    private func writePlanArtifact() {
        do {
            let planArtifactURL = URL(fileURLWithPath: appSettings.operatorPlanArtifactPath)
            let artifact = try operatorSurface.writeTwoPeerRunPlanArtifact(
                to: planArtifactURL,
                runDirectory: planArtifactURL.deletingLastPathComponent().path
            )
            generatedArtifact = artifact
            status = AppPasteboardCopyStatus.message(
                copied: copy(artifact.clipboardText),
                success: "Wrote plan artifact to \(appSettings.operatorPlanArtifactPath).",
                failure: "Wrote plan artifact, but pasteboard copy failed."
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
            generatedArtifact = NativeAppShellGeneratedArtifactState(
                kind: .twoPeerRunPlan,
                generatedAt: report.capturedAt,
                path: appSettings.operatorPlanArtifactPath,
                clipboardText: clipboardText,
                validationSummary: "\(report.id): \(report.verdict.rawValue)"
            )
            status = AppPasteboardCopyStatus.message(
                copied: copy(clipboardText),
                success: "Reloaded plan artifact from \(appSettings.operatorPlanArtifactPath).",
                failure: "Reloaded plan artifact, but pasteboard copy failed."
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
            generatedArtifact = artifact
            status = AppPasteboardCopyStatus.message(
                copied: copy(artifact.clipboardText),
                success: "Copied SSH supervisor command.",
                failure: "Copy failed for SSH supervisor command."
            )
        } catch {
            setFailureStatus("Supervisor command generation failed", error)
        }
    }

    private var fileErrorPresented: Binding<Bool> {
        Binding(
            get: { fileError != nil },
            set: { isPresented in
                if !isPresented {
                    fileError = nil
                }
            }
        )
    }

    private func setFailureStatus(_ prefix: String, _ error: Error) {
        let message = "\(prefix): \(error)"
        status = message
        fileError = message
    }

    private func copy(_ text: String) -> Bool {
        AppPasteboard.copyString(text)
    }
}
