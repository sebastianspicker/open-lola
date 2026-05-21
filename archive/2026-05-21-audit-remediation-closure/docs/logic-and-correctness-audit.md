# Logic and correctness audit

Created: 2026-05-20

Scope: docs-only audit of correctness risks using `AGENTS.md`,
`docs/code-index.md`, `docs/architecture-map.md`,
`docs/verification-baseline.md`, `docs/deprecation-and-simplification-audit.md`,
and focused source/test reads in Direct P2P reports, AV runtime guards, external
connector reports, CLI executable tests, release hygiene scripts, Docker parity
scripts, and the Python Linux connector.

This is not a full line-by-line audit of all 1,512 source-bearing files from
`docs/code-index.md`. Areas not fully inspected are listed at the end.

## Summary

- Original confirmed issues: 8
- Original suspected issues: 2
- Remediation status 2026-05-21: LCA-001 through LCA-010 are mapped to
  completed RFP slices in `docs/remediation-ledger.md` and summarized in
  `docs/remediation-status.md`. This audit keeps the original evidence trail;
  use the remediation ledger for current implementation status.
- Original highest priority: Direct P2P PASS evidence validation, Python media
  reassembly, Linux connector control parsing, release-boundary verification
  trust, and stale executable test probes.

## Confirmed issues

### LCA-001: Direct P2P PASS can accept harmful or unobserved DSCP evidence

- ID: LCA-001
- Status: Remediated locally by RFP-005. The original finding was confirmed
  from source inspection.
- Location:
  - `Sources/OpenLolaCore/Network/P2P/DirectPeerSessionReport.swift`, `validatePassMeasuredEvidence`, `validateDirectPeerSessionDSCPEvidence`
  - `Sources/OpenLolaCore/Network/P2P/DirectPeerSessionEvidence.swift`, `DirectPeerSessionDSCPClassification`
- Evidence:
  - PASS requires a DSCP artifact at `DirectPeerSessionReport.swift:204-208`.
  - DSCP validation only bounds `requested` and `observed` when present, then
    validates `capturePoint` and artifact shape at `DirectPeerSessionReport.swift:673-685`.
  - The classification enum includes `.harmful` at
    `DirectPeerSessionEvidence.swift:7-11`.
  - Existing PASS tests only reject `measuredEvidence.dscp.artifact.captured =
    false` at `DirectPeerSessionReportAVPassTests.swift:61-64`.
- Why it matters: A report can run validation and claim `PASS` while DSCP was
  harmful, ignored, rewritten, or never recorded as an observed value. That is a
  silent wrong-result risk in a network-quality contract.
- Minimal reproduction or reasoning: Build an AV PASS candidate, set
  `report.measuredEvidence?.dscp?.classification = .harmful` or
  `observed = nil`, keep the artifact captured with a 64-character hash, and
  call `report.validate()`. The inspected validation path has no rejection for
  those states.
- Existing test coverage: PASS evidence tests cover missing video proof,
  missing raw video evidence, missing packet capture, missing packet-capture
  hash, and uncaptured DSCP artifact. They do not cover harmful, ignored,
  rewritten, or nil-observed DSCP.
- Missing test that should exist: Closed locally by RFP-005; PASS validator
  tests now reject harmful, ignored, rewritten, and unobserved DSCP evidence.
- Suggested minimal fix: Implemented by RFP-005: PASS-only DSCP validation
  requires honored classification and observed DSCP read-back. Weak DSCP remains
  trace evidence, not PASS evidence.
- Risk level: High.
- Verification command or strategy:
  `swift test --filter DirectPeerSessionReportAVPassTests --no-parallel`, plus
  a focused new PASS-rejection test for DSCP classification and observed value.
- Confidence: High.

### LCA-002: Python LoLa media reassembly can return corrupted frames for gaps or overlaps

- ID: LCA-002
- Status: Remediated locally by RFP-007. The original finding was confirmed
  from source inspection.
- Location:
  - `linux_connector/lola_connector/media.py`, `MediaReassembler.add`
  - `linux_connector/tests/test_codec.py`, media reassembler tests
