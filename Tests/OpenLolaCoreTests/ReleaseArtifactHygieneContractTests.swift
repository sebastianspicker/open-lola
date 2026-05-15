import Foundation
import Testing

@Test
func releaseHygienePolicyManifestDrivesRepositoryPolicyAndCandidateMode() throws {
    let script = try readText("scripts/verify-release-hygiene.sh")
    let gitignore = try readText(".gitignore")
    let releaseManifest = try readText("docs/compliance/release-manifest.md")
    let complianceReadme = try readText("docs/compliance/README.md")
    let policy = try releaseBoundaryPolicy()

    #expect(script.contains("set -euo pipefail"))
    #expect(script.contains("release-boundary-policy.txt"))
    #expect(script.contains("manifest_section"))
    #expect(script.contains("verify_repository_policy"))
    #expect(script.contains("verify_live_checkout"))
    #expect(script.contains("verify_release_candidate"))
    #expect(script.contains("OPEN_LOLA_RELEASE_CANDIDATE"))
    #expect(script.contains("OPEN_LOLA_RELEASE_HYGIENE_LIVE_ROOT"))
    #expect(script.contains("Package.swift"))
    #expect(script.contains("THIRD_PARTY_NOTICES.md"))
    #expect(script.contains("docs/compliance/README.md"))
    #expect(script.contains("docs/compliance/release-manifest.md"))
    #expect(script.contains("Vendor Fence And Patch Policy"))
    #expect(script.contains("COpus"))
    #expect(script.contains("CJpegXSReference"))
    #expect(script.contains("Sources/opus-1.5.2/openlola_bridge/**"))
    #expect(script.contains("find \"$candidate\""))
    #expect(script.contains("-path \"$candidate/private\""))
    #expect(script.contains("-path \"$candidate/private/*\""))
    #expect(script.contains("VERDICT: PASS"))

    for pattern in try #require(policy["gitignore-required"]) {
        #expect(gitignore.containsLine(pattern))
    }
    for excludedPath in try #require(policy["documented-release-exclusion"]) {
        #expect(releaseManifest.contains(excludedPath))
        #expect(complianceReadme.contains(excludedPath))
    }
}

