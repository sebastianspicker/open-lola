public struct KeyValueArgumentParser {
    struct ParsedArguments: Equatable, Sendable {
        var values: [String: String]
        var repeatedValues: [String: [String]]

        func repeatedValues(for key: String) -> [String] {
            repeatedValues[key] ?? []
        }
    }

    /// Default accepted true token for strict CLI booleans.
    public static let defaultBooleanTrueValues: Set<String> = ["true"]
    /// Default accepted false token for strict CLI booleans.
    public static let defaultBooleanFalseValues: Set<String> = ["false"]

    let allowedKeys: Set<String>
    let allowsDashPrefixedValues: Bool

    /// Creates a strict `--key value` parser.
    ///
    /// `allowsDashPrefixedValues` defaults to `true`, so a token such as
    /// `--direct` can be accepted as a value for the preceding key. Set it to
    /// `false` for command parsers where a following `--token` should be
    /// treated as the next argument and reported as a missing value for the
    /// current key. Single-dash values such as negative numbers remain valid.
    public init(allowedKeys: Set<String>, allowsDashPrefixedValues: Bool = true) {
        self.allowedKeys = allowedKeys
        self.allowsDashPrefixedValues = allowsDashPrefixedValues
    }

    /// Parses alternating `--key value` tokens.
    ///
    /// When `allowsDashPrefixedValues` is `true`, `--value` is stored as the
    /// value for the preceding key. When it is `false`, a value beginning with
    /// `--` is rejected as `.missingValue(key)` so callers can surface the
    /// likely omitted value before the next option.
    public func parse<ParseError: Error>(
        _ arguments: [String],
        mapError: (KeyValueArgumentError) -> ParseError
    ) throws -> [String: String] {
        try parseCollectingRepeated(arguments, repeatableKeys: [], mapError: mapError).values
    }

    func parseCollectingRepeated<ParseError: Error>(
        _ arguments: [String],
        repeatableKeys: Set<String>,
        mapError: (KeyValueArgumentError) -> ParseError
    ) throws -> ParsedArguments {
        var values: [String: String] = [:]
        var repeatedValues: [String: [String]] = [:]
        var index = 0
        while index < arguments.count {
            let key = arguments[index]
            guard allowedKeys.contains(key) else {
                throw mapError(.unknownArgument(key))
            }
            let valueIndex = index + 1
            guard valueIndex < arguments.count else {
                throw mapError(.missingValue(key))
            }
            guard allowsDashPrefixedValues || !arguments[valueIndex].hasPrefix("--") else {
                throw mapError(.missingValue(key))
            }
            if repeatableKeys.contains(key) {
                repeatedValues[key, default: []].append(arguments[valueIndex])
            } else {
                guard values[key] == nil else {
                    throw mapError(.duplicateArgument(key))
                }
                values[key] = arguments[valueIndex]
            }
            index += 2
        }
        return ParsedArguments(values: values, repeatedValues: repeatedValues)
    }

    /// Convenience wrapper around `parse(_:mapError:)`.
    ///
    /// The `allowsDashPrefixedValues` parameter intentionally mirrors the
    /// initializer: keep the default `true` for literal values that may begin
    /// with `--`, or pass `false` for conventional CLI option parsing.
    public static func parseValues<Failure: Error>(
        _ arguments: [String],
        allowed: Set<String>,
        allowsDashPrefixedValues: Bool = true,
        unknown: @escaping (String) -> Failure,
        duplicate: @escaping (String) -> Failure,
        missingValue: @escaping (String) -> Failure
    ) throws -> [String: String] {
        try KeyValueArgumentParser(
            allowedKeys: allowed,
            allowsDashPrefixedValues: allowsDashPrefixedValues
        ).parse(arguments) { error in
            switch error {
            case let .unknownArgument(argument):
                unknown(argument)
            case let .duplicateArgument(argument):
                duplicate(argument)
            case let .missingValue(argument):
                missingValue(argument)
            }
        }
    }

    public static func requiredString<Failure: Error>(
        _ argument: String,
        _ values: [String: String],
        missing: (String) -> Failure
    ) throws -> String {
        guard let value = values[argument], !value.isEmpty else {
            throw missing(argument)
        }
        return value
    }

    public static func optionalInteger<Failure: Error>(
        _ argument: String,
        _ values: [String: String],
        invalid: (String, String) -> Failure
    ) throws -> Int? {
        guard let value = values[argument] else {
            return nil
        }
        guard let integer = Int(value) else {
            throw invalid(argument, value)
        }
        return integer
    }

    /// Reads a required positive integer while preserving each command's typed
    /// error enum. Callback contract:
    /// - `missing(argument)` receives the CLI key when the key is absent or empty.
    /// - `invalid(argument, value)` receives the CLI key and unparseable raw value.
    /// - `nonPositive(argument)` receives the CLI key when the value parses but is
    ///   zero or negative.
    public static func requiredPositiveInteger<Missing: Error, Invalid: Error, NonPositive: Error>(
        _ argument: String,
        _ values: [String: String],
        missing: (String) -> Missing,
        invalid: (String, String) -> Invalid,
        nonPositive: (String) -> NonPositive
    ) throws -> Int {
        let value = try requiredString(argument, values, missing: missing)
        guard let integer = Int(value) else {
            throw invalid(argument, value)
        }
        guard integer > 0 else {
            throw nonPositive(argument)
        }
        return integer
    }

    public static func optionalPositiveInteger<Invalid: Error, NonPositive: Error>(
        _ argument: String,
        _ values: [String: String],
        invalid: (String, String) -> Invalid,
        nonPositive: (String) -> NonPositive
    ) throws -> Int? {
        guard let integer = try optionalInteger(argument, values, invalid: invalid) else {
            return nil
        }
        guard integer > 0 else {
            throw nonPositive(argument)
        }
        return integer
    }

    public static func optionalNonNegativeInteger<Invalid: Error, Negative: Error>(
        _ argument: String,
        _ values: [String: String],
        invalid: (String, String) -> Invalid,
        negative: (String) -> Negative
    ) throws -> Int? {
        guard let integer = try optionalInteger(argument, values, invalid: invalid) else {
            return nil
        }
        guard integer >= 0 else {
            throw negative(argument)
        }
        return integer
    }

    public static func optionalNonNegativeDouble<Invalid: Error, Negative: Error>(
        _ argument: String,
        _ values: [String: String],
        invalid: (String, String) -> Invalid,
        negative: (String) -> Negative
    ) throws -> Double? {
        guard let value = values[argument] else {
            return nil
        }
        guard let number = Double(value) else {
            throw invalid(argument, value)
        }
        guard number >= 0 else {
            throw negative(argument)
        }
        return number
    }

    public static func boolean<Failure: Error>(
        _ value: String,
        argument: String,
        trueValues: Set<String> = KeyValueArgumentParser.defaultBooleanTrueValues,
        falseValues: Set<String> = KeyValueArgumentParser.defaultBooleanFalseValues,
        invalid: (String, String) -> Failure
    ) throws -> Bool {
        let normalized = value.lowercased()
        if trueValues.contains(normalized) {
            return true
        }
        if falseValues.contains(normalized) {
            return false
        }
        throw invalid(argument, value)
    }
}

public enum KeyValueArgumentError: Error, Equatable, Sendable {
    case unknownArgument(String)
    case duplicateArgument(String)
    case missingValue(String)
}
