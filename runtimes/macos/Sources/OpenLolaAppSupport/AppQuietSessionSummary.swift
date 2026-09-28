// Formats selected configuration without treating planned media as observed peer agreement.
import OpenLolaCore

struct AppQuietConfigurationRow: Identifiable {
    let label: String
    let value: String
    var id: String { label }
}

struct AppQuietSessionSummary {
    let surface: NativeAppShellOperatorPrototypeState
    let plan: AppOperatorPrototypePlan

    var durationSeconds: Int {
        switch surface.sessionMode {
        case .directMacPeer: surface.directPeerCommandFields.durationSeconds
        case .windowsLoLa: surface.windowsLoLaPeerFields.durationSeconds
        case .jackTrip, .ultraGrid: plan.externalConnectorFields.durationSeconds
        }
    }

    var localPeer: String {
        surface.sessionMode == .directMacPeer
            ? nonempty(surface.directPeerCommandFields.localPeer) : plan.topologyLocalPeer
    }

    var remotePeer: String {
        surface.sessionMode == .directMacPeer
            ? nonempty(surface.directPeerCommandFields.remotePeer) : plan.topologyRemotePeer
    }

    var localHost: String {
        surface.sessionMode == .directMacPeer
            ? nonempty(surface.directPeerCommandFields.localHost) : nonempty(plan.topologyLocalHost)
    }

    var remoteHost: String {
        surface.sessionMode == .directMacPeer
            ? nonempty(surface.directPeerCommandFields.remoteHost) : nonempty(plan.topologyRemoteHost)
    }

    var rows: [AppQuietConfigurationRow] {
        let inventory = surface.inventory
        let selection = inventory.selection
        let input = inventory.audioDevices.first { $0.uid == selection.audioInputUID }?.name
        let output = inventory.audioDevices.first { $0.uid == selection.audioOutputUID }?.name
        let camera = inventory.videoDevices.first { $0.uniqueId == selection.videoDeviceID }?.label
        let requirements = AppRequiredDevicePolicy.requirements(for: surface)
        var devices: [AppQuietConfigurationRow] = []
        if requirements.audioInput {
            devices.append(.init(label: "Audio input", value: input ?? nonempty(selection.audioInputUID)))
        }
        if requirements.audioOutput {
            devices.append(.init(label: "Audio output", value: output ?? nonempty(selection.audioOutputUID)))
        }
        if requirements.videoInput {
            devices.append(.init(label: "Camera", value: camera ?? nonempty(selection.videoDeviceID)))
        }
        return devices + formatRows
    }

    private var formatRows: [AppQuietConfigurationRow] {
        switch surface.sessionMode {
        case .directMacPeer:
            let fields = surface.directPeerCommandFields
            return [
                .init(label: "Audio format", value: "\(fields.sampleRateHertz) Hz · \(fields.sampleFormat)"),
                .init(label: "Packet size", value: "\(fields.framesPerPacket) frames · \(fields.channelCount) channels"),
                .init(label: "Video", value: "\(fields.videoWidth) × \(fields.videoHeight) · \(fields.videoFrameRate) fps · \(fields.videoCompression.rawValue)"),
                .init(label: "Priority / receive buffer", value: "\(fields.avProfile.rawValue) / \(fields.rxBufferProfile.rawValue)"),
                .init(label: "Transport", value: fields.audioTransport.rawValue)
            ]
        case .windowsLoLa:
            let fields = surface.windowsLoLaPeerFields
            return [
                .init(label: "Audio format", value: "\(fields.sampleRateHertz) Hz · \(fields.channelCount) channels"),
                .init(label: "Packet size", value: "\(fields.framesPerPacket) frames"),
                .init(label: "Media mode", value: fields.mediaMode.rawValue),
                .init(label: "Video payload", value: fields.payloadMode.rawValue)
            ]
        case .jackTrip, .ultraGrid:
            return [
                .init(label: "Connector", value: surface.sessionMode.displayName),
                .init(label: "Media mode", value: plan.externalConnectorFields.mediaMode.rawValue),
                .init(label: "Role", value: plan.externalConnectorFields.role.rawValue)
            ]
        }
    }

    private func nonempty(_ text: String?) -> String {
        let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? "Not selected" : trimmed
    }
}
