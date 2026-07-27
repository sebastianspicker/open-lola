// Computes integrated AV timing, overlap, load, and report fields from subordinate evidence.
import Foundation

struct IntegratedValidationField<Value> {
    let name: String
    let value: Value
}

func validateIntegratedFieldSet(
    nonEmpty: [IntegratedValidationField<String>] = [],
    optionalNonEmpty: [IntegratedValidationField<String?>] = [],
    positiveInts: [IntegratedValidationField<Int>] = [],
    positiveDoubles: [IntegratedValidationField<Double>] = [],
    nonNegativeInts: [IntegratedValidationField<Int>] = [],
    nonNegativeDoubles: [IntegratedValidationField<Double>] = [],
    percents: [IntegratedValidationField<Double>] = []
) throws {
    for field in nonEmpty {
        try requireIntegratedNonEmpty(field.value, field.name)
    }
    for field in optionalNonEmpty {
        try requireIntegratedOptionalNonEmpty(field.value, field.name)
    }
    for field in positiveInts {
        try requireIntegratedPositive(field.value, field.name)
    }
    for field in positiveDoubles {
        try requireIntegratedPositive(field.value, field.name)
    }
    for field in nonNegativeInts {
        try requireIntegratedNonNegative(field.value, field.name)
    }
    for field in nonNegativeDoubles {
        try requireIntegratedNonNegative(field.value, field.name)
    }
    for field in percents {
        try requireIntegratedPercent(field.value, field.name)
    }
}

func requireIntegratedNonEmpty(_ value: String, _ field: String) throws {
    if value.isEmpty {
        throw IntegratedAvValidationError.emptyField(field)
    }
}

func requireIntegratedOptionalNonEmpty(_ value: String?, _ field: String) throws {
    if let value, value.isEmpty {
        throw IntegratedAvValidationError.emptyField(field)
    }
}

func requireIntegratedPassProofText(
    _ value: String?,
    field: String,
    missing: IntegratedAvValidationError
) throws {
    guard let value, !value.isEmpty else {
        throw missing
    }
    if isIntegratedProofPlaceholder(value) {
        throw IntegratedAvValidationError.passWithPlaceholderProofField(field)
    }
}

func requireIntegratedPositive(_ value: Int, _ field: String) throws {
    if value <= 0 {
        throw IntegratedAvValidationError.nonPositiveField(field)
    }
}

func requireIntegratedPositive(_ value: Double, _ field: String) throws {
    try requireIntegratedFinite(value, field)
    if value <= 0 {
        throw IntegratedAvValidationError.nonPositiveField(field)
    }
}

func requireIntegratedNonNegative(_ value: Int, _ field: String) throws {
    if value < 0 {
        throw IntegratedAvValidationError.negativeField(field)
    }
}

func requireIntegratedNonNegative(_ value: Double, _ field: String) throws {
    try requireIntegratedFinite(value, field)
    if value < 0 {
        throw IntegratedAvValidationError.negativeField(field)
    }
}

func requireIntegratedPercent(_ value: Double, _ field: String) throws {
    try requireIntegratedFinite(value, field)
    if value < 0 || value > 100 {
        throw IntegratedAvValidationError.percentOutOfRange(field: field, value: value)
    }
}

func requireIntegratedPacketAge(_ packetAge: UdpPcmPacketAgeMetrics, _ field: String) throws {
    try requireIntegratedNonNegative(packetAge.p50Microseconds, "\(field).p50Microseconds")
    try requireIntegratedNonNegative(packetAge.p95Microseconds, "\(field).p95Microseconds")
    try requireIntegratedNonNegative(packetAge.p99Microseconds, "\(field).p99Microseconds")
    try requireIntegratedNonNegative(packetAge.maxMicroseconds, "\(field).maxMicroseconds")
    guard packetAge.p50Microseconds <= packetAge.p95Microseconds,
          packetAge.p95Microseconds <= packetAge.p99Microseconds,
          packetAge.p99Microseconds <= packetAge.maxMicroseconds else {
        throw IntegratedAvValidationError.unorderedPacketAge(field)
    }
}

func requireIntegratedFinite(_ value: Double, _ field: String) throws {
    if !value.isFinite {
        throw IntegratedAvValidationError.nonFiniteField(field)
    }
}

@discardableResult
func requiredIntegratedAvRunString(
    _ argument: String,
    _ values: [String: String]
) throws -> String {
    guard let value = values[argument], !value.isEmpty else {
        throw IntegratedAvRunConfigurationError.missingRequiredArgument(argument)
    }
    return value
}

@discardableResult
func requiredIntegratedAvRunPositiveInteger(
    _ argument: String,
    _ values: [String: String]
) throws -> Int {
    let value = try requiredIntegratedAvRunString(argument, values)
    guard let integer = Int(value) else {
        throw IntegratedAvRunConfigurationError.invalidInteger(argument: argument, value: value)
    }
    guard integer > 0 else {
        throw IntegratedAvRunConfigurationError.nonPositiveArgument(argument)
    }
    return integer
}

@discardableResult
func requiredIntegratedAvRunSwitch(
    _ argument: String,
    _ values: [String: String]
) throws -> Bool {
    let value = try requiredIntegratedAvRunString(argument, values)
    return try integratedAvRunSwitch(argument: argument, value: value)
}

@discardableResult
func optionalIntegratedAvRunSwitch(
    _ argument: String,
    _ values: [String: String],
    defaultValue: Bool
) throws -> Bool {
    guard let value = values[argument] else {
        return defaultValue
    }
    return try integratedAvRunSwitch(argument: argument, value: value)
}

@discardableResult
func integratedAvRunSwitch(argument: String, value: String) throws -> Bool {
    switch value.lowercased() {
    case "true", "yes", "1", "enabled", "on":
        return true
    case "false", "no", "0", "disabled", "off":
        return false
    default:
        throw IntegratedAvRunConfigurationError.invalidSwitch(argument: argument, value: value)
    }
}

@discardableResult
func requiredIntegratedAvRunAtemHost(_ values: [String: String]) throws -> String? {
    let value = try requiredIntegratedAvRunString("--atem-readonly", values)
    switch value.lowercased() {
    case "none", "off", "disabled", "false", "no", "0":
        return nil
    default:
        return value
    }
}

func integratedAvVideoLaneOwner(configuration: IntegratedAvRunConfiguration) -> String {
    if configuration.videoCaptureEnabled || configuration.videoTransportEnabled {
        return "headless-av-runner"
    }
    return "disabled"
}

func isIntegratedProofPlaceholder(_ value: String) -> Bool {
    PlaceholderDetection.matches(
        value,
        containing: [
            PlaceholderDetection.manualEvidenceToken,
            "placeholder",
            "fixture",
            "synthetic",
            "not-captured",
            "not captured"
        ],
        exactly: ["unknown", "tbd"]
    )
}
