import OpenLolaContracts

enum RxBufferPolicyValidator {
    static func requireNonEmpty(_ value: String, _ field: String) throws {
        guard !value.isEmpty else {
            throw RxBufferPolicyValidationError.emptyField(field)
        }
    }

    static func requirePositive(_ value: Int, _ field: String) throws {
        guard value > 0 else {
            throw RxBufferPolicyValidationError.nonPositiveField(field)
        }
    }

    static func requireNonNegative(_ value: Int, _ field: String) throws {
        guard value >= 0 else {
            throw RxBufferPolicyValidationError.negativeField(field)
        }
    }

    static func requireNonNegative(_ value: Double, _ field: String) throws {
        guard value.isFinite else {
            throw RxBufferPolicyValidationError.nonFiniteField(field)
        }
        guard value >= 0 else {
            throw RxBufferPolicyValidationError.negativeField(field)
        }
    }
}
