import OpenLolaContracts

/// Centralizes duration and forbidden-condition rules for validating PASS verdicts.
public enum VerdictValidationPolicy {
    private static let secondsPerMinute = 60
    // Hardware PASS requires a 30-minute field run so short smoke fixtures cannot
    // be promoted as physical reference-rig validation evidence.
// swiftlint:disable:next identifier_name
private static let hardwareValidationMinimumPassDurationMinutes = 30
    // Faster-than-LoLa closure requires a 60-minute comparison run to cover
    // sustained drift, jitter, and packet-loss behavior.
    private static let fasterThanLoLaMinimumPassDurationMinutes = 60

// swiftlint:disable:next identifier_name
 public static let hardwareValidationMinimumPassDurationSeconds =
        Double(hardwareValidationMinimumPassDurationMinutes * secondsPerMinute)
    public static let fasterThanLoLaMinimumPassDurationSeconds =
        fasterThanLoLaMinimumPassDurationMinutes * secondsPerMinute

    public static func validatePass(
        _ verdict: MeasurementVerdict,
        rules: () throws -> Void
    ) rethrows {
        if verdict == .pass {
            try rules()
        }
    }

    public static func passRequires(
        _ condition: Bool,
        _ failure: @autoclosure () -> any Error
    ) throws {
        if !condition {
            throw failure()
        }
    }

    public static func passForbids(
        _ condition: Bool,
        _ failure: @autoclosure () -> any Error
    ) throws {
        if condition {
            throw failure()
        }
    }
}
