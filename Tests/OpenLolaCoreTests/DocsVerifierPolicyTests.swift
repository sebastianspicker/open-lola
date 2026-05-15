import Foundation
import Testing

@Test
func docsVerifierLoadsArchiveTopologyFromManifest() throws {
    let constants = try readDocsVerifierText("scripts/verify_docs/constants.py")
    let topology = try sectionedDocsManifest("scripts/verify_docs/archive_topology.txt")
    let archiveTopology = try #require(topology["archive-topology"])
    let ignorePrefixes = try #require(topology["doc-ignore-prefix"])

    #expect(constants.contains("archive_topology.txt"))
    #expect(constants.contains("ARCHIVED_TOPOLOGY_PATHS = _manifest_section"))
    #expect(!constants.contains("\"archive/2026-05-05-doc-consolidation/docs/historical\""))
    #expect(archiveTopology.contains("archive/2026-05-05-doc-consolidation/docs/historical"))
    #expect(ignorePrefixes.contains("archive/2026-05-10-superseded-plans-audits-goals/generated/re_out"))
}

@Test
func docsArchiveInventoryDiscoversArchiveReadmeEntriesWithoutCodeChanges() throws {
    let temporaryRoot = FileManager.default.temporaryDirectory
        .appendingPathComponent("open-lola-archive-inventory-\(UUID().uuidString)")
    let archiveRoot = temporaryRoot.appendingPathComponent("archive")
    try FileManager.default.createDirectory(
        at: archiveRoot.appendingPathComponent("2099-01-02-synthetic-docs"),
        withIntermediateDirectories: true
    )
    defer {
        try? FileManager.default.removeItem(at: temporaryRoot)
    }

    try """
    # Archive

    ## Archive Sets

    | Folder | Purpose |
    |---|---|
    | [2099-01-02-synthetic-docs/](2099-01-02-synthetic-docs/) | Synthetic archive set for inventory derivation tests. |
    | [2099-01-03-handoff/](2099-01-03-handoff/root/PROGRESS.md) | Synthetic handoff file for inventory derivation tests. |
    """.write(
        to: archiveRoot.appendingPathComponent("README.md"),
        atomically: true,
        encoding: .utf8
    )
    try Data().write(to: archiveRoot
        .appendingPathComponent("2099-01-02-synthetic-docs/README.md"))

    let probe = temporaryRoot.appendingPathComponent("archive_probe.py")
    try """
    from pathlib import Path
    from scripts.verify_docs.archive_inventory import archive_doc_patterns, archive_roots

    root = Path.cwd()
    for value in archive_doc_patterns(root):
        print(f"doc:{value}")
    for value in archive_roots(root):
        print(f"root:{value}")
    """.write(to: probe, atomically: true, encoding: .utf8)

    let result = try runShell(
        in: temporaryRoot,
        environment: ["PYTHONPATH": docsVerifierRepositoryRoot.path],
        arguments: [
            "-c",
            "PYTHONDONTWRITEBYTECODE=1 python3 archive_probe.py",
        ]
    )
    #expect(result.status == 0)
    #expect(result.output.contains("doc:archive/2099-01-02-synthetic-docs/README.md"))
    #expect(result.output.contains("doc:archive/2099-01-03-handoff/root/PROGRESS.md"))
    #expect(result.output.contains("root:archive/2099-01-02-synthetic-docs"))
    #expect(result.output.contains("root:archive/2099-01-03-handoff"))
}

@Test
func docsVerifierRejectsAmbiguousTopLevelArchiveCopyFiles() throws {
    let temporaryRoot = FileManager.default.temporaryDirectory
        .appendingPathComponent("open-lola-archive-copy-\(UUID().uuidString)")
    let archiveRoot = temporaryRoot.appendingPathComponent("archive")
    try FileManager.default.createDirectory(at: archiveRoot, withIntermediateDirectories: true)
    defer {
        try? FileManager.default.removeItem(at: temporaryRoot)
    }

    try Data().write(to: archiveRoot.appendingPathComponent("plan copy.md"))
    try FileManager.default.createDirectory(
        at: archiveRoot.appendingPathComponent("2099-01-02-archive-set"),
        withIntermediateDirectories: true
    )
    try Data().write(
        to: archiveRoot.appendingPathComponent("2099-01-02-archive-set/plan copy.md")
    )

    let probe = temporaryRoot.appendingPathComponent("archive_copy_probe.py")
    try """
    from pathlib import Path
    from scripts.verify_docs.markdown_checks import check_archive_top_level_copy_files

    for error in check_archive_top_level_copy_files(Path.cwd()):
        print(error)
    """.write(to: probe, atomically: true, encoding: .utf8)

    let result = try runShell(
        in: temporaryRoot,
        environment: ["PYTHONPATH": docsVerifierRepositoryRoot.path],
        arguments: [
            "-c",
            "PYTHONDONTWRITEBYTECODE=1 python3 archive_copy_probe.py",
        ]
    )
    #expect(result.status == 0)
    #expect(result.output.contains("archive/plan copy.md: ambiguous top-level archive copy file"))
    #expect(!result.output.contains("2099-01-02-archive-set/plan copy.md"))
}

private var docsVerifierRepositoryRoot: URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
}

private struct ShellResult {
    let status: Int32
    let output: String
}

private func readDocsVerifierText(_ relativePath: String) throws -> String {
    let url = docsVerifierRepositoryRoot.appendingPathComponent(relativePath)
    return try String(contentsOf: url, encoding: .utf8)
}

private func sectionedDocsManifest(_ relativePath: String) throws -> [String: [String]] {
    let text = try readDocsVerifierText(relativePath)
    var result: [String: [String]] = [:]
    var activeSection: String?

    for rawLine in text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init) {
        let line = rawLine.trimmingCharacters(in: .whitespaces)
        if line.isEmpty || line.hasPrefix("#") {
            continue
        }
        if line.hasPrefix("[") && line.hasSuffix("]") {
            let section = String(line.dropFirst().dropLast())
            activeSection = section
            result[section, default: []] = []
            continue
        }
        if let activeSection {
            result[activeSection, default: []].append(line)
        }
    }
    return result
}

private func runShell(
    in workingDirectory: URL,
    environment: [String: String],
    arguments: [String]
) throws -> ShellResult {
    let process = Process()
    let outputPipe = Pipe()
    let errorPipe = Pipe()

    process.executableURL = URL(fileURLWithPath: "/bin/bash")
    process.currentDirectoryURL = workingDirectory
    process.arguments = arguments
    process.environment = ProcessInfo.processInfo.environment.merging(environment) { _, new in new }
    process.standardOutput = outputPipe
    process.standardError = errorPipe

    try process.run()
    process.waitUntilExit()

    var combinedOutput = outputPipe.fileHandleForReading.readDataToEndOfFile()
    let errorOutput = errorPipe.fileHandleForReading.readDataToEndOfFile()
    combinedOutput.append(errorOutput)
    let output = String(decoding: combinedOutput, as: UTF8.self)
    return ShellResult(status: process.terminationStatus, output: output)
}
