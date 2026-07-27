// Verifies that production sources do not ship synthetic placeholder metrics or manual follow-up evidence.
import Foundation
import Testing

@Test
func productionSourcesDoNotShipSyntheticPlaceholderMetricsOrManualTodoEvidence() throws {
    let root = repositoryRootForProductionEvidencePolicy()
    let sourceRoot = root.appendingPathComponent("Sources", isDirectory: true)
    let forbiddenPatterns = [
        ProductionEvidenceForbiddenPattern(
            label: "SyntheticPlaceholderMetrics",
            matches: { $0.contains("SyntheticPlaceholderMetrics") }
        ),
        ProductionEvidenceForbiddenPattern(
            label: "todo(human)",
            matches: { $0.lowercased().contains("todo(human)") }
        )
    ]

    let violations = try productionEvidencePolicySwiftFiles(at: sourceRoot)
        .flatMap { file -> [String] in
            let text = try String(contentsOf: file, encoding: .utf8)
            let relative = productionEvidencePolicyRelativePath(file, root: root)
            return forbiddenPatterns.compactMap { pattern in
                pattern.matches(text) ? "\(relative): \(pattern.label)" : nil
            }
        }
        .sorted()

    if !violations.isEmpty {
        throw ProductionEvidencePlaceholderPolicyError(violations)
    }
}

private struct ProductionEvidenceForbiddenPattern {
    let label: String
    let matches: (String) -> Bool
}

private struct ProductionEvidencePlaceholderPolicyError: Error, CustomStringConvertible {
    let violations: [String]

    init(_ violations: [String]) {
        self.violations = violations
    }

    var description: String {
        "Production source evidence placeholders remain:\n" + violations.joined(separator: "\n")
    }
}

private func productionEvidencePolicySwiftFiles(at root: URL) throws -> [URL] {
    guard let enumerator = FileManager.default.enumerator(
        at: root,
        includingPropertiesForKeys: [.isRegularFileKey],
        options: [.skipsHiddenFiles]
    ) else {
        return []
    }

    return try enumerator.compactMap { item in
        guard let url = item as? URL,
              url.pathExtension == "swift",
              !productionEvidencePolicyIsVendoredSource(url) else {
            return nil
        }
        let values = try url.resourceValues(forKeys: [.isRegularFileKey])
        return values.isRegularFile == true ? url : nil
    }
}

private func productionEvidencePolicyIsVendoredSource(_ url: URL) -> Bool {
    let path = url.standardizedFileURL.path
    return path.contains("/Sources/opus-1.5.2/")
        || path.contains("/Sources/xs_ref_sw_ed2/")
}

private func repositoryRootForProductionEvidencePolicy() -> URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
}

private func productionEvidencePolicyRelativePath(_ file: URL, root: URL) -> String {
    let rootPath = root.standardizedFileURL.path + "/"
    let path = file.standardizedFileURL.path
    guard path.hasPrefix(rootPath) else {
        return path
    }
    return String(path.dropFirst(rootPath.count))
}
