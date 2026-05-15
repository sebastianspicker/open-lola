import Foundation

func requiredExecutable(
    _ configuration: ExternalConnectorSessionConfiguration,
    connector: ExternalConnectorKind,
    defaultName: String
) throws -> String {
    if let executable = configuration.executable, !executable.isEmpty {
        return executable
    }
    return defaultName
}

func requiredVideoExecutable(
    _ configuration: ExternalConnectorSessionConfiguration,
    defaultName: String
) throws -> String {
    if let executable = configuration.videoExecutable, !executable.isEmpty {
        return executable
    }
    return defaultName
}

func parseExternalConnectorKind(_ value: String) throws -> ExternalConnectorKind {
    switch value {
    case "lola":
        return .lola
    case "mvtp-ultragrid", "mvtpUltraGrid", "ultragrid":
        return .mvtpUltraGrid
    case "jacktrip", "jackTrip":
        return .jackTrip
    default:
        throw ExternalConnectorSessionError.invalidConnector(value)
    }
}

func parseExternalConnectorMediaMode(_ value: String) throws -> ExternalConnectorMediaMode {
    switch value {
    case "audio":
        return .audio
    case "video":
        return .video
    case "audio-video", "audioVideo", "av":
        return .audioVideo
    default:
        throw ExternalConnectorSessionError.invalidMediaMode(value)
    }
}

func parseExternalConnectorSessionRole(_ value: String) throws -> ExternalConnectorSessionRole {
    switch value {
    case "tx":
        return .tx
    case "rx":
        return .rx
    case "tx-rx", "txRx", "rxtx", "rx-tx", "bidirectional", "duplex", "full-duplex":
        return .txRx
    default:
        throw ExternalConnectorSessionError.invalidRole(value)
    }
}

func parseExternalConnectorControlTransport(_ value: String) throws -> ExternalConnectorControlTransport {
    switch value {
    case "udp":
        return .udp
    case "tcp":
        return .tcp
    default:
        throw ExternalConnectorSessionError.invalidControlTransport(value)
    }
}

func parseLoLaVideoPayloadKind(_ value: String) throws -> LoLaVideoPayloadKind {
    guard let kind = LoLaVideoPayloadKind(rawValue: value) else {
        throw ExternalConnectorSessionError.unknownArgument("--lola-video-payload \(value)")
    }
    return kind
}

func parseExternalConnectorKeyValueArguments(
    _ arguments: [String],
    allowed: Set<String>
) throws -> [String: String] {
    try KeyValueArgumentParser(allowedKeys: allowed).parse(
        arguments,
        mapError: mapExternalConnectorKeyValueError
    )
}

private func mapExternalConnectorKeyValueError(_ error: KeyValueArgumentError) -> ExternalConnectorSessionError {
    switch error {
    case let .unknownArgument(argument):
        return .unknownArgument(argument)
    case let .duplicateArgument(argument):
        return .duplicateArgument(argument)
    case let .missingValue(argument):
        return .missingValue(argument)
    }
}

func validateMediaMode(
    _ mediaMode: ExternalConnectorMediaMode,
    connector: ExternalConnectorKind
) throws {
    if connector == .mvtpUltraGrid, mediaMode == .audio {
        throw ExternalConnectorSessionError.connectorDoesNotSupportMediaMode(connector, mediaMode)
    }
    if connector == .jackTrip, mediaMode == .video {
        throw ExternalConnectorSessionError.connectorDoesNotSupportMediaMode(connector, mediaMode)
    }
}

func validateTransmitPeer(_ configuration: ExternalConnectorSessionConfiguration) throws {
    guard configuration.role.transmits, configuration.peer.isEmpty else {
        return
    }
    if configuration.connector == .lola {
        throw ExternalConnectorSessionError.lolaRequiresPeerForTx
    }
    throw ExternalConnectorSessionError.connectorRequiresPeerForTx(configuration.connector)
}

enum ExternalConnectorProcessArgumentClass {
    case peerHost
    case jackTripAudioDevice
    case ultraGridModule
    case ultraGridPortMap
}

func validateExternalConnectorProcessArgument(
    _ value: String,
    field: String,
    argumentClass: ExternalConnectorProcessArgumentClass
) throws -> String {
    guard !value.isEmpty else {
        return value
    }
    guard !value.hasPrefix("-") else {
        throw ExternalConnectorSessionError.invalidProcessArgument(field, value)
    }
    let allowedPunctuation = switch argumentClass {
    case .peerHost:
        "._:-[]"
    case .jackTripAudioDevice:
        " ._:/+-"
    case .ultraGridModule:
        " ._:/,+-=@"
    case .ultraGridPortMap:
        ":"
    }
    let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: allowedPunctuation))
    guard value.unicodeScalars.allSatisfy({ allowed.contains($0) }) else {
        throw ExternalConnectorSessionError.invalidProcessArgument(field, value)
    }
    return value
}

