// Exercises release-hygiene failures for generated residue, plan files, bytecode, and unapproved artifacts.
import Foundation
import Testing

extension ReleaseArtifactHygieneSupport {
  static func verifyLiveReleaseHygiene(at temporaryRoot: URL) throws {
    let cleanResult = try runBashScript(
      environment: ["OPEN_LOLA_RELEASE_HYGIENE_LIVE_ROOT": temporaryRoot.path],
      "scripts/verify-release-hygiene.sh"
    )
    #expect(cleanResult.status == 0)
    #expect(cleanResult.output.contains("release hygiene live checkout generated-residue scan"))
    #expect(cleanResult.output.contains("LIVE_RESIDUE_HYGIENE_VERDICT: PASS"))
    #expect(!cleanResult.output.containsLine("HYGIENE_VERDICT: PASS"))
    #expect(!cleanResult.output.contains("\nVERDICT: PASS"))

    let residuePaths = [
      ".venv",
      ".uv-cache",
      ".hypothesis",
      ".tox",
      ".nox",
      "sample.egg-info",
      "pip-wheel-metadata",
      ".cache",
    ]
    for (index, residuePath) in residuePaths.enumerated() {
      let contaminatedRoot = temporaryRoot.appendingPathComponent("residue-\(index)")
      try FileManager.default.createDirectory(
        at: contaminatedRoot.appendingPathComponent(residuePath),
        withIntermediateDirectories: true
      )
      let contaminatedResult = try runBashScript(
        environment: ["OPEN_LOLA_RELEASE_HYGIENE_LIVE_ROOT": contaminatedRoot.path],
        "scripts/verify-release-hygiene.sh"
      )
      #expect(contaminatedResult.status != 0)
      #expect(contaminatedResult.output.contains("live checkout contains forbidden generated artifact"))
      #expect(contaminatedResult.output.contains(residuePath))
    }
  }

  static func verifyCleanReleaseHygieneCandidate(under candidateRoot: URL) throws {
    let cleanCandidate = candidateRoot.appendingPathComponent("clean")
    try makeMinimalReleaseCandidate(at: cleanCandidate)

    let cleanCandidateResult = try runBashScript(
      "scripts/verify-release-hygiene.sh",
      cleanCandidate.path
    )
    #expect(cleanCandidateResult.status == 0)
    #expect(cleanCandidateResult.output.contains("RELEASE_HYGIENE_VERDICT: PASS"))
    #expect(!cleanCandidateResult.output.containsLine("HYGIENE_VERDICT: PASS"))
    #expect(!cleanCandidateResult.output.contains("\nVERDICT: PASS"))
  }

  static func verifyGeneratedResidueCandidateFailures(under candidateRoot: URL) throws {
    try verifyCandidateDirectoryResidue(
      under: candidateRoot, name: "contaminated", residuePath: ".codacy", expectedOutput: ".codacy")
    try verifyCandidateRootPlanResidue(under: candidateRoot)
    try verifyCandidateWorkflowPlanResidue(under: candidateRoot)
    try verifyCandidateArchivePayload(under: candidateRoot)
    try verifyCandidateBytecodeResidue(under: candidateRoot)
    try verifyCandidateDirectoryResidue(
      under: candidateRoot, name: "tool-cache", residuePath: ".ruff_cache",
      expectedOutput: ".ruff_cache")
    try verifyCandidateDirectoryResidue(
      under: candidateRoot, name: "design-tool-cache", residuePath: ".impeccable",
      expectedOutput: ".impeccable")
    try verifyCandidateDirectoryResidue(
      under: candidateRoot, name: "vendor-extra", residuePath: "Sources/opus-1.5.2/tests",
      expectedOutput: "Sources/opus-1.5.2/tests")
    try verifyCandidateUncompiledOpusHelper(under: candidateRoot)
    try verifyCandidateUnapprovedScreenshot(under: candidateRoot)
    try verifyCandidateUnselectedOpusSource(under: candidateRoot)
  }

  static func verifyCandidateDirectoryResidue(
    under candidateRoot: URL, name: String, residuePath: String, expectedOutput: String
  ) throws {
    let candidate = candidateRoot.appendingPathComponent(name)
    try makeMinimalReleaseCandidate(at: candidate)
    try FileManager.default.createDirectory(
      at: candidate.appendingPathComponent(residuePath), withIntermediateDirectories: true)
    try expectReleaseHygieneFailure(candidate, contains: expectedOutput)
  }

