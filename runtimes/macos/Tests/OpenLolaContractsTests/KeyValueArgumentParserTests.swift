// Verifies strict key-value command parsing reports a repeated key before a missing value.

import Testing
@testable import OpenLolaContracts

@Test func transportCLIParserReportsDuplicateBeforeTheRepeatedValueIsMissing() {
    #expect(throws: KeyValueArgumentError.duplicateArgument("--peer")) {
        _ = try KeyValueArgumentParser.parseValuesCheckingDuplicatesFirst(
            ["--peer", "127.0.0.1", "--peer"],
            allowed: ["--peer"],
            unknown: KeyValueArgumentError.unknownArgument,
            duplicate: KeyValueArgumentError.duplicateArgument,
            missingValue: KeyValueArgumentError.missingValue
        )
    }
}
