import Foundation

protocol ValidationEmptyFieldError: Error {
    static func emptyField(_ field: String) -> Self
}

protocol ValidationEmptyListError: Error {
    static func emptyList(_ field: String) -> Self
}

protocol ValidationMalformedFieldError: Error {
    static func malformedField(_ field: String) -> Self
}

protocol ValidationNonPositiveFieldError: Error {
    static func nonPositiveField(_ field: String) -> Self
}

protocol ValidationNegativeFieldError: Error {
    static func negativeField(_ field: String) -> Self
}

protocol ValidationNonFiniteFieldError: Error {
    static func nonFiniteField(_ field: String) -> Self
}

protocol ValidationPercentOutOfRangeFieldError: Error {
    static func percentOutOfRange(field: String, value: Double) -> Self
}

protocol ReportPrimitiveValidating {
    associatedtype ValidationError: Error
}

extension ReportPrimitiveValidating {
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

extension ReportPrimitiveValidating where ValidationError: ValidationEmptyFieldError {
    static func requireNonEmpty(_ value: String, _ field: String) throws {
        try ValidationPrimitives.requireNonEmpty(value, field: field, error: ValidationError.self)
    }

    static func requireOptionalNonEmpty(_ value: String?, _ field: String) throws {
        if let value {
            try requireNonEmpty(value, field)
        }
    }
}

extension ReportPrimitiveValidating where ValidationError: ValidationEmptyListError {
    static func requireNonEmpty<T>(_ values: [T], _ field: String) throws {
        try ValidationPrimitives.requireNonEmptyList(values, field: field, error: ValidationError.self)
    }
}

extension ReportPrimitiveValidating where ValidationError: ValidationEmptyFieldError & ValidationEmptyListError {
    static func requireNonEmptyStrings(_ values: [String], _ field: String) throws {
        try requireNonEmpty(values, field)
        for value in values {
            try requireNonEmpty(value, field)
        }
    }
}

extension ReportPrimitiveValidating where ValidationError: ValidationMalformedFieldError {
    static func requireISO8601Date(_ value: String, _ field: String) throws {
        try ValidationPrimitives.requireISO8601Date(value, field: field, error: ValidationError.self)
    }
}

extension ReportPrimitiveValidating where ValidationError: ValidationNonPositiveFieldError {
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

extension ReportPrimitiveValidating where ValidationError: ValidationNonPositiveFieldError & ValidationNonFiniteFieldError {
    static func requirePositive(_ value: Double, _ field: String) throws {
        try ValidationPrimitives.requirePositive(value, field: field, error: ValidationError.self)
    }
}

extension ReportPrimitiveValidating where ValidationError: ValidationNegativeFieldError {
    static func requireNonNegative(_ value: Int, _ field: String) throws {
        try ValidationPrimitives.requireNonNegative(value, field: field, error: ValidationError.self)
    }
}

extension ReportPrimitiveValidating where ValidationError: ValidationNegativeFieldError & ValidationNonFiniteFieldError {
    static func requireNonNegative(_ value: Double, _ field: String) throws {
        try ValidationPrimitives.requireNonNegative(value, field: field, error: ValidationError.self)
    }
}

extension ReportPrimitiveValidating where ValidationError: ValidationNonFiniteFieldError {
    static func requireFinite(_ value: Double, _ field: String) throws {
        try ValidationPrimitives.requireFinite(value, field: field, error: ValidationError.self)
    }
}

extension ReportPrimitiveValidating where ValidationError: ValidationNonFiniteFieldError & ValidationPercentOutOfRangeFieldError {
    static func requirePercent(_ value: Double, _ field: String) throws {
        try ValidationPrimitives.requirePercent(
            value,
            field: field,
            nonFinite: ValidationError.nonFiniteField,
            outOfRange: ValidationError.percentOutOfRange
        )
    }
}

enum ValidationPrimitives {
    static func requireNonEmpty<E: ValidationEmptyFieldError>(
        _ value: String,
        field: String,
        error: E.Type
    ) throws {
        try requireNonEmpty(value, field: field, empty: E.emptyField)
    }

    static func requireNonEmptyList<T, E: ValidationEmptyListError>(
        _ values: [T],
        field: String,
        error: E.Type
    ) throws {
        try requireNonEmpty(values, field: field, empty: E.emptyList)
    }

    static func requireISO8601Date<E: ValidationMalformedFieldError>(
        _ value: String,
        field: String,
        error: E.Type
    ) throws {
        if ISO8601DateFormatter().date(from: value) == nil {
            throw E.malformedField(field)
        }
    }

    static func requirePositive<E: ValidationNonPositiveFieldError>(
        _ value: Int,
        field: String,
        error: E.Type
    ) throws {
        try requirePositive(value, field: field, nonPositive: E.nonPositiveField)
    }

    static func requirePositive<E: ValidationNonPositiveFieldError & ValidationNonFiniteFieldError>(
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

    static func requireNonNegative<E: ValidationNegativeFieldError>(
        _ value: Int,
        field: String,
        error: E.Type
    ) throws {
        try requireNonNegative(value, field: field, negative: E.negativeField)
    }

    static func requireNonNegative<E: ValidationNegativeFieldError & ValidationNonFiniteFieldError>(
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

    static func requireFinite<E: ValidationNonFiniteFieldError>(
        _ value: Double,
        field: String,
        error: E.Type
    ) throws {
        try requireFinite(value, field: field, nonFinite: E.nonFiniteField)
    }

    static func requireNonEmpty(
        _ value: String,
        field: String,
        empty: (String) -> any Error
    ) throws {
        if value.isEmpty {
            throw empty(field)
        }
    }

    static func requireNonEmpty<T>(
        _ values: [T],
        field: String,
        empty: (String) -> any Error
    ) throws {
        if values.isEmpty {
            throw empty(field)
        }
    }

    static func requireNonEmptyStrings(
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

    static func requireNonBlank(
        _ value: String,
        field: String,
        empty: (String) -> any Error
    ) throws {
        if value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw empty(field)
        }
    }

    static func requirePositive(
        _ value: Int,
        field: String,
        nonPositive: (String) -> any Error
    ) throws {
        if value <= 0 {
            throw nonPositive(field)
        }
    }

    static func requirePositive<T: FixedWidthInteger & UnsignedInteger>(
        _ value: T,
        field: String,
        nonPositive: (String) -> any Error
    ) throws {
        if value == 0 {
            throw nonPositive(field)
        }
    }

    static func requirePositive(
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

    static func requirePositive(
        _ value: Double,
        field: String,
        nonPositive: (String) -> any Error
    ) throws {
        if value <= 0 {
            throw nonPositive(field)
        }
    }

    static func requireNonNegative(
        _ value: Int,
        field: String,
        negative: (String) -> any Error
    ) throws {
        if value < 0 {
            throw negative(field)
        }
    }

    static func requireNonNegative(
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

    static func requireNonNegative(
        _ value: Double,
        field: String,
        negative: (String) -> any Error
    ) throws {
        if value < 0 {
            throw negative(field)
        }
    }

    static func requireFinite(
        _ value: Double,
        field: String,
        nonFinite: (String) -> any Error
    ) throws {
        if !value.isFinite {
            throw nonFinite(field)
        }
    }

    static func requirePercent(
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
