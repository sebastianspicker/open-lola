import Foundation

func requireVideoCaptureNonEmpty(_ value: String, _ field: String) throws {
    try ValidationPrimitives.requireNonEmpty(value, field: field, error: VideoCaptureValidationError.self)
}

func requireVideoCaptureOptionalNonEmpty(_ value: String?, _ field: String) throws {
    if let value {
        try requireVideoCaptureNonEmpty(value, field)
    }
}

func requireVideoCapturePositive(_ value: Int, _ field: String) throws {
    try ValidationPrimitives.requirePositive(value, field: field, error: VideoCaptureValidationError.self)
}

func requireVideoCapturePositive(_ value: UInt64, _ field: String) throws {
    try ValidationPrimitives.requirePositive(value, field: field, nonPositive: VideoCaptureValidationError.nonPositiveField)
}

func requireVideoCapturePositive(_ value: UInt32, _ field: String) throws {
    try ValidationPrimitives.requirePositive(value, field: field, nonPositive: VideoCaptureValidationError.nonPositiveField)
}

func requireVideoCapturePositive(_ value: Double, _ field: String) throws {
    try ValidationPrimitives.requirePositive(value, field: field, error: VideoCaptureValidationError.self)
}

func requireVideoCaptureNonNegative(_ value: Int, _ field: String) throws {
    try ValidationPrimitives.requireNonNegative(value, field: field, error: VideoCaptureValidationError.self)
}

func requireVideoCaptureNonNegative(_ value: Double, _ field: String) throws {
    try ValidationPrimitives.requireNonNegative(value, field: field, error: VideoCaptureValidationError.self)
}

func requireVideoCapturePacketAge(
    _ packetAge: UdpPcmPacketAgeMetrics,
    fieldPrefix: String
) throws {
    try requireVideoCaptureNonNegative(packetAge.p50Microseconds, "\(fieldPrefix).p50Microseconds")
    try requireVideoCaptureNonNegative(packetAge.p95Microseconds, "\(fieldPrefix).p95Microseconds")
    try requireVideoCaptureNonNegative(packetAge.p99Microseconds, "\(fieldPrefix).p99Microseconds")
    try requireVideoCaptureNonNegative(packetAge.maxMicroseconds, "\(fieldPrefix).maxMicroseconds")
    guard packetAge.p50Microseconds <= packetAge.p95Microseconds,
          packetAge.p95Microseconds <= packetAge.p99Microseconds,
          packetAge.p99Microseconds <= packetAge.maxMicroseconds else {
        throw VideoCaptureValidationError.unorderedPacketAge
    }
}

func requireVideoCaptureFinite(_ value: Double, _ field: String) throws {
    try ValidationPrimitives.requireFinite(value, field: field, error: VideoCaptureValidationError.self)
}

func videoCapturePacketAge(from agesMicroseconds: [Double]) -> UdpPcmPacketAgeMetrics {
    let sorted = agesMicroseconds.sorted()
    guard !sorted.isEmpty else {
        return UdpPcmPacketAgeMetrics(
            p50Microseconds: 0,
            p95Microseconds: 0,
            p99Microseconds: 0,
            maxMicroseconds: 0
        )
    }
    return UdpPcmPacketAgeMetrics(
        p50Microseconds: videoCapturePercentile(sorted, 0.50),
        p95Microseconds: videoCapturePercentile(sorted, 0.95),
        p99Microseconds: videoCapturePercentile(sorted, 0.99),
        maxMicroseconds: sorted.last ?? 0
    )
}

private func videoCapturePercentile(_ sorted: [Double], _ percentile: Double) -> Double {
    guard sorted.count > 1 else {
        return sorted.first ?? 0
    }
    let index = Int((Double(sorted.count - 1) * percentile).rounded(.up))
    return sorted[min(max(index, 0), sorted.count - 1)]
}

func videoCaptureFourCCString(_ code: FourCharCode) -> String {
    let bytes = [
        UInt8((code >> 24) & 0xff),
        UInt8((code >> 16) & 0xff),
        UInt8((code >> 8) & 0xff),
        UInt8(code & 0xff),
    ]
    if bytes.allSatisfy({ $0 >= 32 && $0 <= 126 }) {
        return String(bytes: bytes, encoding: .ascii) ?? "\(code)"
    }
    return "\(code)"
}

func videoCaptureIntervalsMicroseconds(from timestampsNanoseconds: [UInt64]) -> [Double] {
    guard timestampsNanoseconds.count > 1 else {
        return []
    }
    return zip(timestampsNanoseconds, timestampsNanoseconds.dropFirst()).map { before, after in
        Double(after >= before ? after - before : 0) / 1_000
    }
}

func requiredVideoCaptureString(
    _ argument: String,
    _ values: [String: String]
) throws -> String {
    guard let value = values[argument], !value.isEmpty else {
        throw VideoCaptureRunConfigurationError.missingRequiredArgument(argument)
    }
    return value
}

func optionalVideoCaptureInteger(
    _ argument: String,
    _ values: [String: String],
    defaultValue: Int
) throws -> Int {
    guard let value = values[argument] else {
        return defaultValue
    }
    guard let integer = Int(value) else {
        throw VideoCaptureRunConfigurationError.invalidInteger(argument: argument, value: value)
    }
    guard integer > 0 else {
        throw VideoCaptureRunConfigurationError.nonPositiveArgument(argument)
    }
    return integer
}

func requiredVideoCaptureInteger(_ argument: String, _ values: [String: String]) throws -> Int {
    let value = try requiredVideoCaptureString(argument, values)
    guard let integer = Int(value) else {
        throw VideoCaptureRunConfigurationError.invalidInteger(argument: argument, value: value)
    }
    guard integer > 0 else {
        throw VideoCaptureRunConfigurationError.nonPositiveArgument(argument)
    }
    return integer
}

func optionalVideoCaptureDouble(
    _ argument: String,
    _ values: [String: String],
    defaultValue: Double
) throws -> Double {
    guard let value = values[argument] else {
        return defaultValue
    }
    guard let double = Double(value) else {
        throw VideoCaptureRunConfigurationError.invalidDouble(argument: argument, value: value)
    }
    guard double > 0 else {
        throw VideoCaptureRunConfigurationError.nonPositiveArgument(argument)
    }
    return double
}

func optionalVideoCaptureBoolean(
    _ argument: String,
    _ values: [String: String]
) throws -> Bool? {
    guard let value = values[argument] else {
        return nil
    }
    switch value.lowercased() {
    case "true", "yes", "on", "1":
        return true
    case "false", "no", "off", "0":
        return false
    default:
        throw VideoCaptureRunConfigurationError.invalidBoolean(argument: argument, value: value)
    }
}
