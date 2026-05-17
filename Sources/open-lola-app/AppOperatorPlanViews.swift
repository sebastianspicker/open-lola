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
    let audioTransport: DirectPeerSessionAudioTransport
    let videoCompression: DirectPeerSessionVideoCompression
    let avProfile: DirectPeerSessionAVProfile
    let rxBufferProfile: RxBufferProfile
    let preview: DirectPeerSessionPreviewMode

    var isConfigured: Bool {
        switch sessionMode {
        case .directMacPeer:
            return report != nil
        case .windowsLoLa:
            return windowsLoLaCommand != nil
        case .jackTrip, .ultraGrid:
            return false
        }
    }

    var topologyLocalPeer: String {
        switch sessionMode {
        case .directMacPeer:
            return macA?.peerID ?? "local Mac"
        case .windowsLoLa:
            return "local Mac"
        case .jackTrip, .ultraGrid:
            return "local endpoint"
        }
    }

    var topologyRemotePeer: String {
        switch sessionMode {
        case .directMacPeer:
            return macB?.peerID ?? "remote Mac"
        case .windowsLoLa:
            return "Windows LoLa"
        case .jackTrip, .ultraGrid:
            return "\(sessionMode.displayName) external connector"
        }
    }

    var topologyLocalHost: String {
        switch sessionMode {
        case .directMacPeer:
            return macA?.host ?? windowsLoLaFields.localHost
        case .windowsLoLa:
            return windowsLoLaFields.localHost
        case .jackTrip, .ultraGrid:
            return "not wired in app"
        }
    }

    var topologyRemoteHost: String {
        switch sessionMode {
        case .directMacPeer:
            return macB?.host ?? windowsLoLaFields.windowsHost
        case .windowsLoLa:
            return windowsLoLaFields.windowsHost
        case .jackTrip, .ultraGrid:
            return "external connector CLI"
        }
    }

    static func make(operatorSurface: NativeAppShellOperatorPrototypeState) -> AppOperatorPrototypePlan {
        let fields = operatorSurface.directPeerCommandFields
        let configuration = operatorSurface.sessionMode == .directMacPeer
            ? Result { try operatorSurface.twoPeerRunPlanConfiguration() }
            : nil
        let twoPeerConfiguration = successValue(configuration)
        let directPeerReport = twoPeerConfiguration.map { configuration in
            Result { try DirectPeerTwoPeerRunPlanner.makeReport(configuration: configuration) }
        }
        let windowsCommand: Result<[String], Error>? = operatorSurface.sessionMode == .windowsLoLa
            ? Result {
                try operatorSurface.windowsLoLaSessionArguments(
                    executablePath: operatorSurface.windowsLoLaPeerFields.executablePath,
                    dryRun: true
                )
            }
            : nil
        let validationError: String?
        switch operatorSurface.sessionMode {
        case .directMacPeer:
            validationError = configuration?.failureDescription ?? directPeerReport?.failureDescription
        case .windowsLoLa:
            validationError = windowsCommand?.failureDescription
        case .jackTrip, .ultraGrid:
            validationError = operatorSurface.sessionMode.unavailableAppReason
        }
        return AppOperatorPrototypePlan(
            sessionMode: operatorSurface.sessionMode,
            report: successValue(directPeerReport),
            windowsLoLaCommand: successValue(windowsCommand),
            macA: twoPeerConfiguration?.macA,
            macB: twoPeerConfiguration?.macB,
            validationError: validationError,
            windowsLoLaFields: operatorSurface.windowsLoLaPeerFields,
            durationSeconds: fields.durationSeconds,
            channelCount: fields.channelCount,
            sampleRateHertz: fields.sampleRateHertz,
            framesPerPacket: fields.framesPerPacket,
            sampleFormat: fields.sampleFormat,
            videoWidth: fields.videoWidth,
            videoHeight: fields.videoHeight,
            videoFrameRate: fields.videoFrameRate,
            audioTransport: fields.audioTransport,
            videoCompression: fields.videoCompression,
            avProfile: fields.avProfile,
            rxBufferProfile: fields.rxBufferProfile,
            preview: fields.preview
        )
    }

    private static func successValue<Value>(_ result: Result<Value, Error>?) -> Value? {
        guard case .success(let value) = result else {
            return nil
        }
        return value
    }
}

struct AppOperatorReadinessView: View {
    let plan: AppOperatorPrototypePlan
    let executionController: AppExecutionController

    var body: some View {
        GroupBox("\(plan.sessionMode.displayName) Operator Readiness") {
            MetricsGrid {
                LabeledContent("Prototype", value: prototypeLabel)
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
                } else if plan.sessionMode == .directMacPeer {
                    LabeledContent("Audio", value: "\(plan.channelCount) ch \(plan.sampleRateHertz) Hz \(plan.sampleFormat)")
                    LabeledContent("Audio transport", value: plan.audioTransport.rawValue)
                    LabeledContent("Frames", value: "\(plan.framesPerPacket)")
                    LabeledContent("Video", value: "\(plan.videoWidth)x\(plan.videoHeight) @ \(plan.videoFrameRate) fps")
                    LabeledContent("Video compression", value: plan.videoCompression.rawValue)
                    LabeledContent("AV profile", value: plan.avProfile.rawValue)
                    LabeledContent("RX buffer", value: plan.rxBufferProfile.rawValue)
                    LabeledContent("Preview", value: plan.preview.rawValue)
                    LabeledContent("Duration", value: "\(plan.durationSeconds) s")
                } else {
                    LabeledContent("Connector", value: plan.sessionMode.externalConnectorKind?.rawValue ?? "none")
                    LabeledContent("Runtime", value: "not wired in app")
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
                if let reason = plan.sessionMode.unavailableAppReason {
                    Label(reason, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(plan.report?.evidenceGates ?? [], id: \.self) { gate in
                        Label(gate, systemImage: "checklist")
                            .labelStyle(.titleAndIcon)
                    }
                }
            }
        }
    }

    private var planReadinessTitle: String {
        if plan.sessionMode == .windowsLoLa {
            return plan.windowsLoLaCommand == nil ? "LoLa fields incomplete" : plan.windowsLoLaFields.outputPath
        }
        if let reason = plan.sessionMode.unavailableAppReason {
            return reason
        }
        return plan.report?.id ?? "remote inventory incomplete"
    }

    private var validationBoundary: String {
        switch plan.sessionMode {
        case .directMacPeer:
            return "physical two-Mac evidence required"
        case .windowsLoLa:
            return "LoLa endpoint evidence required"
        case .jackTrip, .ultraGrid:
            return "external connector evidence not launchable from app"
        }
    }

    private var prototypeLabel: String {
        switch plan.sessionMode {
        case .directMacPeer:
            return "IP/NAT preflight + direct P2P two-peer AV"
        case .windowsLoLa:
            return "external LoLa connector"
        case .jackTrip, .ultraGrid:
            return "external connector contract only"
        }
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
                if let reason = plan.sessionMode.unavailableAppReason {
                    Label(reason, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.secondary)
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
                } else if let reason = plan.sessionMode.unavailableAppReason {
                    AppReadableMetric(
                        label: plan.sessionMode.displayName,
                        value: reason,
                        monospaced: false
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
