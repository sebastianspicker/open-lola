import AppKit
import OpenLolaCore
import SwiftUI

struct AppOperatorArtifactsView: View {
    @Binding var operatorSurface: NativeAppShellOperatorPrototypeState
    @Bindable var appSettings: AppSettings
    @State private var remoteInventoryJSON = ""
    @State private var generatedArtifact: NativeAppShellGeneratedArtifactState?
    @State private var status = "No artifact generated."
    @State private var fileError: String?

    var body: some View {
        GroupBox("Inventory Import / Export") {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Button("Copy Local Inventory JSON") {
                        generateLocalInventoryExport()
                    }
                    Button("Paste Remote Inventory JSON") {
                        pasteRemoteInventoryJSON()
                    }
                    Button("Import Remote Inventory JSON") {
                        importRemoteInventory()
                    }
                }

                TextEditor(text: $remoteInventoryJSON)
                    .font(.system(.caption, design: .monospaced))
                    .frame(minHeight: 180)
                    .border(AppDesignSystem.panelBorder)
            }
        }

        GroupBox("Plan Artifact") {
            VStack(alignment: .leading, spacing: 12) {
                TextField("Plan artifact path", text: $appSettings.operatorPlanArtifactPath)
                    .font(.system(.caption, design: .monospaced))

                HStack {
                    Button("Generate Copyable Plan JSON") {
                        generatePlanArtifact()
                    }
                    Button("Write Plan Artifact") {
                        writePlanArtifact()
                    }
                    Button("Reload Plan Artifact") {
                        reloadPlanArtifact()
                    }
                }

                TextField("Supervisor report path", text: $appSettings.operatorSupervisorReportPath)
                    .font(.system(.caption, design: .monospaced))
                HStack {
                    TextField("Mac A SSH target", text: $appSettings.operatorMacASSH)
                    TextField("Mac B SSH target", text: $appSettings.operatorMacBSSH)
                    Button("Copy SSH Supervisor Command") {
                        generateSupervisorCommand()
                    }
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
            copy(artifact.clipboardText)
            status = "Copied local inventory JSON."
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
            copy(artifact.clipboardText)
            status = "Generated copyable plan JSON."
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
            copy(artifact.clipboardText)
            status = "Wrote plan artifact to \(appSettings.operatorPlanArtifactPath)."
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
            copy(clipboardText)
            status = "Reloaded plan artifact from \(appSettings.operatorPlanArtifactPath)."
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
            copy(artifact.clipboardText)
            status = "Copied SSH supervisor command."
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

    private func copy(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
}
