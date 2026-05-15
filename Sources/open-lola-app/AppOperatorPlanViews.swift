import OpenLolaCore
import SwiftUI

struct AppOperatorPrototypePlan {
    let sessionMode: NativeAppShellSessionMode
    let report: DirectPeerTwoPeerRunPlanReport?
    let windowsLoLaCommand: [String]?
    let macA: DirectPeerTwoPeerRunPlanPeer?
    let macB: DirectPeerTwoPeerRunPlanPeer?
    let validationError: String?
    let windowsLoLaFields: NativeAppShellWindowsLoLaPeerFields
    let durationSeconds: Int
    let channelCount: Int
    let sampleRateHertz: Int
    let framesPerPacket: Int
    let sampleFormat: String
    let videoWidth: Int
    let videoHeight: Int
    let videoFrameRate: Int
    let avProfile: DirectPeerSessionAVProfile
    let rxBufferProfile: RxBufferProfile
    let preview: DirectPeerSessionPreviewMode

    var isConfigured: Bool {
        switch sessionMode {
        case .directMacPeer:
            return report != nil
        case .windowsLoLa:
            return windowsLoLaCommand != nil
        }
    }

    var topologyLocalPeer: String {
        switch sessionMode {
        case .directMacPeer:
            return macA?.peerID ?? "local Mac"
        case .windowsLoLa:
            return "local Mac"
        }
    }

    var topologyRemotePeer: String {
        switch sessionMode {
        case .directMacPeer:
            return macB?.peerID ?? "remote Mac"
        case .windowsLoLa:
            return "Windows LoLa"
        }
    }

    var topologyLocalHost: String {
        switch sessionMode {
        case .directMacPeer:
            return macA?.host ?? windowsLoLaFields.localHost
        case .windowsLoLa:
            return windowsLoLaFields.localHost
        }
    }

    var topologyRemoteHost: String {
        switch sessionMode {
        case .directMacPeer:
            return macB?.host ?? windowsLoLaFields.windowsHost
        case .windowsLoLa:
            return windowsLoLaFields.windowsHost
        }
    }

    static func make(operatorSurface: NativeAppShellOperatorPrototypeState) -> AppOperatorPrototypePlan {
        let fields = operatorSurface.directPeerCommandFields
        let configuration = operatorSurface.sessionMode == .directMacPeer
            ? Result { try operatorSurface.twoPeerRunPlanConfiguration() }
            : nil
        let twoPeerConfiguration = try? configuration?.get()
        let directPeerReport = twoPeerConfiguration.map { configuration in
            Result { try DirectPeerTwoPeerRunPlanner.makeReport(configuration: configuration) }
        }
        let windowsCommand: Result<[String], Error> = Result {
            try operatorSurface.windowsLoLaSessionArguments(
                executablePath: operatorSurface.windowsLoLaPeerFields.executablePath,
                dryRun: true
            )
        }
        return AppOperatorPrototypePlan(
            sessionMode: operatorSurface.sessionMode,
            report: directPeerReport.flatMap { try? $0.get() },
            windowsLoLaCommand: operatorSurface.sessionMode == .windowsLoLa ? (try? windowsCommand.get()) : nil,
            macA: twoPeerConfiguration?.macA,
            macB: twoPeerConfiguration?.macB,
            validationError: operatorSurface.sessionMode == .directMacPeer
                ? (configuration?.failureDescription ?? directPeerReport?.failureDescription)
                : windowsCommand.failureDescription,
            windowsLoLaFields: operatorSurface.windowsLoLaPeerFields,
            durationSeconds: fields.durationSeconds,
            channelCount: fields.channelCount,
            sampleRateHertz: fields.sampleRateHertz,
            framesPerPacket: fields.framesPerPacket,
            sampleFormat: fields.sampleFormat,
            videoWidth: fields.videoWidth,
            videoHeight: fields.videoHeight,
            videoFrameRate: fields.videoFrameRate,
            avProfile: fields.avProfile,
            rxBufferProfile: fields.rxBufferProfile,
            preview: fields.preview
        )
    }
}

struct AppOperatorReadinessView: View {
    let plan: AppOperatorPrototypePlan
    let executionController: AppExecutionController

