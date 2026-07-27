// Supplies DirectP2PSessionRunAVConfigurationSupport helpers, keeping command assembly details out of the primary CLI flow.
import Foundation
import OpenLolaCore

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
    let parameters = DirectP2PSessionAVRunParameters(
        manual: manual,
        audioDeviceUID: audioDeviceUID,
        audioChannelCount: audioChannelCount,
        sampleRateHertz: sampleRateHertz,
        framesPerPacket: framesPerPacket,
        sampleFormat: sampleFormat,
        videoPixelFormatText: videoPixelFormatText,
        audioTransport: audioTransport,
        avProfile: avProfile,
        rxBufferProfile: rxBufferProfile
    )
    return try directP2PSessionAVRunConfiguration(values, parameters: parameters)
}

struct DirectP2PSessionAVRunParameters {
    let manual: DirectPeerSessionManualRunConfiguration
    let audioDeviceUID: String
    let audioChannelCount: Int
    let sampleRateHertz: Int
    let framesPerPacket: Int
    let sampleFormat: UdpPcmSampleFormat
    let videoPixelFormatText: String
    let audioTransport: DirectPeerSessionAudioTransport
    let avProfile: DirectPeerSessionAVProfile
    let rxBufferProfile: RxBufferProfile
}

func directP2PSessionAVRunConfiguration(
    _ values: [String: String],
    parameters: DirectP2PSessionAVRunParameters
) throws -> DirectPeerSessionAVRunConfiguration {
    DirectPeerSessionAVRunConfiguration(
        manual: parameters.manual,
        durationSeconds: try directP2PRequiredPositiveInt("--duration-seconds", values),
        devices: .init(audioDeviceUID: parameters.audioDeviceUID, inputDeviceUID: values["--input-uid"] ?? parameters.audioDeviceUID, outputDeviceUID: values["--output-uid"] ?? parameters.audioDeviceUID),
        audio: .init(sampleRateHertz: parameters.sampleRateHertz, framesPerPacket: parameters.framesPerPacket, sampleFormat: parameters.sampleFormat, inputChannels: try directP2POptionalChannelCSV("--input-channels", values, expectedCount: parameters.audioChannelCount) ?? Array(0..<parameters.audioChannelCount), outputChannels: try directP2POptionalChannelCSV("--output-channels", values, expectedCount: parameters.audioChannelCount) ?? Array(0..<parameters.audioChannelCount), transport: parameters.audioTransport),
        video: .init(deviceID: try directP2PRequiredString("--video-device-id", values), width: try directP2POptionalPositiveInt("--video-width", values) ?? 1_280, height: try directP2POptionalPositiveInt("--video-height", values) ?? 720, pixelFormat: try directP2PVideoPixelFormat(parameters.videoPixelFormatText), compression: try directP2PVideoCompression(values["--video-compression"]), frameRate: try directP2POptionalPositiveInt("--video-frame-rate", values) ?? 30, streamID: try directP2POptionalPositiveInt("--video-stream-id", values) ?? 100),
        quality: .init(profile: parameters.avProfile, rxBufferProfile: parameters.rxBufferProfile, preview: try directP2PPreviewMode(values["--preview"], avProfile: parameters.avProfile), policy: try directP2PQualityPolicy(values["--quality-policy"])),
        aoip: .init(sdpOutputPath: values["--aoip-sdp-output"], sdpInputPath: values["--aoip-sdp-input"])
    )
}

func directP2PAudioDeviceUID(_ values: [String: String]) throws -> String {
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

func directP2PFrames(
    _ values: [String: String],
    avProfile: DirectPeerSessionAVProfile,
    audioTransport: DirectPeerSessionAudioTransport
) throws -> Int {
    if let frames = try directP2POptionalPositiveInt("--frames", values) {
        return frames
    }
    switch audioTransport {
    case .openLolaRaw:
        return avProfile == .fastest
            ? LatencyProfilePolicy.policy(for: .extremeLowLatency8).primaryFrames
            : 32
    case .openLolaOpusCeltLowDelay:
        return OpusCELTLowDelayConstants.frameCount
    case .aes67ST2110L24:
        return avProfile == .fastest
            ? AES67ST2110L24PacketTime.levelBC125Microseconds.framesPerPacket
            : AES67ST2110L24Profile.framesPerPacket
    }
}

func directP2PAVProfile(_ value: String?) throws -> DirectPeerSessionAVProfile {
    guard let value else {
        return .balanced
    }
    guard let profile = DirectPeerSessionAVProfile(rawValue: value) else {
        throw CommandError.invalidArgument("invalid --av-profile")
    }
    return profile
}

func directP2PVideoCompression(_ value: String?) throws -> DirectPeerSessionVideoCompression {
    guard let value else { return .raw }
    guard let compression = DirectPeerSessionVideoCompression(rawValue: value) else {
        throw CommandError.invalidArgument("invalid --video-compression")
    }
    return compression
}

func directP2PAudioCompression(_ value: String?) throws -> DirectPeerSessionAudioCompression {
    guard let value else { return .raw }
    guard let compression = DirectPeerSessionAudioCompression(rawValue: value) else {
        throw CommandError.invalidArgument("invalid --audio-compression")
    }
    return compression
}

func directP2PAudioTransport(_ values: [String: String]) throws -> DirectPeerSessionAudioTransport {
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

func directP2PExplicitAudioTransport(_ value: String?) throws -> DirectPeerSessionAudioTransport? {
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

func directP2PValidateMediaScopedArguments(
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
        "--aoip-sdp-input"
    ]
    if let ignoredArgument = avOnlyArguments.first(where: { values[$0] != nil }) {
        throw CommandError.invalidArgument("\(ignoredArgument) is only valid with --media audio-video")
    }
}

func directP2PValidateAudioTransportShape(
    _ transport: DirectPeerSessionAudioTransport,
    sampleRateHertz: Int,
    framesPerPacket: Int,
    sampleFormat: UdpPcmSampleFormat,
    channelCount: Int
) throws {
    guard transport != .openLolaRaw else {
        return
    }
    do {
        try DirectPeerSessionAVMediaShape.validateAudioTransportShape(
            transport,
            sampleRateHertz: sampleRateHertz,
            framesPerPacket: framesPerPacket,
            sampleFormat: sampleFormat,
            channelCount: channelCount
        )
    } catch {
        throw directP2PInvalidAudioTransportShape(transport)
    }
}

private func directP2PInvalidAudioTransportShape(
    _ transport: DirectPeerSessionAudioTransport
) -> CommandError {
    if transport == .openLolaOpusCeltLowDelay {
        return .invalidArgument(
            "--audio-transport openlola-opus-celt-ld requires --sample-rate 48000, --frames 120, "
                + "--sample-format float32, and --channels 1 or 2"
        )
    }
    return .invalidArgument(
        "--audio-transport aes67-st2110-l24 requires --sample-rate 48000, --frames 6 or 48, "
            + "--sample-format float32, --channels 2"
    )
}

func directP2PValidateAoIPSDPInput(_ path: String?) throws {
    guard let path else {
        return
    }
    let text = try BoundedFileReader.string(at: URL(fileURLWithPath: path))
    _ = try AES67ST2110L24SDP.parse(text)
}

func directP2PRXBufferProfile(
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

func directP2PPreviewMode(
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