@Test
func releaseExportScriptStagesAllowlistedCandidateAndRunsHygieneGate() throws {
    let script = try readText("scripts/export-release-candidate.sh")

    #expect(script.contains("set -euo pipefail"))
    #expect(script.contains("verify-release-hygiene.sh"))
    #expect(script.contains("OPEN_LOLA_RELEASE_CANDIDATE"))
    #expect(script.contains("win-compiled"))
    #expect(script.contains("private"))
    #expect(script.contains("reverse-engineering"))
    #expect(script.contains("archive"))
    #expect(script.contains("__pycache__"))
    #expect(script.contains("*.pyc"))
    #expect(script.contains("remove_uncompiled_vendor_artifacts"))
    #expect(script.contains("Package.swift-selected build subset"))
    #expect(script.contains("VERDICT: PASS"))
    #expect(script.contains("validate_release_relative_path()"))
    #expect(script.contains("validate_release_relative_path \"$relative_path\""))
    #expect(script.contains("fail \"invalid release source path: $relative_path\""))

    let temporaryRoot = FileManager.default.temporaryDirectory
        .appendingPathComponent("open lola export \(UUID().uuidString)")
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
    #expect(exportResult.output.contains("== release hygiene candidate scan:"))
    #expect(exportResult.output.contains("product release readiness remains PARTIAL"))
    #expect(exportResult.output.contains("VERDICT: PASS"))

    let candidatePrefix = "release candidate staged at: "
    let candidateLine = try #require(exportResult.output
        .split(separator: "\n")
        .map(String.init)
        .first { $0.hasPrefix(candidatePrefix) })
    let candidatePath = String(candidateLine.dropFirst(candidatePrefix.count))
    var isDirectory = ObjCBool(false)
    #expect(FileManager.default.fileExists(
        atPath: candidatePath,
        isDirectory: &isDirectory
    ))
    #expect(isDirectory.boolValue)

    for includedPath in [
        ".github/workflows/release-readiness.yml",
        "Package.swift",
        "pyproject.toml",
        "Sources",
        "Tests",
        "Tests/OpenLolaCoreTests/Fixtures",
        "linux_connector",
        "linux_connector/tests",
        "scripts",
        "docs/architecture",
        "docs/compliance",
        "docs/diagrams",
        "docs/reverse-engineering",
        "docs/source-contracts",
        "docs/testing",
    ] {
        #expect(FileManager.default.fileExists(
            atPath: URL(fileURLWithPath: candidatePath)
                .appendingPathComponent(includedPath)
                .path
        ))
    }

    for excludedPath in [
        ".build",
        "win-compiled",
        "private",
        "reverse-engineering",
        "archive",
        "plan.md",
        "plan-remediation-ledger.md",
        "plan-remediation-status.md",
        "docs/mac-port/reports",
        "research/deprecated-research",
        "Sources/opus-1.5.2/.github",
        "Sources/opus-1.5.2/.gitlab-ci.yml",
        "Sources/opus-1.5.2/.gitmodules",
        "Sources/opus-1.5.2/autogen.sh",
        "Sources/opus-1.5.2/configure.ac",
        "Sources/opus-1.5.2/tests",
        "Sources/opus-1.5.2/training",
        "Sources/opus-1.5.2/dnn",
        "Sources/xs_ref_sw_ed2/programs",
        "Sources/xs_ref_sw_ed2/extras",
    ] {
        #expect(!FileManager.default.fileExists(
            atPath: URL(fileURLWithPath: candidatePath)
                .appendingPathComponent(excludedPath)
                .path
        ))
    }

    let hygieneResult = try runBashScript(
        "scripts/verify-release-hygiene.sh",
        candidatePath
    )
    #expect(hygieneResult.status == 0)
    #expect(hygieneResult.output.contains("VERDICT: PASS"))

    let docsResult = try runBashScript(
        in: URL(fileURLWithPath: candidatePath),
        "scripts/verify-docs.sh"
    )
    #expect(docsResult.status == 0)
    #expect(docsResult.output.contains("public-candidate checks"))
    #expect(docsResult.output.contains("Documentation verification passed."))
}

@Test
func releaseReadinessScriptRunsReleaseHygieneGate() throws {
    let script = try readText("scripts/verify-release-readiness.sh")

    #expect(script.contains("ruff check linux_connector scripts/verify_docs scripts/lib/*.py"))
    #expect(script.contains("python -m pytest -p no:cacheprovider linux_connector"))
    #expect(script.contains("python -m mypy --strict linux_connector/lola_connector scripts/verify_docs scripts/lib/*.py"))
    #expect(script.contains("bash scripts/verify-release-hygiene.sh"))
    #expect(script.contains("source-gate-verdict: pass"))
    #expect(script.contains("product-runtime-verdict: partial"))
    #expect(script.contains("VERDICT: PARTIAL"))
    #expect(!script.contains("echo \"VERDICT: PASS\""))
}

@Test
func activePlanDocsContractUsesRemediationCompanions() throws {
    let verifier = try readText("scripts/verify_docs/markdown_checks.py")
    let currentLedger = repositoryRoot.appendingPathComponent("plan-remediation-ledger.md")
    let currentStatus = repositoryRoot.appendingPathComponent("plan-remediation-status.md")

    #expect(verifier.contains("plan-remediation-ledger.md"))
    #expect(verifier.contains("plan-remediation-status.md"))
    #expect(!verifier.contains("plan-findings-ledger.md"))
    #expect(!verifier.contains("plan-status.md"))
    #expect(FileManager.default.fileExists(atPath: currentLedger.path))
    #expect(FileManager.default.fileExists(atPath: currentStatus.path))
}

@Test
func releaseReadinessWorkflowTimeoutCoversLocalStepBudgets() throws {
    let workflow = try readText(".github/workflows/release-readiness.yml")
    let script = try readText("scripts/verify-release-readiness.sh")
    let timeoutMinutes = try workflowTimeoutMinutes(in: workflow)
    let requiredSeconds = try scriptDefaultSeconds(
        "SWIFT_BUILD_TIMEOUT_SECONDS",
        in: script
    ) + scriptDefaultSeconds(
        "SWIFT_TEST_TIMEOUT_SECONDS",
        in: script
    ) + scriptDefaultSeconds(
        "APP_LAUNCH_TIMEOUT_SECONDS",
        in: script
    )

    #expect(timeoutMinutes * 60 >= requiredSeconds)
}