    var body: some View {
        GroupBox(plan.sessionMode == .windowsLoLa ? "Windows LoLa Operator Readiness" : "Mac-to-Mac Operator Readiness") {
            MetricsGrid {
                LabeledContent("Prototype", value: plan.sessionMode == .windowsLoLa ? "external LoLa connector" : "direct P2P two-peer AV")
                AppReadableMetric(label: "Plan report", value: planReadinessTitle, monospaced: true)
                LabeledContent("Verdict", value: plan.report?.verdict.rawValue.uppercased() ?? "PARTIAL")
                LabeledContent("Command count", value: "\(plan.report?.commands.count ?? plan.windowsLoLaCommand.map { _ in 1 } ?? 0)")
                AppReadableMetric(label: "Execution status", value: executionController.status)
                LabeledContent("Validation boundary", value: validationBoundary)
            }
        }

        if let validationError = plan.validationError {
            GroupBox("Plan Input") {
                Label(validationError, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.secondary)
            }
        }

        GroupBox("Media Profile") {
            MetricsGrid {
                if plan.sessionMode == .windowsLoLa {
                    LabeledContent(
                        "Audio",
                        value: "\(plan.windowsLoLaFields.channelCount) ch \(plan.windowsLoLaFields.sampleRateHertz) Hz generated"
                    )
                    LabeledContent("Frames", value: "\(plan.windowsLoLaFields.framesPerPacket)")
                    LabeledContent(
                        "Video",
                        value: "\(plan.windowsLoLaFields.videoWidth)x\(plan.windowsLoLaFields.videoHeight) @ \(plan.windowsLoLaFields.videoFrameRate) fps"
                    )
                    LabeledContent("Payload", value: plan.windowsLoLaFields.payloadMode.rawValue)
                    LabeledContent(
                        "Media packets",
                        value: windowsLoLaMediaPacketCountLabel(plan.windowsLoLaFields)
                    )
                    LabeledContent("Duration", value: "\(plan.windowsLoLaFields.durationSeconds) s")
                } else {
                    LabeledContent("Audio", value: "\(plan.channelCount) ch \(plan.sampleRateHertz) Hz \(plan.sampleFormat)")
                    LabeledContent("Frames", value: "\(plan.framesPerPacket)")
                    LabeledContent("Video", value: "\(plan.videoWidth)x\(plan.videoHeight) @ \(plan.videoFrameRate) fps")
                    LabeledContent("AV profile", value: plan.avProfile.rawValue)
                    LabeledContent("RX buffer", value: plan.rxBufferProfile.rawValue)
                    LabeledContent("Preview", value: plan.preview.rawValue)
                    LabeledContent("Duration", value: "\(plan.durationSeconds) s")
                }
            }
        }

        if plan.sessionMode == .directMacPeer {
            GroupBox("Devices") {
                VStack(alignment: .leading, spacing: 12) {
                    if let macA = plan.macA, let macB = plan.macB {
                        AppPeerDeviceView(title: "Mac A", peer: macA)
                        Divider()
                        AppPeerDeviceView(title: "Mac B", peer: macB)
                    } else {
                        AppWarningBanner(
                            title: "Device Inventory Incomplete",
                            message: "Import local and remote input, output, and video IDs to build the two-peer plan."
                        )
                    }
                }
            }
        }

        GroupBox("Evidence Gates") {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(plan.report?.evidenceGates ?? [], id: \.self) { gate in
                    Label(gate, systemImage: "checklist")
                        .labelStyle(.titleAndIcon)
                }
            }
        }
    }

    private var planReadinessTitle: String {
        if plan.sessionMode == .windowsLoLa {
            return plan.windowsLoLaCommand == nil ? "Windows LoLa fields incomplete" : plan.windowsLoLaFields.outputPath
        }
        return plan.report?.id ?? "remote inventory incomplete"
    }

    private var validationBoundary: String {
        plan.sessionMode == .windowsLoLa
            ? "Windows endpoint evidence required"
            : "physical two-Mac evidence required"
    }
}

private func windowsLoLaMediaPacketCountLabel(_ fields: NativeAppShellWindowsLoLaPeerFields) -> String {
    do {
        return "\(try fields.mediaPacketCount())"
    } catch {
        return "invalid: \(error)"
    }
}

private struct AppPeerDeviceView: View {
    let title: String
    let peer: DirectPeerTwoPeerRunPlanPeer

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)
            MetricsGrid {
                LabeledContent("Peer", value: peer.peerID)
                LabeledContent("Host", value: peer.host)
                LabeledContent("Control port", value: "\(peer.portBase)")
                LabeledContent("Audio port", value: "\(peer.audioPort)")
                LabeledContent("Video port", value: "\(peer.videoPort)")
                LabeledContent("Metrics port", value: "\(peer.metricsPort)")
                AppReadableMetric(label: "Input UID", value: peer.inputUID, monospaced: true)
                AppReadableMetric(label: "Output UID", value: peer.outputUID, monospaced: true)
                AppReadableMetric(label: "Video device", value: peer.videoDeviceID, monospaced: true)
            }
        }
    }
}

struct AppOperatorCommandsView: View {
    let plan: AppOperatorPrototypePlan

    var body: some View {
        GroupBox("Prototype Commands") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Commands are generated from the current operator settings and executed only through the explicit Execution panel.")
                    .foregroundStyle(.secondary)

                ForEach(plan.report?.commands ?? [], id: \.peerID) { command in
                    VStack(alignment: .leading, spacing: 6) {
                        LabeledContent(command.peerID, value: command.role.rawValue)
                        Text(AppCommandPreview.shellLine(command.arguments))
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                            .lineLimit(nil)
                    }
                    .padding(.vertical, 4)
                }
                if let windowsLoLaCommand = plan.windowsLoLaCommand {
                    VStack(alignment: .leading, spacing: 6) {
                        LabeledContent("Windows LoLa", value: "external-connector")
                        Text(AppCommandPreview.shellLine(windowsLoLaCommand))
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                            .lineLimit(nil)
                    }
                    .padding(.vertical, 4)
                }
            }
        }

        GroupBox("Expected Evidence") {
            MetricsGrid {
                if plan.sessionMode == .windowsLoLa {
                    AppReadableMetric(
                        label: "Windows LoLa",
                        value: "ExternalConnectorSessionReport: \(plan.windowsLoLaFields.outputPath)",
                        monospaced: true
                    )
                } else {
                    ForEach(plan.report?.reportReferences ?? [], id: \.peerID) { reference in
                        AppReadableMetric(
                            label: reference.peerID,
                            value: "\(reference.schema): \(reference.path)",
                            monospaced: true
                        )
                    }
                }
            }
        }
    }
}
