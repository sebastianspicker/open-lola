// Translates MadiFullDuplexCommands command syntax into core API calls, keeping CLI parsing independent from domain services.
import Foundation
import OpenLolaCore

func handleMadiFullDuplexCommand(_ arguments: [String]) throws -> Bool {
    switch arguments {
    case ["madi-full-duplex-synthetic-smoke"]:
        let report = try MadiFullDuplexSyntheticSmoke.run()
        try report.validate()
        print(try report.prettyJSONString())
        printVerdict(report.verdict)
    case let args where args.count == 2 && args[0] == "validate-madi-full-duplex-report":
        try validateReport(at: args[1], as: MadiFullDuplexReport.self, label: "MADI full-duplex report")
    case let args where args.first == "madi-full-duplex-run":
        let run = try MadiFullDuplexCommandRun.parse(Array(args.dropFirst()))
        let report = try MadiFullDuplexSocketRunner.run(
            configuration: run.configuration,
            receiverDriftFramesPerPacket: run.receiverDriftFramesPerPacket
        )
        try report.validate()
        try writeJSONData(try report.prettyJSONData(), to: run.outputPath)
        print("MADI full-duplex UDP runtime report written: \(run.outputPath)")
        print("local-peer: \(run.configuration.localPeerID)")
        print("remote-peer: \(run.configuration.remotePeerID)")
        print("packets: \(run.configuration.packetCount)")
        printVerdict(report.verdict)
    default:
        return false
    }
    return true
}

private struct MadiFullDuplexCommandRun {
    var configuration: MadiFullDuplexSessionConfiguration
    var outputPath: String
    var receiverDriftFramesPerPacket: Int

    static func parse(_ arguments: [String]) throws -> MadiFullDuplexCommandRun {
        let values = try parseKeyValues(arguments)
        return MadiFullDuplexCommandRun(
            configuration: try configuration(from: values),
            outputPath: try fdRequired("--output", values, label: "outputPath"),
            receiverDriftFramesPerPacket: try fdOptionalInt(
                "--drift-frames-per-packet",
                values
            ) ?? 0
        )
    }

    private static func configuration(
        from values: [String: String]
    ) throws -> MadiFullDuplexSessionConfiguration {
        let port = try fdPort(values)
        let remotePort = try fdOptionalPort("--remote-port", values) ?? port
        let sampleFormat = try fdSampleFormat(values["--sample-format"] ?? "float32")
        let channelCount = try fdPositiveInt("--channels", values)
        let receiverMixPolicy = values["--receiver-mix"] ?? "identity-default"
        let rxBufferProfile = try fdRxBufferProfile(values["--rx-buffer-profile"] ?? "direct")
        let configuration = try MadiFullDuplexSessionConfiguration.sourceLevel(MadiFullDuplexSourceLevelRequest(
            session: MadiFullDuplexSourceLevelRequest.Session(
                sessionID: values["--session-id"] ?? "m05-manual-full-duplex",
                localPeerID: try fdRequired("--local-peer", values, label: "localPeerID"),
                remotePeerID: try fdRequired("--remote-peer", values, label: "remotePeerID"),
                localEndpoint: SessionNetworkEndpoint(
                    host: try fdRequired("--local-host", values, label: "localEndpoint.host"),
                    port: port
                ),
                remoteEndpoint: SessionNetworkEndpoint(
                    host: try fdRequired("--remote-host", values, label: "remoteEndpoint.host"),
                    port: remotePort
                )
            ),
            devices: MadiFullDuplexSourceLevelRequest.Devices(
                inputUID: values["--input-uid"] ?? "manual-rme-madi",
                outputUID: values["--output-uid"] ?? "manual-rme-madi"
            ),
            audio: MadiFullDuplexSourceLevelRequest.Audio(
                packetCount: try fdPositiveInt("--duration-packets", values),
                channelCount: channelCount,
                sampleRateHertz: try fdPositiveInt("--sample-rate", values),
                framesPerPacket: try fdPositiveInt("--frames", values),
                sampleFormat: sampleFormat
            ),
            streams: MadiFullDuplexSourceLevelRequest.Streams(
                localID: try fdOptionalPositiveInt("--local-stream-id", values) ?? 1,
                remoteID: try fdOptionalPositiveInt("--remote-stream-id", values) ?? 2
            ),
            receiverMix: MadiFullDuplexSourceLevelRequest.ReceiverMix(
                rxBufferProfile: rxBufferProfile,
                snapshot: try fdReceiverMix(receiverMixPolicy, channelCount: channelCount),
                policy: receiverMixPolicy
            )
        ))
        return configuration
    }
}