@Test
func ultraGridDockerHelpersRejectMutableLatestImages() throws {
    let policy = try readText("scripts/open-lola-ultragrid-docker-policy.sh")
    let start = try readText("scripts/start-local-ultragrid-docker.sh")
    let client = try readText("scripts/open-lola-ultragrid-docker-client.sh")
    let build = try readText("scripts/build-local-ultragrid-docker.sh")
    let pair = try readText("scripts/run-local-ultragrid-rxtx-docker.sh")
    let comparator = try readText("scripts/compare-local-ultragrid-parity-docker.sh")
    let dockerfile = try readText("scripts/ultragrid-docker/Dockerfile")

    #expect(policy.contains("open_lola_required_ultragrid_docker_image"))
    #expect(policy.contains("open-lola-ultragrid:1.10.4"))
    #expect(policy.contains("*:latest|latest|*\":latest@\"*"))
    #expect(start.contains("open_lola_required_ultragrid_docker_image"))
    #expect(client.contains("open_lola_required_ultragrid_docker_image"))
    #expect(build.contains("open_lola_required_ultragrid_docker_image"))
    #expect(pair.contains("open_lola_required_ultragrid_docker_image"))
    #expect(comparator.contains("open_lola_required_ultragrid_docker_image"))
    #expect(dockerfile.contains("debian:bookworm-slim@sha256:"))
    #expect(dockerfile.contains("ULTRAGRID_SOURCE_SHA256"))
    #expect(dockerfile.contains("sha256sum -c -"))
    #expect(dockerfile.contains("USER openlola"))
}

@Test
func ultraGridDockerParityHelpersRejectMutableLatestBeforeDockerRuns() throws {
    let temporaryRoot = FileManager.default.temporaryDirectory
        .appendingPathComponent("open-lola-ultragrid-policy-\(UUID().uuidString)")
    defer {
        try? FileManager.default.removeItem(at: temporaryRoot)
    }

    for script in [
        "scripts/run-local-ultragrid-rxtx-docker.sh",
        "scripts/compare-local-ultragrid-parity-docker.sh",
    ] {
        let result = try runBashScript(
            environment: ["OPEN_LOLA_ULTRAGRID_DOCKER_IMAGE": "latest"],
            script,
            temporaryRoot.appendingPathComponent(UUID().uuidString).path
        )
        #expect(result.status != 0)
        #expect(result.output.contains("must not use the mutable latest tag"))
        #expect(!result.output.contains("Cannot connect to the Docker daemon"))
    }
}

@Test
func releaseHygieneNoCandidateModeScansLiveGeneratedResidue() throws {
    let temporaryRoot = FileManager.default.temporaryDirectory
        .appendingPathComponent("open-lola-live-hygiene-\(UUID().uuidString)")
    try FileManager.default.createDirectory(
        at: temporaryRoot,
        withIntermediateDirectories: true
    )
    defer {
        try? FileManager.default.removeItem(at: temporaryRoot)
    }

    let cleanResult = try runBashScript(
        environment: ["OPEN_LOLA_RELEASE_HYGIENE_LIVE_ROOT": temporaryRoot.path],
        "scripts/verify-release-hygiene.sh"
    )
    #expect(cleanResult.status == 0)
    #expect(cleanResult.output.contains("release hygiene live checkout generated-residue scan"))
    #expect(cleanResult.output.contains("VERDICT: PASS"))

    try FileManager.default.createDirectory(
        at: temporaryRoot.appendingPathComponent("module/__pycache__"),
        withIntermediateDirectories: true
    )
    try Data([0x42]).write(to: temporaryRoot.appendingPathComponent("module/__pycache__/sample.pyc"))

    let contaminatedResult = try runBashScript(
        environment: ["OPEN_LOLA_RELEASE_HYGIENE_LIVE_ROOT": temporaryRoot.path],
        "scripts/verify-release-hygiene.sh"
    )
    #expect(contaminatedResult.status != 0)
    #expect(contaminatedResult.output.contains("live checkout contains forbidden generated artifact"))
}

