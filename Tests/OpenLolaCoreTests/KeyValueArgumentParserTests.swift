import Foundation
import Testing

@testable import OpenLolaCore

@Test
func keyValueArgumentParserRejectsDuplicateKeys() {
    let parser = KeyValueArgumentParser(allowedKeys: ["--host"])

    #expect(throws: KeyValueArgumentError.duplicateArgument("--host")) {
        _ = try parser.parse(["--host", "127.0.0.1", "--host", "192.0.2.1"]) { $0 }
    }
}

@Test
func keyValueArgumentParserAllowsDashPrefixedValues() throws {
    let parser = KeyValueArgumentParser(allowedKeys: ["--host"])

    let values = try parser.parse(["--host", "--direct"]) { $0 }

    #expect(values["--host"] == "--direct")
}

@Test
func keyValueArgumentParserCanRejectDashPrefixedValuesForCLICommands() {
    let parser = KeyValueArgumentParser(allowedKeys: ["--host"], allowsDashPrefixedValues: false)

    #expect(throws: KeyValueArgumentError.missingValue("--host")) {
        _ = try parser.parse(["--host", "--port"]) { $0 }
    }
}

@Test
func keyValueArgumentParserAllowsNegativeNumberValuesForCLICommands() throws {
    let parser = KeyValueArgumentParser(allowedKeys: ["--timeout"], allowsDashPrefixedValues: false)

    let values = try parser.parse(["--timeout", "-10"]) { $0 }

    #expect(values["--timeout"] == "-10")
}

@Test
func keyValueArgumentParserDocumentsDashPrefixedValuePolicy() throws {
    let source = try String(
        contentsOf: repositoryRoot.appendingPathComponent(
            "Sources/OpenLolaCore/Core/KeyValueArgumentParser.swift"
        ),
        encoding: .utf8
    )

    #expect(source.contains("`allowsDashPrefixedValues` defaults to `true`"))
    #expect(source.contains("Set it to"))
    #expect(source.contains("reported as a missing value"))
    #expect(source.contains("Single-dash values such as negative numbers remain valid"))
    #expect(source.contains("pass `false` for conventional CLI option parsing"))
}

@Test
func keyValueArgumentParserAllowsEmptyStringValues() throws {
    let parser = KeyValueArgumentParser(allowedKeys: ["--host"])

    let values = try parser.parse(["--host", ""]) { $0 }

    #expect(values["--host"] == "")
}

@Test
func keyValueArgumentParserRejectsUnknownKeysInStrictMode() {
    let parser = KeyValueArgumentParser(allowedKeys: ["--host"])

    #expect(throws: KeyValueArgumentError.unknownArgument("--port")) {
        _ = try parser.parse(["--port", "5000"]) { $0 }
    }
}

@Test
func keyValueArgumentParserRejectsMalformedKeyValueToken() {
    let parser = KeyValueArgumentParser(allowedKeys: ["--host"])

    #expect(throws: KeyValueArgumentError.unknownArgument("--host=127.0.0.1")) {
        _ = try parser.parse(["--host=127.0.0.1"]) { $0 }
    }
}

@Test
func requiredPositiveIntegerDocumentsAndRoutesErrorCallbacks() throws {
    enum ExampleError: Error, Equatable {
        case missing(String)
        case invalid(String, String)
        case nonPositive(String)
    }

    #expect(throws: ExampleError.missing("--count")) {
        _ = try KeyValueArgumentParser.requiredPositiveInteger(
            "--count",
            [:],
            missing: ExampleError.missing,
            invalid: ExampleError.invalid,
            nonPositive: ExampleError.nonPositive
        )
    }
    #expect(throws: ExampleError.invalid("--count", "abc")) {
        _ = try KeyValueArgumentParser.requiredPositiveInteger(
            "--count",
            ["--count": "abc"],
            missing: ExampleError.missing,
            invalid: ExampleError.invalid,
            nonPositive: ExampleError.nonPositive
        )
    }
    #expect(throws: ExampleError.nonPositive("--count")) {
        _ = try KeyValueArgumentParser.requiredPositiveInteger(
            "--count",
            ["--count": "0"],
            missing: ExampleError.missing,
            invalid: ExampleError.invalid,
            nonPositive: ExampleError.nonPositive
        )
    }

    let source = try String(
        contentsOf: repositoryRoot.appendingPathComponent(
            "Sources/OpenLolaCore/Core/KeyValueArgumentParser.swift"
        ),
        encoding: .utf8
    )
    #expect(source.contains("Callback contract:"))
    #expect(source.contains("missing(argument)"))
    #expect(source.contains("invalid(argument, value)"))
    #expect(source.contains("nonPositive(argument)"))
}

@Test
func booleanParserDocumentsAndUsesNamedDefaultSets() throws {
    enum ExampleError: Error, Equatable {
        case invalid(String, String)
    }

    #expect(KeyValueArgumentParser.defaultBooleanTrueValues == ["true"])
    #expect(KeyValueArgumentParser.defaultBooleanFalseValues == ["false"])
    #expect(try KeyValueArgumentParser.boolean(
        "TRUE",
        argument: "--enabled",
        invalid: ExampleError.invalid
    ))
    #expect(try !KeyValueArgumentParser.boolean(
        "false",
        argument: "--enabled",
        invalid: ExampleError.invalid
    ))
    #expect(throws: ExampleError.invalid("--enabled", "yes")) {
        _ = try KeyValueArgumentParser.boolean(
            "yes",
            argument: "--enabled",
            invalid: ExampleError.invalid
        )
    }

    let source = try String(
        contentsOf: repositoryRoot.appendingPathComponent(
            "Sources/OpenLolaCore/Core/KeyValueArgumentParser.swift"
        ),
        encoding: .utf8
    )
    #expect(source.contains("Default accepted true token"))
    #expect(source.contains("Default accepted false token"))
    #expect(source.contains("defaultBooleanTrueValues"))
    #expect(source.contains("defaultBooleanFalseValues"))
}

private var repositoryRoot: URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
}
