// Verifies that verdict validation policy runs rules only for pass verdicts.
import Foundation
import Testing

@testable import OpenLolaCore

private enum ExampleVerdictValidationError: Error, Equatable {
    case missingRequiredEvidence
    case forbiddenBlocker
}

@Test
func verdictValidationPolicyRunsRulesOnlyForPassVerdicts() throws {
    var evaluated = false

    VerdictValidationPolicy.validatePass(.partial) {
        evaluated = true
    }
    #expect(!evaluated)

    VerdictValidationPolicy.validatePass(.pass) {
        evaluated = true
    }
    #expect(evaluated)
}

@Test
func verdictValidationPolicyNamesRequireAndForbidInvalidPassRules() {
    #expect(throws: ExampleVerdictValidationError.missingRequiredEvidence) {
        try VerdictValidationPolicy.passRequires(false, ExampleVerdictValidationError.missingRequiredEvidence)
    }
    #expect(throws: ExampleVerdictValidationError.forbiddenBlocker) {
        try VerdictValidationPolicy.passForbids(true, ExampleVerdictValidationError.forbiddenBlocker)
    }
}

@Test
func verdictValidationPolicyCentralizesUniversalPassForbidPrefixes() {
    #expect(VerdictValidationPolicy.universalPassForbids.map(\.casePrefix) == [
        "passWith",
        "passAllows",
        "passUses",
        "passIncreases",
        "passChanges",
        "passBlocks"
    ])
    #expect(VerdictValidationPolicy.universalPassForbids.allSatisfy { !$0.notes.isEmpty })
    #expect(VerdictValidationPolicy.universalPassForbids.first?.matches(caseName: "passWithBlockers") == true)
    #expect(VerdictValidationPolicy.universalPassForbidCasePrefixes == [
        "passWith",
        "passAllows",
        "passUses",
        "passIncreases",
        "passChanges",
        "passBlocks"
    ])
}