private func parseKeyValues(_ arguments: [String]) throws -> [String: String] {
    let allowed = Set([
        "--session-id",
        "--local-peer",
        "--remote-peer",
        "--local-host",
        "--remote-host",
        "--port",
        "--remote-port",
        "--sample-rate",
        "--frames",
        "--channels",
        "--sample-format",
        "--rx-buffer-profile",
        "--duration-packets",
        "--input-uid",
        "--output-uid",
        "--drift-frames-per-packet",
        "--local-stream-id",
        "--remote-stream-id",
        "--receiver-mix",
        "--output"
    ])
    var values: [String: String] = [:]
    var index = 0
    while index < arguments.count {
        let key = arguments[index]
        guard allowed.contains(key) else {
            throw CommandError.invalidArgument("unknown \(key)")
        }
        guard values[key] == nil else {
            throw CommandError.invalidArgument("duplicate \(key)")
        }
        guard index + 1 < arguments.count, !arguments[index + 1].hasPrefix("--") else {
            throw CommandError.invalidArgument("missing value for \(key)")
        }
        values[key] = arguments[index + 1]
        index += 2
    }
    return values
}

private func fdRequired(_ key: String, _ values: [String: String], label: String? = nil) throws -> String {
    guard let value = values[key], !value.isEmpty else {
        let field = label.map { "\($0) (\(key))" } ?? key
        throw CommandError.invalidArgument("missing \(field)")
    }
    return value
}

private func fdPositiveInt(_ key: String, _ values: [String: String]) throws -> Int {
    guard let value = Int(try fdRequired(key, values)), value > 0 else {
        throw CommandError.invalidArgument("invalid positive integer for \(key)")
    }
    return value
}

private func fdOptionalInt(_ key: String, _ values: [String: String]) throws -> Int? {
    guard let text = values[key] else {
        return nil
    }
    guard let value = Int(text) else {
        throw CommandError.invalidArgument("invalid integer for \(key)")
    }
    return value
}

private func fdOptionalPositiveInt(_ key: String, _ values: [String: String]) throws -> Int? {
    guard let text = values[key] else {
        return nil
    }
    guard let value = Int(text), value > 0 else {
        throw CommandError.invalidArgument("invalid positive integer for \(key)")
    }
    return value
}

private func fdPort(_ values: [String: String]) throws -> UInt16 {
    let value = try fdPositiveInt("--port", values)
    guard value <= Int(UInt16.max) else {
        throw CommandError.invalidPort(String(value))
    }
    return UInt16(value)
}

private func fdOptionalPort(_ key: String, _ values: [String: String]) throws -> UInt16? {
    guard values[key] != nil else {
        return nil
    }
    let value = try fdPositiveInt(key, values)
    guard value <= Int(UInt16.max) else {
        throw CommandError.invalidPort(String(value))
    }
    return UInt16(value)
}

private func fdSampleFormat(_ value: String) throws -> UdpPcmSampleFormat {
    switch value {
    case "float32", "float32-le":
        return .float32LittleEndian
    case "int16", "int16-le":
        return .int16LittleEndian
    default:
        throw CommandError.invalidArgument("invalid --sample-format")
    }
}

private func fdRxBufferProfile(_ value: String) throws -> RxBufferProfile {
    guard let profile = RxBufferProfile(rawValue: value) else {
        throw CommandError.invalidArgument("invalid --rx-buffer-profile \(value)")
    }
    return profile
}

private func fdReceiverMix(
    _ policy: String,
    channelCount: Int
) throws -> ReceiverMixSnapshot? {
    switch policy {
    case "identity-default":
        return nil
    case "identity":
        return ReceiverMixSnapshot.identity(
            inputChannels: AudioChannelSet.defaultInput(count: channelCount),
            outputChannels: AudioChannelSet.defaultOutput(count: channelCount)
        )
    case "swap-stereo":
        guard channelCount >= 2 else {
            throw CommandError.invalidArgument("--receiver-mix swap-stereo requires at least two channels")
        }
        let swapped = [
            ReceiverMixRoute(
                sourceChannelIndex: 0,
                destinationChannelIndex: 1,
                gainDb: 0,
                muted: false,
                pan: 0
            ),
            ReceiverMixRoute(
                sourceChannelIndex: 1,
                destinationChannelIndex: 0,
                gainDb: 0,
                muted: false,
                pan: 0
            )
        ]
        let remaining = (2..<channelCount).map { index in
            ReceiverMixRoute(
                sourceChannelIndex: index,
                destinationChannelIndex: index,
                gainDb: 0,
                muted: false,
                pan: 0
            )
        }
        return ReceiverMixSnapshot(
            routes: swapped + remaining,
            requiresDestructiveDownmix: false
        )
    default:
        throw CommandError.invalidArgument("invalid --receiver-mix")
    }
}
