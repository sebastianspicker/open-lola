import Foundation
import Testing

@Test
func vendoredSourceBoundaryMatchesSwiftPMManifestAndReleaseFence() throws {
    let package = try readText("Package.swift")

    let opusBlock = try packageTargetBlock(named: "COpus", in: package)
    let opusSources = Set(try stringArrayArgument("sources", in: opusBlock))
    let opusPublicHeaders = try stringArgument("publicHeadersPath", in: opusBlock)
    let opusHeaderSearchPaths = try headerSearchPaths(in: opusBlock)

    #expect(!opusSources.isEmpty)
    #expect(opusPublicHeaders == "openlola_bridge/include")
    #expect(opusHeaderSearchPaths == ["include", "celt", "silk", "silk/float", "src"])
    #expect(opusSources.contains("openlola_bridge/COpusBridge.c"))
    #expect(opusSources.contains("src/opus.c"))
    #expect(opusSources.contains("celt/celt.c"))
    #expect(opusSources.contains("silk/enc_API.c"))
    #expect(opusSources.allSatisfy { $0.hasSuffix(".c") })
    #expect(opusSources.allSatisfy { !isKnownOpusCollateralSource($0) })
    for source in opusSources {
        #expect(FileManager.default.fileExists(
            atPath: repositoryRoot
                .appendingPathComponent("Sources/opus-1.5.2")
                .appendingPathComponent(source)
                .path
        ), "missing COpus manifest source: \(source)")
    }
    for path in [
        "Sources/opus-1.5.2/COPYING",
        "Sources/opus-1.5.2/AUTHORS",
        "Sources/opus-1.5.2/README",
        "Sources/opus-1.5.2/openlola_bridge/COpusBridge.c",
        "Sources/opus-1.5.2/openlola_bridge/include/COpusBridge.h",
        "Sources/opus-1.5.2/include/opus.h",
    ] {
        #expect(FileManager.default.fileExists(
            atPath: repositoryRoot.appendingPathComponent(path).path
        ), "missing required COpus boundary path: \(path)")
    }

    let jxsBlock = try packageTargetBlock(named: "CJpegXSReference", in: package)
    let jxsPath = try stringArgument("path", in: jxsBlock)
    let jxsExcludes = Set(try stringArrayArgument("exclude", in: jxsBlock))
    let jxsPublicHeaders = try stringArgument("publicHeadersPath", in: jxsBlock)
    let jxsHeaderSearchPaths = try headerSearchPaths(in: jxsBlock)
    let jxsCompiledSources = Set(try relativeFiles(
        under: repositoryRoot.appendingPathComponent(jxsPath),
        matchingExtensions: ["c"]
    )).subtracting(jxsExcludes)

    #expect(jxsPath == "Sources/xs_ref_sw_ed2/libjxs")
    #expect(jxsExcludes == ["CMakeLists.txt", "src/msbpack.c"])
    #expect(jxsPublicHeaders == "public")
    #expect(jxsHeaderSearchPaths == ["src"])
    #expect(jxsCompiledSources.contains("src/open_lola_jxs_bridge.c"))
    #expect(jxsCompiledSources.contains("src/xs_enc.c"))
    #expect(jxsCompiledSources.contains("src/xs_dec.c"))
    #expect(!jxsCompiledSources.contains("src/msbpack.c"))
    for path in [
        "Sources/xs_ref_sw_ed2/LICENSE.md",
        "Sources/xs_ref_sw_ed2/README.md",
        "Sources/xs_ref_sw_ed2/libjxs/public/libjxs.h",
        "Sources/xs_ref_sw_ed2/libjxs/public/open_lola_jxs_bridge.h",
        "Sources/xs_ref_sw_ed2/libjxs/src/open_lola_jxs_bridge.c",
    ] {
        #expect(FileManager.default.fileExists(
            atPath: repositoryRoot.appendingPathComponent(path).path
        ), "missing required CJpegXSReference boundary path: \(path)")
    }
}

