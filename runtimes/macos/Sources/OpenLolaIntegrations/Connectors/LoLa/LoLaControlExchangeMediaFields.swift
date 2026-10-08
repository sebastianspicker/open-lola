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

/// Prefix of the error raised when a QUICKCONN carries audio settings this
/// station cannot accept; `lolaQuickConnectRejectReason` maps it to REJECT text.
private let lolaIncompatibleQuickConnectPrefix = "incompatible LoLa QuickConn "

/// Maps a QUICKCONN acceptance error to the short REJECT reason the Rust
/// station and the LoLa corpus send, instead of a Swift error description.
func lolaQuickConnectRejectReason(_ error: Error) -> String {
    if case let ExternalConnectorSessionError.malformedLoLaControlMessage(text) = error,
       text.hasPrefix(lolaIncompatibleQuickConnectPrefix) {
        return "audio settings mismatch"
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
        video: lolaQuickConnectAckVideoFields(configuration: configuration, receivedFields: receivedFields)
    )
}

private func lolaQuickConnectAckAudioFields(
    configuration: ExternalConnectorSessionConfiguration,
    receivedFields: [String: String]
) throws -> LoLaCompatibilityAudioFields {
    let expected = [
        "SR": configuration.sampleRateHertz,
        "BPS": 16,
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
        bitsPerSample: 16,
        channels: configuration.channels
    )
}

private func lolaQuickConnectAckVideoFields(
    configuration: ExternalConnectorSessionConfiguration,
    receivedFields: [String: String]
) -> LoLaCompatibilityVideoFields {
    let fallback = lolaQuickConnectVideoFields(configuration: configuration)
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
            bitsPerSample: 16,
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
