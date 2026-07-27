// Enforces finite, nonempty, and pass-evidence invariants used by lighting gate reports before they can authorize output.
import Foundation

func requireLightingNonEmpty(_ value: String, _ field: String) throws {
    try ValidationPrimitives.requireNonEmpty(value, field: field, empty: LightingFixtureGateValidationError.emptyField)
}

func requireLightingPassWorkflowText(
    _ value: String,
    field: String,
    missing: LightingFixtureGateValidationError
) throws {
    guard !value.isEmpty else {
        throw missing
    }
    if isLightingWorkflowPlaceholder(value) {
        throw LightingFixtureGateValidationError.passWithPlaceholderWorkflowField(field)
    }
}

func requireLightingList<T>(_ values: [T], _ field: String) throws {
    try ValidationPrimitives.requireNonEmpty(values, field: field, empty: LightingFixtureGateValidationError.emptyList)
}

func requireLightingPositive(_ value: Int, _ field: String) throws {
try ValidationPrimitives.requirePositive(
value,
field: field,
nonPositive: LightingFixtureGateValidationError.nonPositiveField
)
}

func requireLightingPositive(_ value: Double, _ field: String) throws {
    try ValidationPrimitives.requirePositive(
        value,
        field: field,
        nonPositive: LightingFixtureGateValidationError.nonPositiveField,
        nonFinite: LightingFixtureGateValidationError.nonFiniteField
    )
}

func requireLightingNonNegative(_ value: Int, _ field: String) throws {
try ValidationPrimitives.requireNonNegative(
value,
field: field,
negative: LightingFixtureGateValidationError.negativeField
)
}

func requireLightingNonNegative(_ value: Double, _ field: String) throws {
    try ValidationPrimitives.requireNonNegative(
        value,
        field: field,
        negative: LightingFixtureGateValidationError.negativeField,
        nonFinite: LightingFixtureGateValidationError.nonFiniteField
    )
}

func requireLightingFinite(_ value: Double, _ field: String) throws {
 try ValidationPrimitives.requireFinite(
 value,
 field: field,
 nonFinite: LightingFixtureGateValidationError.nonFiniteField
 )
}

func lightingCurrentStandardEvidence() -> [LightingProtocolStandardEvidence] {
    [
        LightingProtocolStandardEvidence(
            protocolName: .sacn,
            document: "ANSI E1.31-2025, Entertainment Technology - Lightweight streaming protocol " +
                "for transport of DMX512 using ACN",
        status: .reviewed,
        sourceURL: "https://webstore.ansi.org/standards/esta/ansie1312025",
        licenseDisposition: "ESTA published document; source validation records current standard identity only."
    ),
        LightingProtocolStandardEvidence(
            protocolName: .artNet,
            document: "Art-Net 4 specification, Artistic Licence, copyright 1998-2025",
            status: .reviewed,
            sourceURL: "https://art-net.org.uk/",
            licenseDisposition: "Royalty-free protocol use still requires required credit and OEM Code " +
                "before product implementation."
        )
    ]
}

func lightingOscPeerKind(for interopTarget: LightingInteropTarget) -> OscCuePeerKind {
    switch interopTarget {
    case .qlcPlus:
        return .qlcPlus
    case .ola:
        return .ola
    case .none:
        return .localLoopback
    }
}

func isLightingWorkflowPlaceholder(_ value: String) -> Bool {
    PlaceholderDetection.matches(
        value,
        containing: [PlaceholderDetection.manualEvidenceToken, "placeholder", "fixture", "synthetic", "required"],
        exactly: ["unknown", "tbd"]
    )
}

func requiredLightingRunString(
    _ argument: String,
    _ values: [String: String]
) throws -> String {
    try KeyValueArgumentParser.requiredString(
        argument,
        values,
        missing: LightingGateRunConfigurationError.missingRequiredArgument
    )
}

func requiredLightingRunNonNegativeInteger(
    _ argument: String,
    _ values: [String: String]
) throws -> Int {
    let value = try requiredLightingRunString(argument, values)
    guard let integer = Int(value) else {
        throw LightingGateRunConfigurationError.invalidInteger(argument: argument, value: value)
    }
    guard integer >= 0 else {
        throw LightingGateRunConfigurationError.negativeArgument(argument)
    }
    return integer
}

func requiredLightingRunPositiveInteger(
    _ argument: String,
    _ values: [String: String]
) throws -> Int {
    try KeyValueArgumentParser.requiredPositiveInteger(
        argument,
        values,
        missing: LightingGateRunConfigurationError.missingRequiredArgument,
        invalid: LightingGateRunConfigurationError.invalidInteger,
        nonPositive: LightingGateRunConfigurationError.nonPositiveArgument
    )
}

func requiredLightingRunNonNegativeDouble(
    _ argument: String,
    _ values: [String: String]
) throws -> Double {
    let value = try requiredLightingRunString(argument, values)
    guard let double = Double(value) else {
        throw LightingGateRunConfigurationError.invalidDouble(argument: argument, value: value)
    }
    guard double >= 0 else {
        throw LightingGateRunConfigurationError.negativeArgument(argument)
    }
    return double
}

func requiredLightingRunBoolean(
    _ argument: String,
    _ values: [String: String]
) throws -> Bool {
    let value = try requiredLightingRunString(argument, values)
    return try KeyValueArgumentParser.boolean(
        value,
        argument: argument,
        trueValues: ["true", "yes", "1"],
        falseValues: ["false", "no", "0"],
        invalid: LightingGateRunConfigurationError.invalidBoolean
    )
}

func requiredLightingRunProtocol(
    _ argument: String,
    _ values: [String: String]
) throws -> LightingControlProtocol {
    let value = try requiredLightingRunString(argument, values)
    guard let protocolName = LightingControlProtocol(rawValue: value) else {
        throw LightingGateRunConfigurationError.invalidProtocol(value)
    }
    return protocolName
}

func requiredLightingRunInteropTarget(
    _ argument: String,
    _ values: [String: String]
) throws -> LightingInteropTarget {
    let value = try requiredLightingRunString(argument, values)
    guard let target = LightingInteropTarget(rawValue: value) else {
        throw LightingGateRunConfigurationError.invalidInteropTarget(value)
    }
    return target
}

func requiredLightingRunNetworkMode(
    _ argument: String,
    _ values: [String: String]
) throws -> LightingNetworkMode {
    let value = try requiredLightingRunString(argument, values)
    guard let mode = LightingNetworkMode(rawValue: value) else {
        throw LightingGateRunConfigurationError.invalidNetworkMode(value)
    }
    return mode
}

func requiredLightingRunPort(
    _ argument: String,
    _ values: [String: String]
) throws -> Int {
    let value = try requiredLightingRunNonNegativeInteger(argument, values)
    guard value > 0 && value <= Int(UInt16.max) else {
        throw LightingGateRunConfigurationError.invalidPort(value)
    }
    return value
}
