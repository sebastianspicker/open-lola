import OpenLolaContracts
import OpenLolaSessionDomain
import OpenLolaEvidenceModels
import OpenLolaTransport
import OpenLolaMediaPlatform
// Handles LoLaControlExchangeMediaFields control exchange, keeping control-plane details distinct from media data flow.
import Foundation

/// Video fields an audio-only QUICKCONN advertises and expects. Responders
/// validate FPS 1...240, BPP 8/16/24/32 and X/Y >= 1 even when no video flows,
/// so the corpus defaults (`control.quickconn.default.v1`) stand in for zeros.
let lolaAudioOnlyQuickConnectVideoFields = LoLaCompatibilityVideoFields(
    frameRate: 25,
    bitsPerPixel: 8,
    dimensions: LoLaCompatibilityVideoDimensions(width: 640, height: 480),
    compression: 0,
    bayer: 0
)

/// Audio bit depth the connector carries: its PCM codec and Core Audio bridge
/// move 16-bit samples only, although LoLa also announces 8, 24 and 32.
let lolaConnectorAudioBitsPerSample = 16

/// Bit depths a LoLa peer may announce in `BPS` (the Rust station accepts all).
private let lolaAnnouncedAudioBitsPerSample: Set<Int> = [8, 16, 24, 32]

/// Prefix of the error raised when a QUICKCONN carries audio settings this
/// station cannot accept; `lolaQuickConnectRejectReason` maps it to REJECT text.
private let lolaIncompatibleQuickConnectPrefix = "incompatible LoLa QuickConn "

/// Prefix of the runtime mode raised for a valid LoLa bit depth other than 16.
private let lolaUnsupportedAudioDepthPrefix = "lola-audio-bps-unsupported-"

/// Prefix of the runtime mode raised for a video field this connector cannot carry.
private let lolaVideoMismatchPrefix = "lola-video-settings-mismatch-"

/// Video fields in the order a responder checks them, with the REJECT reason
/// for each. FPS, BPP and BAYER come first and use the Rust station's reasons,
/// so both runtimes refuse one tuple with the same text; COMP, X and Y are
/// checked only here because this connector cannot re-encode or scale.
private let lolaVideoFieldRejectReasons: [(key: String, reason: String)] = [
    ("FPS", "video frame rate mismatch"),
    ("BPP", "video pixel format mismatch"),
    ("BAYER", "video Bayer format mismatch"),
    ("COMP", "video compression mismatch"),
    ("X", "video geometry mismatch"),
    ("Y", "video geometry mismatch")
]

/// Maps a QUICKCONN acceptance error to the short REJECT reason the Rust
/// station and the LoLa corpus send, instead of a Swift error description.
/// Reasons are lower-case `<what> mismatch`, or `<reason>: <detail>`.
func lolaQuickConnectRejectReason(_ error: Error) -> String {
    if case let ExternalConnectorSessionError.malformedLoLaControlMessage(text) = error,
       text.hasPrefix(lolaIncompatibleQuickConnectPrefix) {
        return "audio settings mismatch"
    }
    if case let ExternalConnectorSessionError.unsupportedRuntimeMode(mode) = error {
        if mode.hasPrefix(lolaUnsupportedAudioDepthPrefix) {
            return "unsupported audio bit depth: \(mode.dropFirst(lolaUnsupportedAudioDepthPrefix.count))"
        }
        if mode.hasPrefix(lolaVideoMismatchPrefix) {
            let key = mode.dropFirst(lolaVideoMismatchPrefix.count)
            return lolaVideoFieldRejectReasons.first { $0.key == key }?.reason ?? "video settings mismatch"
        }
    }
    return "invalid media settings"
}

func lolaCheckStatusAck(
    configuration: ExternalConnectorSessionConfiguration,
    receivedFields: [String: String],
    senderHost: String
) throws -> String {
    LoLaCompatibilityControlMessage.checkStatusAck(
        sourceIP: lolaAckSourceIP(configuration: configuration, receivedFields: receivedFields, senderHost: senderHost),
        destinationIP: receivedFields["SRCIP"] ?? senderHost,
        sessionID: try lolaControlSessionID(receivedFields["SID"] ?? configuration.sessionID)
    )
}

func lolaQuickConnectAck(
    configuration: ExternalConnectorSessionConfiguration,
    receivedFields: [String: String],
    senderHost: String
) throws -> String {
    try LoLaCompatibilityControlMessage.quickConnectAck(
        lolaQuickConnectAckMediaFields(
            configuration: configuration,
            receivedFields: receivedFields,
            senderHost: senderHost
        )
    )
}

func lolaQuickConnectReject(
    configuration: ExternalConnectorSessionConfiguration,
    receivedFields: [String: String],
    senderHost: String,
    reason: String
) throws -> String {
    LoLaCompatibilityControlMessage.reject(
        sourceIP: lolaAckSourceIP(
            configuration: configuration,
            receivedFields: receivedFields,
            senderHost: senderHost
        ),
        destinationIP: receivedFields["SRCIP"] ?? senderHost,
        sessionID: try lolaControlSessionID(receivedFields["SID"] ?? configuration.sessionID),
        text: reason
    )
}

func lolaQuickConnectMessage(configuration: ExternalConnectorSessionConfiguration, sourceIP: String) throws -> String {
    try LoLaCompatibilityControlMessage.quickConnect(
        lolaQuickConnectMediaFields(configuration: configuration, sourceIP: sourceIP)
    )
}

