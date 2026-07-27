// Parses NMP plan settings and writes validated local and remote connector endpoints.
import Foundation

/// Defines the validated fields for NMP plan configuration fields.
public struct ExternalConnectorNmpPlanConfiguration: Equatable, Sendable, ExternalConnectorMediaOptionConfiguring {
    public var localHost: String
    public var remoteHost: String
    public var outputPath: String
    public var runDirectory: String
    public var connectors: [ExternalConnectorKind]
    public var ultraGridExecutable: String?
    public var jackTripExecutable: String?
    public var jackTripVideoExecutable: String?
    public var mediaMode: ExternalConnectorMediaMode
    public var controlTransport: ExternalConnectorControlTransport
    public var mediaOptions: ExternalConnectorMediaOptionValues
    public var videoCapture: String?
    public var videoDisplay: String?
    public var sessionID: String
    public var localRawLinkInterface: String?
    public var remoteRawLinkInterface: String?
    public var localMAC: LoLaEthernetAddress?
    public var remoteMAC: LoLaEthernetAddress?
    public var mediaPacketCount: Int
    public var audioCapture: String?
    public var audioPlayback: String?

    public init(localHost: String, remoteHost: String, outputPath: String) {
        self.localHost = localHost
        self.remoteHost = remoteHost
        self.outputPath = outputPath
        runDirectory = nmpPlanDefaultRunDirectory(forOutputPath: outputPath)
        connectors = [.lola]
        ultraGridExecutable = nil
        jackTripExecutable = nil
        jackTripVideoExecutable = nil
        mediaMode = .audioVideo
        controlTransport = .udp
        mediaOptions = .defaultValues
        videoCapture = nil
        videoDisplay = nil
        sessionID = "1"
        localRawLinkInterface = nil
        remoteRawLinkInterface = nil
        localMAC = nil
        remoteMAC = nil
        mediaPacketCount = 1
        audioCapture = nil
        audioPlayback = nil
    }

    public static func parse(_ arguments: [String]) throws -> ExternalConnectorNmpPlanConfiguration {
        let values = try parseExternalConnectorKeyValueArguments(arguments, allowed: nmpPlanArguments)
        return try makeNmpPlanConfiguration(values)
    }
}

/// Provides the NMP plan configuration under the field-oriented compatibility name.
public typealias NmpPlanConfigurationFields = ExternalConnectorNmpPlanConfiguration

let nmpPlanArguments = Set([
    "--local-host", "--remote-host", "--output", "--run-dir", "--connectors",
    "--ultragrid-executable", "--jacktrip-executable", "--jacktrip-video-executable",
    "--media", "--control-transport", "--duration-seconds", "--channels",
    "--sample-rate", "--frames", "--video-width", "--video-height", "--video-fps",
    "--video-bpp", "--audio-capture", "--audio-playback", "--video-capture",
    "--video-display", "--session-id", "--local-raw-link-interface",
    "--remote-raw-link-interface", "--local-mac", "--remote-mac", "--media-packets"
])

private func makeNmpPlanConfiguration(
    _ values: [String: String]
) throws -> ExternalConnectorNmpPlanConfiguration {
    let outputPath = try requiredExternalConnectorValue("--output", values)
    let media = try parseExternalConnectorMediaOptionValues(values)
    var fields = NmpPlanConfigurationFields(
        localHost: try requiredExternalConnectorValue("--local-host", values),
        remoteHost: try requiredExternalConnectorValue("--remote-host", values),
        outputPath: outputPath
    )
    fields.runDirectory = values["--run-dir"] ?? fields.runDirectory
    fields.connectors = try values["--connectors"].map(parseNmpConnectorList) ?? [.lola]
    fields.ultraGridExecutable = values["--ultragrid-executable"]
    fields.jackTripExecutable = values["--jacktrip-executable"]
    fields.jackTripVideoExecutable = values["--jacktrip-video-executable"]
    fields.mediaMode = try values["--media"].map(parseExternalConnectorMediaMode) ?? .audioVideo
    fields.controlTransport = try parsedNmpPlanControlTransport(values)
    fields.mediaOptions = media
    fields.audioCapture = values["--audio-capture"]
    fields.audioPlayback = values["--audio-playback"]
    fields.videoCapture = values["--video-capture"]
    fields.videoDisplay = values["--video-display"]
    fields.sessionID = values["--session-id"] ?? "1"
    fields.localRawLinkInterface = values["--local-raw-link-interface"]
    fields.remoteRawLinkInterface = values["--remote-raw-link-interface"]
    fields.localMAC = try values["--local-mac"].map(parseLoLaEthernetAddress)
    fields.remoteMAC = try values["--remote-mac"].map(parseLoLaEthernetAddress)
    fields.mediaPacketCount = try optionalExternalConnectorPositiveInteger("--media-packets", values) ?? 1
    return fields
}