  static func verifyCandidateRootPlanResidue(under candidateRoot: URL) throws {
    let candidate = candidateRoot.appendingPathComponent("root-plan")
    try makeMinimalReleaseCandidate(at: candidate)
    try "# root plan\n".write(
      to: candidate.appendingPathComponent("plan.md"),
      atomically: true,
      encoding: .utf8
    )
    try expectReleaseHygieneFailure(candidate, contains: "plan.md")
  }

  static func verifyCandidateWorkflowPlanResidue(under candidateRoot: URL) throws {
    let candidate = candidateRoot.appendingPathComponent("workflow-plan")
    try makeMinimalReleaseCandidate(at: candidate)
    try "# release workflow plan\n".write(
      to: candidate.appendingPathComponent("docs/source-alpha-plan-draft.md"),
      atomically: true,
      encoding: .utf8
    )
    try expectReleaseHygieneFailure(candidate, contains: "source-alpha-plan-draft.md")
  }

  static func verifyCandidateArchivePayload(under candidateRoot: URL) throws {
    let candidate = candidateRoot.appendingPathComponent("archive-payload")
    try makeMinimalReleaseCandidate(at: candidate)
    let payload = candidate.appendingPathComponent("archive/local/notes.txt")
    try FileManager.default.createDirectory(
      at: payload.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    try "local only\n".write(to: payload, atomically: true, encoding: .utf8)
    try expectReleaseHygieneFailure(candidate, contains: "archive/local")
  }

  static func verifyCandidateBytecodeResidue(under candidateRoot: URL) throws {
    let candidate = candidateRoot.appendingPathComponent("bytecode")
    try makeMinimalReleaseCandidate(at: candidate)
    let pycache = candidate.appendingPathComponent("linux_connector/tests/__pycache__")
    try FileManager.default.createDirectory(at: pycache, withIntermediateDirectories: true)
    try Data([0x42]).write(to: pycache.appendingPathComponent("test_codec.cpython-313.pyc"))
    try expectReleaseHygieneFailure(candidate, containsAnyOf: ["__pycache__", ".pyc"])
  }

  static func verifyCandidateUnapprovedScreenshot(under candidateRoot: URL) throws {
    let candidate = candidateRoot.appendingPathComponent("unapproved-screenshot")
    try makeMinimalReleaseCandidate(at: candidate)
    let screenshot = candidate.appendingPathComponent(
      "linux_connector/docs/assets/historical-lab.png")
    try FileManager.default.createDirectory(
      at: screenshot.deletingLastPathComponent(), withIntermediateDirectories: true)
    try Data([0x89, 0x50, 0x4e, 0x47]).write(to: screenshot)
    try expectReleaseHygieneFailure(candidate, contains: "historical-lab.png")
  }

  static func verifyCandidateUnselectedOpusSource(under candidateRoot: URL) throws {
    let candidate = candidateRoot.appendingPathComponent("unselected-opus-source")
    try makeMinimalReleaseCandidate(at: candidate)
    let source = candidate.appendingPathComponent("Sources/opus-1.5.2/src/opus_demo.c")
    try FileManager.default.createDirectory(
      at: source.deletingLastPathComponent(), withIntermediateDirectories: true)
    try Data("int main(void) { return 0; }\n".utf8).write(to: source)
    try expectReleaseHygieneFailure(candidate, contains: "opus_demo.c")
  }

  static func verifyCandidateUncompiledOpusHelper(under candidateRoot: URL) throws {
    let candidate = candidateRoot.appendingPathComponent("uncompiled-opus-helper")
    try makeMinimalReleaseCandidate(at: candidate)
    let helper = candidate.appendingPathComponent("Sources/opus-1.5.2/scripts/local_build.py")
    try FileManager.default.createDirectory(
      at: helper.deletingLastPathComponent(), withIntermediateDirectories: true)
    try Data("print('not part of COpus')\n".utf8).write(to: helper)
    try expectReleaseHygieneFailure(candidate, contains: "local_build.py")
  }

  static func expectReleaseHygieneFailure(_ candidate: URL, contains expectedOutput: String) throws {
    try expectReleaseHygieneFailure(candidate, containsAnyOf: [expectedOutput])
  }

  static func expectReleaseHygieneFailure(_ candidate: URL, containsAnyOf expectedOutputs: [String])
    throws {
    let result = try runBashScript("scripts/verify-release-hygiene.sh", candidate.path)
    #expect(result.status != 0)
    #expect(result.output.contains("forbidden generated/internal/vendor artifact"))
    #expect(expectedOutputs.contains { result.output.contains($0) })
  }

  static var repositoryRoot: URL {
    URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
  }

  struct CommandResult {
    let status: Int32
    let output: String
  }

  static func readText(_ relativePath: String) throws -> String {
    let url = repositoryRoot.appendingPathComponent(relativePath)
    return try String(contentsOf: url, encoding: .utf8)
  }

  static func releaseBoundaryPolicy() throws -> [String: [String]] {
    try sectionedManifest("scripts/release-boundary-policy.txt")
  }

  static func sectionedManifest(_ relativePath: String) throws -> [String: [String]] {
    let text = try readText(relativePath)
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
  static func pyprojectOptionalDependencies(named group: String, in text: String) throws -> [String] {
    let lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
    let header = "\(group) = ["
    guard
      let startIndex = lines.firstIndex(where: { $0.trimmingCharacters(in: .whitespaces) == header })
    else {
      throw TestParsingError.missingPyprojectGroup(group)
    }

    var dependencies: [String] = []
    for line in lines[(startIndex + 1)...] {
      let trimmed = line.trimmingCharacters(in: .whitespaces)
      if trimmed == "]" {
        return dependencies
      }
      guard trimmed.hasPrefix("\""), trimmed.hasSuffix("\",") else {
        continue
      }
      dependencies.append(String(trimmed.dropFirst().dropLast(2)))
    }
    throw TestParsingError.missingPyprojectGroupTerminator(group)
  }

  static func isBoundedPythonToolDependency(_ dependency: String) -> Bool {
    dependency.contains("==") || (dependency.contains(">=") && dependency.contains(",<"))
  }

  static func workflowRunStep(named stepName: String, in text: String) throws -> String {
    let lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
    guard
      let stepIndex = lines.firstIndex(where: {
        $0.trimmingCharacters(in: .whitespaces) == "- name: \(stepName)"
      })
    else {
      throw TestParsingError.missingWorkflowStep(stepName)
    }

    var runLines: [String] = []
    var foundRun = false
    for line in lines[(stepIndex + 1)...] {
      let trimmed = line.trimmingCharacters(in: .whitespaces)
      if trimmed.hasPrefix("- name: "), foundRun {
        break
      }
      if trimmed == "run: |" || trimmed.hasPrefix("run: ") {
        foundRun = true
        runLines.append(trimmed)
        continue
      }
      if foundRun {
        runLines.append(line)
      }
    }
    guard foundRun else {
      throw TestParsingError.missingWorkflowRun(stepName)
    }
    return runLines.joined(separator: "\n")
  }

  enum TestParsingError: Error {
    case missingPyprojectGroup(String)
    case missingPyprojectGroupTerminator(String)
    case missingWorkflowStep(String)
    case missingWorkflowRun(String)
    case missingWorkflowTimeout
    case missingScriptDefault(String)
  }

  static func workflowTimeoutMinutes(in text: String) throws -> Int {
    for line in text.split(separator: "\n").map(String.init) {
      let trimmed = line.trimmingCharacters(in: .whitespaces)
      guard trimmed.hasPrefix("timeout-minutes:") else {
        continue
      }
      let value =
        trimmed
        .replacingOccurrences(of: "timeout-minutes:", with: "")
        .trimmingCharacters(in: .whitespaces)
      if let minutes = Int(value) {
        return minutes
      }
    }
    throw TestParsingError.missingWorkflowTimeout
  }

  static func scriptDefaultSeconds(_ variable: String, in text: String) throws -> Int {
    let pattern = "\(variable)=\"${\(variable):-"
    for line in text.split(separator: "\n").map(String.init) {
      guard line.hasPrefix(pattern), line.hasSuffix("}\"") else {
        continue
      }
      let value =
        line
        .replacingOccurrences(of: pattern, with: "")
        .dropLast(2)
      if let seconds = Int(value) {
        return seconds
      }
    }
    throw TestParsingError.missingScriptDefault(variable)
  }

  static func runBashScript(_ arguments: String...) throws -> CommandResult {
    try runBashScript(in: repositoryRoot, environment: [:], arguments)
  }

  static func runBashScript(in workingDirectory: URL, _ arguments: String...) throws -> CommandResult {
    try runBashScript(in: workingDirectory, environment: [:], arguments)
  }

  static func runBashScript(
    environment: [String: String],
    _ arguments: String...
  ) throws -> CommandResult {
    try runBashScript(in: repositoryRoot, environment: environment, arguments)
  }

  static func runBashScript(
    environment: [String: String],
    _ arguments: [String]
  ) throws -> CommandResult {
    try runBashScript(in: repositoryRoot, environment: environment, arguments)
  }

  static func runBashScript(
    in workingDirectory: URL,
    environment: [String: String],
    _ arguments: [String]
  ) throws -> CommandResult {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/bin/bash")
    process.currentDirectoryURL = workingDirectory
    process.arguments = arguments
    process.environment = ProcessInfo.processInfo.environment.merging(environment) { _, new in new }
    let result = try runTestProcessCapturingCombinedOutput(process)
    return CommandResult(status: result.status, output: result.output)
  }

  static let minimalReleaseCandidateDirectories = [
    ".github/workflows",
    ".github/assets",
    "scripts/macos",
    "Sources/OpenLolaCore",
    "Sources/open-lola",
    "Sources/open-lola-app",
    "Sources/opus-1.5.2/openlola_bridge/include",
    "Sources/xs_ref_sw_ed2/libjxs/public",
    "Sources/xs_ref_sw_ed2/libjxs/src",
    "Tests/OpenLolaCoreTests/Fixtures",
    "linux_connector/lola_connector",
    "linux_connector/tests",
    "docs"
  ]

  static let minimalReleaseCandidateFiles = [
    "RELEASE_STATUS.md",
    "SUPPORT.md",
    "archive/README.md",
    "Package.swift",
    ".python-version",
    "pyproject.toml",
    ".github/workflows/release-readiness.yml",
    ".github/assets/OpenLoLa.icns",
    ".github/assets/open-lola-app-icon.svg",
    ".github/assets/open-lola-mark-light.svg",
    ".github/assets/open-lola-mark-dark.svg",
    ".github/assets/open-lola-social-preview.svg",
    ".github/assets/open-lola-social-preview.png",
    ".github/assets/open-lola-signal-desk-light.png",
    ".github/assets/open-lola-signal-desk-dark.png",
    "scripts/macos/build_and_run.sh",
    "scripts/macos/build_cli_app_bundle.sh",
    "scripts/macos/generate_brand_assets.sh",
    "scripts/macos/render_svg.swift",
    "scripts/macos/build_icns.swift",
    "scripts/verify_source_documentation.py",
    "Sources/opus-1.5.2/COPYING",
    "Sources/opus-1.5.2/AUTHORS",
    "Sources/opus-1.5.2/README",
    "Sources/opus-1.5.2/LICENSE_PLEASE_READ.txt",
    "Sources/opus-1.5.2/openlola_bridge/COpusBridge.c",
    "Sources/opus-1.5.2/openlola_bridge/include/COpusBridge.h",
    "Sources/xs_ref_sw_ed2/LICENSE.md",
    "Sources/xs_ref_sw_ed2/README.md",
    "Sources/xs_ref_sw_ed2/libjxs/CMakeLists.txt",
    "Sources/xs_ref_sw_ed2/libjxs/src/msbpack.c",
    "docs/README.md",
    "docs/current-state.md",
    "docs/source-contracts.md",
    "docs/testing.md",
    "docs/release-boundary.md",
    "docs/release-manifest.md",
    "docs/RELEASING.md",
    "docs/reverse-engineering-boundary.md"
  ]

  static func makeMinimalReleaseCandidate(at root: URL) throws {
  for directory in minimalReleaseCandidateDirectories {
  try FileManager.default.createDirectory(
  at: root.appendingPathComponent(directory),
  withIntermediateDirectories: true
  )
  }

  for file in minimalReleaseCandidateFiles {
  let url = root.appendingPathComponent(file)
  try FileManager.default.createDirectory(
  at: url.deletingLastPathComponent(),
  withIntermediateDirectories: true
  )
  if file == "Package.swift" {
  try Data(contentsOf: repositoryRoot.appendingPathComponent(file)).write(to: url)
  } else {
  try Data().write(to: url)
  }
  }
  }
}

extension String {
  func containsLine(_ line: String) -> Bool {
    split(separator: "\n", omittingEmptySubsequences: false)
      .map(String.init)
      .contains(line)
  }
}
