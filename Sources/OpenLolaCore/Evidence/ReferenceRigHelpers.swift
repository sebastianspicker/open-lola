import Foundation

enum ReferenceRigValidator: ReportPrimitiveValidating {
    typealias ValidationError = ReferenceRigValidationError

    static func requirePositive(_ value: Double, _ field: String) throws {
        try ValidationPrimitives.requirePositive(
            value,
            field: field,
            nonPositive: ReferenceRigValidationError.nonPositiveField
        )
    }
}

func validateNonEmptyStrings(_ values: [String], _ field: String) throws {
    try ReferenceRigValidator.requireNonEmpty(values, field)
    for (index, value) in values.enumerated() {
        try ReferenceRigValidator.requireNonEmpty(value, "\(field)[\(index)]")
    }
}

func validatePositiveIntegers(_ values: [Int], _ field: String) throws {
    for (index, value) in values.enumerated() {
        try ReferenceRigValidator.requirePositive(value, "\(field)[\(index)]")
    }
}

func requireReferenceRigDscpRange(_ value: Int) throws {
    if value < 0 || value > 63 {
        throw ReferenceRigValidationError.invalidDscpValue(value)
    }
}

func isReferenceRigPlaceholder(_ value: String) -> Bool {
    PlaceholderDetection.matchesPhysicalEvidencePlaceholder(value)
}
