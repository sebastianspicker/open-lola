import Foundation

public struct ExternalConnectorNmpPlanConfiguration: Equatable, Sendable {
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
    public var durationSeconds: Int
    public var channels: Int
    public var sampleRateHertz: Int?
    public var framesPerPacket: Int?
    public var videoWidth: Int
    public var videoHeight: Int
    public var videoFrameRate: Int
    public var videoBitsPerPixel: Int
    public var audioCapture: String?
    public var audioPlayback: String?
    public var videoCapture: String?
    public var videoDisplay: String?
    public var sessionID: String
    public var localRawLinkInterface: String?
    public var remoteRawLinkInterface: String?
    public var localMAC: LoLaEthernetAddress?
    public var remoteMAC: LoLaEthernetAddress?
    public var mediaPacketCount: Int

    public init(
        localHost: String,
        remoteHost: String,
        outputPath: String,
        runDirectory: String? = nil,
        connectors: [ExternalConnectorKind] = [.lola],
        ultraGridExecutable: String? = nil,
        jackTripExecutable: String? = nil,
        jackTripVideoExecutable: String? = nil,
        mediaMode: ExternalConnectorMediaMode = .audioVideo,
        controlTransport: ExternalConnectorControlTransport = .udp,
        durationSeconds: Int = 1,
        channels: Int = 2,
        sampleRateHertz: Int? = nil,
        framesPerPacket: Int? = nil,
        videoWidth: Int = 1920,
        videoHeight: Int = 1080,
        videoFrameRate: Int = 30,
        videoBitsPerPixel: Int = 24,
        audioCapture: String? = nil,
        audioPlayback: String? = nil,
        videoCapture: String? = nil,
        videoDisplay: String? = nil,
        sessionID: String = "1",
        localRawLinkInterface: String? = nil,
        remoteRawLinkInterface: String? = nil,
        localMAC: LoLaEthernetAddress? = nil,
        remoteMAC: LoLaEthernetAddress? = nil,
        mediaPacketCount: Int = 1
    ) {
        self.localHost = localHost
        self.remoteHost = remoteHost
        self.outputPath = outputPath
        self.runDirectory = runDirectory ?? nmpPlanDefaultRunDirectory(forOutputPath: outputPath)
        self.connectors = connectors
        self.ultraGridExecutable = ultraGridExecutable
        self.jackTripExecutable = jackTripExecutable
        self.jackTripVideoExecutable = jackTripVideoExecutable
        self.mediaMode = mediaMode
        self.controlTransport = controlTransport
        self.durationSeconds = durationSeconds
        self.channels = channels
        self.sampleRateHertz = sampleRateHertz
        self.framesPerPacket = framesPerPacket
        self.videoWidth = videoWidth
        self.videoHeight = videoHeight
        self.videoFrameRate = videoFrameRate
        self.videoBitsPerPixel = videoBitsPerPixel
        self.audioCapture = audioCapture
        self.audioPlayback = audioPlayback
        self.videoCapture = videoCapture
        self.videoDisplay = videoDisplay
        self.sessionID = sessionID
        self.localRawLinkInterface = localRawLinkInterface
        self.remoteRawLinkInterface = remoteRawLinkInterface
        self.localMAC = localMAC
        self.remoteMAC = remoteMAC
        self.mediaPacketCount = mediaPacketCount
    }

