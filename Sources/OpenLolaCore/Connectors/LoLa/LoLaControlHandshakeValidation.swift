import Darwin

func lolaExpectedStatusAckFields(sourceIP: String, destinationIP: String, sessionID: Int) -> [String: String] {
    [
        "SRCIP": destinationIP,
        "DSTIP": sourceIP,
        "SID": String(sessionID),
    ]
}

func lolaExpectedQuickConnectFields(
    configuration: ExternalConnectorSessionConfiguration,
    sourceIP: String
) throws -> [String: String] {
    var fields = [
        "SRCIP": configuration.peer,
        "DSTIP": sourceIP,
        "SID": String(try lolaControlSessionID(configuration.sessionID)),
        "SR": String(configuration.sampleRateHertz),
        "BPS": "16",
        "CHNLS": String(configuration.channels),
        "FPS": String(configuration.mediaMode.hasVideo ? configuration.videoFrameRate : 0),
        "BPP": String(configuration.mediaMode.hasVideo ? configuration.videoBitsPerPixel : 0),
        "X": String(configuration.mediaMode.hasVideo ? configuration.videoWidth : 0),
        "Y": String(configuration.mediaMode.hasVideo ? configuration.videoHeight : 0),
        "COMP": String(configuration.mediaMode.hasVideo ? configuration.videoCompression : 0),
        "BAYER": String(configuration.mediaMode.hasVideo ? configuration.videoBayer : 0),
    ]
    if configuration.role == .txRx {
        for key in ["FPS", "BPP", "X", "Y", "COMP", "BAYER"] {
            fields.removeValue(forKey: key)
        }
    }
    return fields
}

func lolaOutgoingHandshakeFailure(
    sentMessages: [String],
    receivedMessages: [String],
    opaqueControlDatagrams: [LoLaOpaqueControlDatagram] = [],
    bytesTransferred: Int,
    parsedMessageName: String,
    fields: [String: String],
    message: String,
    expectedName: String,
    expectedFields: [String: String]
) -> LoLaControlExchangeAttempt? {
    if parsedMessageName != expectedName {
        return lolaHandshakeValidationFailure(
            sentMessages: sentMessages,
            receivedMessages: receivedMessages,
            opaqueControlDatagrams: opaqueControlDatagrams,
            bytesTransferred: bytesTransferred,
            parsedMessageName: parsedMessageName,
            fields: fields,
            message: message
        )
    }
    for (key, expectedValue) in expectedFields
        where !lolaHandshakeFieldMatches(key: key, actual: fields[key], expected: expectedValue) {
        return lolaHandshakeValidationFailure(
            sentMessages: sentMessages,
            receivedMessages: receivedMessages,
            opaqueControlDatagrams: opaqueControlDatagrams,
            bytesTransferred: bytesTransferred,
            parsedMessageName: parsedMessageName,
            fields: fields,
            message: "\(message) expected \(key):\(expectedValue)"
        )
    }
    return nil
}

func lolaIncomingHandshakeFailure(
    sentMessages: [String],
    receivedMessages: [String],
    opaqueControlDatagrams: [LoLaOpaqueControlDatagram] = [],
    bytesTransferred: Int,
    parsedMessageName: String,
    fields: [String: String],
    message: String,
    expectedName: String,
    localHost: String,
    requiresMediaFields: Bool
) -> LoLaControlExchangeAttempt? {
    guard parsedMessageName == expectedName else {
        return lolaHandshakeValidationFailure(
            sentMessages: sentMessages,
            receivedMessages: receivedMessages,
            opaqueControlDatagrams: opaqueControlDatagrams,
            bytesTransferred: bytesTransferred,
            parsedMessageName: parsedMessageName,
            fields: fields,
            message: message
        )
    }
    let required = requiresMediaFields
        ? ["SRCIP", "DSTIP", "SID", "SR", "BPS", "CHNLS", "FPS", "BPP", "X", "Y", "COMP", "BAYER"]
        : ["SRCIP", "DSTIP", "SID"]
    for key in required where fields[key]?.isEmpty ?? true {
        return lolaHandshakeValidationFailure(
            sentMessages: sentMessages,
            receivedMessages: receivedMessages,
            opaqueControlDatagrams: opaqueControlDatagrams,
            bytesTransferred: bytesTransferred,
            parsedMessageName: parsedMessageName,
            fields: fields,
            message: "\(message) missing \(key)"
        )
    }
    if localHost != "0.0.0.0", !lolaIPv4AddressMatches(fields["DSTIP"], expected: localHost) {
        return lolaHandshakeValidationFailure(
            sentMessages: sentMessages,
            receivedMessages: receivedMessages,
            opaqueControlDatagrams: opaqueControlDatagrams,
            bytesTransferred: bytesTransferred,
            parsedMessageName: parsedMessageName,
            fields: fields,
            message: "\(message) expected DSTIP:\(localHost)"
        )
    }
    for key in required.dropFirst(3) + ["SID"] where Int(fields[key] ?? "") == nil {
        return lolaHandshakeValidationFailure(
            sentMessages: sentMessages,
            receivedMessages: receivedMessages,
            opaqueControlDatagrams: opaqueControlDatagrams,
            bytesTransferred: bytesTransferred,
            parsedMessageName: parsedMessageName,
            fields: fields,
            message: "\(message) expected numeric \(key)"
        )
    }
    return nil
}