@Test
func releaseCandidatePreservesVendorFenceFilesAndExcludesCollateral() throws {
    let temporaryRoot = FileManager.default.temporaryDirectory
        .appendingPathComponent("open-lola-vendor-boundary-\(UUID().uuidString)")
    try FileManager.default.createDirectory(
        at: temporaryRoot,
        withIntermediateDirectories: true
    )
    defer {
        try? FileManager.default.removeItem(at: temporaryRoot)
    }

    let exportResult = try runBashScript(
        "scripts/export-release-candidate.sh",
        temporaryRoot.path
    )
    #expect(exportResult.status == 0)
    #expect(exportResult.output.contains("RELEASE_HYGIENE_VERDICT: PASS"))
    #expect(exportResult.output.contains("RELEASE_CANDIDATE_EXPORT_VERDICT: PASS"))

    let candidatePrefix = "release candidate staged at: "
    let candidateLine = try #require(exportResult.output
        .split(separator: "\n")
        .map(String.init)
        .first { $0.hasPrefix(candidatePrefix) })
    let candidateURL = URL(fileURLWithPath: String(candidateLine.dropFirst(candidatePrefix.count)))

    for path in [
        "Sources/opus-1.5.2/COPYING",
        "Sources/opus-1.5.2/AUTHORS",
        "Sources/opus-1.5.2/README",
        "Sources/opus-1.5.2/openlola_bridge/COpusBridge.c",
        "Sources/opus-1.5.2/openlola_bridge/include/COpusBridge.h",
        "Sources/xs_ref_sw_ed2/LICENSE.md",
        "Sources/xs_ref_sw_ed2/README.md",
        "Sources/xs_ref_sw_ed2/libjxs/public/libjxs.h",
        "Sources/xs_ref_sw_ed2/libjxs/public/open_lola_jxs_bridge.h",
        "Sources/xs_ref_sw_ed2/libjxs/src/open_lola_jxs_bridge.c",
    ] {
        #expect(FileManager.default.fileExists(
            atPath: candidateURL.appendingPathComponent(path).path
        ), "release candidate missing required vendor boundary path: \(path)")
    }

    for path in [
        "Sources/opus-1.5.2/.github",
        "Sources/opus-1.5.2/.gitlab-ci.yml",
        "Sources/opus-1.5.2/.gitmodules",
        "Sources/opus-1.5.2/autogen.sh",
        "Sources/opus-1.5.2/configure.ac",
        "Sources/opus-1.5.2/cmake",
        "Sources/opus-1.5.2/m4",
        "Sources/opus-1.5.2/meson",
        "Sources/opus-1.5.2/Makefile.am",
        "Sources/opus-1.5.2/opus_sources.mk",
        "Sources/opus-1.5.2/tests",
        "Sources/opus-1.5.2/training",
        "Sources/opus-1.5.2/dnn",
        "Sources/xs_ref_sw_ed2/CMakeLists.txt",
        "Sources/xs_ref_sw_ed2/libjxs/CMakeLists.txt",
        "Sources/xs_ref_sw_ed2/libjxs/src/msbpack.c",
        "Sources/xs_ref_sw_ed2/programs",
        "Sources/xs_ref_sw_ed2/extras",
        "Sources/xs_ref_sw_ed2/std",
    ] {
        #expect(!FileManager.default.fileExists(
            atPath: candidateURL.appendingPathComponent(path).path
        ), "release candidate retained uncompiled vendor collateral: \(path)")
    }
}

private var repositoryRoot: URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
}

private func readText(_ relativePath: String) throws -> String {
    let url = repositoryRoot.appendingPathComponent(relativePath)
    return try String(contentsOf: url, encoding: .utf8)
}

private func packageTargetBlock(named targetName: String, in text: String) throws -> String {
    guard let nameRange = text.range(of: "name: \"\(targetName)\"") else {
        throw VendoredBoundaryParsingError.missingPackageTarget(targetName)
    }
    let prefix = text[..<nameRange.lowerBound]
    guard let targetStart = prefix.range(of: ".target(", options: .backwards)?.lowerBound else {
        throw VendoredBoundaryParsingError.missingPackageTarget(targetName)
    }

    var depth = 0
    var sawOpening = false
    var index = targetStart
    while index < text.endIndex {
        let character = text[index]
        if character == "(" {
            depth += 1
            sawOpening = true
        } else if character == ")" {
            depth -= 1
            if sawOpening, depth == 0 {
                return String(text[targetStart..<text.index(after: index)])
            }
        }
        index = text.index(after: index)
    }

    throw VendoredBoundaryParsingError.unterminatedPackageTarget(targetName)
}

