import Foundation
import Testing

private let maximumGeneralCodeLines = 720
private let maximumNativeSupportLines = 220
private let maximumReleaseConfigLines = 120
private let exceptionLedgerRelativePath = "scripts/code-line-budget-exceptions.txt"

@Test
func scopedCodeFilesStayWithinLineBudget() throws {
    let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    let scopedPaths = [
        root.appendingPathComponent("Package.swift"),
        root.appendingPathComponent("Sources"),
        root.appendingPathComponent("Tests"),
        root.appendingPathComponent("scripts"),
        root.appendingPathComponent("script"),
        root.appendingPathComponent("linux_connector"),
        root.appendingPathComponent("private"),
        root.appendingPathComponent(".github"),
    ]
    let exceptions = try lineBudgetExceptions(root: root)

    let oversizedFiles = try scopedPaths.flatMap { path in
        try codeFiles(at: path)
    }
    .map { path in
        (
            path: path,
            lineCount: try physicalLineCount(at: path),
            budget: try #require(lineBudget(for: path, root: root, exceptions: exceptions))
        )
    }
    .filter { item in
        item.lineCount > item.budget
    }
    .sorted { left, right in
        if left.lineCount == right.lineCount {
            return left.path.path < right.path.path
        }
        return left.lineCount > right.lineCount
    }

    var violations = oversizedFiles.map { item in
        "\(item.lineCount)/\(item.budget) \(relativePath(item.path, root: root))"
    }
    violations.append(contentsOf: try staleExceptionViolations(exceptions, root: root))

    if !violations.isEmpty {
        throw CodeLineBudgetError(
            violations
        )
    }
}

private struct CodeLineBudgetError: Error, CustomStringConvertible {
    let files: [String]

    init(_ files: [String]) {
        self.files = files
    }

    var description: String {
        "Files exceed per-class LOC budgets:\n" + files.joined(separator: "\n")
    }
}

private func codeFiles(at path: URL) throws -> [URL] {
    var isDirectory: ObjCBool = false
    guard FileManager.default.fileExists(atPath: path.path, isDirectory: &isDirectory) else {
        return []
    }

    if !isDirectory.boolValue {
        return baseLineBudget(for: path) == nil ? [] : [path]
    }

    guard let enumerator = FileManager.default.enumerator(
        at: path,
        includingPropertiesForKeys: [.isRegularFileKey],
        options: [.skipsHiddenFiles]
    ) else {
        return []
    }

    return try enumerator.compactMap { item in
        guard let url = item as? URL else {
            return nil
        }
        if isThirdPartyVendorPath(url) {
            return nil
        }
        if url.pathComponents.contains("__pycache__") {
            return nil
        }
        let resourceValues = try url.resourceValues(forKeys: [.isRegularFileKey])
        guard resourceValues.isRegularFile == true,
              baseLineBudget(for: url) != nil else {
            return nil
        }
        return url
    }
}

private func lineBudget(
    for path: URL,
    root: URL,
    exceptions: [String: LineBudgetException]
) -> Int? {
    let baseBudget = baseLineBudget(for: path)
    let relative = relativePath(path, root: root)
    return exceptions[relative]?.maximumLines ?? baseBudget
}

private func baseLineBudget(for path: URL) -> Int? {
    if path.lastPathComponent == "Dockerfile" {
        return maximumReleaseConfigLines
    }

    switch path.pathExtension {
    case "swift", "py", "sh":
        return maximumGeneralCodeLines
    case "c", "h", "ps1":
        return maximumNativeSupportLines
    case "yml", "yaml":
        return maximumReleaseConfigLines
    default:
        return nil
    }
}

private struct LineBudgetException {
    let maximumLines: Int
}

private func lineBudgetExceptions(root: URL) throws -> [String: LineBudgetException] {
    let ledger = root.appendingPathComponent(exceptionLedgerRelativePath)
    let text = try String(contentsOf: ledger, encoding: .utf8)
    var exceptions: [String: LineBudgetException] = [:]

    for (lineIndex, rawLine) in text.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
        let line = rawLine.trimmingCharacters(in: .whitespaces)
        if line.isEmpty || line.hasPrefix("#") {
            continue
        }
        let fields = line.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
        guard fields.count == 3,
              let maximumLines = Int(fields[1]),
              maximumLines > maximumGeneralCodeLines,
              !fields[0].isEmpty,
              !fields[2].isEmpty else {
            throw CodeLineBudgetError([
                "\(exceptionLedgerRelativePath):\(lineIndex + 1): invalid exception row"
            ])
        }
        if exceptions.updateValue(LineBudgetException(maximumLines: maximumLines), forKey: fields[0]) != nil {
            throw CodeLineBudgetError([
                "\(exceptionLedgerRelativePath):\(lineIndex + 1): duplicate exception row: \(fields[0])"
            ])
        }
    }
    return exceptions
}

private func staleExceptionViolations(
    _ exceptions: [String: LineBudgetException],
    root: URL
) throws -> [String] {
    try exceptions.compactMap { relativePath, exception in
        let path = root.appendingPathComponent(relativePath)
        guard FileManager.default.fileExists(atPath: path.path) else {
            return "stale exception for missing file: \(relativePath)"
        }
        guard let baseBudget = baseLineBudget(for: path) else {
            return "stale exception for non-code file: \(relativePath)"
        }
        let lineCount = try physicalLineCount(at: path)
        if lineCount <= baseBudget {
            return "stale exception below base budget: \(relativePath)"
        }
        if lineCount > exception.maximumLines {
            return "\(lineCount)/\(exception.maximumLines) \(relativePath)"
        }
        return nil
    }
    .sorted()
}

private func isThirdPartyVendorPath(_ path: URL) -> Bool {
    let standardizedPath = path.standardizedFileURL.path
    return standardizedPath.contains("/Sources/opus-1.5.2/")
        || standardizedPath.contains("/Sources/xs_ref_sw_ed2/")
}

private func physicalLineCount(at path: URL) throws -> Int {
    let data = try Data(contentsOf: path)
    return data.reduce(0) { count, byte in
        count + (byte == 10 ? 1 : 0)
    }
}

private func relativePath(_ path: URL, root: URL) -> String {
    let rootPath = root.standardizedFileURL.path + "/"
    let filePath = path.standardizedFileURL.path
    guard filePath.hasPrefix(rootPath) else {
        return filePath
    }
    return String(filePath.dropFirst(rootPath.count))
}