@Test
func pythonToolingManifestDefinesLintTestAndAsyncioPolicy() throws {
    let manifest = try readText("pyproject.toml")
    let workflow = try readText(".github/workflows/release-readiness.yml")
    let matrix = try readText("docs/testing/README.md")
    let devDependencies = try pyprojectOptionalDependencies(named: "dev", in: manifest)
    let pcapDependencies = try pyprojectOptionalDependencies(named: "pcap", in: manifest)
    let installRun = try workflowRunStep(named: "Install Python verification tools", in: workflow)

    #expect(manifest.contains("[project]"))
    #expect(manifest.contains("requires-python = \">=3.11\""))
    #expect(devDependencies == [
        "mypy==1.14.1",
        "pytest>=8.3,<9",
        "pytest-asyncio>=0.25,<1",
        "ruff>=0.11,<1",
    ])
    #expect(pcapDependencies == ["scapy>=2.6,<3"])
    #expect(devDependencies.allSatisfy(isBoundedPythonToolDependency))
    #expect(pcapDependencies.allSatisfy(isBoundedPythonToolDependency))
    #expect(manifest.contains("testpaths = [\"linux_connector/tests\"]"))
    #expect(manifest.contains("pythonpath = [\".\"]"))
    #expect(manifest.contains("asyncio_default_fixture_loop_scope = \"function\""))

    #expect(installRun.contains("tomllib.load"))
    #expect(installRun.contains("[\"project\"][\"optional-dependencies\"][\"dev\"]"))
    #expect(!installRun.contains("pytest>="))
    #expect(!installRun.contains("ruff>="))

    #expect(matrix.contains("ruff check linux_connector scripts/verify_docs scripts/lib/*.py"))
    #expect(matrix.contains("python -m pytest -p no:cacheprovider linux_connector"))
    #expect(matrix.contains("python -m mypy --strict linux_connector/lola_connector scripts/verify_docs scripts/lib/*.py"))
    #expect(matrix.contains("[project.optional-dependencies].dev"))
}

@Test
func releaseManifestAndNoticeDocsDeclareC12Exclusions() throws {
    let releaseManifest = try readText("docs/compliance/release-manifest.md")
    let dependencyReview = try readText("docs/compliance/README.md")
    let thirdPartyNotices = try readText("THIRD_PARTY_NOTICES.md")
    let hygieneDoc = try readText("docs/compliance/README.md")
    let scriptsReadme = try readText("scripts/README.md")

    for excludedPath in try #require(releaseBoundaryPolicy()["documented-release-exclusion"]) {
        #expect(releaseManifest.contains(excludedPath))
        #expect(hygieneDoc.contains(excludedPath))
    }

    #expect(dependencyReview.contains("No external SwiftPM package dependencies"))
    #expect(dependencyReview.contains("verify-release-hygiene.sh"))
    #expect(thirdPartyNotices.contains("No external SwiftPM package dependencies"))
    #expect(thirdPartyNotices.contains("verify-release-hygiene.sh"))
    #expect(releaseManifest.contains("scripts/export-release-candidate.sh"))
    #expect(releaseManifest.contains("linux_connector/**"))
    #expect(releaseManifest.contains("Tests/OpenLolaCoreTests/Fixtures/**"))
    #expect(hygieneDoc.contains("scripts/export-release-candidate.sh"))
    #expect(hygieneDoc.contains("linux_connector/**"))
    #expect(hygieneDoc.contains("Tests/OpenLolaCoreTests/Fixtures/**"))
    #expect(scriptsReadme.contains("export-release-candidate.sh"))
}

@Test
func verificationMatrixIncludesC12ArtifactHygieneGate() throws {
    let matrix = try readText("docs/testing/README.md")

    #expect(matrix.contains("bash scripts/verify-release-hygiene.sh"))
    #expect(matrix.contains("Release hygiene"))
    #expect(matrix.contains("OPEN_LOLA_RELEASE_CANDIDATE"))
    #expect(matrix.contains("manual"))
    #expect(matrix.contains("VERDICT: PARTIAL"))
}