    public static func parse(_ arguments: [String]) throws -> ExternalConnectorNmpPlanConfiguration {
        let allowed = [
            "--local-host", "--remote-host", "--output", "--run-dir", "--connectors",
            "--ultragrid-executable", "--jacktrip-executable", "--jacktrip-video-executable",
            "--media", "--control-transport", "--duration-seconds", "--channels",
            "--sample-rate", "--frames", "--video-width", "--video-height", "--video-fps",
            "--video-bpp", "--audio-capture", "--audio-playback", "--video-capture",
            "--video-display", "--session-id", "--local-raw-link-interface",
            "--remote-raw-link-interface", "--local-mac", "--remote-mac", "--media-packets",
        ]
        var values: [String: String] = [:]
        var index = 0
        while index < arguments.count {
            let argument = arguments[index]
            guard allowed.contains(argument) else {
                throw ExternalConnectorSessionError.unknownArgument(argument)
            }
            guard values[argument] == nil else {
                throw ExternalConnectorSessionError.duplicateArgument(argument)
            }
            let valueIndex = index + 1
            guard valueIndex < arguments.count, !arguments[valueIndex].hasPrefix("--") else {
                throw ExternalConnectorSessionError.missingValue(argument)
            }
            values[argument] = arguments[valueIndex]
            index += 2
        }
        let outputPath = try requiredExternalConnectorValue("--output", values)
        return try ExternalConnectorNmpPlanConfiguration(
            localHost: requiredExternalConnectorValue("--local-host", values),
            remoteHost: requiredExternalConnectorValue("--remote-host", values),
            outputPath: outputPath,
            runDirectory: values["--run-dir"],
            connectors: values["--connectors"].map(parseNmpConnectorList) ?? [.lola],
            ultraGridExecutable: values["--ultragrid-executable"],
            jackTripExecutable: values["--jacktrip-executable"],
            jackTripVideoExecutable: values["--jacktrip-video-executable"],
            mediaMode: values["--media"].map(parseExternalConnectorMediaMode) ?? .audioVideo,
            controlTransport: values["--control-transport"].map(parseExternalConnectorControlTransport) ?? .udp,
            durationSeconds: optionalExternalConnectorPositiveInteger("--duration-seconds", values) ?? 1,
            channels: optionalExternalConnectorPositiveInteger("--channels", values) ?? 2,
            sampleRateHertz: optionalExternalConnectorPositiveInteger("--sample-rate", values),
            framesPerPacket: optionalExternalConnectorPositiveInteger("--frames", values),
            videoWidth: optionalExternalConnectorPositiveInteger("--video-width", values) ?? 1920,
            videoHeight: optionalExternalConnectorPositiveInteger("--video-height", values) ?? 1080,
            videoFrameRate: optionalExternalConnectorPositiveInteger("--video-fps", values) ?? 30,
            videoBitsPerPixel: optionalExternalConnectorPositiveInteger("--video-bpp", values) ?? 24,
            audioCapture: values["--audio-capture"],
            audioPlayback: values["--audio-playback"],
            videoCapture: values["--video-capture"],
            videoDisplay: values["--video-display"],
            sessionID: values["--session-id"] ?? "1",
            localRawLinkInterface: values["--local-raw-link-interface"],
            remoteRawLinkInterface: values["--remote-raw-link-interface"],
            localMAC: try values["--local-mac"].map(parseLoLaEthernetAddress),
            remoteMAC: try values["--remote-mac"].map(parseLoLaEthernetAddress),
            mediaPacketCount: optionalExternalConnectorPositiveInteger("--media-packets", values) ?? 1
        )
    }
}

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
            notes: "Universal NMP A/V handoff plan for LoLa, MVTP/UltraGrid, and JackTrip plus auxiliary UltraGrid video. It emits executable endpoint commands and connector-scoped preflights, but does not claim real interoperability until both peers run and measured media evidence is attached."
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
            outputPath: "\(nmpPlanNormalizedRunDirectory(configuration.runDirectory))/\(connector.rawValue)-connection-plan.json",
            runDirectory: "\(nmpPlanNormalizedRunDirectory(configuration.runDirectory))/\(connector.rawValue)",
            executable: executable(configuration, connector: connector),
            videoExecutable: videoExecutable(configuration, connector: connector),
            mediaMode: configuration.mediaMode,
            controlTransport: connector == .lola ? configuration.controlTransport : defaultControlTransport(for: connector),
            durationSeconds: configuration.durationSeconds,
            controlPort: nil,
            audioPort: nil,
            videoPort: nil,
            channels: configuration.channels,
            sampleRateHertz: configuration.sampleRateHertz,
            framesPerPacket: configuration.framesPerPacket,
            videoWidth: configuration.videoWidth,
            videoHeight: configuration.videoHeight,
            videoFrameRate: configuration.videoFrameRate,
            videoBitsPerPixel: configuration.videoBitsPerPixel,
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
