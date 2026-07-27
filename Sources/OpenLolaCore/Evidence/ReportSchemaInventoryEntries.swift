// Collects measurement evidence evidence, report values, and verdict context so serialized results retain the fields required for review and validation.
extension ReportSchemaInventory {
    public static let entries: [ReportSchemaInventoryEntry] =
        entriesPart1 +
        entriesPart2 +
        entriesPart3 +
        entriesPart4
}
