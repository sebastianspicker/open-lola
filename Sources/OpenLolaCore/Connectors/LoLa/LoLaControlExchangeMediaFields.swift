// Handles LoLaControlExchangeMediaFields control exchange, keeping control-plane details distinct from media data flow.
import Foundation

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
        audio: LoLaCompatibilityAudioFields(
            sampleRateHertz: lolaControlIntegerField(
                receivedFields,
                key: "SR",
                fallback: configuration.sampleRateHertz
            ),
            bitsPerSample: lolaControlIntegerField(receivedFields, key: "BPS", fallback: 16),
            channels: lolaControlIntegerField(receivedFields, key: "CHNLS", fallback: configuration.channels)
        ),
        video: lolaQuickConnectAckVideoFields(configuration: configuration, receivedFields: receivedFields)
    )
}

private func lolaQuickConnectAckVideoFields(
    configuration: ExternalConnectorSessionConfiguration,
    receivedFields: [String: String]
) -> LoLaCompatibilityVideoFields {
    LoLaCompatibilityVideoFields(
        frameRate: lolaControlIntegerField(
            receivedFields,
            key: "FPS",
            fallback: configuration.mediaMode.hasVideo ? configuration.videoFrameRate : 0
        ),
        bitsPerPixel: lolaControlIntegerField(
            receivedFields,
            key: "BPP",
            fallback: configuration.mediaMode.hasVideo ? configuration.videoBitsPerPixel : 0
        ),
        dimensions: LoLaCompatibilityVideoDimensions(
            width: lolaControlIntegerField(
                receivedFields,
                key: "X",
                fallback: configuration.mediaMode.hasVideo ? configuration.videoWidth : 0
            ),
            height: lolaControlIntegerField(
                receivedFields,
                key: "Y",
                fallback: configuration.mediaMode.hasVideo ? configuration.videoHeight : 0
            )
        ),
        compression: lolaControlIntegerField(
            receivedFields,
            key: "COMP",
            fallback: configuration.videoCompression
        ),
        bayer: lolaControlIntegerField(receivedFields, key: "BAYER", fallback: configuration.videoBayer)
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

private func lolaQuickConnectVideoFields(
    configuration: ExternalConnectorSessionConfiguration
) -> LoLaCompatibilityVideoFields {
    LoLaCompatibilityVideoFields(
        frameRate: configuration.mediaMode.hasVideo ? configuration.videoFrameRate : 0,
        bitsPerPixel: configuration.mediaMode.hasVideo ? configuration.videoBitsPerPixel : 0,
        dimensions: LoLaCompatibilityVideoDimensions(
            width: configuration.mediaMode.hasVideo ? configuration.videoWidth : 0,
            height: configuration.mediaMode.hasVideo ? configuration.videoHeight : 0
        ),
        compression: configuration.mediaMode.hasVideo ? configuration.videoCompression : 0,
        bayer: configuration.mediaMode.hasVideo ? configuration.videoBayer : 0
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
