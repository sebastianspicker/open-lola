// Validates LoLaControlHandshakeValidation acceptance rules, keeping failure policy close to its contract rather than the runtime path.
import Darwin

struct LoLaHandshakeValidationFailureContext {
    var sentMessages: [String]
    var receivedMessages: [String]
    var opaqueControlDatagrams: [LoLaOpaqueControlDatagram]
    var bytesTransferred: Int
    var parsedMessageName: String
    var fields: [String: String]
    var message: String
}

func lolaExpectedStatusAckFields(sourceIP: String, destinationIP: String, sessionID: Int) -> [String: String] {
    [
        "SRCIP": destinationIP,
        "DSTIP": sourceIP,
        "SID": String(sessionID)
    ]
}

func lolaExpectedQuickConnectFields(
    configuration: ExternalConnectorSessionConfiguration,
    sourceIP: String
) throws -> [String: String] {
    var fields = try lolaExpectedQuickConnectSessionFields(
        configuration: configuration,
        sourceIP: sourceIP
    )
    if configuration.role != .txRx {
        fields.merge(lolaExpectedQuickConnectVideoFields(configuration)) { _, new in new }
    }
    return fields
}

private func lolaExpectedQuickConnectSessionFields(
    configuration: ExternalConnectorSessionConfiguration,
    sourceIP: String
) throws -> [String: String] {
    [
        "SRCIP": configuration.peer,
        "DSTIP": sourceIP,
        "SID": String(try lolaControlSessionID(configuration.sessionID)),
        "SR": String(configuration.sampleRateHertz),
        "BPS": "16",
        "CHNLS": String(configuration.channels)
    ]
}

private func lolaExpectedQuickConnectVideoFields(
    _ configuration: ExternalConnectorSessionConfiguration
) -> [String: String] {
    guard configuration.mediaMode.hasVideo else {
        return [
            "FPS": "0",
            "BPP": "0",
            "X": "0",
            "Y": "0",
            "COMP": "0",
            "BAYER": "0"
        ]
    }
    return [
        "FPS": String(configuration.videoFrameRate),
        "BPP": String(configuration.videoBitsPerPixel),
        "X": String(configuration.videoWidth),
        "Y": String(configuration.videoHeight),
        "COMP": String(configuration.videoCompression),
        "BAYER": String(configuration.videoBayer)
    ]
}

func lolaOutgoingHandshakeFailure(
    context: LoLaHandshakeValidationFailureContext,
    expectedName: String,
    expectedFields: [String: String]
) -> LoLaControlExchangeAttempt? {
    if context.parsedMessageName != expectedName {
        return lolaHandshakeValidationFailure(context)
    }
    for (key, expectedValue) in expectedFields
        where !lolaHandshakeFieldMatches(key: key, actual: context.fields[key], expected: expectedValue) {
        var failure = context
        failure.message = "\(context.message) expected \(key):\(expectedValue)"
        return lolaHandshakeValidationFailure(failure)
    }
    return nil
}

func lolaIncomingHandshakeFailure(
    context: LoLaHandshakeValidationFailureContext,
    expectedName: String,
    localHost: String,
    requiresMediaFields: Bool
) -> LoLaControlExchangeAttempt? {
    guard context.parsedMessageName == expectedName else {
        return lolaHandshakeValidationFailure(context)
    }
    let required = requiresMediaFields
        ? ["SRCIP", "DSTIP", "SID", "SR", "BPS", "CHNLS", "FPS", "BPP", "X", "Y", "COMP", "BAYER"]
        : ["SRCIP", "DSTIP", "SID"]
    for key in required where context.fields[key]?.isEmpty ?? true {
        var failure = context
        failure.message = "\(context.message) missing \(key)"
        return lolaHandshakeValidationFailure(failure)
    }
    if localHost != "0.0.0.0", !lolaIPv4AddressMatches(context.fields["DSTIP"], expected: localHost) {
        var failure = context
        failure.message = "\(context.message) expected DSTIP:\(localHost)"
        return lolaHandshakeValidationFailure(failure)
    }
    for key in required.dropFirst(3) + ["SID"] where Int(context.fields[key] ?? "") == nil {
        var failure = context
        failure.message = "\(context.message) expected numeric \(key)"
        return lolaHandshakeValidationFailure(failure)
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
    return String(bytes: bytes, encoding: .utf8)
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
            context: lolaRetryResponderValidationContext(message: message, parsed: parsed),
            expectedName: "/MESG_CHECKLOLASTATUS", localHost: configuration.localHost, requiresMediaFields: false
        ) == nil else { return nil }
        return try lolaCheckStatusAck(
            configuration: configuration,
            receivedFields: parsed.fields,
            senderHost: senderHost
        )
    case "/MESG_QUICKCONN":
        guard lolaIncomingHandshakeFailure(
            context: lolaRetryResponderValidationContext(message: message, parsed: parsed),
            expectedName: "/MESG_QUICKCONN", localHost: configuration.localHost, requiresMediaFields: true
        ) == nil else { return nil }
        return try lolaQuickConnectAck(
            configuration: configuration,
            receivedFields: parsed.fields,
            senderHost: senderHost
        )
    default:
        return nil
    }
}

private func lolaRetryResponderValidationContext(
    message: String,
    parsed: (name: String, fields: [String: String])
) -> LoLaHandshakeValidationFailureContext {
    LoLaHandshakeValidationFailureContext(
        sentMessages: [],
        receivedMessages: [message],
        opaqueControlDatagrams: [],
        bytesTransferred: message.utf8.count,
        parsedMessageName: parsed.name,
        fields: parsed.fields,
        message: message
    )
}

private func lolaHandshakeValidationFailure(
    _ context: LoLaHandshakeValidationFailureContext
) -> LoLaControlExchangeAttempt {
    lolaControlAttemptFailure(
        sentMessages: context.sentMessages,
        receivedMessages: context.receivedMessages,
        bytesTransferred: context.bytesTransferred,
        opaqueControlDatagrams: context.opaqueControlDatagrams,
        parsedMessageName: context.parsedMessageName,
        fields: context.fields,
        runtimeError: ExternalConnectorSessionError.malformedLoLaControlMessage(context.message)
    )
}
