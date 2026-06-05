import Foundation

public enum DirectPeerTwoPeerRunPlanError: Error, Equatable, Sendable {
    case missingRequiredArgument(String)
    case missingValue(String)
    case unknownArgument(String)
    case duplicateArgument(String)
    case invalidPositiveInt(String)
    case invalidEnumValue(String)
    case invalidHost(String)
    case invalidPortBase(String)
    case emptyField(String)
    case emptyList(String)
    case mismatchedReportReferences
    case passRequiresMeasuredDirectPeerReports
    case duplicatePeerID(String)
    case mismatchedReceiveProof(String)
    case passRequiresTwoPassingReports
    case passRequiresTwoReceiveProofArtifacts
    case missingCommandArgument(String)
}

public struct DirectPeerTwoPeerRunPlanPeer: Codable, Equatable, Sendable {
    public var peerID: String
    public var host: String
    public var portBase: UInt16
    public var inputUID: String
    public var outputUID: String
    public var videoDeviceID: String

    public var audioPort: UInt16 { portBase + 1 }
    public var videoPort: UInt16 { portBase + 2 }
    public var metricsPort: UInt16 { portBase + 3 }

    public init(
        peerID: String,
        host: String,
        portBase: UInt16,
        inputUID: String,
        outputUID: String,
        videoDeviceID: String
    ) {
        self.peerID = peerID
        self.host = host
        self.portBase = portBase
        self.inputUID = inputUID
        self.outputUID = outputUID
        self.videoDeviceID = videoDeviceID
    }
}

public struct DirectPeerTwoPeerRunPlanConfiguration: Codable, Equatable, Sendable {
    public var outputPath: String
    public var runDirectory: String
    public var executablePath: String
    public var macA: DirectPeerTwoPeerRunPlanPeer
    public var macB: DirectPeerTwoPeerRunPlanPeer
    public var durationSeconds: Int
    public var channelCount: Int
    public var sampleRateHertz: Int
    public var framesPerPacket: Int
    public var sampleFormat: String
    public var audioTransport: DirectPeerSessionAudioTransport
    public var videoWidth: Int
    public var videoHeight: Int
    public var videoPixelFormat: String
    public var videoCompression: DirectPeerSessionVideoCompression
    public var videoFrameRate: Int
    public var avProfile: DirectPeerSessionAVProfile
    public var rxBufferProfile: RxBufferProfile
    public var preview: DirectPeerSessionPreviewMode
    public var timeoutSeconds: Int

    public init(
        outputPath: String,
        runDirectory: String,
        executablePath: String = "open-lola",
        macA: DirectPeerTwoPeerRunPlanPeer,
        macB: DirectPeerTwoPeerRunPlanPeer,
        durationSeconds: Int,
        channelCount: Int = 64,
        sampleRateHertz: Int = 48_000,
        framesPerPacket: Int = 32,
        sampleFormat: String = "float32",
        audioTransport: DirectPeerSessionAudioTransport? = nil,
        audioCompression: DirectPeerSessionAudioCompression = .raw,
        videoWidth: Int = 1_280,
        videoHeight: Int = 720,
        videoPixelFormat: String = "bgra8",
        videoCompression: DirectPeerSessionVideoCompression = .raw,
        videoFrameRate: Int = 30,
        avProfile: DirectPeerSessionAVProfile = .balanced,
        rxBufferProfile: RxBufferProfile? = nil,
        preview: DirectPeerSessionPreviewMode = .on,
        timeoutSeconds: Int = 30
    ) {
        self.outputPath = outputPath
        self.runDirectory = runDirectory
        self.executablePath = executablePath
        self.macA = macA
        self.macB = macB
        self.durationSeconds = durationSeconds
        self.channelCount = channelCount
        self.sampleRateHertz = sampleRateHertz
        self.framesPerPacket = framesPerPacket
        self.sampleFormat = sampleFormat
        self.audioTransport = audioTransport ?? audioCompression.audioTransport
        self.videoWidth = videoWidth
        self.videoHeight = videoHeight
        self.videoPixelFormat = videoPixelFormat
        self.videoCompression = videoCompression
        self.videoFrameRate = videoFrameRate
        self.avProfile = avProfile
        self.rxBufferProfile = rxBufferProfile ?? avProfile.defaultRXBufferProfile
        self.preview = preview
        self.timeoutSeconds = timeoutSeconds
    }