- Evidence:
  - `MediaReassembler.add` checks fragment index range and duplicate index, then
    writes each fragment into a bytearray by offset at
    `linux_connector/lola_connector/media.py:193-230`.
  - It does not verify that offsets are contiguous, non-overlapping, and cover
    the declared frame size exactly.
  - Tests cover zero-size auto-begin, out-of-range fragment, and duplicate
    fragment index at `linux_connector/tests/test_codec.py:285-318`, but not
    overlapping offsets or gaps inside the declared frame.
- Why it matters: A received media frame can assemble without crashing while
  containing overwritten bytes or zero-filled gaps. That is silent media
  corruption in the compatibility connector.
- Minimal reproduction or reasoning: Begin a frame with `expected_size = 8` and
  `fragment_count = 2`; add fragment index 0 at offset 0 length 4, then index 1
  also at offset 0 length 4. The current logic reaches `len(parts) ==
  fragment_count` and returns an 8-byte frame instead of rejecting the overlap.
- Existing test coverage: Reassembler tests cover some malformed shape cases,
  but not offset coverage.
- Missing test that should exist: Closed locally by RFP-007; media reassembler
  tests now cover overlap, missing middle ranges, and exact contiguous coverage.
- Suggested minimal fix: Implemented by RFP-007: malformed overlap and gap
  fragments now raise instead of returning zero-filled or overwritten media.
- Risk level: High.
- Verification command or strategy:
  `PYTHONDONTWRITEBYTECODE=1 python -m pytest -p no:cacheprovider linux_connector/tests/test_codec.py`.
- Confidence: High.

### LCA-003: Python control parsing silently truncates fractional media settings

- ID: LCA-003
- Status: Remediated locally by RFP-008. The original behavior was confirmed;
  OSC tolerance is now limited to integer-valued doubles covered by tests.
- Location:
  - `linux_connector/lola_connector/protocol.py`, `MediaSettings.from_fields`
    and `finite_int_arg`
- Evidence:
  - ASCII media fields are parsed with `float(value)` and returned with
    `int(numeric)` at `linux_connector/lola_connector/protocol.py:78-88`.
  - OSC numeric arguments are also converted with `int(numeric)` at
    `linux_connector/lola_connector/protocol.py:420-427`.
  - Current tests reject garbage and nonfinite values at
    `linux_connector/tests/test_codec.py:74-83`, but not fractional values.
- Why it matters: `SR:44100.9`, `FPS:29.9`, or similar malformed control
  values can be silently coerced to a different integer instead of rejected.
  That can negotiate the wrong media mode while appearing valid.
- Minimal reproduction or reasoning: `MediaSettings.from_fields({"SR":
  "44100.9"})` returns `sample_rate == 44100` by inspection of the parser.
- Existing test coverage: Garbage and infinity are rejected; fractional values
  are not tested.
- Missing test that should exist: Closed locally by RFP-008; tests now reject
  fractional ASCII media numbers and fractional OSC15 doubles while preserving
  integer-valued OSC15 doubles.
- Suggested minimal fix: Implemented by RFP-008: fractional media settings fail
  closed instead of being truncated.
- Risk level: Medium.
- Verification command or strategy:
  `PYTHONDONTWRITEBYTECODE=1 python -m pytest -p no:cacheprovider linux_connector/tests/test_codec.py linux_connector/tests/test_process_runtime.py`.
- Confidence: Medium.

### LCA-004: Python ASCII control parser accepts duplicate fields with last-write wins

- ID: LCA-004
- Status: Remediated locally by RFP-008. The original duplicate-field behavior
  was confirmed from source inspection.
- Location:
  - `linux_connector/lola_connector/protocol.py`, `parse_control_datagram`
  - `linux_connector/lola_connector/connector.py`, `settings_from_quickconn_ack`
- Evidence:
  - `parse_control_datagram` assigns `fields[key] = value` for every field at
    `linux_connector/lola_connector/protocol.py:192-200`; duplicate field names
    overwrite earlier values.
  - QuickConn ACK settings are then derived from those fields, defaulting
    missing fields to local settings at
    `linux_connector/lola_connector/connector.py:508-515`.
  - Tests cover malformed garbage ACKs at
    `linux_connector/tests/test_process_runtime.py:191-205`, but not duplicate
    fields or missing required media fields.
