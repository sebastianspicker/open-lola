import Foundation
import Testing

@Test
func swiftTestingTopLevelTestFunctionsCarryTestAttribute() throws {
    let testRoot = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
    let swiftFiles = try swiftTestFiles(under: testRoot)
    let missingAttributes = try swiftFiles.flatMap { try topLevelTestFunctionsMissingTestAttribute(in: $0) }

    #expect(missingAttributes == [])
}

private func swiftTestFiles(under root: URL) throws -> [URL] {
    let enumerator = FileManager.default.enumerator(
        at: root,
        includingPropertiesForKeys: [.isRegularFileKey],
        options: [.skipsHiddenFiles]
    )
    let urls = enumerator?.compactMap { $0 as? URL } ?? []
    return try urls.filter { url in
        guard url.pathExtension == "swift" else { return false }
        let values = try url.resourceValues(forKeys: [.isRegularFileKey])
        return values.isRegularFile == true
    }
}

private func topLevelTestFunctionsMissingTestAttribute(in file: URL) throws -> [String] {
    let allowedHelperFunctions = Set([
        "bpfTestRecord",
        "directPeerAVSupportConfiguration",
        "measuredPassReceiveProof",
        "measuredPassVideoFormat",
        "readLoLaMediaSessionSource",
    ])
    let text = try String(contentsOf: file, encoding: .utf8)
    let lines = text.components(separatedBy: .newlines)
    var missingAttributes: [String] = []

    for (index, line) in lines.enumerated() {
        guard line.hasPrefix("func ") else { continue }
        if file.lastPathComponent.contains("TestSupport") {
            continue
        }
        if let name = functionName(fromDeclarationLine: line), allowedHelperFunctions.contains(name) {
            continue
        }
        guard !previousCodeLineBefore(lines, index: index).starts(with: "@Test") else { continue }

        missingAttributes.append("\(file.lastPathComponent):\(index + 1): \(line)")
    }

    return missingAttributes
}

private func functionName(fromDeclarationLine line: String) -> String? {
    guard let nameStart = line.dropFirst("func ".count).split(separator: "(").first else {
        return nil
    }
    return String(nameStart.trimmingCharacters(in: .whitespaces))
}

private func previousCodeLineBefore(_ lines: [String], index: Int) -> String {
    guard index > 0 else { return "" }

    for lineIndex in stride(from: index - 1, through: 0, by: -1) {
        let trimmed = lines[lineIndex].trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty {
            return trimmed
        }
    }

    return ""
}