    public var audioCompression: DirectPeerSessionAudioCompression {
        get { audioTransport.legacyAudioCompression ?? .raw }
        set { audioTransport = newValue.audioTransport }
    }

    public static func parse(_ arguments: [String]) throws -> DirectPeerTwoPeerRunPlanConfiguration {
        let values = try directPeerTwoPeerValues(arguments)
        let avProfile = try directPeerTwoPeerAVProfile(values["--av-profile"])
        let audioTransport = try directPeerTwoPeerAudioTransport(values)
        let sampleRateHertz = try directPeerTwoPeerOptionalPositiveInt("--sample-rate", values) ?? 48_000
        let framesPerPacket = try directPeerTwoPeerOptionalPositiveInt("--frames", values) ?? 32
        let channelCount = try directPeerTwoPeerOptionalPositiveInt("--channels", values) ?? 64
        let sampleFormatText = values["--sample-format"] ?? "float32"
        let videoPixelFormatText = values["--video-pixel-format"] ?? "bgra8"
        let sampleFormat = try directPeerTwoPeerSampleFormat(sampleFormatText)
        try directPeerTwoPeerValidateAudioTransportShape(
            audioTransport,
            sampleRateHertz: sampleRateHertz,
            framesPerPacket: framesPerPacket,
            sampleFormat: sampleFormat,
            channelCount: channelCount
        )
        let macA = try directPeerTwoPeerPeer(prefix: "mac-a", values)
        let macB = try directPeerTwoPeerPeer(prefix: "mac-b", values)
        try directPeerTwoPeerValidateNetworkShape(local: macA, remote: macB)
        return DirectPeerTwoPeerRunPlanConfiguration(
            outputPath: try directPeerTwoPeerRequired("--output", values),
            runDirectory: try directPeerTwoPeerRequired("--run-dir", values),
            executablePath: values["--executable"] ?? "open-lola",
            macA: macA,
            macB: macB,
            durationSeconds: try directPeerTwoPeerPositiveInt("--duration-seconds", values),
            channelCount: channelCount,
            sampleRateHertz: sampleRateHertz,
            framesPerPacket: framesPerPacket,
            sampleFormat: sampleFormatText,
            audioTransport: audioTransport,
            videoWidth: try directPeerTwoPeerOptionalPositiveInt("--video-width", values) ?? 1_280,
            videoHeight: try directPeerTwoPeerOptionalPositiveInt("--video-height", values) ?? 720,
            videoPixelFormat: try directPeerTwoPeerVideoPixelFormat(videoPixelFormatText),
            videoCompression: try directPeerTwoPeerVideoCompression(values["--video-compression"]),
            videoFrameRate: try directPeerTwoPeerOptionalPositiveInt("--video-frame-rate", values) ?? 30,
            avProfile: avProfile,
            rxBufferProfile: try directPeerTwoPeerRXBufferProfile(
                values["--rx-buffer-profile"],
                avProfile: avProfile
            ),
            preview: try directPeerTwoPeerPreview(values["--preview"]),
            timeoutSeconds: try directPeerTwoPeerOptionalPositiveInt("--timeout-seconds", values) ?? 30
        )
    }
}

private func directPeerTwoPeerSampleFormat(_ value: String) throws -> UdpPcmSampleFormat {
    do {
        return try DirectPeerSessionAVMediaShape.sampleFormat(from: value)
    } catch {
        throw DirectPeerTwoPeerRunPlanError.invalidEnumValue("--sample-format")
    }
}