- Why it matters: Ambiguous control input can run without crashing and negotiate
  the last duplicate value. Missing fields can fall back to local defaults,
  which may hide a malformed peer message.
- Minimal reproduction or reasoning: A QuickConn ACK containing duplicate
  sample-rate fields leaves `fields["SR"] == "48000"` when the later field uses
  `48000`. A missing `SR` in an ACK is filled from `self.settings` by
  `settings_from_quickconn_ack`.
- Existing test coverage: Invalid numeric ACKs are classified as malformed.
  Duplicate or missing required media fields are not covered.
- Missing test that should exist: Closed locally by RFP-008; tests now reject
  duplicate QuickConn media fields, missing required QuickConn/ACK media fields,
  and runtime malformed ACK input.
- Suggested minimal fix: Implemented by RFP-008: ambiguous QuickConn/ACK media
  settings fail closed instead of applying last-write-wins or default fallback.
- Risk level: Medium.
- Verification command or strategy:
  `PYTHONDONTWRITEBYTECODE=1 python -m pytest -p no:cacheprovider linux_connector/tests/test_process_runtime.py linux_connector/tests/test_codec.py`.
- Confidence: High for duplicate overwrite; medium for whether defaults are
  still required.

### LCA-005: Release-candidate verification can fail while live docs and hygiene checks pass

- ID: LCA-005
- Status: Remediated locally by RFP-001. The original issue was confirmed by
  the planning baseline and release-hygiene source.
- Location:
  - `scripts/verify-release-hygiene.sh`
  - `Tests/OpenLolaCoreTests/ReleaseArtifactHygieneContractTests.swift`
  - `docs/verification-baseline.md`
- Evidence:
  - Candidate hygiene requires a flattened allowlisted candidate surface at
    `scripts/verify-release-hygiene.sh:221-278`.
  - With no candidate, the script scans only live generated residue, prints a
    warning, then prints `HYGIENE_VERDICT: PASS` at
    `scripts/verify-release-hygiene.sh:288-296`.
  - Tests assert the live no-candidate PASS string at
    `ReleaseArtifactHygieneContractTests.swift:324-329`.
  - The current baseline records that the candidate export failed because
    `docs/code-index.md` references `script/` paths not present in the candidate
    at `docs/verification-baseline.md:190-199`.
- Why it matters: A maintainer or CI wrapper can see a passing live docs/hygiene
  check and miss that the actual staged release candidate is broken.
- Minimal reproduction or reasoning: Run `bash scripts/verify-release-hygiene.sh`
  without a candidate and it can emit `HYGIENE_VERDICT: PASS`; the baseline
  shows the candidate export contract still failed for the same working tree.
- Existing test coverage: Release artifact contract tests cover the staged
  candidate and currently fail in the baseline. Live hygiene tests also assert
  the no-candidate PASS text.
- Missing test that should exist: Closed locally by RFP-001; release hygiene
  tests now distinguish live generated-residue checks from staged candidate
  hygiene.
- Suggested minimal fix: Implemented by RFP-001: live no-candidate hygiene and
  staged candidate hygiene use distinct verdict labels, and release-candidate
  export/hygiene checks passed with remaining product blockers kept `PARTIAL`.
- Risk level: High.
- Verification command or strategy:
  `swift test --filter ReleaseArtifactHygieneContractTests --no-parallel` and
  `bash scripts/export-release-candidate.sh /tmp/open-lola-release-check`.
- Confidence: High.

### LCA-006: Several executable-behavior tests can run against a stale CLI binary

- ID: LCA-006
- Status: Remediated locally by RFP-002. The original issue was confirmed from
  tests and the planning baseline.
- Location:
  - `Tests/OpenLolaCoreTests/CLICommandInventoryTests.swift`
  - `Tests/OpenLolaCoreTests/DirectPeerSessionCLITests.swift`
  - `Tests/OpenLolaCoreTests/MadiFullDuplexSessionTests.swift`
  - `Tests/OpenLolaCoreTests/MachineReadableSurfaceContractTests.swift`
  - `docs/verification-baseline.md`
