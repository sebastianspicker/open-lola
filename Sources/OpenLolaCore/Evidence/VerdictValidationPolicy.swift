public enum InvalidPassValidationRule: String, Codable, Equatable, Sendable {
    case requires
    case forbids
}

public struct InvalidPassValidationDescriptor: Codable, Equatable, Sendable {
    public var caseName: String
    public var rule: InvalidPassValidationRule

    public init(caseName: String, rule: InvalidPassValidationRule) {
        self.caseName = caseName
        self.rule = rule
    }
}

public struct VerdictForbidCondition: Codable, Equatable, Sendable {
    public var casePrefix: String
    public var notes: String

    public init(casePrefix: String, notes: String) {
        self.casePrefix = casePrefix
        self.notes = notes
    }

    public func matches(caseName: String) -> Bool {
        caseName.hasPrefix(casePrefix)
    }
}

public enum VerdictValidationPolicy {
    private static let secondsPerMinute = 60
    // Hardware PASS requires a 30-minute field run so short smoke fixtures cannot
    // be promoted as physical reference-rig validation evidence.
    private static let hardwareValidationMinimumPassDurationMinutes = 30
    // Faster-than-LoLa closure requires a 60-minute comparison run to cover
    // sustained drift, jitter, and packet-loss behavior.
    private static let fasterThanLoLaMinimumPassDurationMinutes = 60

    public static let hardwareValidationMinimumPassDurationSeconds =
        Double(hardwareValidationMinimumPassDurationMinutes * secondsPerMinute)
    public static let fasterThanLoLaMinimumPassDurationSeconds =
        fasterThanLoLaMinimumPassDurationMinutes * secondsPerMinute
    public static let universalPassForbids = [
        VerdictForbidCondition(
            casePrefix: "passWith",
            notes: "PASS verdicts must not carry forbidden runtime, evidence, or release state."
        ),
        VerdictForbidCondition(
            casePrefix: "passAllows",
            notes: "PASS verdicts must not allow unsafe behavior or missing gate enforcement."
        ),
        VerdictForbidCondition(
            casePrefix: "passUses",
            notes: "PASS verdicts must not rely on forbidden runtime paths."
        ),
        VerdictForbidCondition(
            casePrefix: "passIncreases",
            notes: "PASS verdicts must not accept regressions against a baseline."
        ),
        VerdictForbidCondition(
            casePrefix: "passChanges",
            notes: "PASS verdicts must not mutate accepted runtime targets."
        ),
        VerdictForbidCondition(
            casePrefix: "passBlocks",
            notes: "PASS verdicts must not block protected realtime paths."
        ),
    ]
    public static let universalPassForbidCasePrefixes = universalPassForbids.map(\.casePrefix)

    static func validatePass(
        _ verdict: MeasurementVerdict,
        rules: () throws -> Void
    ) rethrows {
        if verdict == .pass {
            try rules()
        }
    }

    static func passRequires(
        _ condition: Bool,
        _ failure: @autoclosure () -> any Error
    ) throws {
        if !condition {
            throw failure()
        }
    }

    static func passForbids(
        _ condition: Bool,
        _ failure: @autoclosure () -> any Error
    ) throws {
        if condition {
            throw failure()
        }
    }

    public static func describeInvalidPassCase(_ caseName: String) -> InvalidPassValidationDescriptor? {
        guard caseName.hasPrefix("pass") else {
            return nil
        }
        if caseName.hasPrefix("passWithout")
            || caseName.hasPrefix("passMissing")
            || caseName.hasPrefix("passRunTooShort")
            || caseName.hasPrefix("passRequires") {
            return InvalidPassValidationDescriptor(caseName: caseName, rule: .requires)
        }
        if caseName.hasPrefix("passForbidden") {
            return InvalidPassValidationDescriptor(caseName: caseName, rule: .forbids)
        }
        if universalPassForbids.contains(where: { $0.matches(caseName: caseName) }) {
            return InvalidPassValidationDescriptor(caseName: caseName, rule: .forbids)
        }
        return nil
    }
}