private func stringArrayArgument(_ label: String, in text: String) throws -> [String] {
    guard let labelRange = text.range(of: "\(label):") else {
        throw VendoredBoundaryParsingError.missingStringArray(label)
    }
    guard let opening = text.range(
        of: "[",
        range: labelRange.upperBound..<text.endIndex
    )?.lowerBound else {
        throw VendoredBoundaryParsingError.missingStringArray(label)
    }

    var depth = 0
    var index = opening
    while index < text.endIndex {
        let character = text[index]
        if character == "[" {
            depth += 1
        } else if character == "]" {
            depth -= 1
            if depth == 0 {
                let body = String(text[text.index(after: opening)..<index])
                return try regexCaptures(#""([^"]+)""#, in: body)
            }
        }
        index = text.index(after: index)
    }

    throw VendoredBoundaryParsingError.missingStringArray(label)
}

private func stringArgument(_ label: String, in text: String) throws -> String {
    let pattern = "\(NSRegularExpression.escapedPattern(for: label)):\\s*\"([^\"]+)\""
    let matches = try regexCaptures(pattern, in: text)
    guard let value = matches.first else {
        throw VendoredBoundaryParsingError.missingStringArgument(label)
    }
    return value
}

private func headerSearchPaths(in text: String) throws -> [String] {
    try regexCaptures(#"\.headerSearchPath\("([^"]+)"\)"#, in: text)
}

private func regexCaptures(_ pattern: String, in text: String) throws -> [String] {
    let regex = try NSRegularExpression(pattern: pattern)
    let range = NSRange(text.startIndex..<text.endIndex, in: text)
    return regex.matches(in: text, range: range).compactMap { match in
        guard let matchRange = Range(match.range(at: 1), in: text) else {
            return nil
        }
        return String(text[matchRange])
    }
}

private func relativeFiles(under root: URL, matchingExtensions extensions: Set<String>) throws -> [String] {
    let enumerator = try #require(FileManager.default.enumerator(
        at: root,
        includingPropertiesForKeys: [.isRegularFileKey],
        options: [.skipsHiddenFiles]
    ))
    let rootPath = root.path + "/"
    return try enumerator
        .compactMap { $0 as? URL }
        .filter { extensions.contains($0.pathExtension) }
        .map { url in
            guard url.path.hasPrefix(rootPath) else {
                throw VendoredBoundaryParsingError.pathOutsideRoot(url.path)
            }
            return String(url.path.dropFirst(rootPath.count))
        }
        .sorted()
}

private func isKnownOpusCollateralSource(_ source: String) -> Bool {
    [
        ".github/",
        "celt/tests/",
        "cmake/",
        "dnn/",
        "doc/",
        "m4/",
        "meson/",
        "silk/tests/",
        "tests/",
        "training/",
    ].contains { source.hasPrefix($0) }
}

private enum VendoredBoundaryParsingError: Error {
    case missingPackageTarget(String)
    case unterminatedPackageTarget(String)
    case missingStringArray(String)
    case missingStringArgument(String)
    case pathOutsideRoot(String)
}

private struct CommandResult {
    let status: Int32
    let output: String
}

private func runBashScript(_ arguments: String...) throws -> CommandResult {
    let process = Process()
    let outputPipe = Pipe()
    let errorPipe = Pipe()
    process.executableURL = URL(fileURLWithPath: "/bin/bash")
    process.currentDirectoryURL = repositoryRoot
    process.arguments = arguments
    process.environment = ProcessInfo.processInfo.environment
    process.standardOutput = outputPipe
    process.standardError = errorPipe

    try process.run()
    process.waitUntilExit()

    var combinedOutput = outputPipe.fileHandleForReading.readDataToEndOfFile()
    let errorOutput = errorPipe.fileHandleForReading.readDataToEndOfFile()
    combinedOutput.append(errorOutput)
    return CommandResult(
        status: process.terminationStatus,
        output: String(decoding: combinedOutput, as: UTF8.self)
    )
}