- Evidence:
  - `MachineReadableSurfaceContractTests` checks freshness of the fixed binary
    at `MachineReadableSurfaceContractTests.swift:235-254`.
  - Other helpers choose the first executable candidate, starting with
    `/private/tmp/open-lola2-swiftpm-build/debug/open-lola`, without the same
    freshness check at `CLICommandInventoryTests.swift:100-110`,
    `DirectPeerSessionCLITests.swift:101-111`, and
    `MadiFullDuplexSessionTests.swift:306-315`.
  - The baseline states fixed-path CLI probes are not self-contained unless the
    binary is freshly built at `docs/verification-baseline.md:264-266`, and that
    MachineReadable tests passed only after refreshing that path at
    `docs/verification-baseline.md:184-187`.
- Why it matters: Tests can pass or fail against an old executable while source
  changes are different, producing false confidence or false failures.
- Minimal reproduction or reasoning: Leave a stale executable at
  `/private/tmp/open-lola2-swiftpm-build/debug/open-lola`; test helpers that
  prefer it will run that binary even when repo sources changed.
- Existing test coverage: One test file has freshness checking; several others
  do not.
- Missing test that should exist: Closed locally by RFP-002; executable CLI
  tests now share stale fixed-path binary rejection.
- Suggested minimal fix: Implemented by RFP-002: fixed-path executable tests use
  the same freshness rule and fail loudly against stale binaries.
- Risk level: High for verification trust; medium for product runtime.
- Verification command or strategy:
  `swift build --product open-lola --build-path /private/tmp/open-lola2-swiftpm-build`
  then rerun executable-behavior filters; add a stale-binary helper test if
  practical.
- Confidence: High.

### LCA-007: Docker parity scripts lack a bounded daemon preflight

- ID: LCA-007
- Status: Remediated locally by RFP-004. The original issue was confirmed by
  scripts and the planning baseline environment result.
- Location:
  - `scripts/compare-local-ultragrid-parity-docker.sh`
  - `scripts/compare-local-jacktrip-parity-docker.sh`
  - `scripts/lib/parity.sh`
  - `docs/verification-baseline.md`
- Evidence:
  - The UltraGrid parity script calls `docker image inspect` before any explicit
    bounded daemon preflight at `compare-local-ultragrid-parity-docker.sh:44-48`.
  - The JackTrip parity script reaches Docker operations after setup with no
    daemon preflight at `compare-local-jacktrip-parity-docker.sh:39-48`.
  - Shared log helpers call `docker container inspect`, `docker logs`,
    `docker kill`, and `docker wait` directly at `scripts/lib/parity.sh:74-110`.
  - The current baseline records that `docker --version` passed but `docker ps`
    hung and was killed at `docs/verification-baseline.md:31-32`.
- Why it matters: A parity gate can hang or fail unclearly when Docker CLI is
  installed but the daemon is unhealthy. That blocks verification and can hide
  whether parity failed for product reasons or host setup.
- Minimal reproduction or reasoning: On the audited host, `docker ps` hung. The
  scripts invoke Docker commands without a short daemon-health check, so they
  can hit the same blocker during parity runs.
- Existing test coverage: ShellCheck covers syntax, not daemon availability or
  bounded failure behavior.
- Missing test that should exist: Closed locally by RFP-004; deterministic
  tooling tests cover an unresponsive fake Docker command and bounded failure.
- Suggested minimal fix: Implemented by RFP-004: Docker parity scripts call the
  shared bounded daemon preflight before Docker parity work.
- Risk level: Medium.
- Verification command or strategy:
  `timeout 5 docker ps`; then run the parity script preflight path once Docker
  daemon health is known.
- Confidence: High.

### LCA-008: `runtimeErrorFree` is true for PARTIAL external connector reports

- ID: LCA-008
- Status: Remediated locally by RFP-010. The original behavior and test
  expectation were confirmed.
- Location:
  - `Sources/OpenLolaCore/Connectors/Core/ExternalConnectorSession.swift`
  - `Sources/OpenLolaCore/Connectors/UltraGrid/UltraGridCompatibility.swift`
  - `Sources/OpenLolaCore/Connectors/JackTrip/JackTripCompatibility.swift`
  - `Tests/OpenLolaCoreTests/ExternalConnectorSessionTests.swift`
