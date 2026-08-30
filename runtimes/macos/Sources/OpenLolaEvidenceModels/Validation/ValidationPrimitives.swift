// Validates ValidationPrimitives acceptance rules, keeping failure policy close to its contract rather than the runtime path.
import Foundation
import OpenLolaContracts

public protocol ValidationEmptyFieldError: Error {
    static func emptyField(_ field: String) -> Self
}

public protocol ValidationEmptyListError: Error {
    static func emptyList(_ field: String) -> Self
}

public protocol ValidationMalformedFieldError: Error {
    static func malformedField(_ field: String) -> Self
}

public protocol ValidationNonPositiveFieldError: Error {
    static func nonPositiveField(_ field: String) -> Self
}

public protocol ValidationNegativeFieldError: Error {
    static func negativeField(_ field: String) -> Self
}

public protocol ValidationNonFiniteFieldError: Error {
    static func nonFiniteField(_ field: String) -> Self
}

public protocol ValidationPercentOutOfRangeFieldError: Error {
    static func percentOutOfRange(field: String, value: Double) -> Self
}

public protocol ReportPrimitiveValidating {
    associatedtype ValidationError: Error
}

public extension ReportPrimitiveValidating {
    static func validateVerdictNotRun<V: RawRepresentable>(
        _ verdict: V,
        _ failure: @autoclosure () -> ValidationError
    ) throws where V.RawValue == String {
        if verdict.rawValue == "notRun" {
            throw failure()
        }
    }

    static func validateVerdictPass(
        _ verdict: MeasurementVerdict,
        rules: () throws -> Void
    ) rethrows {
        try VerdictValidationPolicy.validatePass(verdict, rules: rules)
    }

    static func validateThreshold<Value: Comparable>(
        value: Value,
        max maximum: Value,
        error: @autoclosure () -> ValidationError
    ) throws {
        if value > maximum {
            throw error()
        }
    }
}

public extension ReportPrimitiveValidating where ValidationError: ValidationEmptyFieldError {
    static func requireNonEmpty(_ value: String, _ field: String) throws {
        try ValidationPrimitives.requireNonEmpty(value, field: field, error: ValidationError.self)
    }

    static func requireOptionalNonEmpty(_ value: String?, _ field: String) throws {
        if let value {
            try requireNonEmpty(value, field)
        }
    }
}

public extension ReportPrimitiveValidating where ValidationError: ValidationEmptyListError {
    static func requireNonEmpty<T>(_ values: [T], _ field: String) throws {
        try ValidationPrimitives.requireNonEmptyList(values, field: field, error: ValidationError.self)
    }
}

public extension ReportPrimitiveValidating where ValidationError: ValidationEmptyFieldError & ValidationEmptyListError {
    static func requireNonEmptyStrings(_ values: [String], _ field: String) throws {
        try requireNonEmpty(values, field)
        for value in values {
            try requireNonEmpty(value, field)
        }
    }
}

public extension ReportPrimitiveValidating where ValidationError: ValidationMalformedFieldError {
    static func requireISO8601Date(_ value: String, _ field: String) throws {
        try ValidationPrimitives.requireISO8601Date(value, field: field, error: ValidationError.self)
    }
}

public extension ReportPrimitiveValidating where ValidationError: ValidationNonPositiveFieldError {
    static func requirePositive(_ value: Int, _ field: String) throws {
        try ValidationPrimitives.requirePositive(value, field: field, error: ValidationError.self)
    }

    static func requirePositive<T: FixedWidthInteger & UnsignedInteger>(
        _ value: T,
        _ field: String
    ) throws {
        try ValidationPrimitives.requirePositive(
            value,
            field: field,
            nonPositive: ValidationError.nonPositiveField
        )
    }
}

public extension ReportPrimitiveValidating
where ValidationError: ValidationNonPositiveFieldError & ValidationNonFiniteFieldError {
    static func requirePositive(_ value: Double, _ field: String) throws {
        try ValidationPrimitives.requirePositive(value, field: field, error: ValidationError.self)
    }
}

public extension ReportPrimitiveValidating where ValidationError: ValidationNegativeFieldError {
    static func requireNonNegative(_ value: Int, _ field: String) throws {
        try ValidationPrimitives.requireNonNegative(value, field: field, error: ValidationError.self)
    }
}

public extension ReportPrimitiveValidating
where ValidationError: ValidationNegativeFieldError & ValidationNonFiniteFieldError {
    static func requireNonNegative(_ value: Double, _ field: String) throws {
        try ValidationPrimitives.requireNonNegative(value, field: field, error: ValidationError.self)
    }
}

public extension ReportPrimitiveValidating where ValidationError: ValidationNonFiniteFieldError {
    static func requireFinite(_ value: Double, _ field: String) throws {
        try ValidationPrimitives.requireFinite(value, field: field, error: ValidationError.self)
    }
}

public extension ReportPrimitiveValidating
where ValidationError: ValidationNonFiniteFieldError & ValidationPercentOutOfRangeFieldError {
    static func requirePercent(_ value: Double, _ field: String) throws {
        try ValidationPrimitives.requirePercent(
            value,
            field: field,
            nonFinite: ValidationError.nonFiniteField,
            outOfRange: ValidationError.percentOutOfRange
        )
    }
}