private func directPeerTwoPeerVideoPixelFormat(_ value: String) throws -> String {
    do {
        return try DirectPeerSessionAVMediaShape.normalizedVideoPixelFormat(from: value)
    } catch {
        throw DirectPeerTwoPeerRunPlanError.invalidEnumValue("--video-pixel-format")
    }
}

private func directPeerTwoPeerValidateAudioTransportShape(
    _ transport: DirectPeerSessionAudioTransport,
    sampleRateHertz: Int,
    framesPerPacket: Int,
    sampleFormat: UdpPcmSampleFormat,
    channelCount: Int
) throws {
    do {
        try DirectPeerSessionAVMediaShape.validateAudioTransportShape(
            transport,
            sampleRateHertz: sampleRateHertz,
            framesPerPacket: framesPerPacket,
            sampleFormat: sampleFormat,
            channelCount: channelCount
        )
    } catch {
        throw DirectPeerTwoPeerRunPlanError.invalidEnumValue("--audio-transport")
    }
}

public enum DirectPeerTwoPeerRunPlanner {
    public static func makeReport(
        configuration: DirectPeerTwoPeerRunPlanConfiguration
    ) throws -> DirectPeerTwoPeerRunPlanReport {
        try directPeerTwoPeerValidateNetworkShape(local: configuration.macA, remote: configuration.macB)
        let commands = [
            try command(role: .responder, local: configuration.macB, remote: configuration.macA, configuration),
            try command(role: .initiator, local: configuration.macA, remote: configuration.macB, configuration),
        ]
        return DirectPeerTwoPeerRunPlanReport(
            id: "m06-direct-p2p-two-peer-plan",
            capturedAt: ISO8601DateFormatter().string(from: Date()),
            runDirectory: configuration.runDirectory,
            commands: commands,
            reportReferences: commands.map {
                DirectPeerTwoPeerRunReportReference(peerID: $0.peerID, path: $0.outputReportPath)
            },
            evidenceGates: [
                "Run mac-to-mac-connection-preflight-run first; default setup must collect IP/NAT reachability and route evidence before media readiness is trusted.",
                "Run both commands on two physical Macs with the listed manual IP addresses.",
                "Attach packet capture path, DSCP observation, and route label to measured evidence.",
                "Validate both direct P2P reports before promoting any aggregate evidence.",
                "Require nonzero routed audio/video counters and raw video receive evidence for PASS.",
            ],
            verdict: .partial,
            notes: "Two-peer orchestration plan only; PASS remains gated on measured direct-peer reports."
        )
    }

    private static func command(
        role: DirectPeerSessionManualRole,
        local: DirectPeerTwoPeerRunPlanPeer,
        remote: DirectPeerTwoPeerRunPlanPeer,
        _ configuration: DirectPeerTwoPeerRunPlanConfiguration
    ) throws -> DirectPeerTwoPeerRunCommand {
        let outputPath = "\(configuration.runDirectory)/m06-direct-p2p-av-\(local.peerID).json"
        return DirectPeerTwoPeerRunCommand(
            peerID: local.peerID,
            role: role,
            outputReportPath: outputPath,
            arguments: try commandArguments(
                role: role,
                local: local,
                remote: remote,
                configuration: configuration,
                outputPath: outputPath
            )
        )
    }
}