- Evidence:
  - Session reports default `runtimeErrorFree` to `runtimeError == nil` at
    `ExternalConnectorSession.swift:603-604`.
  - UltraGrid and JackTrip media reports do the same at
    `UltraGridCompatibility.swift:215-217` and
    `JackTripCompatibility.swift:154-156`.
  - Tests assert `runtimeErrorFree == true` while `verdict == .partial` at
    `ExternalConnectorSessionTests.swift:492-502`.
  - PASS validation separately checks evidence at
    `ExternalConnectorSession.swift:658-665`, so this is not currently a PASS
    validator bypass.
- Why it matters: The field name reads like a health/ready signal even when the
  report is only PARTIAL and still missing real-world evidence. UI/report
  consumers can run without crashing and show a misleading healthy state if they
  use the field without verdict/evidence context.
- Minimal reproduction or reasoning: Run an external connector dry-run or
  source-level partial report with no runtime error. The report validates with
  `runtimeErrorFree == true` and `verdict == .partial`.
- Existing test coverage: Existing tests enshrine this behavior.
- Missing test that should exist: Closed locally by RFP-010; derived connector
  runtime evidence state and app-shell tests now prove partial no-error reports
  are not treated as validated media evidence.
- Suggested minimal fix: Implemented by RFP-010: `runtimeErrorFree` remains a
  JSON compatibility field, while derived display/validation state pairs it with
  verdict and completeness before treating evidence as validated.
- Risk level: Medium.
- Verification command or strategy:
  `swift test --filter ExternalConnectorSessionTests --no-parallel` plus
  app/UI tests for external connector evidence summaries.
- Confidence: High.

## Suspected issues

### LCA-009: Structural Direct P2P quality policy can bypass useful-media checks

- ID: LCA-009
- Status: Remediated locally by RFP-009. The original finding was a suspected
  false-success risk, not a confirmed PASS bug.
- Location:
  - `Sources/OpenLolaCore/Network/P2P/DirectPeerSessionAVSocketRunner.swift`
  - `Sources/open-lola/Commands/Network/DirectP2PSessionQualityPolicyCommandSupport.swift`
  - `Sources/open-lola/Commands/Network/DirectP2PSessionRunCommandSupport.swift`
  - `Sources/OpenLolaCore/Network/P2P/DirectPeerSessionAVReportBuilder.swift`
- Evidence:
  - The useful-media guard returns immediately unless policy is
    `.requireUsefulMedia` at `DirectPeerSessionAVSocketRunner.swift:594-600`.
  - CLI help exposes `--quality-policy structural|require-useful-media` at
    `DirectP2PSessionRunCommandSupport.swift:20-24`.
  - The default is `requireUsefulMedia` at
    `DirectP2PSessionQualityPolicyCommandSupport.swift:3-12`.
  - Built AV reports remain `.partial` at
    `DirectPeerSessionAVReportBuilder.swift:45-47`.
- Why it matters: A structural run can complete and write a valid PARTIAL report
  even when no useful media moved. That can be valuable for structural
  diagnostics, but it is a false-success risk if copied into readiness evidence
  or displayed without an explicit "no useful media required" marker.
- Minimal reproduction or reasoning: Run an AV command with
  `--quality-policy structural`; the inspected guard does not enforce audio sent,
  playout, video reassembly, or receive proof.
- Existing test coverage: The original audit did not find tests specifically
  proving structural reports are labeled distinctly or cannot be promoted/used
  as useful media evidence. RFP-009 added structural and required useful-media
  proof report tests plus PASS validator rejection tests; see
  `docs/remediation-ledger.md`.
- Missing test that should exist: Closed locally by RFP-009 while current report
  contracts remain in force. Re-audit if Direct P2P AV report schema,
  `usefulMediaProof`, quality-policy output, or promotion workflows change.
- Suggested minimal fix: Implemented by RFP-009: AV runtime reports expose
  `qualityPolicy` and `usefulMediaProof`; structural runs encode
  `not-required`, required-policy reports with missing media encode
  `required-but-not-proven`, and AV PASS validation requires
  `required-and-proven`.
