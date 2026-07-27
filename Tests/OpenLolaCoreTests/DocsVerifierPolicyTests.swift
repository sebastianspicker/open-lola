// Verifies that docs verifier uses public documentation only.
import Foundation
import Testing

@Test
func docsVerifierUsesPublicDocumentationOnly() throws {
    let result = try ReleaseArtifactHygieneSupport.runBashScript(
        in: ReleaseArtifactHygieneSupport.repositoryRoot,
        environment: [:],
        [
            "-c",
            """
            PYTHONDONTWRITEBYTECODE=1 python3 - <<'PY'
            from scripts.verify_docs.constants import DOC_PATTERNS

            for value in DOC_PATTERNS:
                print(f"doc:{value}")
            PY
            """
        ]
    )

    #expect(result.status == 0)
    #expect(result.output.contains("doc:*.md"))
    #expect(result.output.contains("doc:.github/**/*.md"))
    #expect(result.output.contains("doc:archive/README.md"))
    #expect(result.output.contains("doc:docs/**/*.md"))
    #expect(result.output.contains("doc:linux_connector/**/*.md"))
    #expect(result.output.contains("doc:scripts/README.md"))
    #expect(!result.output.contains("private/"))
    #expect(!result.output.contains("2026-"))
}

@Test
func docsArchiveInventoryExposesOnlyPublicBoundarySummary() throws {
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
    # Local Archive Boundary
    """.write(to: archiveRoot.appendingPathComponent("README.md"), atomically: true, encoding: .utf8)
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

    let result = try ReleaseArtifactHygieneSupport.runBashScript(
        in: temporaryRoot,
        environment: ["PYTHONPATH": ReleaseArtifactHygieneSupport.repositoryRoot.path],
        [
            "-c",
            "PYTHONDONTWRITEBYTECODE=1 python3 archive_probe.py"
        ]
    )
    #expect(result.status == 0)
    #expect(result.output == "doc:archive/README.md\n")
}

@Test
func docsVerifierAcceptsSourceLocations() throws {
    let temporaryRoot = FileManager.default.temporaryDirectory
        .appendingPathComponent("open-lola-doc-source-locations-\(UUID().uuidString)")
    try FileManager.default.createDirectory(
        at: temporaryRoot.appendingPathComponent("Sources"),
        withIntermediateDirectories: true
    )
    try FileManager.default.createDirectory(
        at: temporaryRoot.appendingPathComponent("Tests"),
        withIntermediateDirectories: true
    )
    try FileManager.default.createDirectory(
        at: temporaryRoot.appendingPathComponent("docs"),
        withIntermediateDirectories: true
    )
    defer {
        try? FileManager.default.removeItem(at: temporaryRoot)
    }

    try Data().write(to: temporaryRoot.appendingPathComponent("Sources/Example.swift"))
    try Data().write(to: temporaryRoot.appendingPathComponent("Tests/ExampleTests.swift"))
    try "# Audit\n\n- `Sources/Example.swift:1-3`\n- `Tests/ExampleTests.swift:7`\n".write(
        to: temporaryRoot.appendingPathComponent("docs/audit.md"),
        atomically: true,
        encoding: .utf8
    )

    try verifyDocsSourceLocations(at: temporaryRoot)
}

@Test
func docsVerifierAcceptsGeneratedResidueMentions() throws {
    let temporaryRoot = FileManager.default.temporaryDirectory
        .appendingPathComponent("open-lola-doc-generated-residue-\(UUID().uuidString)")
    try FileManager.default.createDirectory(
        at: temporaryRoot.appendingPathComponent("docs"),
        withIntermediateDirectories: true
    )
    defer {
        try? FileManager.default.removeItem(at: temporaryRoot)
    }

    try "# Audit\n\n- `scripts/verify_docs/__pycache__`\n".write(
        to: temporaryRoot.appendingPathComponent("docs/audit.md"),
        atomically: true,
        encoding: .utf8
    )

    try verifyDocsSourceLocations(at: temporaryRoot)
}

private func verifyDocsSourceLocations(at temporaryRoot: URL) throws {
    let probe = temporaryRoot.appendingPathComponent("source_location_probe.py")
    try """
    from pathlib import Path
    from scripts.verify_docs.markdown_checks import check_backticked_source_paths

    errors = check_backticked_source_paths([Path.cwd() / "docs/audit.md"])
    for error in errors:
        print(error)
    raise SystemExit(1 if errors else 0)
    """.write(to: probe, atomically: true, encoding: .utf8)

    let result = try ReleaseArtifactHygieneSupport.runBashScript(
        in: temporaryRoot,
        environment: ["PYTHONPATH": ReleaseArtifactHygieneSupport.repositoryRoot.path],
        [
            "-c",
            "PYTHONDONTWRITEBYTECODE=1 python3 source_location_probe.py"
        ]
    )
    #expect(result.status == 0)
    #expect(result.output.isEmpty)
}
