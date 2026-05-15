import Foundation
import OpenLolaCore

private let directP2PPositiveIntegerBounds: [String: Int] = [
    "--packets": 1_000_000,
    "--sample-rate": 384_000,
    "--frames": 4_096,
    "--duration-seconds": 86_400,
    "--video-width": 8_192,
    "--video-height": 8_192,
    "--video-frame-rate": 240,
    "--video-stream-id": Int(UInt32.max),
    "--channels": 256,
    "--timeout-seconds": 86_400,
]

func printDirectP2PSessionRunUsage() {
    let supportedOptions = directP2PSessionRunPublicArguments().sorted().joined(separator: " ")
    print(
        """
        Usage:
          open-lola direct-p2p-session-run --output <path> [--packets <n>]
          open-lola direct-p2p-session-run --role initiator|responder --local-peer <id> --remote-peer <id> --local-host <ip> --remote-host <ip> --control-port <n> --remote-control-port <n> --audio-port <n> --video-port <n> --metrics-port <n> --output <path> [--packets <n>]
          open-lola direct-p2p-session-run --media audio-video --role initiator|responder --local-peer <id> --remote-peer <id> --local-host <ip> --remote-host <ip> --control-port <n> --remote-control-port <n> --audio-port <n> --video-port <n> --metrics-port <n> --output <path> --duration-seconds <n> --input-uid <uid> --output-uid <uid> --video-device-id <id|auto> [--av-profile balanced|fastest] [--rx-buffer-profile direct|small|adaptive|stableWan] [--audio-transport openlola-raw|openlola-opus-celt-ld|aes67-st2110-l24] [--video-compression raw|jpeg-xs] [--preview on|off] [--quality-policy structural|require-useful-media]

        Supported options:
          \(supportedOptions)
        """
    )
}

func parseDirectP2PSessionRunArguments(_ arguments: [String]) throws -> [String: String] {
    try KeyValueArgumentParser.parseValues(
        arguments,
        allowed: directP2PSessionRunAllowedArguments(),
        allowsDashPrefixedValues: false,
        unknown: { CommandError.invalidArgument("unknown \($0)") },
        duplicate: { CommandError.invalidArgument("duplicate \($0)") },
        missingValue: { CommandError.invalidArgument("missing value for \($0)") }
    )
}

func directP2PSessionRunOutputPath(_ values: [String: String]) throws -> String {
    guard let outputPath = values["--output"], !outputPath.isEmpty else {
        throw CommandError.invalidArgument("missing --output")
    }
    return outputPath
}