@Test
func releaseHygieneScriptScansCandidateDirectories() throws {
    let temporaryRoot = FileManager.default.temporaryDirectory
        .appendingPathComponent("open-lola-c12-\(UUID().uuidString)")
    try FileManager.default.createDirectory(
        at: temporaryRoot,
        withIntermediateDirectories: true
    )
    defer {
        try? FileManager.default.removeItem(at: temporaryRoot)
    }

    let cleanCandidate = temporaryRoot.appendingPathComponent("clean")
    try makeMinimalReleaseCandidate(at: cleanCandidate)

    let cleanResult = try runBashScript(
        "scripts/verify-release-hygiene.sh",
        cleanCandidate.path
    )
    #expect(cleanResult.status == 0)
    #expect(cleanResult.output.contains("VERDICT: PASS"))

    let contaminatedCandidate = temporaryRoot.appendingPathComponent("contaminated")
    try makeMinimalReleaseCandidate(at: contaminatedCandidate)
    try FileManager.default.createDirectory(
        at: contaminatedCandidate.appendingPathComponent(".build"),
        withIntermediateDirectories: true
    )

    let contaminatedResult = try runBashScript(
        "scripts/verify-release-hygiene.sh",
        contaminatedCandidate.path
    )
    #expect(contaminatedResult.status != 0)
    #expect(contaminatedResult.output.contains("forbidden generated/internal/vendor artifact"))
    #expect(contaminatedResult.output.contains(".build"))

    let bytecodeCandidate = temporaryRoot.appendingPathComponent("bytecode")
    try makeMinimalReleaseCandidate(at: bytecodeCandidate)
    let pycache = bytecodeCandidate
        .appendingPathComponent("linux_connector/tests/__pycache__")
    try FileManager.default.createDirectory(at: pycache, withIntermediateDirectories: true)
    try Data([0x42]).write(to: pycache.appendingPathComponent("test_codec.cpython-313.pyc"))

    let bytecodeResult = try runBashScript(
        "scripts/verify-release-hygiene.sh",
        bytecodeCandidate.path
    )
    #expect(bytecodeResult.status != 0)
    #expect(bytecodeResult.output.contains("forbidden generated/internal/vendor artifact"))
    #expect(bytecodeResult.output.contains("__pycache__") || bytecodeResult.output.contains(".pyc"))

    let cacheCandidate = temporaryRoot.appendingPathComponent("tool-cache")
    try makeMinimalReleaseCandidate(at: cacheCandidate)
    try FileManager.default.createDirectory(
        at: cacheCandidate.appendingPathComponent(".ruff_cache"),
        withIntermediateDirectories: true
    )

    let cacheResult = try runBashScript(
        "scripts/verify-release-hygiene.sh",
        cacheCandidate.path
    )
    #expect(cacheResult.status != 0)
    #expect(cacheResult.output.contains("forbidden generated/internal/vendor artifact"))
    #expect(cacheResult.output.contains(".ruff_cache"))

    let vendorCandidate = temporaryRoot.appendingPathComponent("vendor-extra")
    try makeMinimalReleaseCandidate(at: vendorCandidate)
    try FileManager.default.createDirectory(
        at: vendorCandidate.appendingPathComponent("Sources/opus-1.5.2/tests"),
        withIntermediateDirectories: true
    )

    let vendorResult = try runBashScript(
        "scripts/verify-release-hygiene.sh",
        vendorCandidate.path
    )
    #expect(vendorResult.status != 0)
    #expect(vendorResult.output.contains("forbidden generated/internal/vendor artifact"))
    #expect(vendorResult.output.contains("Sources/opus-1.5.2/tests"))
}

private var repositoryRoot: URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
}

private struct CommandResult {
    let status: Int32
    let output: String
}

private func readText(_ relativePath: String) throws -> String {
    let url = repositoryRoot.appendingPathComponent(relativePath)
    return try String(contentsOf: url, encoding: .utf8)
}

private func releaseBoundaryPolicy() throws -> [String: [String]] {
    try sectionedManifest("scripts/release-boundary-policy.txt")
}

