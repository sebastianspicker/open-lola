// Builds and inspects staged release candidates for required paths, exclusions, and exported hygiene gates.
import Foundation
import Testing

enum ReleaseArtifactHygieneSupport {}

extension ReleaseArtifactHygieneSupport {
  static func makeTemporaryDirectory(named prefix: String) throws -> URL {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(
      "\(prefix)-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    return root
  }

  static func verifyReleaseCandidateExport(to temporaryRoot: URL) throws -> CommandResult {
    let exportResult = try runBashScript(
      environment: ["OPEN_LOLA_ALLOW_DIRTY_INSPECTION": "1"],
      ["scripts/export-release-candidate.sh", temporaryRoot.path]
    )
    #expect(exportResult.status == 0)
    #expect(exportResult.output.contains("== release hygiene candidate scan:"))
    #expect(exportResult.output.contains("product release readiness remains PARTIAL"))
    #expect(exportResult.output.contains("RELEASE_HYGIENE_VERDICT: PASS"))
    #expect(!exportResult.output.containsLine("HYGIENE_VERDICT: PASS"))
    #expect(exportResult.output.contains("RELEASE_CANDIDATE_EXPORT_VERDICT: PASS"))
    #expect(exportResult.output.contains("SOURCE_PROVENANCE_VERDICT:"))
    #expect(!exportResult.output.contains("\nVERDICT: PASS"))
    return exportResult
  }

  static func releaseCandidatePath(from exportResult: CommandResult) throws -> String {
    let candidatePrefix = "release candidate staged at: "
    let candidateLine = try #require(
      exportResult.output
        .split(separator: "\n")
        .map(String.init)
        .first { $0.hasPrefix(candidatePrefix) })
    return String(candidateLine.dropFirst(candidatePrefix.count))
  }

  static func verifyReleaseCandidateDirectory(at candidatePath: String) throws {
    var isDirectory = ObjCBool(false)
    #expect(FileManager.default.fileExists(atPath: candidatePath, isDirectory: &isDirectory))
    #expect(isDirectory.boolValue)
  }

