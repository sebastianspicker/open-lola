// Parses typed connector options and applies defaults for ports, timing, media, and device values.
import Foundation

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

func requireExternalConnectorSessionNonEmptyEvidenceClasses(
    _ values: [ExternalConnectorEvidenceClass],
    _ field: String
) throws {
    guard !values.isEmpty else {
        throw ExternalConnectorSessionError.emptyList(field)
    }
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
        return 32
    case .jackTrip:
        return 32
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