private func lolaQuickConnectAckMediaFields(
    configuration: ExternalConnectorSessionConfiguration,
    receivedFields: [String: String],
    senderHost: String
) throws -> LoLaCompatibilityMediaFields {
    LoLaCompatibilityMediaFields(
        session: LoLaControlSessionFields(
            sourceIP: lolaAckSourceIP(
                configuration: configuration,
                receivedFields: receivedFields,
                senderHost: senderHost
            ),
            destinationIP: receivedFields["SRCIP"] ?? senderHost,
            sessionID: try lolaControlSessionID(receivedFields["SID"] ?? configuration.sessionID)
        ),
        audio: try lolaQuickConnectAckAudioFields(
            configuration: configuration,
            receivedFields: receivedFields
        ),
        video: try lolaQuickConnectAckVideoFields(configuration: configuration, receivedFields: receivedFields)
    )
}

private func lolaQuickConnectAckAudioFields(
    configuration: ExternalConnectorSessionConfiguration,
    receivedFields: [String: String]
) throws -> LoLaCompatibilityAudioFields {
    if let depth = Int(receivedFields["BPS"] ?? ""), depth != lolaConnectorAudioBitsPerSample,
       lolaAnnouncedAudioBitsPerSample.contains(depth) {
        throw ExternalConnectorSessionError.unsupportedRuntimeMode("\(lolaUnsupportedAudioDepthPrefix)\(depth)")
    }
    let expected = [
        "SR": configuration.sampleRateHertz,
        "BPS": lolaConnectorAudioBitsPerSample,
        "CHNLS": configuration.channels
    ]
    for (key, expectedValue) in expected where Int(receivedFields[key] ?? "") != expectedValue {
        let receivedValue = receivedFields[key] ?? ""
        throw ExternalConnectorSessionError.malformedLoLaControlMessage(
            "\(lolaIncompatibleQuickConnectPrefix)\(key):\(receivedValue)"
        )
    }
    return LoLaCompatibilityAudioFields(
        sampleRateHertz: configuration.sampleRateHertz,
        bitsPerSample: lolaConnectorAudioBitsPerSample,
        channels: configuration.channels
    )
}

private func lolaQuickConnectAckVideoFields(
    configuration: ExternalConnectorSessionConfiguration,
    receivedFields: [String: String]
) throws -> LoLaCompatibilityVideoFields {
    let fallback = lolaQuickConnectVideoFields(configuration: configuration)
    if configuration.mediaMode.hasVideo {
        let expected = [
            "FPS": fallback.frameRate, "BPP": fallback.bitsPerPixel,
            "X": fallback.dimensions.width, "Y": fallback.dimensions.height,
            "COMP": fallback.compression, "BAYER": fallback.bayer
        ]
        for (key, _) in lolaVideoFieldRejectReasons where Int(receivedFields[key] ?? "") != expected[key] {
            throw ExternalConnectorSessionError.unsupportedRuntimeMode("\(lolaVideoMismatchPrefix)\(key)")
        }
    }
    return LoLaCompatibilityVideoFields(
        frameRate: lolaControlIntegerField(receivedFields, key: "FPS", fallback: fallback.frameRate),
        bitsPerPixel: lolaControlIntegerField(receivedFields, key: "BPP", fallback: fallback.bitsPerPixel),
        dimensions: LoLaCompatibilityVideoDimensions(
            width: lolaControlIntegerField(receivedFields, key: "X", fallback: fallback.dimensions.width),
            height: lolaControlIntegerField(receivedFields, key: "Y", fallback: fallback.dimensions.height)
        ),
        compression: lolaControlIntegerField(receivedFields, key: "COMP", fallback: fallback.compression),
        bayer: lolaControlIntegerField(receivedFields, key: "BAYER", fallback: fallback.bayer)
    )
}

private func lolaQuickConnectMediaFields(
    configuration: ExternalConnectorSessionConfiguration,
    sourceIP: String
) throws -> LoLaCompatibilityMediaFields {
    LoLaCompatibilityMediaFields(
        session: LoLaControlSessionFields(
            sourceIP: sourceIP,
            destinationIP: configuration.peer,
            sessionID: try lolaControlSessionID(configuration.sessionID)
        ),
        audio: LoLaCompatibilityAudioFields(
            sampleRateHertz: configuration.sampleRateHertz,
            bitsPerSample: lolaConnectorAudioBitsPerSample,
            channels: configuration.channels
        ),
        video: lolaQuickConnectVideoFields(configuration: configuration)
    )
}

func lolaQuickConnectVideoFields(
    configuration: ExternalConnectorSessionConfiguration
) -> LoLaCompatibilityVideoFields {
    guard configuration.mediaMode.hasVideo else {
        return lolaAudioOnlyQuickConnectVideoFields
    }
    return LoLaCompatibilityVideoFields(
        frameRate: configuration.videoFrameRate,
        bitsPerPixel: configuration.videoBitsPerPixel,
        dimensions: LoLaCompatibilityVideoDimensions(
            width: configuration.videoWidth,
            height: configuration.videoHeight
        ),
        compression: configuration.videoCompression,
        bayer: configuration.videoBayer
    )
}

private func lolaAckSourceIP(
    configuration: ExternalConnectorSessionConfiguration,
    receivedFields: [String: String],
    senderHost: String
) -> String {
    if configuration.localHost != "0.0.0.0" {
        return configuration.localHost
    }
    return receivedFields["DSTIP"] ?? senderHost
}

private func lolaControlIntegerField(_ fields: [String: String], key: String, fallback: Int) -> Int {
    guard let value = fields[key], let parsed = Int(value) else {
        return fallback
    }
    return parsed
}