  static func verifyReleaseCandidateIncludedPaths(at candidatePath: String) {
    for includedPath in releaseCandidateIncludedPaths {
      #expect(
        FileManager.default.fileExists(
          atPath: URL(fileURLWithPath: candidatePath).appendingPathComponent(includedPath).path))
    }
  }

  static func verifyReleaseCandidateExcludedPaths(at candidatePath: String) {
    for excludedPath in releaseCandidateExcludedPaths {
      #expect(
        !FileManager.default.fileExists(
          atPath: URL(fileURLWithPath: candidatePath).appendingPathComponent(excludedPath).path))
    }
  }

  static func verifyExportedCandidateHygieneAndDocs(at candidatePath: String) throws {
    let hygieneResult = try runBashScript(
      "scripts/verify-release-hygiene.sh",
      candidatePath
    )
    #expect(hygieneResult.status == 0)
    #expect(hygieneResult.output.contains("RELEASE_HYGIENE_VERDICT: PASS"))
    #expect(!hygieneResult.output.containsLine("HYGIENE_VERDICT: PASS"))
    #expect(!hygieneResult.output.contains("\nVERDICT: PASS"))

    let docsResult = try runBashScript(
      in: URL(fileURLWithPath: candidatePath),
      "scripts/verify-docs.sh"
    )
    #expect(docsResult.status == 0)
    #expect(docsResult.output.contains("public documentation only"))
    #expect(docsResult.output.contains("Documentation verification passed."))
  }

  static let releaseCandidateIncludedPaths = [
    "RELEASE_STATUS.md",
    "archive/README.md",
    ".github/workflows/release-readiness.yml",
    ".github/ISSUE_TEMPLATE/bug-report.yml",
    ".github/ISSUE_TEMPLATE/interoperability-evidence.yml",
    ".github/assets/OpenLoLa.icns",
    ".github/assets/open-lola-app-icon.svg",
    ".github/assets/open-lola-mark-light.svg",
    ".github/assets/open-lola-mark-dark.svg",
    ".github/assets/open-lola-social-preview.svg",
    ".github/assets/open-lola-social-preview.png",
    ".github/assets/open-lola-signal-desk-light.png",
    ".github/assets/open-lola-signal-desk-dark.png",
    "CONTRIBUTING.md",
    "SECURITY.md",
    "CODE_OF_CONDUCT.md",
    "SUPPORT.md",
    "CHANGELOG.md",
    "Package.swift",
    ".python-version",
    "pyproject.toml",
    "Sources",
    "Tests",
    "Tests/OpenLolaCoreTests/Fixtures",
    "linux_connector",
    "linux_connector/tests",
    "scripts",
    "scripts/macos/build_and_run.sh",
    "scripts/macos/build_cli_app_bundle.sh",
    "scripts/macos/generate_brand_assets.sh",
    "scripts/macos/render_svg.swift",
    "scripts/macos/build_icns.swift",
    "docs",
    "docs/README.md",
    "docs/current-state.md",
    "docs/product.md",
    "docs/design-system.md",
    "docs/release-boundary.md",
    "docs/release-manifest.md",
    "docs/RELEASING.md",
    "docs/testing.md",
    "docs/source-contracts.md",
    "docs/reverse-engineering-boundary.md"
  ]

  static let releaseCandidateExcludedPaths = [
    ".build",
    "win-compiled",
    "private",
    "reverse-engineering",
    ".agents",
    ".claude",
    ".codex",
    ".codegraph",
    ".cursor",
    ".impeccable",
    ".serena",
    "AGENTS.md",
    "CLAUDE.md",
    "GEMINI.md",
    "docs/implementation-handoff.md",
    "docs/archive-binary-retention-proposal.md",
    "plan.md",
    "plan-draft.md",
    "plan-findings-ledger.md",
    "plan-status.md",
    "plan-remediation-ledger.md",
    "plan-remediation-status.md",
    "private/reports",
    "research/deprecated-research",
    "Sources/opus-1.5.2/.github",
    "Sources/opus-1.5.2/.gitlab-ci.yml",
    "Sources/opus-1.5.2/.gitmodules",
    "Sources/opus-1.5.2/autogen.sh",
    "Sources/opus-1.5.2/configure.ac",
    "Sources/opus-1.5.2/scripts",
    "Sources/opus-1.5.2/tests",
    "Sources/opus-1.5.2/training",
    "Sources/opus-1.5.2/dnn",
    "Sources/xs_ref_sw_ed2/programs",
    "Sources/xs_ref_sw_ed2/extras",
    "docs/architecture",
    "docs/compliance",
    "docs/diagrams",
    "docs/mac-port",
    "docs/reverse-engineering",
    "docs/source-contracts",
    "docs/testing"
  ]

  static func verifyTrackedBoundary() throws {
    let result = try runBashScript("scripts/verify-tracked-boundary.sh")
    #expect(result.status == 0)
    #expect(result.output.contains("TRACKED_BOUNDARY_VERDICT: PASS"))
  }

  static func verifyExportedCandidateTrackedBoundaryFailsClosed(at candidatePath: String) throws {
    let result = try runBashScript(
      in: URL(fileURLWithPath: candidatePath),
      "scripts/verify-tracked-boundary.sh"
    )
    #expect(result.status != 0)
    #expect(result.output.contains("requires a Git worktree"))
    #expect(!result.output.contains("TRACKED_BOUNDARY_VERDICT: PASS"))
  }

  static func verifyReleaseReadinessTimeoutBudget(workflow: String, script: String) throws {
    let timeoutMinutes = try workflowTimeoutMinutes(in: workflow)
    let requiredSeconds =
      try scriptDefaultSeconds("SWIFT_BUILD_TIMEOUT_SECONDS", in: script)
      + scriptDefaultSeconds("SWIFT_TEST_TIMEOUT_SECONDS", in: script)
      + scriptDefaultSeconds("APP_LAUNCH_TIMEOUT_SECONDS", in: script)
    #expect(timeoutMinutes * 60 >= requiredSeconds)
  }

  static func verifyPublicDocumentationContract() throws {
    let result = try runBashScript(
      "-c",
      """
      PYTHONDONTWRITEBYTECODE=1 python3 -m scripts.verify_docs
      """
    )
    #expect(result.status == 0)
    #expect(result.output.contains("Documentation verification passed."))
  }

  static func verifyPythonToolingManifest(
    manifest: String,
    pythonVersion: String,
    workflow: String
  ) throws {
    let devDependencies = try pyprojectOptionalDependencies(named: "dev", in: manifest)
    let pcapDependencies = try pyprojectOptionalDependencies(named: "pcap", in: manifest)
    let syncRun = try workflowRunStep(named: "Sync Python verification tools", in: workflow)
    let lowerBoundSync = try workflowRunStep(
      named: "Sync lower-bound Python environment",
      in: workflow
    )
    let lowerBoundAssert = try workflowRunStep(
      named: "Assert lower-bound Python interpreter",
      in: workflow
    )
    let lowerBoundRun = try workflowRunStep(
      named: "Run Python 3.11 verification",
      in: workflow
    )

    verifyPythonManifestMetadata(
      manifest: manifest,
      pythonVersion: pythonVersion,
      devDependencies: devDependencies,
      pcapDependencies: pcapDependencies
    )
    verifyPythonWorkflow(
      workflow: workflow,
      syncRun: syncRun,
      lowerBoundSync: lowerBoundSync,
      lowerBoundAssert: lowerBoundAssert,
      lowerBoundRun: lowerBoundRun
    )
  }

  private static func verifyPythonManifestMetadata(
    manifest: String,
    pythonVersion: String,
    devDependencies: [String],
    pcapDependencies: [String]
  ) {
    #expect(manifest.contains("[project]"))
    #expect(manifest.contains("requires-python = \">=3.11\""))
    #expect(manifest.contains("required-version = \"==0.10.7\""))
    #expect(pythonVersion.trimmingCharacters(in: .whitespacesAndNewlines) == "3.14.6")
    #expect(
  devDependencies == [
  "mypy==1.14.1", "pytest>=9.1,<10", "ruff>=0.11,<1"
  ])
    #expect(pcapDependencies == ["scapy>=2.6,<3"])
    #expect(devDependencies.allSatisfy(isBoundedPythonToolDependency))
    #expect(pcapDependencies.allSatisfy(isBoundedPythonToolDependency))
    #expect(manifest.contains("testpaths = [\"linux_connector/tests\"]"))
    #expect(manifest.contains("pythonpath = [\".\"]"))
    #expect(!manifest.contains("pytest-asyncio"))
    #expect(!manifest.contains("open-lola = \"linux_connector.lola_connector.cli:main\""))
  }

  private static func verifyPythonWorkflow(
    workflow: String,
    syncRun: String,
    lowerBoundSync: String,
    lowerBoundAssert: String,
    lowerBoundRun: String
  ) {
    #expect(workflow.contains("astral-sh/setup-uv@08807647e7069bb48b6ef5acd8ec9567f424441b"))
    #expect(workflow.contains("[[ \"$(uv --version)\" == \"uv 0.10.7\"* ]]"))
    #expect(workflow.contains("python_path=\"$(uv python find 3.14.6)\""))
    #expect(workflow.contains("python-version: \"3.14.6\""))
    #expect(workflow.contains("python-311:"))
    #expect(workflow.contains("python-version: \"3.11\""))
    #expect(lowerBoundSync.contains("uv sync --python 3.11 --locked --extra dev"))
    #expect(lowerBoundAssert.contains("uv run --python 3.11"))
    #expect(lowerBoundAssert.contains("[[ \"$python_version\" == \"Python 3.11.\"* ]]"))
    #expect(
      lowerBoundRun.components(separatedBy: "uv run --python 3.11").count - 1 == 4
    )
    #expect(workflow.contains("UV_PROJECT_ENVIRONMENT: ${{ runner.temp }}/open-lola-uv-env"))
    #expect(syncRun.contains("uv sync --locked --extra dev"))
    #expect(!syncRun.contains("pytest>="))
    #expect(!syncRun.contains("ruff>="))
  }

  static func verifyPythonToolingDocumented(in matrix: String) {
    #expect(matrix.contains("ruff check linux_connector scripts/verify_docs scripts/lib/*.py"))
    #expect(matrix.contains("python -m pytest -p no:cacheprovider linux_connector"))
    #expect(
      matrix.contains(
        "python -m mypy --strict linux_connector/lola_connector scripts/verify_docs scripts/lib/*.py")
    )
    #expect(matrix.contains("[project.optional-dependencies].dev"))
  }
}