private func parsedNmpPlanControlTransport(
    _ values: [String: String]
) throws -> ExternalConnectorControlTransport {
    try values["--control-transport"].map(parseExternalConnectorControlTransport) ?? .udp
}

/// Records the evidence and outcome for external connector NMP plan report.
public struct ExternalConnectorNmpPlanReport: ReportValidatingArtifact, PrettyJSONCodable, Equatable, Sendable {
    public var id: String
    public var capturedAt: String
    public var localHost: String
    public var remoteHost: String
    public var runDirectory: String
    public var connectors: [ExternalConnectorKind]
    public var mediaMode: ExternalConnectorMediaMode
    public var plans: [ExternalConnectorConnectionPlanReport]
    public var verdict: MeasurementVerdict
    public var notes: String

    public func validate() throws {
        try requireExternalConnectorSessionNonEmpty(id, "id")
        try requireExternalConnectorSessionNonEmpty(capturedAt, "capturedAt")
        try requireExternalConnectorSessionNonEmpty(localHost, "localHost")
        try requireExternalConnectorSessionNonEmpty(remoteHost, "remoteHost")
        try requireExternalConnectorSessionNonEmpty(runDirectory, "runDirectory")
        try requireExternalConnectorSessionNonEmpty(notes, "notes")
        guard verdict != .pass else {
            throw ExternalConnectorValidationError.realWorldPassNotAllowed
        }
        guard !connectors.isEmpty, Set(connectors).count == connectors.count else {
            throw ExternalConnectorSessionError.emptyField("connectors")
        }
        guard plans.count == connectors.count, plans.map(\.connector) == connectors else {
            throw ExternalConnectorSessionError.emptyField("plans")
        }
        for plan in plans {
            try plan.validate()
            guard plan.localHost == localHost, plan.remoteHost == remoteHost else {
                throw ExternalConnectorSessionError.emptyField("plans")
            }
            guard plan.mediaMode == mediaMode else {
                throw ExternalConnectorSessionError.invalidMediaMode(plan.mediaMode.rawValue)
            }
        }
    }
}

/// Builds and validates the local and remote endpoint plan used by NMP orchestration.
public enum ExternalConnectorNmpPlanRunner {
    public static func run(
        configuration: ExternalConnectorNmpPlanConfiguration
    ) throws -> ExternalConnectorNmpPlanReport {
        try validateNmpRawLinkConfiguration(configuration)
        let plans = try configuration.connectors.map {
            try ExternalConnectorConnectionPlanRunner.run(configuration: connectionPlanConfiguration(
                configuration,
                connector: $0
            ))
        }
        return ExternalConnectorNmpPlanReport(
            id: "external-connector-nmp-av-plan",
            capturedAt: ISO8601DateFormatter().string(from: Date()),
            localHost: configuration.localHost,
            remoteHost: configuration.remoteHost,
            runDirectory: configuration.runDirectory,
            connectors: configuration.connectors,
            mediaMode: configuration.mediaMode,
            plans: plans,
            verdict: .partial,
            notes: nmpPlanNotes()
        )
    }

