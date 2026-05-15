import Foundation
import Testing

@Test
func validateCallTestsContainAssertionsOrExpectedFailureChecks() throws {
    let offenders = try discoverValidateTestsWithoutAssertions()

    #expect(offenders.isEmpty, "validate-bearing tests without assertions: \(offenders.joined(separator: ", "))")
}

private func discoverValidateTestsWithoutAssertions() throws -> [String] {
    let testRoot = repositoryRoot.appendingPathComponent("Tests/OpenLolaCoreTests")
    guard let enumerator = FileManager.default.enumerator(
        at: testRoot,
        includingPropertiesForKeys: [.isRegularFileKey],
        options: [.skipsHiddenFiles]
    ) else {
        return []
    }

    var offenders: [String] = []
    for case let url as URL in enumerator where url.pathExtension == "swift" {
        let values = try url.resourceValues(forKeys: [.isRegularFileKey])
        guard values.isRegularFile == true,
              url.lastPathComponent != "ValidateAssertionContractTests.swift" else {
            continue
        }

        let source = try String(contentsOf: url, encoding: .utf8)
        for test in testFunctionBlocks(in: source) {
            guard test.body.contains(".validate(") || test.body.contains(".validate()") else {
                continue
            }
            guard !containsAssertionOrExpectedFailure(in: test.body) else {
                continue
            }

            offenders.append("\(relativePath(url)):\(test.name)")
        }
    }
    return offenders.sorted()
}

private struct TestFunctionBlock {
    let name: String
    let body: Substring
}

private func testFunctionBlocks(in source: String) -> [TestFunctionBlock] {
    let pattern = #"@Test(?:\([^)]*\))?\s*(?:@[A-Za-z0-9_]+(?:\([^)]*\))?\s*)*func\s+([A-Za-z0-9_]+)\s*\([^)]*\)\s*(?:async\s*)?(?:throws\s*)?\{"#
    guard let regex = try? NSRegularExpression(pattern: pattern) else {
        return []
    }

    let nsRange = NSRange(source.startIndex..<source.endIndex, in: source)
    return regex.matches(in: source, range: nsRange).compactMap { match in
        guard let nameRange = Range(match.range(at: 1), in: source),
              let openBraceRange = Range(match.range, in: source),
              let bodyEnd = closingBraceIndex(in: source, from: source.index(before: openBraceRange.upperBound)) else {
            return nil
        }

        return TestFunctionBlock(
            name: String(source[nameRange]),
            body: source[openBraceRange.upperBound..<bodyEnd]
        )
    }
}

private func closingBraceIndex(in source: String, from openBrace: String.Index) -> String.Index? {
    var depth = 0
    var index = openBrace

    while index < source.endIndex {
        switch source[index] {
        case "{":
            depth += 1
        case "}":
            depth -= 1
            if depth == 0 {
                return index
            }
        default:
            break
        }
        index = source.index(after: index)
    }
    return nil
}

private func containsAssertionOrExpectedFailure(in body: Substring) -> Bool {
    body.contains("#expect")
        || body.contains("#require")
        || body.contains("withKnownIssue")
        || body.contains("confirmation(")
}

private var repositoryRoot: URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
}

private func relativePath(_ url: URL) -> String {
    let rootPath = repositoryRoot.standardizedFileURL.path + "/"
    let filePath = url.standardizedFileURL.path
    guard filePath.hasPrefix(rootPath) else {
        return filePath
    }
    return String(filePath.dropFirst(rootPath.count))
}