private func lolaHandshakeFieldMatches(key: String, actual: String?, expected: String) -> Bool {
    if key == "SRCIP" || key == "DSTIP" {
        return lolaIPv4AddressMatches(actual, expected: expected)
    }
    return actual == expected
}

private func lolaIPv4AddressMatches(_ actual: String?, expected: String) -> Bool {
    guard let actual else {
        return false
    }
    if let normalizedActual = normalizedLoLaIPv4Address(actual),
       let normalizedExpected = normalizedLoLaIPv4Address(expected) {
        return normalizedActual == normalizedExpected
    }
    return trimmedLoLaIPv4Token(actual) == trimmedLoLaIPv4Token(expected)
}

private func normalizedLoLaIPv4Address(_ value: String) -> String? {
    let token = trimmedLoLaIPv4Token(value)
    var address = in_addr()
    guard token.withCString({ inet_pton(AF_INET, $0, &address) }) == 1 else {
        return nil
    }
    var buffer = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
    guard inet_ntop(AF_INET, &address, &buffer, socklen_t(INET_ADDRSTRLEN)) != nil else {
        return nil
    }
    let bytes = buffer.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }
    return String(decoding: bytes, as: UTF8.self)
}

private func trimmedLoLaIPv4Token(_ value: String) -> String {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
        .first
        .map(String.init) ?? trimmed
}

func lolaRetryResponderAck(
    configuration: ExternalConnectorSessionConfiguration,
    message: String,
    parsed: (name: String, fields: [String: String]),
    senderHost: String
) throws -> String? {
    switch parsed.name {
    case "/MESG_CHECKLOLASTATUS":
        guard lolaIncomingHandshakeFailure(
            sentMessages: [], receivedMessages: [message], bytesTransferred: message.utf8.count,
            parsedMessageName: parsed.name, fields: parsed.fields, message: message,
            expectedName: "/MESG_CHECKLOLASTATUS", localHost: configuration.localHost, requiresMediaFields: false
        ) == nil else { return nil }
        return try lolaCheckStatusAck(configuration: configuration, receivedFields: parsed.fields, senderHost: senderHost)
    case "/MESG_QUICKCONN":
        guard lolaIncomingHandshakeFailure(
            sentMessages: [], receivedMessages: [message], bytesTransferred: message.utf8.count,
            parsedMessageName: parsed.name, fields: parsed.fields, message: message,
            expectedName: "/MESG_QUICKCONN", localHost: configuration.localHost, requiresMediaFields: true
        ) == nil else { return nil }
        return try lolaQuickConnectAck(configuration: configuration, receivedFields: parsed.fields, senderHost: senderHost)
    default:
        return nil
    }
}

private func lolaHandshakeValidationFailure(
    sentMessages: [String],
    receivedMessages: [String],
    opaqueControlDatagrams: [LoLaOpaqueControlDatagram],
    bytesTransferred: Int,
    parsedMessageName: String,
    fields: [String: String],
    message: String
) -> LoLaControlExchangeAttempt {
    lolaControlAttemptFailure(
        sentMessages: sentMessages,
        receivedMessages: receivedMessages,
        bytesTransferred: bytesTransferred,
        opaqueControlDatagrams: opaqueControlDatagrams,
        parsedMessageName: parsedMessageName,
        fields: fields,
        runtimeError: ExternalConnectorSessionError.malformedLoLaControlMessage(message)
    )
}