func directP2PReadyFileWriter(_ values: [String: String]) -> (() -> Void)? {
    guard let readyFilePath = values["--ready-file"] else {
        return nil
    }
    return {
        let readyFileURL = URL(fileURLWithPath: readyFilePath)
        do {
            try FileManager.default.createDirectory(
                at: readyFileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try Data("ready\n".utf8).write(to: readyFileURL)
        } catch {
            writeError("failed to write direct P2P readiness marker: \(error)")
        }
    }
}

func directP2PSessionMediaMode(
    _ values: [String: String]
) throws -> DirectPeerSessionMediaMode {
    guard let value = values["--media"] else {
        return .audio
    }
    guard let mode = DirectPeerSessionMediaMode(rawValue: value) else {
        throw CommandError.invalidArgument("invalid --media")
    }
    return mode
}

func directP2PSessionRunPacketCount(
    _ values: [String: String],
    mediaMode: DirectPeerSessionMediaMode
) throws -> Int {
    if mediaMode == .audioVideo {
        if values["--packets"] != nil {
            throw CommandError.invalidArgument("--packets is not valid with --media audio-video")
        }
        return 1
    }
    guard let value = values["--packets"] else {
        return 3
    }
    guard let count = Int(value),
          count > 0,
          count <= directP2PMaximumPositiveInteger(for: "--packets") else {
        throw CommandError.invalidArgument("invalid --packets")
    }
    return count
}

func directP2PSessionAVConfiguration(
    _ values: [String: String]
) throws -> DirectPeerSessionAVRunConfiguration {
    guard values["--role"] != nil else {
        throw CommandError.invalidArgument("--media audio-video requires --role initiator|responder")
    }
    guard values["--duration-seconds"] != nil else {
        throw CommandError.invalidArgument("--media audio-video requires --duration-seconds")
    }
    let audioDeviceUID = try directP2PAudioDeviceUID(values)
    guard values["--video-device-id"] != nil else {
        throw CommandError.invalidArgument("--media audio-video requires --video-device-id")
    }
    let manual = try directP2PSessionManualConfiguration(values, packetCount: 1)
    let audioChannelCount = manual.audioChannelCount
    let avProfile = try directP2PAVProfile(values["--av-profile"])
    let rxBufferProfile = try directP2PRXBufferProfile(
        values["--rx-buffer-profile"],
        avProfile: avProfile
    )
    let sampleRateHertz = try directP2POptionalPositiveInt("--sample-rate", values) ?? 48_000
    let audioTransport = try directP2PAudioTransport(values)
    let framesPerPacket = try directP2PFrames(values, avProfile: avProfile, audioTransport: audioTransport)
    let sampleFormatText = values["--sample-format"] ?? "float32"
    let videoPixelFormatText = values["--video-pixel-format"] ?? "bgra8"
    let sampleFormat = try directP2PSampleFormat(sampleFormatText)
    try directP2PValidateAudioTransportShape(
        audioTransport,
        sampleRateHertz: sampleRateHertz,
        framesPerPacket: framesPerPacket,
        sampleFormat: sampleFormat,
        channelCount: audioChannelCount
    )
    try directP2PValidateAoIPSDPInput(values["--aoip-sdp-input"])
    return DirectPeerSessionAVRunConfiguration(
        manual: manual,
        durationSeconds: try directP2PRequiredPositiveInt("--duration-seconds", values),
        audioDeviceUID: audioDeviceUID,
        inputDeviceUID: values["--input-uid"] ?? audioDeviceUID,
        outputDeviceUID: values["--output-uid"] ?? audioDeviceUID,
        sampleRateHertz: sampleRateHertz,
        framesPerPacket: framesPerPacket,
        sampleFormat: sampleFormat,
        inputChannels: try directP2POptionalChannelCSV(
            "--input-channels",
            values,
            expectedCount: audioChannelCount
        ) ?? Array(0..<audioChannelCount),
        outputChannels: try directP2POptionalChannelCSV(
            "--output-channels",
            values,
            expectedCount: audioChannelCount
        ) ?? Array(0..<audioChannelCount),
        videoDeviceID: try directP2PRequiredString("--video-device-id", values),
        videoWidth: try directP2POptionalPositiveInt("--video-width", values) ?? 1_280,
        videoHeight: try directP2POptionalPositiveInt("--video-height", values) ?? 720,
        videoPixelFormat: try directP2PVideoPixelFormat(videoPixelFormatText),
        audioTransport: audioTransport,
        videoCompression: try directP2PVideoCompression(values["--video-compression"]),
        videoFrameRate: try directP2POptionalPositiveInt("--video-frame-rate", values) ?? 30,
        videoStreamID: try directP2POptionalPositiveInt("--video-stream-id", values) ?? 100,
        avProfile: avProfile,
        rxBufferProfile: rxBufferProfile,
        preview: try directP2PPreviewMode(values["--preview"], avProfile: avProfile),
        qualityPolicy: try directP2PQualityPolicy(values["--quality-policy"]),
        aoipSDPOutputPath: values["--aoip-sdp-output"],
        aoipSDPInputPath: values["--aoip-sdp-input"]
    )
}

private func directP2PAudioDeviceUID(_ values: [String: String]) throws -> String {
    if let audioDeviceUID = values["--audio-device-uid"], !audioDeviceUID.isEmpty {
        if let inputUID = values["--input-uid"], inputUID != audioDeviceUID {
            throw CommandError.invalidArgument("--input-uid must equal --audio-device-uid in v1 audio-video mode")
        }
        if let outputUID = values["--output-uid"], outputUID != audioDeviceUID {
            throw CommandError.invalidArgument("--output-uid must equal --audio-device-uid in v1 audio-video mode")
        }
        return audioDeviceUID
    }
    guard let inputUID = values["--input-uid"], !inputUID.isEmpty else {
        throw CommandError.invalidArgument("--media audio-video requires --input-uid and --output-uid")
    }
    guard let outputUID = values["--output-uid"], !outputUID.isEmpty else {
        throw CommandError.invalidArgument("--media audio-video requires --input-uid and --output-uid")
    }
    return inputUID
}

private func directP2PFrames(
    _ values: [String: String],
    avProfile: DirectPeerSessionAVProfile,
    audioTransport: DirectPeerSessionAudioTransport
) throws -> Int {
    if let frames = try directP2POptionalPositiveInt("--frames", values) {
        return frames
    }
    if audioTransport == .aes67ST2110L24 {
        return AES67ST2110L24Profile.framesPerPacket
    }
    if avProfile == .fastest {
        return OpenLolaCLI.localCapabilitySet().audio.framesPerPacketOptions.min() ?? 32
    }
    return 32
}

private func directP2PAVProfile(_ value: String?) throws -> DirectPeerSessionAVProfile {
    guard let value else {
        return .balanced
    }
    guard let profile = DirectPeerSessionAVProfile(rawValue: value) else {
        throw CommandError.invalidArgument("invalid --av-profile")
    }
    return profile
}

private func directP2PVideoCompression(_ value: String?) throws -> DirectPeerSessionVideoCompression {
    guard let value else { return .raw }
    guard let compression = DirectPeerSessionVideoCompression(rawValue: value) else {
        throw CommandError.invalidArgument("invalid --video-compression")
    }
    return compression
}

private func directP2PAudioCompression(_ value: String?) throws -> DirectPeerSessionAudioCompression {
    guard let value else { return .raw }
    guard let compression = DirectPeerSessionAudioCompression(rawValue: value) else {
        throw CommandError.invalidArgument("invalid --audio-compression")
    }
    return compression
}

private func directP2PAudioTransport(_ values: [String: String]) throws -> DirectPeerSessionAudioTransport {
    let explicitTransport = try directP2PExplicitAudioTransport(values["--audio-transport"])
    let legacyCompression = try directP2PAudioCompression(values["--audio-compression"])
    guard let explicitTransport else {
        return legacyCompression.audioTransport
    }
    let legacyWasSet = values["--audio-compression"] != nil
    if legacyWasSet, explicitTransport != legacyCompression.audioTransport {
        throw CommandError.invalidArgument("conflicting --audio-transport and --audio-compression")
    }
    return explicitTransport
}

private func directP2PExplicitAudioTransport(_ value: String?) throws -> DirectPeerSessionAudioTransport? {
    guard let value else {
        return nil
    }
    guard let transport = DirectPeerSessionAudioTransport(rawValue: value) else {
        throw CommandError.invalidArgument("invalid --audio-transport")
    }
    return transport
}

func directP2PValidateAudioCompressionScope(
    _ values: [String: String],
    mediaMode: DirectPeerSessionMediaMode
) throws {
    try directP2PValidateMediaScopedArguments(values, mediaMode: mediaMode)
    let transport = try directP2PAudioTransport(values)
    guard transport != .openLolaRaw,
          mediaMode != .audioVideo else {
        return
    }
    throw CommandError.invalidArgument("--audio-transport \(transport.rawValue) is only valid with --media audio-video")
}

private func directP2PValidateMediaScopedArguments(
    _ values: [String: String],
    mediaMode: DirectPeerSessionMediaMode
) throws {
    guard mediaMode != .audioVideo else {
        return
    }
    let avOnlyArguments = [
        "--sample-rate",
        "--frames",
        "--sample-format",
        "--input-channels",
        "--output-channels",
        "--video-device-id",
        "--video-width",
        "--video-height",
        "--video-pixel-format",
        "--video-compression",
        "--video-frame-rate",
        "--video-stream-id",
        "--av-profile",
        "--rx-buffer-profile",
        "--preview",
        "--quality-policy",
        "--aoip-sdp-output",
        "--aoip-sdp-input",
    ]
    if let ignoredArgument = avOnlyArguments.first(where: { values[$0] != nil }) {
        throw CommandError.invalidArgument("\(ignoredArgument) is only valid with --media audio-video")
    }
}

private func directP2PValidateAudioTransportShape(
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
        switch transport {
        case .openLolaRaw:
            return
        case .openLolaOpusCeltLowDelay:
            throw CommandError.invalidArgument(
                "--audio-transport openlola-opus-celt-ld requires --sample-rate 48000, --frames 120, --sample-format float32, and --channels 1 or 2"
            )
        case .aes67ST2110L24:
            throw CommandError.invalidArgument(
                "--audio-transport aes67-st2110-l24 requires --sample-rate 48000, --frames 48, --sample-format float32, and --channels 2"
            )
        }
    }
}