public enum ValidationPrimitives {
    public static func requireNonEmpty<E: ValidationEmptyFieldError>(
        _ value: String,
        field: String,
        error: E.Type
    ) throws {
        try requireNonEmpty(value, field: field, empty: E.emptyField)
    }

    public static func requireNonEmptyList<T, E: ValidationEmptyListError>(
        _ values: [T],
        field: String,
        error: E.Type
    ) throws {
        try requireNonEmpty(values, field: field, empty: E.emptyList)
    }

    public static func requireISO8601Date<E: ValidationMalformedFieldError>(
        _ value: String,
        field: String,
        error: E.Type
    ) throws {
        if ISO8601DateFormatter().date(from: value) == nil {
            throw E.malformedField(field)
        }
    }

    public static func requirePositive<E: ValidationNonPositiveFieldError>(
        _ value: Int,
        field: String,
        error: E.Type
    ) throws {
        try requirePositive(value, field: field, nonPositive: E.nonPositiveField)
    }

    public static func requirePositive<E: ValidationNonPositiveFieldError & ValidationNonFiniteFieldError>(
        _ value: Double,
        field: String,
        error: E.Type
    ) throws {
        try requirePositive(
            value,
            field: field,
            nonPositive: E.nonPositiveField,
            nonFinite: E.nonFiniteField
        )
    }

    public static func requireNonNegative<E: ValidationNegativeFieldError>(
        _ value: Int,
        field: String,
        error: E.Type
    ) throws {
        try requireNonNegative(value, field: field, negative: E.negativeField)
    }

    public static func requireNonNegative<E: ValidationNegativeFieldError & ValidationNonFiniteFieldError>(
        _ value: Double,
        field: String,
        error: E.Type
    ) throws {
        try requireNonNegative(
            value,
            field: field,
            negative: E.negativeField,
            nonFinite: E.nonFiniteField
        )
    }

    public static func requireFinite<E: ValidationNonFiniteFieldError>(
        _ value: Double,
        field: String,
        error: E.Type
    ) throws {
        try requireFinite(value, field: field, nonFinite: E.nonFiniteField)
    }

    public static func requireNonEmpty(
        _ value: String,
        field: String,
        empty: (String) -> any Error
    ) throws {
        if value.isEmpty {
            throw empty(field)
        }
    }

    public static func requireNonEmpty<T>(
        _ values: [T],
        field: String,
        empty: (String) -> any Error
    ) throws {
        if values.isEmpty {
            throw empty(field)
        }
    }

    public static func requireNonEmptyStrings(
        _ values: [String],
        field: String,
        emptyField: (String) -> any Error,
        emptyList: (String) -> any Error
    ) throws {
        try requireNonEmpty(values, field: field, empty: emptyList)
        for value in values {
            try requireNonEmpty(value, field: field, empty: emptyField)
        }
    }

    public static func requireNonBlank(
        _ value: String,
        field: String,
        empty: (String) -> any Error
    ) throws {
        if value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw empty(field)
        }
    }

    public static func requirePositive(
        _ value: Int,
        field: String,
        nonPositive: (String) -> any Error
    ) throws {
        if value <= 0 {
            throw nonPositive(field)
        }
    }

    public static func requirePositive<T: FixedWidthInteger & UnsignedInteger>(
        _ value: T,
        field: String,
        nonPositive: (String) -> any Error
    ) throws {
        if value == 0 {
            throw nonPositive(field)
        }
    }

    public static func requirePositive(
        _ value: Double,
        field: String,
        nonPositive: (String) -> any Error,
        nonFinite: (String) -> any Error
    ) throws {
        try requireFinite(value, field: field, nonFinite: nonFinite)
        if value <= 0 {
            throw nonPositive(field)
        }
    }

    public static func requirePositive(
        _ value: Double,
        field: String,
        nonPositive: (String) -> any Error
    ) throws {
        if value <= 0 {
            throw nonPositive(field)
        }
    }

    public static func requireNonNegative(
        _ value: Int,
        field: String,
        negative: (String) -> any Error
    ) throws {
        if value < 0 {
            throw negative(field)
        }
    }

    public static func requireNonNegative(
        _ value: Double,
        field: String,
        negative: (String) -> any Error,
        nonFinite: (String) -> any Error
    ) throws {
        try requireFinite(value, field: field, nonFinite: nonFinite)
        if value < 0 {
            throw negative(field)
        }
    }

    public static func requireNonNegative(
        _ value: Double,
        field: String,
        negative: (String) -> any Error
    ) throws {
        if value < 0 {
            throw negative(field)
        }
    }

    public static func requireFinite(
        _ value: Double,
        field: String,
        nonFinite: (String) -> any Error
    ) throws {
        if !value.isFinite {
            throw nonFinite(field)
        }
    }

    public static func requirePercent(
        _ value: Double,
        field: String,
        nonFinite: (String) -> any Error,
        outOfRange: (String, Double) -> any Error
    ) throws {
        try requireFinite(value, field: field, nonFinite: nonFinite)
        if value < 0 || value > 100 {
            throw outOfRange(field, value)
        }
    }
}