private func directPeerTwoPeerValues(_ arguments: [String]) throws -> [String: String] {
    let allowed = Set([
        "--output", "--run-dir", "--executable", "--duration-seconds", "--channels", "--sample-rate",
        "--frames", "--sample-format", "--video-width", "--video-height",
        "--video-pixel-format", "--audio-transport", "--audio-compression", "--video-compression", "--video-frame-rate", "--av-profile", "--rx-buffer-profile", "--preview",
        "--timeout-seconds", "--mac-a-peer", "--mac-a-host",
        "--mac-a-port-base", "--mac-a-input-uid", "--mac-a-output-uid",
        "--mac-a-video-device-id", "--mac-b-peer", "--mac-b-host",
        "--mac-b-port-base", "--mac-b-input-uid", "--mac-b-output-uid",
        "--mac-b-video-device-id",
    ])
    var values: [String: String] = [:]
    var index = 0
    while index < arguments.count {
        let argument = arguments[index]
        guard allowed.contains(argument) else {
            throw DirectPeerTwoPeerRunPlanError.unknownArgument(argument)
        }
        guard values[argument] == nil else {
            throw DirectPeerTwoPeerRunPlanError.duplicateArgument(argument)
        }
        let valueIndex = index + 1
        guard valueIndex < arguments.count, !arguments[valueIndex].hasPrefix("--") else {
            throw DirectPeerTwoPeerRunPlanError.missingValue(argument)
        }
        values[argument] = arguments[valueIndex]
        index += 2
    }
    return values
}

private func directPeerTwoPeerPeer(
    prefix: String,
    _ values: [String: String]
) throws -> DirectPeerTwoPeerRunPlanPeer {
    let hostArgument = "--\(prefix)-host"
    let host = try directPeerTwoPeerRequired(hostArgument, values)
    guard DirectPeerManualEndpointValidator.isSupportedAdvertisedIPv4Host(host) else {
        throw DirectPeerTwoPeerRunPlanError.invalidHost(hostArgument)
    }
    return DirectPeerTwoPeerRunPlanPeer(
        peerID: try directPeerTwoPeerRequired("--\(prefix)-peer", values),
        host: host,
        portBase: try directPeerTwoPeerPortBase("--\(prefix)-port-base", values),
        inputUID: try directPeerTwoPeerRequired("--\(prefix)-input-uid", values),
        outputUID: try directPeerTwoPeerRequired("--\(prefix)-output-uid", values),
        videoDeviceID: try directPeerTwoPeerRequired("--\(prefix)-video-device-id", values)
    )
}

private func directPeerTwoPeerValidateNetworkShape(
    local: DirectPeerTwoPeerRunPlanPeer,
    remote: DirectPeerTwoPeerRunPlanPeer
) throws {
    do {
        try DirectPeerManualNetworkShape(
            localHost: local.host,
            remoteHost: remote.host,
            ports: DirectPeerPortSet(
                controlPort: local.portBase,
                remoteControlPort: remote.portBase,
                audioPort: local.audioPort,
                videoPort: local.videoPort,
                metricsPort: local.metricsPort
            )
        ).validate()
        try DirectPeerManualNetworkShape(
            localHost: remote.host,
            remoteHost: local.host,
            ports: DirectPeerPortSet(
                controlPort: remote.portBase,
                remoteControlPort: local.portBase,
                audioPort: remote.audioPort,
                videoPort: remote.videoPort,
                metricsPort: remote.metricsPort
            )
        ).validate()
    } catch DirectPeerSessionSocketRunnerError.invalidManualHost(let field, _) {
        throw DirectPeerTwoPeerRunPlanError.invalidHost(field)
    } catch DirectPeerSessionSocketRunnerError.invalidManualHostParse(let field, _, _) {
        throw DirectPeerTwoPeerRunPlanError.invalidHost(field)
    } catch DirectPeerSessionSocketRunnerError.invalidManualPort(let field, _) {
        throw DirectPeerTwoPeerRunPlanError.invalidPortBase(field)
    } catch DirectPeerSessionSocketRunnerError.duplicateManualPort(let field, _) {
        throw DirectPeerTwoPeerRunPlanError.invalidPortBase(field)
    } catch {
        throw DirectPeerTwoPeerRunPlanError.invalidPortBase("network")
    }
}

private func directPeerTwoPeerRequired(_ argument: String, _ values: [String: String]) throws -> String {
    guard let value = values[argument], !value.isEmpty else {
        throw DirectPeerTwoPeerRunPlanError.missingRequiredArgument(argument)
    }
    return value
}