private func directP2PValidateAoIPSDPInput(_ path: String?) throws {
    guard let path else {
        return
    }
    let text = try BoundedFileReader.string(at: URL(fileURLWithPath: path))
    _ = try AES67ST2110L24SDP.parse(text)
}

private func directP2PRXBufferProfile(
    _ value: String?,
    avProfile: DirectPeerSessionAVProfile
) throws -> RxBufferProfile {
    let profile: RxBufferProfile
    if let value {
        guard let parsed = RxBufferProfile(rawValue: value) else {
            throw CommandError.invalidArgument("invalid --rx-buffer-profile")
        }
        profile = parsed
    } else {
        profile = avProfile.defaultRXBufferProfile
    }
    do {
        _ = try DirectPeerSessionAVBufferPolicy.resolve(
            avProfile: avProfile,
            rxBufferProfile: profile
        )
    } catch {
        throw CommandError.invalidArgument(
            "--rx-buffer-profile \(profile.rawValue) is not valid with --av-profile \(avProfile.rawValue)"
        )
    }
    return profile
}

private func directP2PPreviewMode(
    _ value: String?,
    avProfile: DirectPeerSessionAVProfile
) throws -> DirectPeerSessionPreviewMode {
    guard let value else {
        return avProfile == .fastest ? .off : .on
    }
    guard let preview = DirectPeerSessionPreviewMode(rawValue: value) else {
        throw CommandError.invalidArgument("invalid --preview")
    }
    return preview
}