    private static func connectionPlanConfiguration(
        _ configuration: ExternalConnectorNmpPlanConfiguration,
        connector: ExternalConnectorKind
    ) -> ExternalConnectorConnectionPlanConfiguration {
        ExternalConnectorConnectionPlanConfiguration(
            connector: connector,
            localHost: configuration.localHost,
            remoteHost: configuration.remoteHost,
            outputPath: nmpConnectionPlanOutputPath(configuration, connector: connector),
            runDirectory: nmpConnectionPlanRunDirectory(configuration, connector: connector),
            executable: executable(configuration, connector: connector),
            videoExecutable: videoExecutable(configuration, connector: connector),
            mediaMode: configuration.mediaMode,
            controlTransport: nmpConnectionPlanControlTransport(configuration, connector: connector),
            mediaOptions: configuration.mediaOptions,
            controlPort: nil,
            audioPort: nil,
            videoPort: nil,
            audioCapture: configuration.audioCapture,
            audioPlayback: configuration.audioPlayback,
            videoCapture: configuration.videoCapture,
            videoDisplay: configuration.videoDisplay,
            sessionID: configuration.sessionID,
            localRawLinkInterface: connector == .lola ? configuration.localRawLinkInterface : nil,
            remoteRawLinkInterface: connector == .lola ? configuration.remoteRawLinkInterface : nil,
            localMAC: connector == .lola ? configuration.localMAC : nil,
            remoteMAC: connector == .lola ? configuration.remoteMAC : nil,
            mediaPacketCount: configuration.mediaPacketCount,
            ultraGridTopologyMode: .directPeer,
            ultraGridFECMode: .none,
            jackTrip: JackTripRunConfiguration()
        )
    }
}

private func nmpPlanNotes() -> String {
    [
        "Universal NMP A/V handoff plan for LoLa, MVTP/UltraGrid, and JackTrip",
        "plus auxiliary UltraGrid video.",
        "It emits executable endpoint commands and connector-scoped preflights,",
        "but does not claim real interoperability until both peers run",
        "and measured media evidence is attached."
    ].joined(separator: " ")
}

private func nmpConnectionPlanOutputPath(
    _ configuration: ExternalConnectorNmpPlanConfiguration,
    connector: ExternalConnectorKind
) -> String {
    "\(nmpConnectionPlanRunDirectory(configuration, connector: connector))-connection-plan.json"
}

private func nmpConnectionPlanRunDirectory(
    _ configuration: ExternalConnectorNmpPlanConfiguration,
    connector: ExternalConnectorKind
) -> String {
    "\(nmpPlanNormalizedRunDirectory(configuration.runDirectory))/\(connector.rawValue)"
}

private func nmpConnectionPlanControlTransport(
    _ configuration: ExternalConnectorNmpPlanConfiguration,
    connector: ExternalConnectorKind
) -> ExternalConnectorControlTransport {
    connector == .lola ? configuration.controlTransport : defaultControlTransport(for: connector)
}

private func validateNmpRawLinkConfiguration(_ configuration: ExternalConnectorNmpPlanConfiguration) throws {
    let hasRawLinkInput = configuration.localRawLinkInterface != nil
        || configuration.remoteRawLinkInterface != nil
        || configuration.localMAC != nil
        || configuration.remoteMAC != nil
    guard hasRawLinkInput else {
        return
    }
    guard configuration.connectors.contains(.lola) else {
        throw ExternalConnectorSessionError.rawLinkRequiresLoLaConnector
    }
}

private func executable(
    _ configuration: ExternalConnectorNmpPlanConfiguration,
    connector: ExternalConnectorKind
) -> String? {
    switch connector {
    case .lola:
        return nil
    case .mvtpUltraGrid:
        return configuration.ultraGridExecutable
    case .jackTrip:
        return configuration.jackTripExecutable
    }
}

private func videoExecutable(
    _ configuration: ExternalConnectorNmpPlanConfiguration,
    connector: ExternalConnectorKind
) -> String? {
    guard connector == .jackTrip else {
        return nil
    }
    return configuration.jackTripVideoExecutable ?? configuration.ultraGridExecutable
}

private func parseNmpConnectorList(_ value: String) throws -> [ExternalConnectorKind] {
    let connectors = try value.split(separator: ",").map {
        try parseExternalConnectorKind(String($0))
    }
    guard !connectors.isEmpty, Set(connectors).count == connectors.count else {
        throw ExternalConnectorSessionError.emptyField("connectors")
    }
    return connectors
}

private func nmpPlanDefaultRunDirectory(forOutputPath outputPath: String) -> String {
    guard let slash = outputPath.lastIndex(of: "/") else {
        return "."
    }
    if slash == outputPath.startIndex {
        return "/"
    }
    return String(outputPath[..<slash])
}

private func nmpPlanNormalizedRunDirectory(_ runDirectory: String) -> String {
    guard runDirectory.count > 1, runDirectory.hasSuffix("/") else {
        return runDirectory
    }
    return String(runDirectory.dropLast())
}