private func directPeerTwoPeerOptionalPositiveInt(
    _ argument: String,
    _ values: [String: String]
) throws -> Int? {
    guard let value = values[argument] else {
        return nil
    }
    guard let number = Int(value), number > 0 else {
        throw DirectPeerTwoPeerRunPlanError.invalidPositiveInt(argument)
    }
    return number
}

private func directPeerTwoPeerPositiveInt(_ argument: String, _ values: [String: String]) throws -> Int {
    guard let number = try directPeerTwoPeerOptionalPositiveInt(argument, values) else {
        throw DirectPeerTwoPeerRunPlanError.missingRequiredArgument(argument)
    }
    return number
}

private func directPeerTwoPeerPortBase(_ argument: String, _ values: [String: String]) throws -> UInt16 {
    let number = try directPeerTwoPeerPositiveInt(argument, values)
    guard number <= Int(UInt16.max) - 3 else {
        throw DirectPeerTwoPeerRunPlanError.invalidPortBase(argument)
    }
    return UInt16(number)
}

private func directPeerTwoPeerAVProfile(_ value: String?) throws -> DirectPeerSessionAVProfile {
    guard let value else {
        return .balanced
    }
    guard let profile = DirectPeerSessionAVProfile(rawValue: value) else {
        throw DirectPeerTwoPeerRunPlanError.invalidEnumValue("--av-profile")
    }
    return profile
}

private func directPeerTwoPeerVideoCompression(_ value: String?) throws -> DirectPeerSessionVideoCompression {
    guard let value else {
        return .raw
    }
    guard let compression = DirectPeerSessionVideoCompression(rawValue: value) else {
        throw DirectPeerTwoPeerRunPlanError.invalidEnumValue("--video-compression")
    }
    return compression
}

private func directPeerTwoPeerAudioCompression(_ value: String?) throws -> DirectPeerSessionAudioCompression {
    guard let value else {
        return .raw
    }
    guard let compression = DirectPeerSessionAudioCompression(rawValue: value) else {
        throw DirectPeerTwoPeerRunPlanError.invalidEnumValue("--audio-compression")
    }
    return compression
}

private func directPeerTwoPeerAudioTransport(_ values: [String: String]) throws -> DirectPeerSessionAudioTransport {
    let legacyCompression = try directPeerTwoPeerAudioCompression(values["--audio-compression"])
    guard let value = values["--audio-transport"] else {
        return legacyCompression.audioTransport
    }
    guard let transport = DirectPeerSessionAudioTransport(rawValue: value) else {
        throw DirectPeerTwoPeerRunPlanError.invalidEnumValue("--audio-transport")
    }
    if values["--audio-compression"] != nil, transport != legacyCompression.audioTransport {
        throw DirectPeerTwoPeerRunPlanError.invalidEnumValue("--audio-transport")
    }
    return transport
}

private func directPeerTwoPeerRXBufferProfile(
    _ value: String?,
    avProfile: DirectPeerSessionAVProfile
) throws -> RxBufferProfile {
    guard let value else {
        return avProfile.defaultRXBufferProfile
    }
    guard let profile = RxBufferProfile(rawValue: value) else {
        throw DirectPeerTwoPeerRunPlanError.invalidEnumValue("--rx-buffer-profile")
    }
    do {
        _ = try DirectPeerSessionAVBufferPolicy.resolve(
            avProfile: avProfile,
            rxBufferProfile: profile
        )
    } catch {
        throw DirectPeerTwoPeerRunPlanError.invalidEnumValue("--rx-buffer-profile")
    }
    return profile
}

private func directPeerTwoPeerPreview(_ value: String?) throws -> DirectPeerSessionPreviewMode {
    guard let value else {
        return .on
    }
    guard let preview = DirectPeerSessionPreviewMode(rawValue: value) else {
        throw DirectPeerTwoPeerRunPlanError.invalidEnumValue("--preview")
    }
    return preview
}