func directP2PSessionManualConfiguration(
    _ values: [String: String],
    packetCount: Int
) throws -> DirectPeerSessionManualRunConfiguration {
    let roleText = try directP2PRequiredString("--role", values)
    guard let role = DirectPeerSessionManualRole(rawValue: roleText) else {
        throw CommandError.invalidArgument("invalid --role")
    }
    return DirectPeerSessionManualRunConfiguration(
        role: role,
        localPeerID: try directP2PRequiredString("--local-peer", values),
        remotePeerID: try directP2PRequiredString("--remote-peer", values),
        localHost: try directP2PRequiredString("--local-host", values),
        remoteHost: try directP2PRequiredString("--remote-host", values),
        controlPort: try directP2PRequiredPort("--control-port", values),
        remoteControlPort: try directP2PRequiredPort("--remote-control-port", values),
        audioPort: try directP2PRequiredPort("--audio-port", values),
        videoPort: try directP2PRequiredPort("--video-port", values),
        metricsPort: try directP2PRequiredPort("--metrics-port", values),
        packetCount: packetCount,
        audioChannelCount: try directP2POptionalPositiveInt("--channels", values) ?? 2,
        timeoutSeconds: try directP2POptionalPositiveInt("--timeout-seconds", values) ?? 5,
        dscp: try directP2POptionalDscp(values)
    )
}

private func directP2PRequiredString(
    _ key: String,
    _ values: [String: String]
) throws -> String {
    guard let value = values[key], !value.isEmpty else {
        throw CommandError.invalidArgument("missing \(key)")
    }
    return value
}

private func directP2PRequiredPort(
    _ key: String,
    _ values: [String: String]
) throws -> UInt16 {
    let value = try directP2PRequiredString(key, values)
    guard let port = UInt16(value), port > 0 else {
        throw CommandError.invalidArgument("invalid \(key)")
    }
    return port
}

private func directP2POptionalPositiveInt(
    _ key: String,
    _ values: [String: String]
) throws -> Int? {
    guard let value = values[key] else {
        return nil
    }
    guard let number = Int(value), number > 0 else {
        throw CommandError.invalidArgument("invalid \(key)")
    }
    let maximum = directP2PMaximumPositiveInteger(for: key)
    guard number <= maximum else {
        throw CommandError.invalidArgument("invalid \(key)")
    }
    return number
}

private func directP2PMaximumPositiveInteger(for key: String) -> Int {
    directP2PPositiveIntegerBounds[key] ?? 1_000_000
}

private func directP2POptionalDscp(_ values: [String: String]) throws -> Int? {
    guard let value = values["--dscp"] else {
        return nil
    }
    guard let dscp = Int(value), dscp >= 0, dscp <= 63 else {
        throw CommandError.invalidArgument("invalid --dscp")
    }
    return dscp
}

private func directP2PRequiredPositiveInt(
    _ key: String,
    _ values: [String: String]
) throws -> Int {
    guard let number = try directP2POptionalPositiveInt(key, values) else {
        throw CommandError.invalidArgument("missing \(key)")
    }
    return number
}

private func directP2PSampleFormat(_ value: String) throws -> UdpPcmSampleFormat {
    do {
        return try DirectPeerSessionAVMediaShape.sampleFormat(from: value)
    } catch {
        throw CommandError.invalidArgument("invalid --sample-format")
    }
}

private func directP2PVideoPixelFormat(_ value: String) throws -> String {
    do {
        return try DirectPeerSessionAVMediaShape.normalizedVideoPixelFormat(from: value)
    } catch {
        throw CommandError.invalidArgument("invalid --video-pixel-format")
    }
}

private func directP2POptionalChannelCSV(
    _ key: String,
    _ values: [String: String],
    expectedCount: Int
) throws -> [Int]? {
    guard let value = values[key] else {
        return nil
    }
    let channels = value.split(separator: ",").map(String.init)
    guard !channels.isEmpty else {
        throw CommandError.invalidArgument("invalid \(key)")
    }
    guard channels.count == expectedCount else {
        throw CommandError.invalidArgument("\(key) must contain \(expectedCount) entries")
    }
    return try channels.map { channel in
        guard let number = Int(channel), number >= 0 else {
            throw CommandError.invalidArgument("invalid \(key)")
        }
        return number
    }
}
