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
        DesignPanel(title: "\(plan.sessionMode.displayName) operator readiness", systemImage: "flag.checkered") {
            MetricsGrid {
                AppReadableMetric(label: "Status", value: planReadinessTitle, monospaced: true)
                LabeledContent("Verdict", value: plan.report?.verdict.rawValue ?? "partial")
                AppReadableMetric(label: "Execution status", value: executionController.status)
            }
        }

        if let validationError = plan.validationError {
            AppWarningBanner(
                title: "\(plan.sessionMode.displayName) validation",
                message: validationError
            )
        }

        GroupBox("Media profile") {
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
                VStack(alignment: .leading, spacing: AppSpacing.s) {
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
    }

    private var planReadinessTitle: String {
        if plan.sessionMode == .windowsLoLa {
            return plan.windowsLoLaCommand == nil ? "LoLa fields incomplete" : plan.windowsLoLaFields.outputPath
        }
        if let reason = plan.sessionMode.unavailableAppReason {
            return reason
        }
        return plan.report?.id ?? "Remote inventory incomplete"
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
        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
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
        DesignPanel(title: "Commands", systemImage: "list.bullet.rectangle") {
            DisclosureGroup("Show generated commands") {
                VStack(alignment: .leading, spacing: AppSpacing.s) {
                    Text("Commands are generated from the current operator settings and executed only through the explicit Execution panel.")
                        .foregroundStyle(.secondary)

                    ForEach(plan.report?.commands ?? [], id: \.peerID) { command in
                        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                            HStack {
                                LabeledContent(command.peerID, value: command.role.rawValue)
                                Spacer(minLength: AppSpacing.xs)
                                Button {
                                    AppPasteboard.copyString(AppCommandPreview.shellLine(command.arguments))
                                } label: {
                                    Label("Copy", systemImage: "doc.on.doc")
                                }
                                .font(.caption)
                                .buttonStyle(.plain)
                            }
                            Text(AppCommandPreview.shellLine(command.arguments))
                                .font(.system(.caption, design: .monospaced))
                                .textSelection(.enabled)
                                .lineLimit(nil)
                        }
                        .padding(.vertical, AppSpacing.xxs)
                    }
                    if let windowsLoLaCommand = plan.windowsLoLaCommand {
                        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                            HStack {
                                LabeledContent("Windows LoLa", value: "external-connector")
                                Spacer(minLength: AppSpacing.xs)
                                Button {
                                    AppPasteboard.copyString(AppCommandPreview.shellLine(windowsLoLaCommand))
                                } label: {
                                    Label("Copy", systemImage: "doc.on.doc")
                                }
                                .font(.caption)
                                .buttonStyle(.plain)
                            }
                            Text(AppCommandPreview.shellLine(windowsLoLaCommand))
                                .font(.system(.caption, design: .monospaced))
                                .textSelection(.enabled)
                                .lineLimit(nil)
                        }
                        .padding(.vertical, AppSpacing.xxs)
                    }
                    if let reason = plan.sessionMode.unavailableAppReason {
                        Label(reason, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}
