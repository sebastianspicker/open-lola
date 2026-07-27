// Joins the two source-ownership row tables, keeping the public inventory ordering explicit while each table stays below size limits.
import Foundation

extension SourceOwnershipInventory {
    public static let entries: [SourceOwnershipEntry] = entriesPart1 + entriesPart2
}
