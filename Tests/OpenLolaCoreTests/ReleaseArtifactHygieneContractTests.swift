// Verifies that release hygiene policy, docs, manifest notice, and verification matrix stay aligned.
import Foundation
import Testing

@Test
func releaseHygienePolicyDocsManifestNoticeAndVerificationMatrixStayAligned() throws {
  let gitignore = try ReleaseArtifactHygieneSupport.readText(".gitignore")
  let releaseManifest = try ReleaseArtifactHygieneSupport.readText("docs/release-manifest.md")
  let complianceReadme = try ReleaseArtifactHygieneSupport.readText("docs/release-boundary.md")
  let designSystem = try ReleaseArtifactHygieneSupport.readText("docs/design-system.md")
  let thirdPartyNotices = try ReleaseArtifactHygieneSupport.readText("THIRD_PARTY_NOTICES.md")
  let scriptsReadme = try ReleaseArtifactHygieneSupport.readText("scripts/README.md")
  let matrix = try ReleaseArtifactHygieneSupport.readText("docs/testing.md")
  let policy = try ReleaseArtifactHygieneSupport.releaseBoundaryPolicy()

  for pattern in try #require(policy["gitignore-required"]) {
    #expect(gitignore.containsLine(pattern))
  }
  #expect(try #require(policy["documented-release-exclusion"]).isEmpty == false)
  #expect(releaseManifest.contains("scripts/release-boundary-policy.txt"))
  #expect(complianceReadme.contains("scripts/release-boundary-policy.txt"))

  #expect(complianceReadme.contains("No external SwiftPM package dependencies"))
  #expect(complianceReadme.contains("verify-release-hygiene.sh"))
  #expect(thirdPartyNotices.contains("No external SwiftPM package dependencies"))
  #expect(thirdPartyNotices.contains("verify-release-hygiene.sh"))
  #expect(releaseManifest.contains("scripts/export-release-candidate.sh"))
  #expect(releaseManifest.contains("RELEASE_STATUS.md"))
  #expect(releaseManifest.contains("docs/RELEASING.md"))
  #expect(releaseManifest.contains("linux_connector/**"))
  #expect(releaseManifest.contains("Tests/OpenLolaCoreTests/Fixtures/**"))
  #expect(releaseManifest.contains("scripts/**"))
  #expect(complianceReadme.contains("scripts/export-release-candidate.sh"))
  #expect(complianceReadme.contains("RELEASE_STATUS.md"))
  #expect(complianceReadme.contains("docs/RELEASING.md"))
  #expect(complianceReadme.contains("linux_connector/**"))
  #expect(complianceReadme.contains("Tests/OpenLolaCoreTests/Fixtures/**"))
  #expect(complianceReadme.contains("scripts/**"))
  #expect(scriptsReadme.contains("export-release-candidate.sh"))
  #expect(scriptsReadme.contains("LIVE_RESIDUE_HYGIENE_VERDICT: PASS"))
  #expect(scriptsReadme.contains("RELEASE_HYGIENE_VERDICT: PASS"))
  #expect(matrix.contains("bash scripts/verify-release-hygiene.sh"))
  #expect(matrix.contains("Release hygiene"))
  #expect(matrix.contains("OPEN_LOLA_RELEASE_CANDIDATE"))
  #expect(matrix.contains("manual"))
  #expect(matrix.contains("VERDICT: PARTIAL"))
  #expect(designSystem.contains("../.github/assets/open-lola-signal-desk-light.png"))
  #expect(designSystem.contains("../.github/assets/open-lola-signal-desk-dark.png"))
  #expect(designSystem.contains("open-lola-mark-light.svg"))
  #expect(designSystem.contains("open-lola-mark-dark.svg"))
  #expect(designSystem.contains("OpenLoLa.icns"))
  #expect(designSystem.contains("open-lola-social-preview.png"))
  #expect(designSystem.contains("scripts/macos/generate_brand_assets.sh --check"))
}

@Test
func releaseExportScriptStagesAllowlistedCandidateAndRunsHygieneGate() throws {
  let temporaryRoot = try ReleaseArtifactHygieneSupport.makeTemporaryDirectory(named: "open lola export")
  defer { try? FileManager.default.removeItem(at: temporaryRoot) }

  let exportResult = try ReleaseArtifactHygieneSupport.verifyReleaseCandidateExport(to: temporaryRoot)
  let candidatePath = try ReleaseArtifactHygieneSupport.releaseCandidatePath(from: exportResult)
  try ReleaseArtifactHygieneSupport.verifyReleaseCandidateDirectory(at: candidatePath)
  ReleaseArtifactHygieneSupport.verifyReleaseCandidateIncludedPaths(at: candidatePath)
  ReleaseArtifactHygieneSupport.verifyReleaseCandidateExcludedPaths(at: candidatePath)
  try ReleaseArtifactHygieneSupport.verifyExportedCandidateHygieneAndDocs(at: candidatePath)
  try ReleaseArtifactHygieneSupport.verifyExportedCandidateTrackedBoundaryFailsClosed(
    at: candidatePath
  )
}
@Test
func releaseVerificationContractsCoverTrackedBoundaryTimeoutsAndPythonTooling() throws {
  let workflow = try ReleaseArtifactHygieneSupport.readText(".github/workflows/release-readiness.yml")
  let script = try ReleaseArtifactHygieneSupport.readText("scripts/verify-release-readiness.sh")
  let pythonVersion = try ReleaseArtifactHygieneSupport.readText(".python-version")
  let manifest = try ReleaseArtifactHygieneSupport.readText("pyproject.toml")
  let matrix = try ReleaseArtifactHygieneSupport.readText("docs/testing.md")

  try ReleaseArtifactHygieneSupport.verifyTrackedBoundary()
  try ReleaseArtifactHygieneSupport.verifyReleaseReadinessTimeoutBudget(workflow: workflow, script: script)
  try ReleaseArtifactHygieneSupport.verifyPublicDocumentationContract()
  try ReleaseArtifactHygieneSupport.verifyPythonToolingManifest(
    manifest: manifest,
    pythonVersion: pythonVersion,
    workflow: workflow
  )
  ReleaseArtifactHygieneSupport.verifyPythonToolingDocumented(in: matrix)
}
@Test
func releaseHygieneScriptScansLiveAndCandidateGeneratedResidue() throws {
  let temporaryRoot = try ReleaseArtifactHygieneSupport.makeTemporaryDirectory(named: "open-lola-live-hygiene")
  defer { try? FileManager.default.removeItem(at: temporaryRoot) }

  try ReleaseArtifactHygieneSupport.verifyLiveReleaseHygiene(at: temporaryRoot)

  let candidateRoot = try ReleaseArtifactHygieneSupport.makeTemporaryDirectory(named: "open-lola-c12")
  defer { try? FileManager.default.removeItem(at: candidateRoot) }

  try ReleaseArtifactHygieneSupport.verifyCleanReleaseHygieneCandidate(under: candidateRoot)
  try ReleaseArtifactHygieneSupport.verifyGeneratedResidueCandidateFailures(under: candidateRoot)
}

@Test
func releaseArtifactHygieneProcessCaptureDrainsLargeOutput() throws {
  let result = try ReleaseArtifactHygieneSupport.runBashScript(
    "-c",
    "printf '%070000d' 0; printf '%070000d' 0 >&2"
  )

  #expect(result.status == 0)
  #expect(result.output.utf8.count == 140_000)
}