func requiredExternalConnectorValue(
    _ key: String,
    _ values: [String: String]
) throws -> String {
    guard let value = values[key], !value.isEmpty else {
        throw ExternalConnectorSessionError.missingRequiredArgument(key)
    }
    return value
}

func optionalExternalConnectorBoolean(
    _ key: String,
    _ values: [String: String]
) throws -> Bool? {
    guard let value = values[key] else {
        return nil
    }
    switch value {
    case "true":
        return true
    case "false":
        return false
    default:
        throw ExternalConnectorSessionError.invalidBoolean(value)
    }
}

func optionalExternalConnectorPositiveInteger(
    _ key: String,
    _ values: [String: String]
) throws -> Int? {
    guard let value = values[key] else {
        return nil
    }
    guard let parsed = Int(value), parsed > 0 else {
        throw ExternalConnectorSessionError.invalidPositiveInteger(key, value)
    }
    return parsed
}

func optionalExternalConnectorNonNegativeInteger(
    _ key: String,
    _ values: [String: String]
) throws -> Int? {
    guard let value = values[key] else {
        return nil
    }
    guard let parsed = Int(value), parsed >= 0 else {
        throw ExternalConnectorSessionError.invalidPositiveInteger(key, value)
    }
    return parsed
}

func optionalExternalConnectorPort(
    _ key: String,
    _ values: [String: String]
) throws -> UInt16? {
    guard let value = values[key] else {
        return nil
    }
    guard let parsed = UInt16(value), parsed > 0 else {
        throw ExternalConnectorSessionError.invalidPort(key, value)
    }
    return parsed
}

func requireExternalConnectorSessionNonEmpty(_ value: String, _ field: String) throws {
    try ValidationPrimitives.requireNonEmpty(value, field: field, empty: ExternalConnectorSessionError.emptyField)
}

func requireExternalConnectorSessionNonEmptyList(_ values: [String], _ field: String) throws {
    try ValidationPrimitives.requireNonEmptyStrings(
        values,
        field: field,
        emptyField: ExternalConnectorSessionError.emptyField,
        emptyList: ExternalConnectorSessionError.emptyList
    )
}

func defaultControlPort(for connector: ExternalConnectorKind) -> UInt16 {
    switch connector {
    case .lola:
        return 7000
    case .mvtpUltraGrid:
        return 0
    case .jackTrip:
        return 0
    }
}

func defaultAudioPort(for connector: ExternalConnectorKind) -> UInt16 {
    switch connector {
    case .lola:
        return 19788
    case .mvtpUltraGrid:
        return 5006
    case .jackTrip:
        return 4464
    }
}

func defaultVideoPort(for connector: ExternalConnectorKind) -> UInt16 {
    switch connector {
    case .lola:
        return 19798
    case .mvtpUltraGrid:
        return 5004
    case .jackTrip:
        return 5004
    }
}

func defaultSampleRate(for connector: ExternalConnectorKind) -> Int {
    switch connector {
    case .lola:
        return 44_100
    case .mvtpUltraGrid:
        return 48_000
    case .jackTrip:
        return 48_000
    }
}

func defaultFramesPerPacket(for connector: ExternalConnectorKind) -> Int {
    switch connector {
    case .lola:
        return 64
    case .mvtpUltraGrid:
        return 128
    case .jackTrip:
        return 128
    }
}

func defaultMediaMode(for connector: ExternalConnectorKind) -> ExternalConnectorMediaMode {
    switch connector {
    case .lola:
        return .audioVideo
    case .mvtpUltraGrid:
        return .audioVideo
    case .jackTrip:
        return .audio
    }
}

func defaultControlTransport(for connector: ExternalConnectorKind) -> ExternalConnectorControlTransport {
    switch connector {
    case .lola:
        return .udp
    case .mvtpUltraGrid, .jackTrip:
        return .udp
    }
}

func lolaControlSessionID(_ value: String) throws -> Int {
    guard let parsed = Int(value), parsed >= 0 else {
        throw ExternalConnectorSessionError.invalidLoLaSessionID(value)
    }
    return parsed
}
