import Testing

@testable import OpenLolaCore

@Test
func keyValueArgumentParserRejectsInvalidKeyShapes() {
    let parser = KeyValueArgumentParser(allowedKeys: ["--host"])

    #expect(throws: KeyValueArgumentError.duplicateArgument("--host")) {
        _ = try parser.parse(["--host", "127.0.0.1", "--host", "192.0.2.1"]) { $0 }
    }
    #expect(throws: KeyValueArgumentError.unknownArgument("--port")) {
        _ = try parser.parse(["--port", "5000"]) { $0 }
    }
    #expect(throws: KeyValueArgumentError.unknownArgument("--host=127.0.0.1")) {
        _ = try parser.parse(["--host=127.0.0.1"]) { $0 }
    }
}

@Test
func keyValueArgumentParserHandlesDashPrefixedAndEmptyValues() throws {
    let permissiveParser = KeyValueArgumentParser(allowedKeys: ["--host"])
    let strictParser = KeyValueArgumentParser(
        allowedKeys: ["--host", "--timeout"],
        allowsDashPrefixedValues: false
    )

    let permissiveValues = try permissiveParser.parse(["--host", "--direct"]) { $0 }
    let negativeNumberValues = try strictParser.parse(["--timeout", "-10"]) { $0 }
    let emptyValues = try permissiveParser.parse(["--host", ""]) { $0 }

    #expect(permissiveValues["--host"] == "--direct")
    #expect(negativeNumberValues["--timeout"] == "-10")
    #expect(emptyValues["--host"] == "")
    #expect(throws: KeyValueArgumentError.missingValue("--host")) {
        _ = try strictParser.parse(["--host", "--port"]) { $0 }
    }
}

@Test
func requiredPositiveIntegerRoutesErrorCallbacks() throws {
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
}

@Test
func booleanParserUsesNamedDefaultSets() throws {
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
}
