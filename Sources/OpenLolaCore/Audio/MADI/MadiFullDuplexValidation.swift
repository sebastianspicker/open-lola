import Foundation

func requireM05NonEmpty(_ value: String, _ field: String) throws {
    try ValidationPrimitives.requireNonEmpty(value, field: field, error: MadiFullDuplexError.self)
}

func requireM05Positive(_ value: Int, _ field: String) throws {
    try ValidationPrimitives.requirePositive(value, field: field, error: MadiFullDuplexError.self)
}

func requireM05NonNegative(_ value: Int, _ field: String) throws {
    try ValidationPrimitives.requireNonNegative(value, field: field, error: MadiFullDuplexError.self)
}

func requireM05NonNegative(_ value: Double, _ field: String) throws {
    try ValidationPrimitives.requireNonNegative(value, field: field, error: MadiFullDuplexError.self)
}

func requireM05Finite(_ value: Double, _ field: String) throws {
    try ValidationPrimitives.requireFinite(value, field: field, error: MadiFullDuplexError.self)
}

func requireM05PositiveFinite(_ value: Double, _ field: String) throws {
    try ValidationPrimitives.requirePositive(value, field: field, error: MadiFullDuplexError.self)
}
