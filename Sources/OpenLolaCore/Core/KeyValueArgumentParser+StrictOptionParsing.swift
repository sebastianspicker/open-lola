// Adds strict option parsing helpers that reject repeated, missing, and malformed command-line values.
extension KeyValueArgumentParser {
    /// Parses strict option pairs while reporting a duplicate key before inspecting its value.
    static func parseValuesCheckingDuplicatesFirst<Failure: Error>(
        _ arguments: [String],
        allowed: Set<String>,
        unknown: @escaping (String) -> Failure,
        duplicate: @escaping (String) -> Failure,
        missingValue: @escaping (String) -> Failure
    ) throws -> [String: String] {
        var values: [String: String] = [:]
        var remaining = arguments.makeIterator()

        while let argument = remaining.next() {
            guard allowed.contains(argument) else {
                throw unknown(argument)
            }
            guard values[argument] == nil else {
                throw duplicate(argument)
            }
            guard let value = remaining.next(), !value.hasPrefix("--") else {
                throw missingValue(argument)
            }
            values[argument] = value
        }
        return values
    }
}