private func sectionedManifest(_ relativePath: String) throws -> [String: [String]] {
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

private extension String {
    func containsLine(_ line: String) -> Bool {
        split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)
            .contains(line)
    }
}

private func pyprojectOptionalDependencies(named group: String, in text: String) throws -> [String] {
    let lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
    let header = "\(group) = ["
    guard let startIndex = lines.firstIndex(where: { $0.trimmingCharacters(in: .whitespaces) == header }) else {
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

private func isBoundedPythonToolDependency(_ dependency: String) -> Bool {
    dependency.contains("==") || (dependency.contains(">=") && dependency.contains(",<"))
}

private func workflowRunStep(named stepName: String, in text: String) throws -> String {
    let lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
    guard let stepIndex = lines.firstIndex(where: {
        $0.trimmingCharacters(in: .whitespaces) == "- name: \(stepName)"
    }) else {
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

private enum TestParsingError: Error {
    case missingPyprojectGroup(String)
    case missingPyprojectGroupTerminator(String)
    case missingWorkflowStep(String)
    case missingWorkflowRun(String)
    case missingWorkflowTimeout
    case missingScriptDefault(String)
}

private func workflowTimeoutMinutes(in text: String) throws -> Int {
    for line in text.split(separator: "\n").map(String.init) {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("timeout-minutes:") else {
            continue
        }
        let value = trimmed
            .replacingOccurrences(of: "timeout-minutes:", with: "")
            .trimmingCharacters(in: .whitespaces)
        if let minutes = Int(value) {
            return minutes
        }
    }
    throw TestParsingError.missingWorkflowTimeout
}

private func scriptDefaultSeconds(_ variable: String, in text: String) throws -> Int {
    let pattern = "\(variable)=\"${\(variable):-"
    for line in text.split(separator: "\n").map(String.init) {
        guard line.hasPrefix(pattern), line.hasSuffix("}\"") else {
            continue
        }
        let value = line
            .replacingOccurrences(of: pattern, with: "")
            .dropLast(2)
        if let seconds = Int(value) {
            return seconds
        }
    }
    throw TestParsingError.missingScriptDefault(variable)
}

private func runBashScript(_ arguments: String...) throws -> CommandResult {
    try runBashScript(in: repositoryRoot, environment: [:], arguments)
}

private func runBashScript(in workingDirectory: URL, _ arguments: String...) throws -> CommandResult {
    try runBashScript(in: workingDirectory, environment: [:], arguments)
}

private func runBashScript(
    environment: [String: String],
    _ arguments: String...
) throws -> CommandResult {
    try runBashScript(in: repositoryRoot, environment: environment, arguments)
}

private func runBashScript(
    in workingDirectory: URL,
    environment: [String: String],
    _ arguments: [String]
) throws -> CommandResult {
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
    return CommandResult(status: process.terminationStatus, output: output)
}

private func makeMinimalReleaseCandidate(at root: URL) throws {
    let directories = [
        ".github/workflows",
        "Sources/OpenLolaCore",
        "Sources/open-lola",
        "Sources/open-lola-app",
        "Sources/opus-1.5.2/openlola_bridge/include",
        "Sources/xs_ref_sw_ed2/libjxs/public",
        "Sources/xs_ref_sw_ed2/libjxs/src",
        "Tests/OpenLolaCoreTests/Fixtures",
        "linux_connector/lola_connector",
        "linux_connector/tests",
        "docs/testing",
        "docs/diagrams",
        "docs/reverse-engineering",
    ]
    for directory in directories {
        try FileManager.default.createDirectory(
            at: root.appendingPathComponent(directory),
            withIntermediateDirectories: true
        )
    }

    for file in [
        "Package.swift",
        "pyproject.toml",
        ".github/workflows/release-readiness.yml",
        "Sources/opus-1.5.2/COPYING",
        "Sources/opus-1.5.2/openlola_bridge/COpusBridge.c",
        "Sources/opus-1.5.2/openlola_bridge/include/COpusBridge.h",
        "Sources/xs_ref_sw_ed2/LICENSE.md",
    ] {
        let url = root.appendingPathComponent(file)
        try Data().write(to: url)
    }
}