- Risk level: Medium.
- Verification command or strategy:
  Focused Direct P2P AV CLI/report tests with `--quality-policy structural`,
  plus validator/UI checks that distinguish structural from media-proven runs.
- Confidence: Medium.

### LCA-010: Evidence artifact validation checks declarations, not artifact existence or hash content

- ID: LCA-010
- Status: Remediated locally by RFP-006. Pure report validation remains
  portable; evidence-bundle verification now owns artifact existence and hash
  checks before promotion.
- Location:
  - `Sources/OpenLolaCore/Network/P2P/DirectPeerSessionReport.swift`
- Evidence:
  - PASS artifact validation requires non-placeholder path, allowed extension,
    `captured == true`, and a 64-character hex SHA at
    `DirectPeerSessionReport.swift:612-659`.
  - The inspected validator does not read the artifact path or compare the hash
    against file contents.
- Why it matters: A report can validate with a declared artifact path and
  syntactically valid SHA even if the artifact is absent from the local evidence
  bundle. That can produce wrong release/evidence conclusions if schema
  validation is treated as artifact verification.
- Minimal reproduction or reasoning: Build a PASS candidate with
  `packetCapture.path = "reports/captures/missing.pcapng"` and a valid-looking
  SHA string. Based on the inspected validator, schema validation checks the
  string shape, not the file.
- Existing test coverage: Original tests asserted missing SHA and uncaptured
  artifact rejection but did not assert file existence or hash verification.
  RFP-006 added deterministic Direct P2P PASS evidence-bundle verifier tests for
  pure schema validation, missing artifacts, hash mismatch, and matching
  artifacts; see `docs/remediation-ledger.md`.
- Missing test that should exist: Closed locally by RFP-006 while current Direct
  P2P evidence-bundle promotion contracts remain in force. Re-audit if release
  promotion stops invoking the bundle verifier or if artifact contracts change.
- Suggested minimal fix: Implemented by RFP-006: report schema validation stays
  file-IO-free, and `verify-direct-p2p-session-evidence-bundle` verifies
  declared PASS artifacts exist and match SHA-256 hashes before promotion.
- Risk level: Medium.
- Verification command or strategy:
  Decide whether report validation or release evidence verification owns file
  existence/hash checks; then add a focused verifier test for missing and
  mismatched artifacts.
- Confidence: Medium.

## Coverage gaps and uncertainty

- Full line-by-line inspection was not performed for all Swift, Python, shell,
  C, vendored Opus, or JPEG XS reference files.
- Core Audio realtime callback paths, UDP/P2P socket runners, NAT routes,
  NMP workflow internals, and full SwiftUI rendering were sampled through
  high-risk documents and targeted searches, not exhaustively audited.
- ThreadSanitizer coverage is blocked on this host per
  `docs/verification-baseline.md`; race-condition findings here are therefore
  source-review based, not sanitizer-backed.
- Docker parity behavior is inferred from scripts and the baseline blocker; the
  parity scripts were not run because `docker ps` hung during baseline.
- Hardware/peer interoperability, real audio devices, Windows LoLa, UltraGrid,
  JackTrip, camera capture, packet capture, and PTP/clock evidence were not run.

## Recommended next audit targets

1. Re-audit Direct P2P PASS evidence gates only when report schema,
   `usefulMediaProof`, DSCP, artifact-bundle verification, or promotion
   workflows change.
2. Re-audit Python Linux connector parsing/reassembly only when media/control
   parsing changes or Windows/WSL runtime evidence contradicts the current
   tests.
3. Re-audit executable CLI test freshness when adding tests that invoke a
   fixed-path `open-lola` binary or a generated release-candidate executable.
4. Re-run Docker/reference-peer parity audits after the Docker daemon and
   reference peer environment are available.
5. Audit remaining runtime correctness gaps that were not exhaustively covered:
   realtime audio callbacks, UDP/P2P concurrency, physical two-peer
   interoperability, hardware capture, manual app/operator behavior beyond the
   locally passed AX launch verifier, and field teardown behavior.
