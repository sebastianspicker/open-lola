# Active Test Quality Audit

Date: 2026-05-16
Status: completed test-quality remediation
Verdict: PASS for the test-quality target; product runtime evidence remains
separately governed by the project `PARTIAL` gates.

This audit accounts for the active test surface and identifies tests that create
false confidence, duplicate low-signal checks, or miss runtime risks. It does
not change production code, tests, fixtures, or verification scripts. The
remediation ledger below records follow-up implementation slices.

## Scope

Included:

- `Tests/OpenLolaCoreTests/*.swift`
- `Tests/OpenLolaCoreTests/Fixtures/**`
- `linux_connector/tests/*.py`
- Active verification contracts referenced by `docs/testing/README.md`

Excluded:

- `archive/**`
- historical documentation snapshots
- generated build output
- implementation remediation

## Inventory

Live inventory commands:

```bash
find Tests/OpenLolaCoreTests -maxdepth 1 -type f -name '*.swift'
find Tests/OpenLolaCoreTests/Fixtures -type f
find linux_connector -path '*/tests/*' -type f
rg -n "@Test|#expect|def test_|assert |pytest.raises" Tests/OpenLolaCoreTests linux_connector/tests
```

Observed counts:

| Surface | Files | Test declarations | Check calls | Notes |
|---|---:|---:|---:|---|
| Swift test files | 168 | 454 `@Test`; full Swift suite passed with 454 executed Swift Testing tests | 3,944 `#expect` | Includes support-only helper files with no `@Test`; high-density zero-argument files now use semantic scenario wrappers with selected high-signal helper bodies. Low-signal helper bodies, source-only test files, and source-scanning meta-tests were deleted instead of only hiding old micro-tests behind wrappers. |
| Swift fixtures | 56 | n/a | n/a | 53 JSON fixtures and 3 packet hex fixtures. |
| Python connector tests | 3 | 71 `def test_`; 87 collected cases | 195 `assert`/`pytest.raises` | Source-text guards were removed; parametrization expands to 87 collected tests; remaining private seams are tracked below. |

Signal flags:

| Signal | Count | Meaning |
|---|---:|---|
| Swift source-code substring/range scanner lines | 0 | Source-code substring assertions and regex scanners were eliminated from active Swift tests. |
| Swift `String(contentsOf:)` file-read lines | 16 | Remaining file reads cover temp outputs, generated logs, docs, scripts, and policy files rather than production Swift source-substring assertions. |
| Swift files with `String(contentsOf:)` reads | 13 | These are still worth periodic review, but they are no longer counted as source-text assertion guards. |
| Python files reading source text | 2 | `test_codec.py` and `test_process_runtime.py`. |
| Files with 50+ checks | 40 | High duplication risk, especially when checks are literals. |

## High-Signal Coverage To Keep

The suite is not merely shallow. Keep the following classes of coverage:

- Protocol/parser/serialization tests that mutate packet bytes, reject malformed
  datagrams, verify codec round trips, and preserve LoLa control/media
  contracts.
- Runtime behavior tests that exercise failure propagation, cleanup, malformed
  payload counters, explicit partial/fail verdicts, and no-fake-success states.
- Realtime audio tests that exercise injected capture, playout buffering,
  channel mapping, sequence gaps, duplicates, reorder handling, drop counters,
  and overflow rejection through real public or test-only seams.
- Python connector tests that run control/media parsing, loopback selftests,
  process lifecycle failures, malformed payload handling, and bounded CLI
  validation.
- Fixture/schema tests that prevent synthetic `PASS` reports from bypassing
  measured-evidence gates.

## Findings

### TQA-001 Source-Text Guards Dominate High-Risk Coverage

- ID: TQA-001
- Severity: P1
- Category: false confidence / brittle test design
- Subsystem: realtime audio, UDP/P2P, release tooling, Python connector
- File: `Tests/OpenLolaCoreTests/UdpPcmRouteReportTests.swift`,
  `Tests/OpenLolaCoreTests/RealtimeAudioPacketHandoffTests.swift`,
  `Tests/OpenLolaCoreTests/VerificationToolingContractTests.swift`,
  `linux_connector/tests/test_process_runtime.py`
- Line range or symbol:
  - `UdpPcmRouteReportTests.swift:202-229`, `416-571`
  - `RealtimeAudioPacketHandoffTests.swift:184-207`
  - `VerificationToolingContractTests.swift:4-90`
  - `test_process_runtime.py:183-191`, `394-415`
- Evidence: 132 active test files contain source-text or broad string guards.
  The audit counted 1,985 string/source assertion lines. The listed examples
  assert substrings such as function names, shell snippets, source comments,
  lock names, `contains(...)`, and absence of implementation text.
- Why it matters: A source substring can stay present while behavior breaks, or
  disappear during a correct refactor. In runtime-critical paths, this can hide
  invalid state transitions, fake success, callback blocking, or packet loss.
- Runtime/user impact: Operators may receive green tests for code that still
  mishandles realtime callbacks, socket readiness, process cleanup, or release
  readiness behavior.
- Suggested remediation: Rewrite source-text guards into behavioral seams when
  the behavior can be exercised. Keep source-text guards only for policy-level
  invariants that have no practical runtime seam, and move those into fewer
  focused contract tests.
- Disposition: rewrite
- Candidate replacement coverage: direct API tests for state transitions,
  callback results, parser errors, report validator output, subprocess cleanup,
  socket helper behavior, and CLI exit/status output.
- Verification required: focused Swift/Python tests for each rewritten file,
  then full Swift and Python matrices.
- Suggested test: Replace one source-text group at a time with failing tests
  that mutate inputs or invoke the runtime seam and assert the observable error,
  counter, report verdict, or output.
- Risk of change: medium
- Confidence: high

### TQA-002 Report, Fixture, And Inventory Tests Are Overlapping

- ID: TQA-002
- Severity: P2
- Category: duplication / low-signal regression surface
- Subsystem: report schemas, fixture matrix, release evidence ledgers
- File: `Tests/OpenLolaCoreTests/FixtureSmokeMatrixTests.swift`,
  `Tests/OpenLolaCoreTests/ReportSchemaInventoryTests.swift`,
  `Tests/OpenLolaCoreTests/*ReportTests.swift`,
  `Tests/OpenLolaCoreTests/Fixtures/**`
- Line range or symbol:
  - `FixtureSmokeMatrixTests.swift:6-97`
  - `ReportSchemaInventoryTests.swift:6-178`
- Evidence: `FixtureSmokeMatrixTests` checks fixed fixture counts, fixture
  group names, synthetic smoke command labels, and high-risk false-pass groups.
  `ReportSchemaInventoryTests` repeats owner/linkage/schema assertions across
  the same fixture and validator surface. Many report-specific files repeat JSON
  round-trip, `PARTIAL` verdict, fixture count, and validator-output checks.
- Why it matters: Repeated count and literal checks make the suite large without
  proportionally increasing regression confidence. They also make legitimate
  schema evolution expensive because many tests fail for one intended change.
- Runtime/user impact: Maintainers may spend time updating duplicated fixture
  metadata while runtime gaps in audio/video/network behavior remain uncovered.
- Suggested remediation: Keep one authoritative inventory test per public
  matrix, merge duplicated fixture-count and owner-link checks, and retain
  report-specific tests only where they validate unique pass/fail policy.
- Disposition: merge
- Candidate replacement coverage: a table-driven fixture/schema validator that
  checks every registered schema once, plus report-specific negative tests for
  high-risk false `PASS` conditions.
- Verification required: `swift test` and docs verifier because inventory
  contracts are also documented.
- Suggested test: One generated inventory comparison that maps schema entry to
  fixture group, validator command, synthetic smoke, owner file, and required
  measured-evidence flag.
- Risk of change: medium
- Confidence: high

### TQA-003 Realtime And Native AV Tests Still Rely On Synthetic Seams

- ID: TQA-003
- Severity: P1
- Category: missing coverage / runtime risk
- Subsystem: realtime audio, native AV, CoreAudio, TX/RX/local RX
- File: `Tests/OpenLolaCoreTests/DirectPeerRealtimeAudioGraphTests.swift`,
  `Tests/OpenLolaCoreTests/DirectPeerRealtimeAudioGraphRxBufferingTests.swift`,
  `Tests/OpenLolaCoreTests/AudioLoopbackRunTests.swift`,
  `Tests/OpenLolaCoreTests/BlackmagicReceiveRenderTests.swift`,
  `Tests/OpenLolaCoreTests/Madi*Tests.swift`
- Line range or symbol:
  - `DirectPeerRealtimeAudioGraphTests.swift:7-455`
  - `DirectPeerRealtimeAudioGraphRxBufferingTests.swift:7-29`
- Evidence: The realtime graph has useful injected capture/playout tests and a
  bounded concurrent producer/consumer probe, but these still run through
  synthetic seams. The active testing index explicitly leaves hardware/manual
  evidence gates open in `docs/testing/README.md`.
- Why it matters: Real device graphs fail under timing, callback ownership,
  channel layout, and start/stop races that synthetic unit seams do not fully
  model.
- Runtime/user impact: A green local suite can still miss callback blocking,
  stale IOProc state, device mismatch, partial stream startup, or misleading
  healthy/streaming status.
- Suggested remediation: Keep the synthetic tests, but add narrow host-local
  runtime probes that exercise lifecycle and failure transitions without real
  hardware when possible. Keep hardware evidence as manual/PARTIAL until real
  devices are tested.
- Disposition: keep plus add coverage
- Candidate replacement coverage: lifecycle start/stop state-machine tests,
  callback-safe counter tests, device-preflight negative cases, injected
  concurrent capture/render tests, and explicit `PARTIAL` report checks for
  missing hardware.
- Verification required: focused Swift tests for audio graph and report
  surfaces, then `swift test --no-parallel`.
- Suggested test: deterministic concurrent capture/render stress using the
  existing injected graph seam with bounded iterations and no sleeps in the
  callback path.
- Risk of change: medium
- Confidence: medium

### TQA-004 UDP/P2P Coverage Needs More Adverse Network Behavior

- ID: TQA-004
- Severity: P1
- Category: missing coverage / false confidence
- Subsystem: UDP, P2P, packet loss, jitter, reordering, duplicate packets
- File: `Tests/OpenLolaCoreTests/UdpPcmRouteReportTests.swift`,
  `Tests/OpenLolaCoreTests/UdpPcmLoopbackLatencyTests.swift`,
  `Tests/OpenLolaCoreTests/NatFriendlyRouteTests.swift`,
  `Tests/OpenLolaCoreTests/RealtimeAudioPacketHandoffTests.swift`,
  `linux_connector/tests/test_runtime_contracts.py`
- Line range or symbol:
  - `UdpPcmRouteReportTests.swift:553-571`
  - `RealtimeAudioPacketHandoffTests.swift:130-160`
  - `test_runtime_contracts.py:164-240`
- Evidence: Some packet loss, duplicate, malformed payload, and reorder seams
  exist. The remaining route tests heavily assert source strings around socket
  readiness, sleeps, fcntl sentinels, and loss accounting. Python runtime tests
  exercise malformed payload counters but not sustained jitter/loss/reorder.
- Why it matters: The project is latency and packet-loss sensitive. Single
  local loopback paths and source-text guards do not prove correct behavior
  under burst loss, delayed packets, duplicate packets, or backpressure.
- Runtime/user impact: Tests may miss receiver stalls, invalid loss metrics,
  silent drops, or optimistic route reports.
- Suggested remediation: Introduce deterministic in-memory or localhost
  datagram schedulers for loss, delay, duplicate, and reorder cases. Keep socket
  source guards only where platform APIs cannot be probed reliably.
- Disposition: rewrite plus add coverage
- Candidate replacement coverage: scripted packet schedules that assert unique
  sequence counts, loss totals, duplicate totals, jitter summaries, timeout
  behavior, and report verdicts.
- Verification required: focused UDP/P2P Swift tests and Python connector tests,
  then full Swift/Python matrices.
- Suggested test: a deterministic packet scheduler that feeds sequence
  `[1, 3, 2, 2, 5]` with controlled timestamps and verifies loss, reorder,
  duplicate, and playout behavior.
- Risk of change: medium
- Confidence: high

### TQA-005 Release/Docs Verification Tests Are Too Literal

- ID: TQA-005
- Severity: P2
- Category: maintainability / literal snapshot checks
- Subsystem: release readiness, docs verification, scripts
- File: `Tests/OpenLolaCoreTests/VerificationToolingContractTests.swift`,
  `Tests/OpenLolaCoreTests/ReleaseArtifactHygieneContractTests.swift`,
  `Tests/OpenLolaCoreTests/DocsVerifierPolicyTests.swift`,
  `Tests/OpenLolaCoreTests/AppBundleScriptSourcePolicyTests.swift`
- Line range or symbol:
  - `VerificationToolingContractTests.swift:4-90`
  - `ReleaseArtifactHygieneContractTests.swift:4-110`
- Evidence: `VerificationToolingContractTests` contains 197 checks, all
  dominated by source or literal string assertions. `ReleaseArtifactHygiene`
  similarly asserts many shell, manifest, and path literals while also running
  some higher-signal candidate/hygiene checks.
- Why it matters: Literal script/doc checks are easy to satisfy accidentally
  and expensive to maintain. The high-signal part is command behavior and
  output, not that exact substrings remain in one script.
- Runtime/user impact: Release-readiness tests may pass even when command
  behavior drifts, or fail loudly for harmless wording/path refactors.
- Suggested remediation: Keep behavioral script execution tests and compress
  source-text assertions into one minimal policy contract per script.
- Disposition: merge/rewrite
- Candidate replacement coverage: execute scripts against temporary valid and
  contaminated trees, assert exit codes and verifier output, and use a small
  allowlist of mandatory public path boundaries.
- Verification required: docs verifier, release hygiene script, focused Swift
  tests, and broader release-readiness gate when scripts change.
- Suggested test: candidate tree with a forbidden generated file, one with a
  forbidden private path, and one clean candidate; assert pass/fail outputs.
- Risk of change: low to medium
- Confidence: high

### TQA-006 Python Connector Has Good Runtime Tests Mixed With Private And Source Guards

- ID: TQA-006
- Severity: P2
- Category: test design / maintainability
- Subsystem: Python Linux connector
- File: `linux_connector/tests/test_codec.py`,
  `linux_connector/tests/test_process_runtime.py`,
  `linux_connector/tests/test_runtime_contracts.py`
- Line range or symbol:
  - `test_process_runtime.py:183-191`, `394-415`, `418-435`
  - `test_runtime_contracts.py:17-263`
- Evidence: Python tests include valuable parser, process lifecycle, timeout,
  malformed payload, and loopback coverage. Weaknesses are the source reads in
  `test_codec.py`/`test_process_runtime.py` and private-state assertions such
  as `_tasks`, `_audio_sock`, and socket lock registries.
- Why it matters: Private-state tests discourage refactors and do not always
  prove user-visible runtime behavior.
- Runtime/user impact: Connector implementation can be pinned to internal
  names while missing externally visible status, cleanup, or logging behavior.
- Suggested remediation: Keep behavior tests. Rewrite source reads and private
  member checks into public observable outcomes where practical.
- Disposition: keep plus rewrite selected tests
- Candidate replacement coverage: assert log records, socket closure effects,
  subprocess cleanup effects, CLI output/exit behavior, and runtime stats
  rather than private attributes.
- Verification required: `PYTHONDONTWRITEBYTECODE=1 python -m pytest -p no:cacheprovider linux_connector`.
- Suggested test: a fake socket/process backend with public observable close
  counters and runtime stats, not direct `_tasks` or source string checks.
- Risk of change: low
- Confidence: high

## Prune Ledger

| ID | Area | Action | Rationale |
|---|---|---|---|
| TQA-001 | Source-text guards in runtime and tooling tests | rewrite | Replace brittle substring checks with behavioral assertions. |
| TQA-002 | Report/schema/fixture overlap | merge | Keep unique false-pass and validator policy tests, merge repeated counts and ownership checks. |
| TQA-003 | Realtime/native AV synthetic-only gaps | keep plus add coverage | Existing synthetic tests are useful but insufficient for runtime risk. |
| TQA-004 | UDP/P2P adverse network behavior gaps | rewrite plus add coverage | Convert source guards into deterministic packet/loss/reorder behavior tests. |
| TQA-005 | Literal release/docs verification tests | merge/rewrite | Prefer command behavior over many script substring assertions. |
| TQA-006 | Python connector private/source guards | keep plus rewrite selected tests | Retain behavior coverage, reduce private/internal coupling. |

No active test file is recommended for immediate deletion without replacement.
Deletion should happen only after a merged or rewritten behavioral test proves
the same contract with less noise.

## Remediation Status

This ledger is active. Completed rows below are implementation slices, not a
claim that the whole audit is closed.

| Slice | Status | Files | Evidence |
|---|---|---|---|
| Make this audit an accepted active testing document | done | `docs/testing/README.md`, `scripts/verify_docs/markdown_checks.py` | `docs/testing/README.md` routes to this ledger and the docs verifier allows `docs/testing/test-quality-audit.md` as an intentional active testing surface. |
| Rewrite Python source-text guards | done | `linux_connector/tests/test_codec.py`, `linux_connector/tests/test_process_runtime.py` | OSC15 source identity, JPEG frame extraction, runtime TX gating, and UDP helper serialization now use behavior probes; duplicate source-comment checks were removed where adjacent behavior already covers the contract. |
| Rewrite Python private-state guards | done | `linux_connector/tests/test_process_runtime.py`, `linux_connector/tests/test_runtime_contracts.py` | Duplicate task-handle injection and internal cleanup-state assertions were removed; media/control malformed-payload checks now run through public `run_for`/stats/log behavior. The only retained private seams are deliberate white-box cleanup and loop-precondition probes: socket-lock registry cleanup after `close_udp_socket`, `_control_loop()` without an initialized control socket, and `_audio_tx_loop()` before an initialized audio socket. Rewriting those through public `run_for` would hide the precondition because startup initializes the sockets first; adding production hooks only for tests is not justified. |
| Rewrite Swift verification/release source guards | done | `Tests/OpenLolaCoreTests/VerificationToolingContractTests.swift`, `Tests/OpenLolaCoreTests/ReleaseArtifactHygieneContractTests.swift`, `Tests/OpenLolaCoreTests/VerificationToolingPairScriptTests.swift`, `Tests/OpenLolaCoreTests/ExternalConnectorProcessGroupTests.swift` | Redundant release-hygiene and export-script source substring assertions were pruned where the same file already runs the scripts against clean and contaminated candidate trees. The densest release-readiness matrix assertion was compressed to externally meaningful gates and commands instead of helper internals, and the release-readiness matrix now sources the real script, overrides execution functions, calls `main`, and asserts the emitted orchestration. JackTrip and UltraGrid Docker policy, paired JackTrip RX/TX orchestration, paired UltraGrid Docker RX/TX orchestration, paired native UltraGrid RX/TX preflight success/failure and metrics orchestration, parity timestamp coverage, the active-plan docs contract, release-readiness manual-gate output, the WSL LoLa network helper dry-run, native UltraGrid connection metrics, UltraGrid parity metrics, UltraGrid stress summary behavior, native UltraGrid Dockerfile policy, native UltraGrid wrapper mode/refusal behavior, UltraGrid Docker wrapper role/port behavior, and external connector role environment propagation now run behavior through fail-fast wrapper invocations, fake Docker/executable seams, synthetic journals, verifier-function execution, a sourceable release-readiness helper, a PowerShell `-WhatIf` temp-config probe, direct metrics-writer execution, a fake child-compare seam, deterministic Dockerfile instruction parsing, and a real runner fake-executable seam instead of broad shell/PowerShell/Python/Swift source text assertions. Overlapping UltraGrid mutable-`latest`, local UltraGrid Docker literal documentation, native app bundle helper documentation, UltraGrid Docker helper-internal function names, UltraGrid comparator/stress helper internals, release-readiness hygiene-gate checks, direct-P2P CLI source checks, video transport source checks, and UDP media source checks were merged into behavior or parsed-policy coverage. Remaining file reads in the listed verification/release suites are explicit docs, workflow, manifest, Dockerfile, or release-boundary policy contracts. |
| Merge fixture/schema/report duplicate checks | done | `Tests/OpenLolaCoreTests/FixtureSmokeMatrixTests.swift`, `Tests/OpenLolaCoreTests/ReportSchemaInventoryTests.swift`, report fixture suites | The first low-risk pass pruned source-shape checks that only asserted implementation grouping names or schema-policy field declarations. A second pass replaced fixed literal totals for fixture files, extension counts, schema count, clean-Mac gates, and false-PASS fixtures with derived checks against the active fixture tree and inventory entries. A third pass removed two report-validator implementation-shape source guards because adjacent tests already exercise validator output, strict validation failures, JSON coding, metadata conformance, CLI validator mapping, fixture links, inventory summaries, and JSON surfaces. A fourth pass replaced E2E benchmark source guards for synthetic audio deltas, key-value parser use, and CLI missing-input labels with report/parser/executable behavior, and deleted a duplicate threshold source scan already covered by threshold mutation behavior. A fifth pass replaced Drift PLC fixed-target and key-value parser source scans with direct fixed-target and parser error behavior. A sixth pass replaced the Integrated AV key-value parser source scan with parser error behavior. A seventh pass replaced the Hardware Validation required-route source scan with route-enforcement behavior derived from the active route enum. An eighth pass replaced the Reference Rig stable-buffer source/comment scan with PASS threshold-target enforcement behavior. A ninth pass replaced two RME fastest-path implementation scans with Thunderbolt helper behavior and dynamic supported-sample-rate validation behavior. A tenth pass removed Integrated Profile runtime-evidence helper-name trivia and replaced combined-metric source scans with generated report behavior for worst-case gauges and summed event counts. An eleventh pass replaced Integrated AV validation/helper source scans with sync-policy and scalar-field validation behavior. A twelfth pass replaced Direct Peer prototype FNV/video comment scans with hash, SSRC, digest, and frame-proof behavior, and deleted an overlapping raw-audio metadata comment guard already covered by raw-audio reassembly behavior. A thirteenth pass replaced the Direct Peer two-peer run-plan peer-ID extraction source scan with prototype-report builder behavior that proves configured peer IDs are used instead of report IDs and empty peer lists fail validation. A fourteenth pass pruned CoreAudio fallback-cache and property-address source-shape checks as implementation trivia while retaining hard-to-observe CoreFoundation ownership, AudioBufferList allocation, and four-character-code guards. A fifteenth pass replaced the DebugTrace file-backed/print-debugging source scan with an actual temp-file `write(to:)` JSONL behavior check. A sixteenth pass replaced DirectPeer audio payload ring helper-name and alignment source scans with public metadata, selective release, and payload-address alignment behavior. A seventeenth pass replaced Blackmagic receive/render latency-buffer source scans with rolling-window renderer behavior. An eighteenth pass replaced the PeerSession metrics/control session-ID source scan with negotiation behavior proving length-prefixed peer IDs in the accepted configuration. A nineteenth pass replaced LoLa live UDP media routing source scans with direct routing-predicate behavior for generated, AVFoundation raw8, unsupported live capture, and audio-only modes. A twentieth pass replaced the LoLa raw-link BPF source-offset guard with packet-extraction behavior that proves the parser honors captured-length and header-length fields. A twenty-first pass replaced the LoLa control-socket bind-errno source scan with socket behavior that proves success clears stale `errno` while invalid descriptors still report `EBADF`. A twenty-second pass pruned a duplicate LoLa quick-connect control-parser source scan because adjacent behavior already proves unescaped semicolon text is preserved and control datagrams still parse/truncate correctly. A twenty-third pass replaced the remaining RME fastest-path placeholder checklist source scan with validator behavior for static and dynamic placeholder fields. A twenty-fourth pass pruned KeyValueArgumentParser source-comment checks because adjacent behavior already proves dash-prefixed values, callback routing, and boolean default token sets. A twenty-fifth pass replaced the MediaClock implementation source guard with full-width frame-count conversion and half-up rounding behavior. A twenty-sixth pass pruned a DirectPeer manual-validation source scan because the same test already proves `inet_pton` failure status is preserved in the public error. A twenty-seventh pass replaced the native app Opus storage source scan with `AppShellStoredDefaults` behavior for persisted `audioTransport` and legacy `audioCompression` migration. A twenty-eighth pass replaced the LoLa UDP media socket fallback source scan with socket behavior proving an unassigned specific host falls back to wildcard binding on the requested port. A twenty-ninth pass replaced the Rx impairment deterministic-jitter source scan with seeded packet-age behavior. The final pass moved report false-pass fixture authority into `ReportSchemaInventory`, made `FixtureSmokeMatrixTests` derive high-risk false-pass groups from that inventory, replaced remaining low-signal Mac-to-Mac, LoLa parity, recording-session, source-ownership, and video-transport report source-shape checks with behavior, and leaves hard-to-observe runtime source guards to the separate runtime-source-guard rows. |
| Add adverse UDP/realtime runtime schedules | done | UDP/P2P and realtime audio Swift/Python runtime tests | `RealtimeAudioPacketHandoffTests.swift` now drives an out-of-order, missing, duplicate receive schedule through public receive/render calls and asserts truthful loss/reorder/duplicate/underrun/overrun metrics. `UdpMediaTransportTests.swift` now runs the audit-recommended `[1, 3, 2, 2, 5]` loopback packet schedule and asserts received/lost/late/reordered/duplicate counters, and its packet-codec guards now use malformed nested payloads instead of source scans. `DirectPeerRealtimeAudioGraphTests.swift` covers a bounded concurrent synthetic capture producer and payload consumer without sleeps. `UdpPcmContinuousReceiverTests.swift` runs the continuous UDP PCM receiver against a duplicate/missing sequence schedule and validates unique-packet loss accounting. `UdpPcmLoopbackLatencyTests.swift` drives the UDP PCM socket sender against a fake echo peer that sends a duplicate echo instead of one unique sequence, and the sender now reports loss from unique echoes. `PeerSessionRunnerLifecycleTests.swift` and `DirectPeerSessionProductionAVRegressionTests.swift` cover code-level shutdown and production AV preflight/blocker behavior; physical native AV and hardware lifecycle proof remains a release-evidence gate, not a deterministic unit-test remediation item. |
| Semantic-prune high-density zero-argument Swift tests below 500 | done | 44 high-density `Tests/OpenLolaCoreTests/*.swift` files | Raw Swift `@Test` declarations dropped from 800 to 470 in the first semantic-prune pass, and the retained semantic scenarios kept representative runtime, parser, report, packet-loss, AV, UI-truthfulness, source-policy, and false-PASS checks. Follow-up source-scanner pruning dropped the active Swift surface to 454 `@Test` and 3,944 direct `#expect` calls. |
| Eliminate remaining Swift source-text assertions | done | `AudioLoopbackRunTests.swift`, `SPSCAtomicRingTests.swift`, `MadiReceiveSourceAndReportTests.swift`, `CoreAudioInventoryTests.swift`, `RecordingSessionLiveCaptureTests.swift`, `UdpPcmV2PacketTests.swift`, `DirectAudioMediaRouterTests.swift`, `BoundedFileReaderTests.swift`, `PlaceholderDetectionTests.swift`, `NativeAppShellArtifactTests.swift`, `PackagingFieldTestTests.swift`, `ReleaseRunConfigurationContractTests.swift`, `AppShellSourceContractTests.swift`, `GoalReportContractTests.swift`, and related source-only guards | Active Swift literal `source.contains` assertions dropped from 157 to 0. Source-only assertions were either replaced with behavior (`DirectAudioMediaRouter`, `BoundedFileReader`, LoLa packet fixture temp directories) or deleted where adjacent behavior already covers the runtime/report contract. |
| Remove broad Swift source-code scanners | done | `VideoCaptureReportTests.swift`, `RealtimeAudioPacketHandoffTests.swift`, `ExternalConnectorSessionTests.swift`, `LoLaCompatibilityTcpControlTests.swift`, `PeerSessionAVSupportVideoTests.swift`, `PeerSessionAVSupportTests.swift`, `CLICommandInventoryTests.swift`, `FixtureSmokeMatrixTests.swift`, `LoLaParityDeferredFeaturesTests.swift`, `VerdictValidationPolicyTests.swift`, deleted `SwiftTestingDiscoveryTests.swift`, deleted `ValidateAssertionContractTests.swift` | The refined source-scanner pattern now reports 0 production-Swift substring/range/regex scanner guards. Broad `String(contentsOf:)` reads dropped from 42 to 16 across 11 files; retained reads are temp outputs, generated logs, docs, scripts, and policy files. Focused Swift verification passed with 50 selected tests, and full Swift verification passed with 454 executed Swift Testing tests. |
| Prune DirectPeer graph source guards | done | `Tests/OpenLolaCoreTests/DirectPeerRealtimeAudioGraphTests.swift` | Removed 12 source-string/doc/order guards from the over-budget realtime graph test file. A follow-up pass grouped injected-capture IOProc rejection with payload borrow lifetime, overflow start-frame rejection with drop/underrun accounting, RX-buffer target delay with reordered due-frame playout, and zero-channel input/output rejection. The remaining 9 tests keep runtime behavior coverage for legacy config migration, interleaved and multibuffer channel mapping, preflight validation, bounded playout/drop accounting, adverse concurrent capture handoff, and zero-channel failure. |
| Prune AudioLoopback conversion trivia source guard | done | `Tests/OpenLolaCoreTests/AudioLoopbackRunTests.swift` | Removed the microseconds-per-second naming source guard as implementation trivia. A later source-assertion purge removed the remaining AudioLoopback source-string assertions; retained coverage now comes from parser/profile behavior, RX-buffer handoff configuration, host-time conversion, endpoint metric defaults, RME MADI preflight, run-report round trip, and completed-run handoff validation. |
| Prune CoreAudio inventory source-shape guards | done | `Tests/OpenLolaCoreTests/CoreAudioInventoryTests.swift` | Removed CoreAudio source-shape scans. Existing behavior still proves fallback identity values and diagnostics, fixture validation, channel layout validation, channel-set selection, and JSON round trip. |
| Prune CoreAudio inventory model/source-contract micro-tests | done | `Tests/OpenLolaCoreTests/CoreAudioInventoryTests.swift` | Grouped empty, mismatched-layout, and unknown-device validation failures; grouped buffer-frame classification, synthesized channel labels, stable channel selection, and fallback identity diagnostics. Valid inventory JSON round trip remains separate. |
| Rewrite DebugTrace file-backed source guard | done | `Tests/OpenLolaCoreTests/DebugTraceTests.swift` | Replaced the file-backed trace/source-no-print scan with a temp-file `DebugTrace.write(to:)` behavior test that proves JSONL output, directory creation through the requested path, and trailing newline behavior. Retained the encoding-fallback source guard because the public Codable path cannot deterministically force `JSONEncoder` failure without widening production test seams. |
| Rewrite DirectPeer audio payload ring source guards | done | `Tests/OpenLolaCoreTests/DirectPeerAudioPayloadRingTests.swift` | Replaced private push-helper and storage-alignment substring checks with behavior that proves frame metadata, host-time metadata, selective `copyPayload` release, stale-payload dropping, and payload preservation under concurrent producer/consumer load. A later source-assertion purge removed the remaining raw-pointer/capacity source scans. |
| Rewrite Blackmagic receive/render latency-buffer source guard | done | `Tests/OpenLolaCoreTests/BlackmagicReceiveRenderTests.swift` | Replaced the `VideoOutputRenderer` bounded-sample source scan with behavior that renders 10,005 frames, seeds the first five with high receive-to-reassembly latency, and proves the public metrics window reports only the recent low-latency samples. Removed the file reader from this suite. |
| Prune Blackmagic receive/render micro-tests | done | `Tests/OpenLolaCoreTests/BlackmagicReceiveRenderTests.swift` | Grouped stream-bucket, duplicate-fragment, and incomplete-flush reassembler metrics; grouped deadline, backpressure, continuity, and rolling latency-window renderer behavior; and grouped synthetic smoke, DeckLink boundary report, explicit PARTIAL limitation, and physical-output PASS rejection. Reassembler safety, renderer pacing, latency metrics, and Blackmagic false-PASS policy remain covered. |
| Rewrite PeerSession metrics/control session-ID source guard | done | `Tests/OpenLolaCoreTests/PeerSessionMetricsAndControlTests.swift` | Replaced source scans for private session-ID helper shape and call sites with a loopback negotiation behavior test that asserts the accepted audio session ID uses explicit local/remote byte counts. The first behavior attempt used slash-delimited peer IDs and correctly failed validation as `invalidCLIIdentifier`; the final test uses CLI-safe hyphenated IDs. |
| Rewrite LoLa live UDP media routing source guard | done | `Tests/OpenLolaCoreTests/LoLaLiveUdpMediaRoutingTests.swift` | Replaced source scans for AVFoundation raw8 live routing with direct `shouldUseLoLaLiveSocketTransmitter` behavior. The test now proves generated video, AVFoundation raw8 video, unsupported live capture, generated audio-only, and raw8 audio-only routing decisions without starting sockets or camera capture. |
| Prune KeyValueArgumentParser source-comment guards | done | `Tests/OpenLolaCoreTests/KeyValueArgumentParserTests.swift` | Removed source-comment assertions from parser policy, positive-integer callback, and boolean-default tests. Existing behavior still proves dash-prefixed values, negative numbers, empty values, duplicate/unknown/malformed keys, required positive-integer error callbacks, named default boolean sets, case-insensitive true/false parsing, and invalid boolean routing. |
| Rewrite MediaClock implementation source guard | done | `Tests/OpenLolaCoreTests/MediaClockTests.swift` | Replaced source assertions for full-width multiplication and rounding internals with public `MediaClock.nanoseconds` behavior. The test now proves `UInt64.max` frame counts at 1 GHz convert without overflowing intermediate multiplication, and that exact half and below-half fractional nanoseconds round as expected. Crash-on-overflow behavior remains untested because Swift Testing does not provide a narrow death-test seam here. |
| Prune DirectPeer manual-validation source guard | done | `Tests/OpenLolaCoreTests/DirectPeerManualValidationTests.swift` | Removed the source assertions for `inet_pton` status plumbing. The public validator test already proves unsupported hostnames throw `invalidManualHostParse` with the preserved status value, and native app settings still route through the shared manual-network validation. |
| Rewrite native app Opus storage source guard | done | `Tests/OpenLolaCoreTests/NativeAppShellOpusCommandTests.swift` | Replaced app-source string scans with `OpenLolaAppSupport` behavior. The test now proves persisted `audioTransport` hydrates Opus only with an Opus-compatible audio shape, and legacy `audioCompression=opus-celt-ld` migrates to `audioTransport=openlola-opus-celt-ld` while removing the legacy key. |
| Rewrite LoLa UDP media socket fallback source guard | done | `Tests/OpenLolaCoreTests/LoLaUdpMediaSocketTests.swift` | Replaced source assertions for wildcard fallback binding with socket behavior. The first cleanup-on-failure behavior attempt was not deterministic on macOS because duplicate UDP binds can succeed with reuse semantics; the final test uses an unassigned IPv4 host and proves the returned socket is bound to `0.0.0.0` on the requested port. |
| Rewrite Rx impairment deterministic-jitter source guard | done | `Tests/OpenLolaCoreTests/RxBufferingTests.swift` | Replaced source assertions for PCG-style jitter internals with seeded simulator output behavior. The test now proves the first five packet ages for a fixed seed, packet shape, base transit, and jitter amplitude. |
| Rewrite LoLa raw-link BPF source-offset guard | done | `Tests/OpenLolaCoreTests/LoLaCompatibilityRawLinkAndUdpMediaTests.swift`, `Tests/OpenLolaCoreTests/LoLaCompatibilityMediaSessionSupportTests.swift` | Replaced the raw-link BPF implementation-symbol scan with a packet-extraction behavior test. The support helper now allows a non-default BPF header length, and the test proves `extractBpfPackets` reads the captured length and header length from the record fields rather than assuming the minimum header layout. |
| Rewrite LoLa control-socket bind-errno source guard | done | `Tests/OpenLolaCoreTests/LoLaCompatibilityControlSocketTests.swift` | Replaced the bind helper implementation scan with socket behavior. The test now seeds stale `errno`, verifies a successful loopback bind returns zero, and verifies an invalid descriptor returns `EBADF`; the suite no longer reads `LoLaCompatibilityControlSocket.swift`. |
| Prune LoLa quick-connect parser source guard | done | `Tests/OpenLolaCoreTests/LoLaQuickConnectFallbackTests.swift` | Removed a duplicate source scan for the old `acceptsTruncatedText` parser shape. `lolaControlParserPreservesUnescapedTextSemicolons()` already proves `TXT` absorbs unescaped semicolon suffixes, and the datagram test still validates 1,024-byte control messages with long text truncation. The suite no longer reads `LoLaCompatibilityControlMessage.swift`. |
| Rewrite UDP packet codec source guard | done | `Tests/OpenLolaCoreTests/UdpPcmPacketTests.swift` | Removed the remaining source-file reads from the packet codec suite. `networkPacketTypesSharePacketCodecContract()` now proves shared `PacketCodec` conformance with compile-time generic constraints plus real encode/decode round trips for UDP PCM v1, UDP PCM v2, UDP media envelope, and Opus CELT low-delay packets; malformed packet tests keep the checked-reader behavior coverage. |
| Rewrite UDP route configuration source guards | done | `Tests/OpenLolaCoreTests/UdpPcmRouteReportTests.swift`, `Tests/OpenLolaCoreTests/UdpPcmContinuousReceiverTests.swift`, `Tests/OpenLolaCoreTests/CLICommandInventoryTests.swift`, `Sources/OpenLolaCore/Network/UDP/UdpPcmRouteCertification.swift` | Removed configuration-validation source assertions from the UDP route report suite. Parser validation, programmatic initializer validation, packet-count overflow, packet-age percentile behavior, zero-byte UDP receive rejection, checked deadline arithmetic, UDP/NAT positive-integer bounds, invalid nonblocking descriptor handling, socket-readiness helper behavior, source-address receive behavior, UDP route CLI help flag exposure, requested UDP socket buffer readback, and continuous receiver mode rejection plus duplicate/loss accounting are now checked through public route/socket/executable behavior. The remaining caller-readiness placement source guards were pruned as overlapping implementation-shape checks because the active suite already exercises socket readiness, continuous localhost route, UDP loopback localhost smoke, NAT rendezvous/relay localhost smokes, and DirectPeer AV wait-timeout behavior. |
| Rewrite UDP route packet-age and zero-byte receive guards | done | `Tests/OpenLolaCoreTests/UdpPcmRouteReportTests.swift` | Replaced packet-age implementation-body substring checks with unsorted/duplicate sample behavior assertions and replaced the zero-byte receive source guard with a real loopback UDP zero-length datagram that must throw `receiveFailed(EINVAL)`. |
| Rewrite UDP route deadline/bounds/fcntl guards | done | `Tests/OpenLolaCoreTests/UdpPcmRouteReportTests.swift` | Replaced deadline arithmetic, UDP/NAT integer-bound, and fcntl sentinel source guards with direct helper overflow checks, parser rejection behavior for over-limit route/NAT values, and invalid descriptor behavior through `setNonBlocking(-1)`. |
| Rewrite UDP route readiness/source-address guards | done | `Tests/OpenLolaCoreTests/UdpPcmRouteReportTests.swift` | Replaced the socket-readiness helper source assertions with real loopback `waitForReadableSocket` false/true behavior and replaced source-address receive substring checks with `receiveDatagramWithSourceIfAvailable` data/host/source-port assertions. |
| Rewrite UDP route CLI help source guard | done | `Tests/OpenLolaCoreTests/UdpPcmRouteReportTests.swift`, `Tests/OpenLolaCoreTests/CLICommandInventoryTests.swift` | Moved the physical-evidence flag check out of a `main.swift` source scan and into the executable CLI inventory suite, where `open-lola udp-pcm-route-run --help` must expose the flags in real command output. |
| Rewrite UDP socket buffer source guard | done | `Tests/OpenLolaCoreTests/UdpPcmRouteReportTests.swift` | Replaced the UDP socket buffer implementation substring guard with a real `makeUdpSocket` readback test that verifies both `SO_RCVBUF` and `SO_SNDBUF` are at least the requested 4 MiB on this macOS runtime. |
| Rewrite UDP continuous receiver mode/duplicate/loss guards | done | `Tests/OpenLolaCoreTests/UdpPcmContinuousReceiverTests.swift`, `Tests/OpenLolaCoreTests/UdpPcmRouteReportTests.swift`, `Sources/OpenLolaCore/Network/UDP/UdpPcmRouteCertification.swift` | Replaced the continuous receiver mode-order and unique-sequence source guards with a public loopback receiver run that sends a wrong-mode sequence `1` plus valid `[0, 2, 2]` for a four-packet epoch and asserts received, lost, duplicate, and rx-buffer duplicate metrics. The slice also fixed route report validation so partial duplicate reports validate when `lostPackets` is computed from non-duplicate received packets. |
| Fix UDP loopback duplicate-echo loss accounting | done | `Tests/OpenLolaCoreTests/UdpPcmLoopbackLatencyTests.swift`, `Sources/OpenLolaCore/Network/UDP/UdpPcmLoopbackSocketRunners.swift` | Added a fake loopback echo peer that returns sequence `0` twice while the sender transmits sequences `0` and `1`; the sender now computes `lostPackets` from unique echoed sequences so a duplicate echo cannot hide a missing packet. The same pass removed loopback default, UUID, and bound-port source scans because synthetic/default report behavior, generated UUID parsing, and localhost smoke execution now cover those contracts directly. |
| Prune report-validator source-shape guards | done | `Tests/OpenLolaCoreTests/ReportSchemaInventoryTests.swift` | Removed two tests that scanned `ReportValidatorSurface.swift` and Integrated AV validation source for protocol/helper shape. The remaining schema inventory tests keep behavior coverage for validator output, extra lines, strict validation failure, JSON coding, metadata conformance, CLI validator coverage, fixture/smoke links, owners/tests, schema summaries, and JSON round trip. |
| Prune report schema inventory micro-tests | done | `Tests/OpenLolaCoreTests/ReportSchemaInventoryTests.swift` | Grouped validator output, extra-line, strict-failure, and JSON coding behavior; grouped metadata conformance, CLI validator coverage, fixture/smoke links, and owner/test path checks; and grouped LoLa UDP media evidence with parity validation-only policy. |
| Prune network diagnostics parser/report/process micro-tests | done | `Tests/OpenLolaCoreTests/NetworkDiagnosticsTests.swift` | Grouped macOS ping parsing with malformed summary handling, grouped traceroute hop timing with bracketed IPv6 normalization, grouped PASS policy/verdict/JSON round-trip behavior, and grouped verbose-output draining with timeout handling for a SIGTERM-ignoring child. |
| Rewrite validation primitive source guards | done | `Tests/OpenLolaCoreTests/ValidationPrimitivesTests.swift` | Removed source inventory checks from the validation primitive suite. The tests now exercise shared validator protocol extensions directly with a test validator, keep existing real-validator error routing coverage, and assert percentile ordering behavior through `timingPercentilesAreOrdered` instead of source substring checks. |
| Prune source naming and release config policy trivia | done | `Tests/OpenLolaCoreTests/SourceNamingConventionTests.swift`, `Tests/OpenLolaCoreTests/ReleaseRunConfigurationContractTests.swift` | Removed the source-file TODO substring guard from the two-peer prototype naming test, merged duplicate policy-document assertions into one clean-room naming/command/schema contract, and grouped release-run source-doc contracts with the testing-index harness contract. Remaining checks are policy-level invariants with no runtime seam, not separate implementation-shape tests. |
| Rewrite Opus packet source guard | done | `Tests/OpenLolaCoreTests/AudioOpusCeltLowDelayPacketTests.swift` | Replaced the checked-reader source substring guard with malformed packet decode assertions for truncated headers, invalid magic, unsupported version, invalid header guard, and payload length mismatch. |
| Rewrite Opus codec source guards | done | `Tests/OpenLolaCoreTests/OpusCELTLowDelayCodecTests.swift` | Replaced source substring checks for force-unwrap avoidance and scratch-buffer API exposure with caller-owned scratch-buffer capacity behavior. The suite now proves successful scratch-buffer encode/decode plus deterministic encode/decode errors for undersized caller buffers. |
| Rewrite Opus CLI source guard | done | `Tests/OpenLolaCoreTests/DirectPeerSessionOpusCLITests.swift` | Replaced source substring checks for hidden legacy `--audio-compression` migration with executable CLI behavior. The suite now verifies help exposes only canonical `--audio-transport`, legacy compression still parses through the canonical transport scope error, and the default raw transport does not trigger audio-video-only validation. |
| Rewrite release-readiness matrix source guard | done | `Tests/OpenLolaCoreTests/VerificationToolingContractTests.swift` | Replaced source substring checks for the local release matrix with a sourceable script probe that overrides execution functions, calls `main`, and asserts the actual orchestrated docs, shellcheck, ruff, pytest, mypy, release hygiene, Swift build/test, CLI probe, native-app, and final partial-verdict sequence without running the expensive gates. |
| Rewrite release-readiness manual-gate source guard | done | `Tests/OpenLolaCoreTests/VerificationToolingContractTests.swift`, `scripts/verify-release-readiness.sh` | Wrapped the release-readiness script's executable body in `main` so tests can source helper functions without running the full gate. `releaseReadinessScriptKeepsReleaseBoundaryExplicit()` now invokes `manual_hardware_signing_gate` and asserts the emitted manual evidence and release-exclusion policy instead of scanning the script body. |
| Rewrite UltraGrid parity metrics writer source guard | done | `Tests/OpenLolaCoreTests/VerificationToolingContractTests.swift`, `scripts/lib/write-ultragrid-parity-metrics.py` | Replaced source substring checks for parity metric fields with a direct metrics-writer execution against synthetic direct/managed UltraGrid logs. The behavior test proves comparison booleans, endpoint-health flags, and display-FPS minima in the emitted JSON, and exposed/fixed Python 3.9 incompatibility by removing `zip(..., strict=True)` after the existing even-argument validation. |
| Prune duplicate JackTrip helper source checks | done | `Tests/OpenLolaCoreTests/VerificationToolingContractTests.swift` | Removed duplicate JackTrip pair-script startup-sleep and Docker UDP port source scans. The paired-run behavior test already proves the configurable startup path by running with `OPEN_LOLA_JACKTRIP_STARTUP_SECONDS=0`, and the Docker helper behavior test already proves TCP/UDP port publishing without privileged or mutable-latest defaults. |
| Rewrite UltraGrid stress-script source guards | done | `Tests/OpenLolaCoreTests/VerificationToolingContractTests.swift`, `Tests/OpenLolaCoreTests/VerificationToolingPairScriptTests.swift` | Removed source substring checks for UltraGrid comparator/stress helper internals. `ultraGridStressScriptsSummarizeTrialHealthAndNativePreflightFailure()` now runs the real Docker and native stress scripts with a fake child `bash` seam, proving repeated Docker trial aggregation, all-trials/direct/managed health flags, native preflight failure short-circuiting, status 77, `hostReady: false`, and durable JSON summary output without real Docker or UltraGrid. |
| Rewrite UltraGrid Dockerfile policy source guard | done | `Tests/OpenLolaCoreTests/ReleaseArtifactHygieneContractTests.swift` | Replaced raw Dockerfile substring checks with deterministic Dockerfile instruction parsing. The test now validates both pinned `FROM` images, the source checksum `ARG`, checksum verification in a `RUN` instruction, and non-root `USER openlola` as parsed Dockerfile instructions, alongside the existing helper-script mutable-`latest` refusal behavior. |
| Prune release artifact hygiene doc/tooling/script micro-tests | done | `Tests/OpenLolaCoreTests/ReleaseArtifactHygieneContractTests.swift` | Grouped release boundary policy, manifest, notices, and verification-matrix hygiene docs; grouped active plan docs, workflow timeout, and Python tooling manifest contracts; and grouped live-checkout plus candidate-directory hygiene scans. Export staging and UltraGrid Docker image policy remain separate. |
| Rewrite app bundle script source policy | done | `Tests/OpenLolaCoreTests/AppBundleScriptSourcePolicyTests.swift` | Replaced broad script substring checks with temp-root script executions using fake `swift`, `codesign`, `lldb`, and `pgrep` tools. The tests now verify generated app/CLI bundle layout, product-scoped build invocations, plist executable/name/privacy keys, ad-hoc signing arguments, and debug launch target without building or launching the real app. |
| Rewrite UltraGrid native wrapper source guard | done | `Tests/OpenLolaCoreTests/VerificationToolingContractTests.swift`, `scripts/open-lola-ultragrid-native-client.sh` | Replaced native wrapper role/refusal substring checks with a fake UltraGrid executable seam that proves RX maps to `--server`, TX maps to `--client`, peer hosts are removed from server mode, port-map state is exported, and a Python `uv` identity is rejected. The behavior test exposed Bash 4-only lowercase expansion in the wrapper, so the script now lowercases identity text with `tr` for macOS `/bin/bash` compatibility. |
| Rewrite UltraGrid Docker wrapper source guard | done | `Tests/OpenLolaCoreTests/VerificationToolingContractTests.swift` | Replaced UltraGrid Docker wrapper role substring checks with a fake `docker` seam that proves RX maps to `--server` with UDP port publishing and no peer host, while TX maps to `--client peer.example` without server port publishing. |
| Rewrite paired JackTrip RX/TX role source guard | done | `Tests/OpenLolaCoreTests/VerificationToolingContractTests.swift` | Replaced paired JackTrip RX/TX role source checks with fake `open-lola` and fake `docker` execution of `run-local-jacktrip-rxtx-docker.sh`, proving managed RX/TX role invocation, container name prefixes, report validation calls, captured peer journal handling, and report file creation without real Docker or JackTrip. |
| Rewrite paired UltraGrid Docker RX/TX role source guard | done | `Tests/OpenLolaCoreTests/VerificationToolingContractTests.swift` | Replaced paired UltraGrid Docker RX/TX role source checks with fake `open-lola` and fake `docker` execution of `run-local-ultragrid-rxtx-docker.sh`, proving managed RX/TX role invocation, container name prefixes, readiness and incoming-format log handling, report validation calls, report file creation, and connection metrics output without real Docker or UltraGrid. |
| Rewrite paired native UltraGrid RX/TX preflight source guard | done | `Tests/OpenLolaCoreTests/VerificationToolingPairScriptTests.swift` | Replaced native UltraGrid preflight/log/executable success-path source checks with fake `open-lola` execution of `run-local-ultragrid-rxtx-native.sh`, while the real extractor and connection metrics writer run through the script. The test proves preflight command invocation, selected executable propagation, managed RX/TX roles, live-log readiness/incoming-format handling, report validation calls, report files, and connection metrics output without real UltraGrid. |
| Rewrite paired native UltraGrid preflight failure source guard | done | `Tests/OpenLolaCoreTests/VerificationToolingPairScriptTests.swift` | Replaced the native UltraGrid preflight failure `exit 77` source check with fake `open-lola` execution that writes a failing executable-preflight report. The script now proves it exits 77, emits `VERDICT: PARTIAL`, keeps the preflight report, and does not create RX/TX reports after a failed preflight. |
| Rewrite direct-P2P CLI and video transport source guards | done | `Tests/OpenLolaCoreTests/DirectPeerSessionCLITests.swift`, `Tests/OpenLolaCoreTests/VideoTransportRunnerTests.swift`, `Tests/OpenLolaCoreTests/MultiVideoTransportTests.swift` | Replaced direct-P2P CLI argument, parser, supervisor, bounds, and RX-proof source scans with executable help/error/report behavior. Removed video transport implementation-shape scans and kept runtime coverage through packet-size rejection, synthetic UDP video reports, per-stream observed queue depth, and dry-run two-peer plan/report JSON validation. |
| Rewrite UDP media packet source guards | done | `Tests/OpenLolaCoreTests/UdpMediaTransportTests.swift` | Removed source scans for UDP media reader internals and nested-payload byte-count validation. The suite now relies on complete truncated-header boundary behavior plus malformed audio/video nested payloads with valid envelope lengths but trailing bytes, preserving the real packet-codec regression signal without implementation text checks. |
| Prune latency benchmark report documentation source guards | done | `Tests/OpenLolaCoreTests/LatencyBenchmarkReportTests.swift` | Removed methodology-comment and monotonic-clock source scans. Retained behavior proves repeated sampling, invalid sampling counts, finite-only summaries, report validation, PASS threshold violations, physical PASS validation, low-buffer evidence, and synthetic session-profile telemetry. |
| Rewrite E2E benchmark report source guards | done | `Tests/OpenLolaCoreTests/E2EBenchmarkReportTests.swift` | Replaced source scans for synthetic audio delta wiring, shared key-value parser use, and CLI missing-input label plumbing with executable behavior: synthetic reports now prove video profiles keep zero audio baseline delta, parser tests cover duplicate/missing/unknown/invalid/non-positive arguments, and the built `open-lola e2e-benchmark-run` command reports missing audio, integrated A/V, video transport, and performance audit inputs with component labels. Removed the duplicate threshold source scan because `e2eBenchmarkRejectsPassThresholdViolations()` already proves threshold-driven validation behavior. |
| Prune E2E benchmark parser/report/pass-policy micro-tests | done | `Tests/OpenLolaCoreTests/E2EBenchmarkReportTests.swift` | Grouped synthetic smoke profile neutrality with runner aggregation, grouped required parser success with key-value parser failures, grouped invalid PASS evidence with threshold violations, and grouped PASS candidate, timing tolerance, and timing-improvement behavior. CLI missing-input component-label coverage remains separate. |
| Rewrite Drift PLC report source guards | done | `Tests/OpenLolaCoreTests/DriftPlcReportTests.swift` | Replaced the fixed-target helper source scan with direct behavior proving an invalid zero `framesPerPacket` is not silently clamped, and replaced the shared-parser source scan with parser error behavior for duplicate, missing, unknown, invalid integer, non-positive duration, and invalid boolean arguments. Retained the realtime jitter-buffer preallocation source guard and direct RX target source guard as narrower hard-to-observe runtime invariants. |
| Rewrite Integrated AV parser source guard | done | `Tests/OpenLolaCoreTests/IntegratedAvReportTests.swift` | Replaced the `IntegratedAvRunConfiguration` source scan for shared key-value parsing and dash-prefixed value rejection with parser behavior for dash-prefixed missing values, duplicate, missing, unknown, invalid integer, and non-positive duration arguments. Retained separate Integrated AV validation/helper source guards for this slice because they cover different report-validation structure contracts. |
| Rewrite Integrated AV validation source guards | done | `Tests/OpenLolaCoreTests/IntegratedAvReportTests.swift` | Removed implementation-shape scans for validation helper tables, scalar helper signatures, and discardable argument helpers. Added behavior coverage for sync policies that can move audio timing and for invalid mechanical scalar fields: non-positive playout targets, negative audio counters, non-finite callback values, and empty video source labels. |
| Rewrite direct peer prototype source guards | done | `Tests/OpenLolaCoreTests/DirectPeerTwoPeerPrototypeReportTests.swift` | Replaced FNV constant/callsite and video digest comment scans with direct hash, AES67 SSRC, payload digest, and frame-proof behavior. Removed the raw-audio same-deadline metadata comment scan as overlapping implementation documentation because `PeerSessionAVSupportTests.swift` already exercises complete, missing, reordered, and flushed raw-audio deadline reassembly behavior. |
| Rewrite direct peer two-peer run-plan source guard | done | `Tests/OpenLolaCoreTests/DirectPeerTwoPeerRunPlanTests.swift` | Replaced the prototype peer-ID extraction source scan with report-builder behavior proving peer evidence uses configured peer IDs rather than report IDs. The empty-peer case now records the real public validation order: `DirectPeerSessionReport.validate()` rejects the empty peer list before prototype aggregation can fall back. Removed unused source-reader helpers from the file. |
| Rewrite Hardware Validation route source guard | done | `Tests/OpenLolaCoreTests/HardwareValidationReportTests.swift` | Replaced the source scan that checked route requirements were derived from `UdpPcmRouteKind` with behavior that derives the current required route set from `UdpPcmRouteKind.allCases.filter(\.requiresHardwareValidation)` and proves each required route is rejected when absent from a PASS candidate. |
| Rewrite Reference Rig stable-buffer source guard | done | `Tests/OpenLolaCoreTests/ReferenceRigReportTests.swift` | Replaced the stable-buffer target source/comment scan with PASS-candidate behavior that verifies the public threshold values and proves invalid primary, stretch, and fallback buffer targets are rejected by validation. |
| Rewrite RME fastest-path source guards | done | `Tests/OpenLolaCoreTests/RmeFastestAudioPathTests.swift` | Replaced the Thunderbolt token source scan with direct `isThunderboltPerformancePath` behavior for Thunderbolt, TB3, TB4, broad `thun`, and USB cases. Removed duplicate implementation-shape assertions from the supported-sample-rate test because the same test already proves an added supported 44.1 kHz matrix without stable mode fails PASS validation. Replaced the remaining placeholder checklist source scan with validator behavior proving PASS rejects a static placeholder field (`notes`) and a dynamic sample-rate placeholder field (`loopbackReport.sampleRates[2].unsupportedReason`). |
| Rewrite Integrated Profile runtime-evidence source guards | done | `Tests/OpenLolaCoreTests/IntegratedProfileRunEvidenceTests.swift` | Deleted the helper-name source scan as implementation trivia already covered by runtime evidence aggregation behavior. Replaced combined-metric source scans with a generated audio-video-control report row that proves worst-case gauge metrics and summed event counts in validated output. |
| Split verification tooling pair-script behavior tests | done | `Tests/OpenLolaCoreTests/VerificationToolingContractTests.swift`, `Tests/OpenLolaCoreTests/VerificationToolingPairScriptTests.swift` | Moved paired helper/wrapper behavior tests into a dedicated file so both verification-tooling test files stay under the repository 720-line budget without adding a line-budget exception. |
| Rewrite docs verifier constants source guard | done | `Tests/OpenLolaCoreTests/DocsVerifierPolicyTests.swift` | Replaced direct `constants.py` substring assertions with a runtime import of `ARCHIVED_TOPOLOGY_PATHS` and `DOC_IGNORE_PREFIXES`, compared against the manifest-backed archive topology sample paths. The existing temp-root archive inventory and ambiguous-copy probes remain behavioral. |
| Rewrite external connector role environment source guard | done | `Tests/OpenLolaCoreTests/ExternalConnectorProcessGroupTests.swift`, `Tests/OpenLolaCoreTests/VerificationToolingContractTests.swift` | Replaced runtime source substring checks for `OPEN_LOLA_EXTERNAL_CONNECTOR_ROLE` and `invocation.role.rawValue` with a real `RealExternalConnectorProcessRunner` fake-executable test that proves the runner exports both connector and role environment values. |
| Prune external connector process-group source-shape guard | done | `Tests/OpenLolaCoreTests/ExternalConnectorProcessGroupTests.swift` | Removed the source-only implementation-symbol scan for event-driven helpers, sleep substrings, pipe-capture internals, and process-slot shape. The file retains behavioral coverage for timed termination, process-group child cleanup, large-output draining, injected process group launch/failure results, host-readiness partial reports, and connector/role environment export. |
| Prune external connector process-group report micro-tests | done | `Tests/OpenLolaCoreTests/ExternalConnectorProcessGroupTests.swift` | Grouped injected JackTrip primary/auxiliary process orchestration, grouped missing auxiliary/nonzero/early-exit failure reports, and grouped UltraGrid/JackTrip host-readiness defaults. Real environment export, child cleanup, and large-output draining remain separate real-process probes. |
| Prune app-shell/process source trivia | done | `Tests/OpenLolaCoreTests/AppShellBehaviorTests.swift`, `Tests/OpenLolaCoreTests/ManagedProcessRunnerTests.swift`, deleted `AppShellSourceContractTests.swift` | Removed app-shell UI source-shape tests for scene ordering, literal view components, layout helper names, settings-tab split names, managed-process call-site wiring, and the remaining app receiver source contract. App-shell behavior remains covered by state truthfulness, evidence gating, command preview escaping/readability, log-open errors, preview disabled/stop behavior, packet monitor failures, settings port rejection, readable metric accessibility, and real managed-process execution. `AppShellSourceContractTests.swift` was deleted as source-only coverage. |
| Prune current-evidence matrix count trivia | done | `Tests/OpenLolaCoreTests/CurrentEvidenceStatusMatrixTests.swift` | Removed fixed lane/task count and crosswalk membership tests that duplicate `CurrentEvidenceStatusMatrixReport.validate()` and the shared machine-readable surface round-trip. Kept the non-source-completable gate assertions, false-PASS rejection, and validator-output behavior. |
| Prune inventory summary count/source-helper trivia | done | `Tests/OpenLolaCoreTests/RealtimeAudioPathInventoryTests.swift`, `Tests/OpenLolaCoreTests/GoalRuntimeEvidenceTemplateTests.swift`, `Tests/OpenLolaCoreTests/NetworkRouteCommandMatrixTests.swift`, `Tests/OpenLolaCoreTests/VideoControlDegradeMatrixTests.swift` | Removed fixed summary-count tests and a video-control helper source scan that duplicated derived summary logic or existing entry-level safety checks. Kept owner/source/doc existence checks, CLI inventory coverage, false-PASS rejection, required command/validator checks, NAT/diagnostic evidence boundaries, disarmed-control policy, and degrade-before-audio-impact behavior. |
| Prune command/source ownership summary trivia | done | `Tests/OpenLolaCoreTests/CLICommandInventoryTests.swift`, `Tests/OpenLolaCoreTests/SourceOwnershipInventoryTests.swift` | Removed fixed summary-count tests that duplicated executable command discovery, source coverage, and shared machine-readable inventory JSON coverage. Kept duplicate-command detection, owner/test path checks, executable help/JSON probes, full source ownership coverage, vendor fence behavior, and high-risk runtime deferral checks. |
| Prune source ownership inventory micro-tests | done | `Tests/OpenLolaCoreTests/SourceOwnershipInventoryTests.swift` | Grouped entry path and duplicate checks, grouped unknown/fallback/exact-directory-proposed resolution behavior, and grouped external connector ownership, C02 move policy, high-risk runtime deferrals, vendor fencing, and CLI command coverage. Full source-file coverage remains separate. |
| Prune AudioLoopback parser micro-tests | done | `Tests/OpenLolaCoreTests/AudioLoopbackRunTests.swift` | Grouped required and multichannel parser success cases, grouped low-buffer opt-in rejection with explicit low-buffer profile parsing, and grouped unknown, duplicate, missing-value, invalid-bool, missing-required, and non-positive frame parser rejections. RX-buffer handoff configuration, host-time conversion, endpoint metric defaults, callback safety source contracts, RME MADI preflight, run-report round-trip, and completed-run handoff validation remain separate coverage. |
| Prune AudioLoopback runtime/preflight/report micro-tests | done | `Tests/OpenLolaCoreTests/AudioLoopbackRunTests.swift` | Grouped parser success/profile/rejection behavior, grouped RX-buffer handoff, host-time conversion, callback metric defaults, and source-safety guards, grouped RME MADI accept plus unsafe preflight blockers, and grouped report round-trip with completed-run handoff-metric validation. |
| Merge false-PASS report policy micro-tests | done | report/pass-policy suites | Consolidated repeated one-field invalid-PASS tests across video capture/transport, recording artifacts, NAT routes, E2E/performance reports, RME fastest path, AoIP certification, reference rig, faster-than-LoLa closure, field-ready runtime proof, DirectPeer AV PASS, integrated profile, release hardening, latency benchmark, UDP PCM route, and Drift PLC reports. The remaining grouped tests still mutate each evidence field and assert the specific validation error; runtime/pass-candidate behavior and public report contracts were retained. |
| Merge runtime source-contract groups | done | `Tests/OpenLolaCoreTests/AudioLoopbackRunTests.swift`, `Tests/OpenLolaCoreTests/PeerSessionRunnerTests.swift`, `Tests/OpenLolaCoreTests/RealtimeAudioPacketHandoffTests.swift`, `Tests/OpenLolaCoreTests/RealtimeAudioEngineTests.swift`, `Tests/OpenLolaCoreTests/PeerSessionAVSupportVideoTests.swift` | Consolidated related source-contract checks into grouped tests where no clean public seam exists, while preserving packet handoff, jitter/drop/reorder, lifecycle, AV preview/reassembly, CoreAudio callback, and buffer-accounting behavior tests. |
| Prune realtime playout and direct-RX policy micro-tests | done | `Tests/OpenLolaCoreTests/RealtimeAudioEngineTests.swift` | Grouped due-frame/silence playout and out-of-order arrival behavior, grouped ahead-window, overflow-window, and late-block classification, and grouped measured plus implicit zero-block direct-RX rejection. A follow-up pass folded synthetic-PASS rejection and unordered performance-counter evidence into the invalid-report test, and grouped one-packet handoff with late-packet and mismatched-mode receive behavior. UDP PCM v2 fragment handoff, source-contract safety, positive PASS validation, ring bounds, and direct-RX validation remain separate coverage. |
| Prune realtime packet-handoff micro-tests | done | `Tests/OpenLolaCoreTests/RealtimeAudioPacketHandoffTests.swift` | Grouped V1 capture/send, full-ring drop, invalid interleaved shape, oversized payload, and burst-drain behavior into one capture-side scenario; grouped playout queue exhaustion, zero-target fallback, and overflowing playout-frame rejection into one receive-side scenario; and grouped the two invalid V2 pre-send transport-mode cases. The adverse loss/reorder/duplicate/underrun/overrun schedule and callback-safe packetization source contract remain separate coverage. |
| Prune Native App Shell low-signal tests | done | `Tests/OpenLolaCoreTests/NativeAppShellTests.swift` | Merged invalid local/remote selection, unsafe command-field, duplicate-port, Windows LoLa overflow, supervisor local/SSH argument, default-path, packet-monitor negative-limit, runtime-smoke parse/report cases, packet-monitor filter/accessibility cases, operator state/local-command/two-peer plan positives, and surface-probe partial/false-PASS cases into grouped behavior tests. Removed one source-comment guard for the `Sendable` snapshot prose because it only verified private documentation text. |
| Prune OSC/ATEM low-signal tests | done | `Tests/OpenLolaCoreTests/OscCueReportTests.swift` | Merged malformed OSC packet and unsafe ATEM network-argument rejection tests, and removed source-comment/private-helper scans for OSC cursor documentation, synthetic receive-time implementation text, and ATEM Darwin helper visibility. Live OSC UDP receive, oversized datagram, external peer, ATEM read-only report, and false-PASS behavior remain covered. |
| Prune external connector session micro-tests | done | `Tests/OpenLolaCoreTests/ExternalConnectorSessionTests.swift` | Merged unsupported connector media modes, missing peer/audio port, unsafe module argument, invalid port/session/duration, dry-run report, invalid report contract, and parser typo cases into grouped behavior tests. Removed the test-source self-inspection guard for readiness polling; retained the actual socket-heavy LoLa control loopback and the hard-to-observe runtime preflight/source guards. |
| Prune recording-session artifact micro-tests | done | `Tests/OpenLolaCoreTests/RecordingSessionArtifactTests.swift` | Merged one-case parser failures, baseline read/decode failures, live-capture source-contract scans, off/audio/video/audio-video parser success variants, and injected audio/video/audio-video artifact variants into grouped behavior tests. Artifact writing, rollback cleanup, unavailable-media truthfulness, writer-pressure behavior, and cancellable wait behavior remain covered. |
| Prune session negotiation micro-tests | done | `Tests/OpenLolaCoreTests/SessionNegotiationTests.swift` | Merged peer-media topology, audio transport, MTU, stream-ID, and Blackmagic video-shape rejection checks into grouped behavior tests. A follow-up pass grouped default/reconnect acceptance, positive topology plus invalid endpoint maps, direct/balanced profile acceptance, balanced video/rx rejection cases, and multi-video/WAN buffer policy checks. The previously unannotated non-positive video frame-rate denominator helper is now active inside the grouped balanced-AV rejection test. Profile policy and control-message round-trip coverage remain separate. |
| Prune UDP PCM v2 packet micro-tests | done | `Tests/OpenLolaCoreTests/UdpPcmV2PacketTests.swift` | Merged fragment-planner overflow cases and malformed packet header/payload decode checks into grouped behavior tests. Truncated-header boundary, private checked-reader, reassembler duplicate/mismatch, and copy-bound source contracts remain separate because they protect packet safety behavior. |
| Prune UDP PCM v2 packet subsystem micro-tests | done | `Tests/OpenLolaCoreTests/UdpPcmV2PacketTests.swift` | Grouped fragment planning metadata/overflow/source-contract checks, grouped round-trip/truncated/malformed decode and checked-reader guards, and grouped reassembler duplicate/mismatch/copy-bound behavior with packetizer copy-bound source ordering. |
| Prune DirectPeer two-peer plan false-PASS micro-tests | done | `Tests/OpenLolaCoreTests/DirectPeerTwoPeerRunPlanTests.swift` | Merged DirectPeer session invalid-PASS evidence checks and two-peer plan invalid contract checks. Measured AV pass candidates, command generation, CLI parsing, local supervisor execution states, SSH preflight, prototype peer-ID extraction, and receive-proof artifacts remain covered separately. |
| Prune endpoint loopback certification micro-tests | done | `Tests/OpenLolaCoreTests/EndpointLoopbackReportTests.swift` | Merged required frame-row, unsupported-rate reason, accepted-mode loopback metrics, stability duration, hidden-buffer-growth, and eight-frame long-run validation checks into one behavior test over the same fixture family. |
| Prune small report-policy suites | done | `Tests/OpenLolaCoreTests/NativeAppShellPolicyTests.swift`, `Tests/OpenLolaCoreTests/MacToMacRouteCertificationTests.swift`, `Tests/OpenLolaCoreTests/ExternalConnectorReportTests.swift`, `Tests/OpenLolaCoreTests/AoipEvaluationReportTests.swift` | Merged repeated invalid-PASS policy mutations into one grouped behavior test per report suite. Native app realtime ownership, Mac-to-Mac route evidence, external connector source/real-world boundaries, and AoIP interoperability evidence still assert each specific validation error. |
| Prune fixture and release-ledger micro-tests | done | `Tests/OpenLolaCoreTests/MeasurementReportFixtureTests.swift`, `Tests/OpenLolaCoreTests/LoLaParityDeferredFeaturesTests.swift`, `Tests/OpenLolaCoreTests/ReleaseHardeningTests.swift`, `Tests/OpenLolaCoreTests/GoalCompletionAuditTests.swift` | Merged invalid measurement fixtures, deferred-feature pass-policy mutations, release hardening pass/internal-evidence rejections, and goal audit summary/verdict failures into grouped behavior tests. Positive fixture decoding, deferred TODO cross-reference, release runner/docs, blocker mapping, and validator output remain separate. |
| Prune lighting fixture gate micro-tests | done | `Tests/OpenLolaCoreTests/LightingFixtureGateTests.swift` | Merged one-case unsafe-output policy checks and one-field run-configuration parser rejections into grouped behavior tests. Allowed-universe behavior, observed-universe normalization, invalid PASS evidence, partial safety handoff reports, direct capture-tool validation, packet-capture truthfulness, and partial workflow validation remain separate. |
| Prune lighting fixture gate policy/runner micro-tests | done | `Tests/OpenLolaCoreTests/LightingFixtureGateTests.swift` | Grouped unsafe-state and armed/isolated allowed-universe decisions, and grouped run-configuration parsing/rejection, invalid direct-capture configuration, partial safety handoff report construction, and packet-capture truthfulness. Observed-universe normalization, invalid PASS evidence, and partial workflow validation remain separate. |
| Prune external connector AV/connection-plan micro-tests | done | `Tests/OpenLolaCoreTests/ExternalConnectorAvMatrixTests.swift`, `Tests/OpenLolaCoreTests/ExternalConnectorConnectionPlanTests.swift` | Merged raw-link, missing-peer, media-mode, placeholder-command, stale-shell-command, and raw-link tuple rejection cases into grouped public parser/runner/validator tests. Connector AV plan generation, configured device modules, role aliases, typo handling, side-scoped ports, executable defaults, LoLa media packet count, and bidirectional raw-link command generation remain separate. |
| Prune external connector AV matrix role/module variants | done | `Tests/OpenLolaCoreTests/ExternalConnectorAvMatrixTests.swift` | Grouped TX/RX and explicit bidirectional AV matrix plans, grouped UltraGrid endpoint and TX/RX full-duplex process variants, grouped JackTrip configured audio and auxiliary-video module checks, and grouped JackTrip endpoint plus TX/RX auxiliary-video variants. Connector production capture/playback module checks, video dimension rejection, flag-like peer/device rejection, parser device-module options, role aliases, typo rejection, and invalid connector inputs remain separate. |
| Prune external connector session launch/session variants | done | `Tests/OpenLolaCoreTests/ExternalConnectorSessionTests.swift` | Grouped UltraGrid, JackTrip, tuned JackTrip, and JackTrip AV launch-plan variants; grouped parser and launch-plan rejection cases; folded the dead unannotated JackTrip whitespace-device check into the active whitespace-device test; grouped dry-run and process-run reports; and grouped the remaining runtime source guards. The socket-heavy LoLa control loopback, invalid report-contract checks, process-run invocation coverage, and hard-to-observe runtime preflight/failure-verdict contracts remain covered. |
| Prune UDP loopback and video runner parser micro-tests | done | `Tests/OpenLolaCoreTests/UdpPcmLoopbackLatencyTests.swift`, `Tests/OpenLolaCoreTests/VideoTransportRunnerTests.swift` | Merged UDP loopback session-pair mismatch cases and video transport parser rejection cases into grouped behavior tests while preserving each exact validation error. Sender parsing, byte-exact echo validation, ICMP diagnostics, generated UUIDs, localhost echo smoke, duplicate-echo loss accounting, QoS policy, fragment-size rejection, raw route parsing, and partial video transport reports remain separate. |
| Prune session protocol validation micro-tests | done | `Tests/OpenLolaCoreTests/SessionProtocolTests.swift` | Merged stable peer-ID rejection cases and domain capability validation failures into grouped behavior tests while preserving the exact validation errors. Positive peer identity, deterministic control-message coding, advisory audio metadata, state-machine transitions, local capability document validation, capability protocol dependency source contract, and capability summary behavior remain separate. |
| Prune session protocol control/capability micro-tests | done | `Tests/OpenLolaCoreTests/SessionProtocolTests.swift` | Grouped positive peer identity with invalid ID rejection, grouped deterministic hello coding with advisory audio-metadata coding/state-machine behavior, grouped error, skipped-handshake, explicit-handshake, and idempotent-shutdown state-machine transitions, and grouped capability document round-trip, negotiation protocol source contract, and capability-summary checks. Domain validation failure coverage remains separate. |
| Prune NAT route parser and report-validation micro-tests | done | `Tests/OpenLolaCoreTests/NatFriendlyRouteTests.swift` | Merged positive NAT parser checks, registration-helper duplicate/unsafe peer-ID rejections, and NAT route invalid-evidence checks into grouped behavior tests. Localhost rendezvous, relay fallback, direct traversal loopback measurement, relay/forwarder smoke behavior, protocol constants, explicit ACK/source contracts, and raw-P2P preference behavior remain separate. |
| Prune latency benchmark summary micro-tests | done | `Tests/OpenLolaCoreTests/LatencyBenchmarkReportTests.swift` | Merged percentile/warmup/non-finite sample summary checks and jitter validation failures into grouped behavior tests. A follow-up pass grouped repeated measurement, invalid sampling counts, and summaries; grouped fail-fast identity, invalid fixtures, invalid PASS evidence, and jitter-field validation; and grouped low-buffer physical/warning evidence. Monotonic-clock source contract, synthetic session-profile telemetry, threshold violations, and physical PASS validation remain separate. |
| Prune UDP PCM route parser/socket smoke micro-tests | done | `Tests/OpenLolaCoreTests/UdpPcmRouteReportTests.swift` | Merged DSCP not-tested reason cases, sender/physical parser checks, parser rejection cases, invalid receive checks, and localhost partial route smoke assertions into grouped behavior tests. Invalid PASS evidence, packet accounting, transport policy docs, packet-age metrics, programmatic initializer validation, bounded packet arithmetic, checked deadlines, UDP/NAT integer bounds, socket buffer sizing, fcntl failure, source-address receive behavior, and continuous/route localhost smoke behavior remain covered. |
| Prune UDP PCM route validation/config micro-tests | done | `Tests/OpenLolaCoreTests/UdpPcmRouteReportTests.swift` | Grouped DSCP not-tested, invalid PASS evidence, and packet-accounting validation checks; grouped sender/physical parser success, parser rejection, programmatic initializer validation, bounded packet-count, and overflow checks; and grouped invalid nonblocking plus invalid receive behavior. Transport policy docs, packet-age metrics, checked deadlines, UDP/NAT integer bounds, socket buffer sizing, source-address receive behavior, and localhost smoke behavior remain separate coverage. |
| Prune Integrated AV parser/partial-validator micro-tests | done | `Tests/OpenLolaCoreTests/IntegratedAvReportTests.swift` | Merged invalid switch and key-value parser rejections, and folded frame-identity, sync-policy, and mechanical scalar validation into one grouped partial-field behavior test. Synthetic PASS rejection, required-argument parsing, partial P04 report construction, and invalid PASS evidence remain separate. |
| Prune LoLa control handshake transport duplicates | done | `Tests/OpenLolaCoreTests/LoLaControlHandshakeValidationTests.swift` | Merged duplicate UDP/TCP wrong-session ACK and non-handshake receive rejection tests into transport-paired behavior tests while preserving both control transports and exact malformed-control evidence. Retry responder, parser byte accounting, TX/RX video profile, and IPv4 normalization behavior remain separate. |
| Prune LoLa media envelope rejection duplicates | done | `Tests/OpenLolaCoreTests/LoLaCompatibilityMediaEnvelopeValidationTests.swift` | Merged duplicate-video-prelude, fragment-without-prelude, and prelude-without-fragments cases into one grouped video envelope behavior test with exact codec errors. Port filtering, unexpected port rejection, channel block-size rejection, and direct video reassembly sequence mismatch remain separate. |
| Prune UDP PCM packet fixture/malformed micro-tests | done | `Tests/OpenLolaCoreTests/UdpPcmPacketTests.swift` | Merged valid Int16/Float32 fixture decode, explicit fixture round-trip, and fixture re-encode checks; grouped silence packet sizing with mode mismatch behavior; grouped malformed packet parsing with byte-range helper and missing timestamp rejection; and grouped UDP PCM v2 round-trip with malformed-v2 rejection. Codec conformance, sequence tracking, and localhost smoke behavior remain separate. |
| Prune LoLa media codec micro-tests | done | `Tests/OpenLolaCoreTests/LoLaCompatibilityMediaCodecTests.swift` | Merged JPEG marker/metadata behavior, default/live audio fragment serialization and reject-size behavior, video prelude/datagram/fragment-limit behavior, generated video size/pattern/overflow behavior, and duplicate/missing/wrong-prelude/inconsistent-header/prelude-bounds reassembly failures. Wire-frame TTL/port behavior remains separate. |
| Prune external connector LoLa compatibility variants | done | `Tests/OpenLolaCoreTests/ExternalConnectorLoLaCompatibilityTests.swift` | Grouped recovered Ethernet/IPv4/UDP wire-frame round-trip, padding, and variable IPv4-ID behavior; grouped quick-connect, status, ACK, video-capability, unknown-message rejection, and visible recovered control templates. Launch-plan defaults, static media-model facts, invalid audio sizing, raw-link parser options, and raw-link dry-run media-frame report coverage remain separate. |
| Prune video transport reassembler/decode micro-tests | done | `Tests/OpenLolaCoreTests/VideoTransportReportTests.swift` | Merged duplicate newer-frame incomplete-drop coverage into the newer-frame reassembler test and grouped invalid magic, invalid index, empty payload, and oversized metadata fragment-decode rejections into one malformed-fields test. Fragmentation, wire constants, out-of-order completion, duplicate fragments, stale bucket eviction, shared-state aliasing, concurrent receive, expiration, capacity drop, wrap-aware ordering, corrupt metadata, truncation boundaries, percentile interpolation, encoding-field context, and latest-frame queue behavior remain separate. |
| Prune video transport packet/reassembler micro-tests | done | `Tests/OpenLolaCoreTests/VideoTransportReportTests.swift` | Grouped deterministic packet/fragment/wire-format checks, out-of-order/duplicate/alias reassembly checks, newer/expired/capacity incomplete-frame drops, wrapped sequence completion and incomplete ordering, and malformed decode/truncation/encoding-shape rejections. Same-sequence stale-bucket eviction, concurrent receive serialization, oversized fragment-set rejection, corrupt metadata rejection, percentile interpolation, and latest-frame queue behavior remain separate coverage. |
| Prune video capture parser/inventory micro-tests | done | `Tests/OpenLolaCoreTests/VideoCaptureReportTests.swift` | Merged presentation/fallback timestamp checks, external-capture classification plus auto-selection, Blackmagic production-evidence derivation plus generic-camera refusal, and run-configuration rejection cases. Test-pattern frames, latest-frame queue drops, invalid PASS evidence, inventory report round-trip, source-contract guards, required/production parser paths, and partial snapshot report behavior remain separate. |
| Prune video capture AVFoundation source-contract micro-tests | done | `Tests/OpenLolaCoreTests/VideoCaptureReportTests.swift` | Grouped AVFoundation capture configuration restore/unlock guards, capture wait behavior, sample-buffer collector locking/TSAN guard, raw-frame retention compaction checks, and invalid pixel-buffer geometry guards into one source-contract test. Timestamp behavior, deterministic test-pattern frames, latest-frame queue drops, invalid PASS evidence, inventory report round-trip, device classification, production evidence, run configuration, and snapshot report behavior remain separate coverage. |
| Prune video capture frame/inventory/parser micro-tests | done | `Tests/OpenLolaCoreTests/VideoCaptureReportTests.swift` | Grouped deterministic test-pattern frame emission with latest-frame queue stale-drop behavior, grouped inventory round-trip with external-capture classification and production-evidence derivation, and grouped required, invalid, and measured run-configuration parser variants. Invalid PASS evidence, AVFoundation source-contract guards, timestamp behavior, and partial snapshot report construction remain separate. |
| Prune LoLa raw-link/UDP media micro-tests | done | `Tests/OpenLolaCoreTests/LoLaCompatibilityRawLinkAndUdpMediaTests.swift` | Grouped BPF malformed-record and header-length extraction checks, raw-link real receive/timeout/bounded receiver configuration checks, UDP sleep/send retry transient and structural error checks, and UDP receive timeout/validation failure report checks. Raw-link TX/RX success, malformed MAC rejection, UDP media TX, wildcard-source advertisement, UDP RX success, peer-source filtering, and bidirectional TX/RX behavior remain separate coverage. |
| Prune LoLa raw-link/UDP transport-family micro-tests | done | `Tests/OpenLolaCoreTests/LoLaCompatibilityRawLinkAndUdpMediaTests.swift` | Grouped raw-link TX success with malformed-MAC rejection, grouped raw-link RX memory success with real receive/timeout/bounded-receiver checks, grouped UDP TX with wildcard-source advertisement, and grouped UDP RX success, timeout/invalid failure reports, and peer-source filtering. BPF extraction, sleep/send retry behavior, and bidirectional UDP TX/RX remain separate coverage. |
| Prune UDP media packet/metric micro-tests | done | `Tests/OpenLolaCoreTests/UdpMediaTransportTests.swift` | Merged audio/video/timing envelope checks, truncated/mismatched/malformed nested-payload checks, packetizer limit and too-small-limit behavior, UDP video loopback plus DSCP capture, and loss/jitter/rollover/stale/reorder/duplicate/adverse/clock-skew schedules. Raw video packetizer/reassembler byte preservation remains separate, and the adverse `[1, 3, 2, 2, 5]` loopback schedule still runs through real UDP sockets. |
| Prune OSC/ATEM parser and probe micro-tests | done | `Tests/OpenLolaCoreTests/OscCueReportTests.swift` | Merged OSC external parser positive/loopback rejection, ATEM report round-trip/armed-command rejection, ATEM parser positive/unsafe rejection, and partial/connected ATEM network report checks. OSC packet round-trip/malformed decode, fd-set guard, synthetic/live loopback, timeout and large datagram receive, external runner, cue-count and jitter validation, OSC false-PASS policy, ATEM unavailable report, and ATEM false-PASS policy remain separate. |
| Prune OSC/ATEM parser, receive, and report validation micro-tests | done | `Tests/OpenLolaCoreTests/OscCueReportTests.swift` | Grouped OSC packet round-trip with malformed decode, grouped UDP receive timeout with oversized datagram behavior, grouped cue-count, jitter rounding, and invalid PASS evidence checks, and grouped ATEM unavailable plus connected-handshake-only report behavior. OSC fd-set guard, synthetic/live loopback runners, external runner configuration/report behavior, ATEM read-only report round-trip/armed-command rejection, ATEM parser rejection, and ATEM invalid PASS policy remain separate. |
| Prune OSC/ATEM socket, loopback, external, and read-only micro-tests | done | `Tests/OpenLolaCoreTests/OscCueReportTests.swift` | Grouped fd-set bounds, timeout, and oversized-datagram receive behavior; grouped synthetic and live UDP loopback report evidence; grouped external-run parser and runner evidence; and grouped ATEM report round-trip, read-only probe, parser rejection, and invalid-PASS policy. OSC packet codec and cue-count/jitter/false-PASS validation remain separate. |
| Prune RX buffer validation/simulator micro-tests | done | `Tests/OpenLolaCoreTests/RxBufferingTests.swift` | Merged direct-policy target, empty-field, and non-finite-event validation checks, and grouped deterministic impairment simulator boundary cases for maximum packet count, first-packet loss, non-negative reorder, and two-sample percentile behavior. A follow-up pass grouped the main impairment schedule with seeded jitter output and duplicate-excluded jitter metrics. Runtime handoff, adaptive controller, fastest-pass rejection, boundary cases, latency report, benchmark runner, and physical-evidence policy remain covered. |
| Prune RX buffer controller/report micro-tests | done | `Tests/OpenLolaCoreTests/RxBufferingTests.swift` | Grouped adaptive-controller hysteresis/bounds and quiet-decrease cases, grouped latency benchmark RX-buffer impact plus fastest-pass ineligibility, and grouped benchmark runner profile, default-packet-count, and false-PASS physical-evidence checks. A follow-up pass grouped direct and small packet-handoff RX-policy behavior. Stable-WAN fastest rejection, deterministic impairment boundaries, validation boundaries, and the remaining precondition source guard remain separate. |
| Prune parser/negotiation/connection-plan micro-tests | done | `Tests/OpenLolaCoreTests/KeyValueArgumentParserTests.swift`, `Tests/OpenLolaCoreTests/SessionNegotiationTests.swift`, `Tests/OpenLolaCoreTests/ExternalConnectorConnectionPlanTests.swift` | Merged parser invalid-key and value-shape edge cases, folded balanced-AV enabled-video and fractional-frame-rate acceptance into one behavior test, removed the redundant SessionNegotiation source-order denominator guard already covered by non-positive denominator behavior, and grouped UltraGrid run-directory/preflight plus side-scoped/no-control port plan behavior. Required positive-integer callbacks, boolean parsing, audio/video negotiation rejection, profile policies, connection-plan real-run command inputs, executable defaults, LoLa media packet counts, and raw-link command generation remain separate. |
| Prune DirectPeer two-peer plan/report micro-tests | done | `Tests/OpenLolaCoreTests/DirectPeerTwoPeerRunPlanTests.swift` | Grouped measured PASS validation with invalid PASS evidence rejections, command generation with explicit executable path behavior, CLI parse success with enum/host/port rejection cases, plan and supervisor validator-surface checks, executed/downgraded/invalid local-run report states, and receive-proof metadata with nil-position digest behavior. AV run defaults, SSH preflight, prototype peer-ID extraction, and dry-run supervisor helper coverage remain separate. |
| Prune NAT route parser/source/smoke micro-tests | done | `Tests/OpenLolaCoreTests/NatFriendlyRouteTests.swift` | Grouped positive NAT parser checks with shared-port and ephemeral-port rejection, merged rendezvous registration and direct-traversal loopback smoke coverage to avoid running the same localhost smoke twice, and grouped runner/protocol/smoke source-safety guards. Relay fallback, launcher, report invalid-evidence, round-trip, raw-P2P preference, registration helper, and incomplete registration response coverage remain separate. |
| Prune MADI/multichannel/drift micro-tests | done | `Tests/OpenLolaCoreTests/MadiReceiveTests.swift`, `Tests/OpenLolaCoreTests/MadiFullDuplexSessionTests.swift`, `Tests/OpenLolaCoreTests/MultichannelTransportTests.swift`, `Tests/OpenLolaCoreTests/DriftPlcReportTests.swift` | Merged MADI receive mix-routing and pan behavior, ready-block ring capacity/future guards, MADI full-duplex audio-pair mismatch/RX-buffer/video-reject configuration checks, render lifecycle checks, drift simulation/non-monotonic estimate checks, MADI source-safety guards, 64-channel payload-byte-count checks, fixed-target due/reordered playout behavior, and invalid-shape/overflow jitter-buffer behavior. A follow-up multichannel pass folded an unannotated 64-channel negotiation check into live coverage, grouped fragment-planner boundary/error/source-contract cases, grouped packetizer/reassembler complete/lost/overlap cases, grouped receiver-mix/store/pan behavior, and grouped RME metadata unavailable/round-trip/rate-limit checks. Removed one Drift PLC source literal for direct RX target because runner behavior already proves a nonzero fixed playout target. Socket exchange, receiver mix reporting, adaptive RX buffering, same-deadline PLC, callback-preallocation source safety, MADI source safety, multichannel negotiation, packetizer/reassembler behavior, and RME metadata behavior remain covered. |
| Prune MADI receive transport and pending-deadline micro-tests | done | `Tests/OpenLolaCoreTests/MadiReceiveTests.swift` | Grouped metadata-revision, sample-rate, and packing-mode transport mismatch coverage, and grouped ready-pool overrun, pending-deadline limit, colliding modulo sequence, and pending-slot reuse behavior. Required-channel depacketization, missing-fragment same-deadline recovery, late drops, playout overflow, sample-reader base-address errors, far-future packet drops, small/adaptive RX buffering, mix routing, ready-block ring capacity/future guards, and ready-ring source preconditions remain separate. |
| Prune MADI receive/render micro-tests | done | `Tests/OpenLolaCoreTests/MadiReceiveTests.swift` | Grouped required-channel depacketization with missing-fragment same-deadline recovery; grouped late-packet drops, playout-frame overflow rejection, and far-future packet drops; grouped small fixed-latency and adaptive target-change RX-buffer behavior; and grouped ready-block ring capacity/future behavior with its storage-index precondition guard. Sample-reader base-address errors, transport mismatch behavior, mix routing/pan, pending-deadline bounds, and source/report companion coverage remain separate. |
| Prune Drift PLC report/parser/jitter micro-tests | done | `Tests/OpenLolaCoreTests/DriftPlcReportTests.swift` | Reduced the file from 28 to 9 active `@Test` declarations by grouping report validator mutations, parser success/error cases, pass/repeat runner behavior, due/reordered jitter-buffer playback, and invalid-shape/overflow rejection. Removed JSON round-trip and synthetic-smoke wrapper trivia already covered by report decoding/validation and broader synthetic-smoke contracts. Fixed-target invalid-packet behavior, false-PASS prevention, same-deadline PLC, late-drop behavior, callback-preallocation source safety, and drift clock correction remain covered. |
| Prune app-shell state/evidence micro-tests | done | `Tests/OpenLolaCoreTests/AppShellBehaviorTests.swift` | Grouped session state with runtime-evidence scope checks, complete and partial latency metrics loading, long and shell-escaped command preview formatting, missing direct-peer and Windows LoLa report validation failures, and preview stop/disabled idle states. App importability/action inventory, console status, remote inventory import, channel meters, successful direct-peer evidence validation, packet-monitor failures, section selection, missing-log errors, and persisted-port rejection remain separate behavior coverage. |
| Prune app-shell UI helper micro-tests | done | `Tests/OpenLolaCoreTests/AppShellBehaviorTests.swift` | Grouped app import/action inventory with console status, grouped channel-meter/peak-state display helpers with command-preview escaping, grouped validation failure and success evidence gates, grouped packet-monitor row failure with hidden-section selection behavior, and grouped missing-log error handling with invalid persisted-port defaults. Latency supervisor evidence loading, remote inventory import, app runtime-evidence scope, and async preview disable/stop behavior remain separate. |
| Prune peer-session runner micro-tests | done | `Tests/OpenLolaCoreTests/PeerSessionRunnerTests.swift` | Grouped AV preflight overflow and packet-count validation, invalid manual-host and duplicate-port preflight checks, mesh topology false-PASS and missing-route validation, mesh runtime metric/false-PASS validation, and lifecycle premature-start/recovery/shutdown boundary checks. Source-safety guard coverage, state-machine mutation ordering, malformed peer-media topology, three-peer topology/runtime smoke, UDP role exchange, AV routing, and partial bind cleanup remain separate behavior coverage. |
| Prune peer-session runner validation/runtime micro-tests | done | `Tests/OpenLolaCoreTests/PeerSessionRunnerTests.swift` | Grouped manual overflow/host/port/packet preflight rejection into one pre-bind safety scenario, grouped control state-machine mutation ordering with lifecycle start/recovery/shutdown boundaries, grouped malformed session peer-media endpoints with topology smoke/missing-route/false-PASS validation, and grouped runtime mesh smoke with metric-mismatch/false-PASS validation. Socket-heavy UDP role exchange, AV routing, source-safety guard coverage, and partial bind cleanup remain separate. |
| Prune peer-session negotiation helper micro-tests | done | `Tests/OpenLolaCoreTests/PeerSessionRunnerNegotiationTests.swift` | Grouped localhost smoke and socket-runner UDP exchange, grouped balanced raw/JPEG XS/fastest AV proposal negotiation through a shared handshake helper, grouped video sequence/raw-budget/playout-sync helpers, and grouped AES67/RTP host-time, overflow, sequence-number, and timestamp helper behavior. Each public behavior assertion remains, while repeated handshake/setup-only test declarations were removed. |
| Prune peer-session AV video helper micro-tests | done | `Tests/OpenLolaCoreTests/PeerSessionAVSupportVideoTests.swift` | Grouped raw-BGRA preview dimensions and bitmap-info checks, grouped production/synthetic fastest-sync policy tolerance, grouped host-time retimestamping, deferred-frame replacement, and frame-delivery gate behavior, and grouped negotiated fragment-budget rejection with oversize-drop metric source coverage. Preflight, source-contract, reassembly metric delta, and AV video support behavior remain covered. |
| Prune packaging field-test parser/fixture micro-tests | done | `Tests/OpenLolaCoreTests/PackagingFieldTestTests.swift` | Grouped synthetic-pass and invalid-pass fixture validation, grouped required parser success with missing-report rejection, and grouped Q010 placeholder context with invalid-PASS policy mutations. Ad-hoc package writing and pass-guard runner behavior remain separate because they exercise filesystem artifacts and verdict policy. |
| Prune peer-session AV support micro-tests | done | `Tests/OpenLolaCoreTests/PeerSessionAVSupportTests.swift` | Grouped transport-decoded RX source guards with the audio-path no-video-decode guard, grouped raw/Opus/AES67 malformed audio RX drop checks, and grouped AV socket-runner frame-rate, audio-poll, and video-drain source-safety checks. A follow-up pass grouped AV configuration with preview-sink selection, raw-audio complete/limit/incomplete/reordered/flush reassembly boundaries, and metrics publish/drain/report fields. Video corrupt-drop handling, AES67 gap recovery, decoded-RX source safety, socket-runner source safety, and AV loop wait behavior remain separate coverage. |

## File Accounting

The following table accounts for active test files. `Action` is the audit
recommendation for the next remediation pass, not a change performed here.

| File | Tests | Classification | Action |
|---|---:|---|---|
| `Tests/OpenLolaCoreTests/AES67ST2110L24TransportTests.swift` | 7 | protocol/runtime, some string guards | keep |
| `Tests/OpenLolaCoreTests/AVTimestampAlignmentTests.swift` | 6 | runtime behavior | keep |
| `Tests/OpenLolaCoreTests/AoipEvaluationReportTests.swift` | 1 | report contract; invalid PASS checks grouped | keep |
| `Tests/OpenLolaCoreTests/AppBundleScriptSourcePolicyTests.swift` | 2 | app bundle script behavior | keep |
| `Tests/OpenLolaCoreTests/AppShellBehaviorTests.swift` | 9 | UI/app behavior; surface/status, state/evidence, preview, command/display, packet-monitor, and defaults checks grouped | keep |
| `Tests/OpenLolaCoreTests/AppShellSlice05Tests.swift` | 6 | UI/app behavior | keep |
| `Tests/OpenLolaCoreTests/AudioLoopbackRunTests.swift` | 4 | realtime audio; parser, RX-buffer behavior, preflight, and report validation checks grouped | keep |
| `Tests/OpenLolaCoreTests/AudioOpusCeltLowDelayPacketTests.swift` | 3 | packet codec behavior; source guard pruned | keep |
| `Tests/OpenLolaCoreTests/BlackmagicCaptureTransmitTests.swift` | 5 | video runtime/report | keep |
| `Tests/OpenLolaCoreTests/BlackmagicReceiveRenderTests.swift` | 3 | video runtime/report; reassembler, renderer, and Blackmagic boundary behavior grouped | keep |
| `Tests/OpenLolaCoreTests/BoundedFileReaderTests.swift` | 3 | utility behavior | keep |
| `Tests/OpenLolaCoreTests/CLICommandInventoryTests.swift` | 10 | inventory contract, executable help behavior; summary count check pruned | keep |
| `Tests/OpenLolaCoreTests/CapabilitySummaryTests.swift` | 4 | CLI/report contract | keep |
| `Tests/OpenLolaCoreTests/ClockDriftSimulationTests.swift` | 2 | drift simulation behavior | keep |
| `Tests/OpenLolaCoreTests/CodeLineBudgetTests.swift` | 1 | meta quality gate | keep |
| `Tests/OpenLolaCoreTests/CoreAudioInventoryTests.swift` | 4 | CoreAudio/report behavior; validation, model, fixture, and fallback diagnostics grouped | keep |
| `Tests/OpenLolaCoreTests/CurrentEvidenceStatusMatrixTests.swift` | 3 | evidence matrix; duplicate count checks pruned | keep |
| `Tests/OpenLolaCoreTests/DebugTraceTests.swift` | 8 | debug output/privacy behavior; selected source guard pruned | keep remaining hard-to-trigger encoding fallback source guard |
| `Tests/OpenLolaCoreTests/DirectAudioMediaRouterTests.swift` | 1 | audio router behavior | keep |
| `Tests/OpenLolaCoreTests/DirectPeerAudioPayloadRingTests.swift` | 7 | realtime audio ring behavior; source guards removed | keep |
| `Tests/OpenLolaCoreTests/DirectPeerManualValidationTests.swift` | 3 | manual validation behavior; source guard pruned | keep |
| `Tests/OpenLolaCoreTests/DirectPeerRealtimeAudioGraphRxBufferingTests.swift` | 1 | rx buffer behavior | keep |
| `Tests/OpenLolaCoreTests/DirectPeerRealtimeAudioGraphTests.swift` | 9 | realtime graph behavior; source guards pruned and capture/playout/zero-channel variants grouped | keep, add host-local runtime probes where possible |
| `Tests/OpenLolaCoreTests/DirectPeerSessionAVRXBufferProfileTests.swift` | 7 | AV rx-buffer CLI/runtime | keep |
| `Tests/OpenLolaCoreTests/DirectPeerSessionCLITests.swift` | 8 | CLI executable behavior and two-peer plan/report contract | keep |
| `Tests/OpenLolaCoreTests/DirectPeerSessionEvidenceTestHelpers+TestSupport.swift` | 0 | support helper | keep |
| `Tests/OpenLolaCoreTests/DirectPeerSessionOpusCLITests.swift` | 5 | Opus CLI behavior; source guard pruned | keep |
| `Tests/OpenLolaCoreTests/DirectPeerSessionProductionAVRegressionTests.swift` | 5 | AV regression coverage | keep |
| `Tests/OpenLolaCoreTests/DirectPeerSessionReportAVPassTests.swift` | 3 | report false-pass policy | keep; duplicate AV PASS checks merged |
| `Tests/OpenLolaCoreTests/DirectPeerTwoPeerPrototypeReportTests.swift` | 7 | two-peer report/hash/digest behavior; source guards pruned | keep |
| `Tests/OpenLolaCoreTests/DirectPeerTwoPeerRunPlanTests.swift` | 10 | two-peer plan/report behavior; parser, validator, local-run, and proof micro-tests grouped | keep |
| `Tests/OpenLolaCoreTests/DocsVerifierPolicyTests.swift` | 3 | docs verifier behavior and manifest contract | keep |
| `Tests/OpenLolaCoreTests/DriftPlcFixedTargetCertificationFixtures+TestSupport.swift` | 0 | support helper | keep |
| `Tests/OpenLolaCoreTests/DriftPlcFixedTargetCertificationTests.swift` | 2 | drift/PLC report behavior; validator micro-tests merged | keep |
| `Tests/OpenLolaCoreTests/DriftPlcReportTests.swift` | 9 | report/parser/jitter-buffer behavior; source guards pruned where behavior exists and micro-tests grouped | keep remaining hard-to-observe runtime source guard |
| `Tests/OpenLolaCoreTests/E2EBenchmarkReportTests.swift` | 5 | report/parser/executable CLI behavior; smoke, runner, parser, pass-policy, and tolerance checks grouped | keep |
| `Tests/OpenLolaCoreTests/EndpointLoopbackReportTests.swift` | 1 | loopback report validation checks grouped | keep |
| `Tests/OpenLolaCoreTests/ExternalConnectorAvMatrixTests.swift` | 11 | connector AV matrix; role/module variants and invalid connector inputs grouped | keep |
| `Tests/OpenLolaCoreTests/ExternalConnectorConnectionPlanTests.swift` | 10 | connector plan behavior; invalid inputs/artifacts, run-directory/preflight, and port checks grouped | keep |
| `Tests/OpenLolaCoreTests/ExternalConnectorExecutablePreflightTests.swift` | 7 | executable preflight behavior | keep |
| `Tests/OpenLolaCoreTests/ExternalConnectorLoLaCompatibilityTests.swift` | 7 | LoLa connector behavior; wire-frame and control-message variants grouped | keep |
| `Tests/OpenLolaCoreTests/ExternalConnectorLoLaMediaEvidenceTests.swift` | 5 | LoLa media evidence | keep |
| `Tests/OpenLolaCoreTests/ExternalConnectorNmpEndpointRunTests.swift` | 8 | connector endpoint runtime | keep |
| `Tests/OpenLolaCoreTests/ExternalConnectorNmpPlanTests.swift` | 5 | NMP plan contract | keep |
| `Tests/OpenLolaCoreTests/ExternalConnectorNmpPreflightTests.swift` | 3 | NMP preflight | keep |
| `Tests/OpenLolaCoreTests/ExternalConnectorNmpWorkflowTests.swift` | 7 | NMP workflow | keep |
| `Tests/OpenLolaCoreTests/ExternalConnectorProcessGroupTests.swift` | 6 | process group runtime and environment behavior; injected-runner, failure, and host-readiness cases grouped | keep |
| `Tests/OpenLolaCoreTests/ExternalConnectorReportTests.swift` | 1 | report contract; source/real-world pass checks grouped | keep |
| `Tests/OpenLolaCoreTests/ExternalConnectorSessionTests.swift` | 7 | connector session behavior; launch/session variants grouped | keep |
| `Tests/OpenLolaCoreTests/FasterThanLoLaClosureTests.swift` | 4 | closure report; false-PASS checks grouped | keep |
| `Tests/OpenLolaCoreTests/FieldReadyRuntimeProofTests.swift` | 7 | proof report policy; false-PASS checks grouped | keep |
| `Tests/OpenLolaCoreTests/FileDescriptorSetTests.swift` | 3 | fd utility behavior | keep |
| `Tests/OpenLolaCoreTests/FixtureSmokeMatrixTests.swift` | 5 | fixture matrix | merge |
| `Tests/OpenLolaCoreTests/GoalCodewiseClosureTests.swift` | 8 | goal closure report | keep |
| `Tests/OpenLolaCoreTests/GoalCompletionAuditTests.swift` | 4 | goal audit report; invalid summary/verdict checks grouped | keep |
| `Tests/OpenLolaCoreTests/GoalRuntimeEvidenceTemplateTests.swift` | 4 | evidence template; fixed deliverable-count check pruned | keep |
| `Tests/OpenLolaCoreTests/GoalRuntimePreflightTests.swift` | 5 | runtime preflight; duplicate JSON/mapping checks pruned | keep |
| `Tests/OpenLolaCoreTests/HardwareValidationReportTests.swift` | 7 | hardware report behavior; validator micro-tests merged | merge remaining report checks |
| `Tests/OpenLolaCoreTests/IntegratedAvDegradeFirstTests.swift` | 3 | AV degrade policy | keep |
| `Tests/OpenLolaCoreTests/IntegratedAvReportTests.swift` | 6 | integrated AV report/parser/validation behavior; parser and partial-validator micro-tests grouped | keep |
| `Tests/OpenLolaCoreTests/IntegratedAvRunAggregationTests.swift` | 2 | aggregation behavior | keep |
| `Tests/OpenLolaCoreTests/IntegratedProfileReportTests.swift` | 4 | integrated profile report; false-PASS checks grouped | keep |
| `Tests/OpenLolaCoreTests/IntegratedProfileRunEvidenceTests.swift` | 4 | run evidence behavior; source guards pruned | keep |
| `Tests/OpenLolaCoreTests/JPEGXSReferenceCodecTests.swift` | 1 | codec contract | keep |
| `Tests/OpenLolaCoreTests/KeyValueArgumentParserTests.swift` | 4 | parser behavior; source-comment guards and value/key micro-tests grouped | keep |
| `Tests/OpenLolaCoreTests/LatencyBenchmarkReportTests.swift` | 6 | latency report behavior; sampling/report/low-buffer checks grouped and source guards removed | keep |
| `Tests/OpenLolaCoreTests/LatencyProfileTests.swift` | 8 | latency profile behavior | keep |
| `Tests/OpenLolaCoreTests/LatencyTuningReportTests.swift` | 4 | latency tuning report; validator micro-tests merged | keep; duplicate report checks merged |
| `Tests/OpenLolaCoreTests/LightingFixtureGateTests.swift` | 5 | lighting fixture gate report; policy, runner, pass-policy, and workflow checks grouped | keep |
| `Tests/OpenLolaCoreTests/LoLaCompatibilityCaptureReportTests.swift` | 9 | LoLa capture report | keep |
| `Tests/OpenLolaCoreTests/LoLaCompatibilityControlSocketTests.swift` | 6 | control socket behavior; source guard rewritten | keep |
| `Tests/OpenLolaCoreTests/LoLaCompatibilityMediaCodecTests.swift` | 6 | media codec behavior; JPEG, audio, video, generated-payload, and reassembly variants grouped | keep |
| `Tests/OpenLolaCoreTests/LoLaCompatibilityMediaEnvelopeValidationTests.swift` | 7 | media envelope validation; video envelope rejection cases grouped | keep |
| `Tests/OpenLolaCoreTests/LoLaCompatibilityMediaSessionSupportTests.swift` | 1 | support contract | keep |
| `Tests/OpenLolaCoreTests/LoLaCompatibilityMediaSessionTests.swift` | 7 | media session behavior | keep |
| `Tests/OpenLolaCoreTests/LoLaCompatibilityPacketFixtureTests.swift` | 3 | packet fixtures | keep |
| `Tests/OpenLolaCoreTests/LoLaCompatibilityRawLinkAndUdpMediaTests.swift` | 7 | raw link/UDP media behavior; TX/RX, BPF, retry, failure-report, filtering, and bidirectional scenarios grouped | keep |
| `Tests/OpenLolaCoreTests/LoLaCompatibilityTcpControlTests.swift` | 5 | TCP control behavior | keep |
| `Tests/OpenLolaCoreTests/LoLaControlHandshakeValidationTests.swift` | 7 | control handshake validation; UDP/TCP duplicate cases grouped | keep |
| `Tests/OpenLolaCoreTests/LoLaLiveAudioBridgeTests.swift` | 3 | live audio bridge | keep |
| `Tests/OpenLolaCoreTests/LoLaLiveUdpMediaRoutingTests.swift` | 1 | UDP media routing behavior; source guard rewritten | keep |
| `Tests/OpenLolaCoreTests/LoLaParityDeferredFeaturesTests.swift` | 3 | parity deferred report; invalid pass checks grouped | keep |
| `Tests/OpenLolaCoreTests/LoLaQuickConnectFallbackTests.swift` | 9 | quick-connect fallback behavior; duplicate source guard pruned | keep |
| `Tests/OpenLolaCoreTests/LoLaUdpMediaSocketTests.swift` | 3 | UDP socket behavior; fallback source guard rewritten | keep |
| `Tests/OpenLolaCoreTests/LoLaVideoPayloadProviderTests.swift` | 3 | video payload provider | keep |
| `Tests/OpenLolaCoreTests/LoopbackUdpPort+TestSupport.swift` | 0 | support helper | keep |
| `Tests/OpenLolaCoreTests/MacToMacRouteCertificationTests.swift` | 2 | route certification report; invalid PASS checks grouped | keep |
| `Tests/OpenLolaCoreTests/MadiFullDuplexSessionTests.swift` | 9 | MADI session behavior/report; configuration, render, drift, and source guards grouped | keep |
| `Tests/OpenLolaCoreTests/MadiReceiveSourceAndReportTests.swift` | 3 | MADI receive report behavior; source-only checks removed | keep |
| `Tests/OpenLolaCoreTests/MadiReceiveTests.swift` | 8 | MADI receive behavior/report; depacketization/recovery, reject paths, RX-buffer, mix, ring, transport-mismatch, and pending-deadline micro-tests grouped | rewrite selected guards |
| `Tests/OpenLolaCoreTests/MadiTransmitTests.swift` | 7 | MADI transmit behavior/report | rewrite selected guards |
| `Tests/OpenLolaCoreTests/ManagedProcessRunnerTests.swift` | 1 | process behavior; source guard pruned | keep |
| `Tests/OpenLolaCoreTests/MeasurementMethodologyTests.swift` | 1 | methodology contract | keep |
| `Tests/OpenLolaCoreTests/MeasurementReportFixtureTests.swift` | 2 | fixture/report contract; invalid fixture checks grouped | keep |
| `Tests/OpenLolaCoreTests/MediaClockTests.swift` | 9 | media clock behavior; source guard rewritten | keep |
| `Tests/OpenLolaCoreTests/MultiVideoStreamNegotiationTests.swift` | 5 | negotiation behavior | keep |
| `Tests/OpenLolaCoreTests/MultiVideoTransportTests.swift` | 8 | video transport behavior; source guards pruned | keep |
| `Tests/OpenLolaCoreTests/MultichannelTransportTests.swift` | 6 | multichannel transport behavior; planner, packetizer, receiver mix, and metadata variants grouped; source scanner removed | keep |
| `Tests/OpenLolaCoreTests/NatFriendlyRouteTests.swift` | 11 | NAT route behavior; parser, source-safety, and duplicate smoke checks grouped | keep |
| `Tests/OpenLolaCoreTests/NativeAppShellArtifactTests.swift` | 9 | app artifact/report | rewrite selected guards |
| `Tests/OpenLolaCoreTests/NativeAppShellOpusCommandTests.swift` | 2 | app command/defaults behavior; source guard rewritten | keep |
| `Tests/OpenLolaCoreTests/NativeAppShellPolicyTests.swift` | 1 | app policy behavior; invalid PASS checks grouped | keep |
| `Tests/OpenLolaCoreTests/NativeAppShellSurfaceActionTests.swift` | 1 | app action behavior | keep |
| `Tests/OpenLolaCoreTests/NativeAppShellTests.swift` | 9 | app behavior; packet monitor, operator command/plan, surface-probe, and runtime-smoke variants grouped | keep |
| `Tests/OpenLolaCoreTests/NativeAppShellWindowsLoLaTests.swift` | 4 | Windows LoLa app behavior | keep |
| `Tests/OpenLolaCoreTests/NetworkAoipCertificationFixtures+TestSupport.swift` | 0 | support helper | keep |
| `Tests/OpenLolaCoreTests/NetworkAoipCertificationTests.swift` | 3 | network/AoIP certification; false-PASS checks grouped | keep |
| `Tests/OpenLolaCoreTests/NetworkDiagnosticsTests.swift` | 4 | diagnostics behavior; parser, verdict/report, and process checks grouped | keep |
| `Tests/OpenLolaCoreTests/NetworkRouteCommandMatrixTests.swift` | 3 | route command matrix; fixed summary-count check pruned | keep |
| `Tests/OpenLolaCoreTests/OpenLolaContractsTargetTests.swift` | 2 | target contract | keep |
| `Tests/OpenLolaCoreTests/OpenSourceReleaseReadinessTests.swift` | 8 | release readiness report | rewrite selected guards |
| `Tests/OpenLolaCoreTests/OpusCELTLowDelayCodecTests.swift` | 4 | codec behavior; source guards pruned | keep |
| `Tests/OpenLolaCoreTests/OpusSessionNegotiationTests.swift` | 3 | negotiation behavior | keep |
| `Tests/OpenLolaCoreTests/OscCueReportTests.swift` | 6 | OSC cue and ATEM behavior; socket boundaries, loopback, external run, parser/probe, and validation checks grouped | keep |
| `Tests/OpenLolaCoreTests/PackagingFieldTestTests.swift` | 5 | packaging field report; parser, fixture, and pass-policy checks grouped | keep |
| `Tests/OpenLolaCoreTests/PeerSessionAVFastestTests.swift` | 2 | AV fastest path | keep |
| `Tests/OpenLolaCoreTests/PeerSessionAVSupportTests.swift` | 9 | AV support behavior; decoded-RX, malformed-audio, reassembly, metrics, and source-safety micro-tests grouped; source-reader helper removed | keep |
| `Tests/OpenLolaCoreTests/PeerSessionAVSupportVideoTests.swift` | 7 | AV video support behavior; preview, sync, frame-helper, and fragment-budget scenarios grouped; source scanner removed | keep |
| `Tests/OpenLolaCoreTests/PeerSessionMetricsAndControlTests.swift` | 5 | metrics/control behavior; source guard rewritten | keep |
| `Tests/OpenLolaCoreTests/PeerSessionRunnerLifecycleTests.swift` | 3 | lifecycle behavior | keep |
| `Tests/OpenLolaCoreTests/PeerSessionRunnerNegotiationTests.swift` | 4 | negotiation behavior; loopback/socket, AV profile/compression, video helper, and AES67/RTP helper variants grouped | keep |
| `Tests/OpenLolaCoreTests/PeerSessionRunnerTestSupport.swift` | 0 | support helper | keep |
| `Tests/OpenLolaCoreTests/PeerSessionRunnerTests.swift` | 8 | peer runner behavior; preflight, state/lifecycle, topology, and runtime validation micro-tests grouped; source-reader helpers removed | keep |
| `Tests/OpenLolaCoreTests/PerformanceAuditTests.swift` | 5 | performance contract; false-PASS checks grouped | keep |
| `Tests/OpenLolaCoreTests/PlaceholderDetectionTests.swift` | 7 | placeholder detection behavior | keep |
| `Tests/OpenLolaCoreTests/RealtimeAudioEngineFixtures+TestSupport.swift` | 0 | support helper | keep |
| `Tests/OpenLolaCoreTests/RealtimeAudioEngineTests.swift` | 8 | realtime engine behavior; report, playout, and handoff variants grouped; source-reader helper removed | keep |
| `Tests/OpenLolaCoreTests/RealtimeAudioPacketHandoffTests.swift` | 5 | packet handoff behavior; capture/drop, receive/fallback/rejection, and V2 mismatch micro-tests consolidated; source scanner removed | keep |
| `Tests/OpenLolaCoreTests/RealtimeAudioPathInventoryTests.swift` | 2 | audio path inventory; fixed summary-count check pruned | keep |
| `Tests/OpenLolaCoreTests/ReconnectionTests.swift` | 1 | reconnection behavior | keep |
| `Tests/OpenLolaCoreTests/RecordingSessionArtifactPolicyTests.swift` | 3 | recording artifact policy; false-PASS checks grouped | keep |
| `Tests/OpenLolaCoreTests/RecordingSessionArtifactTests.swift` | 9 | recording artifact/report behavior; parser, injected-artifact, and source-contract checks grouped | keep |
| `Tests/OpenLolaCoreTests/RecordingSessionLiveCaptureTests.swift` | 6 | recording live capture behavior; source-only checks removed | keep |
| `Tests/OpenLolaCoreTests/ReferenceRigReportTests.swift` | 4 | reference rig report behavior; source and false-PASS checks grouped | keep |
| `Tests/OpenLolaCoreTests/ReleaseArtifactHygieneContractTests.swift` | 5 | release hygiene contract; docs, tooling, export, Docker policy, and hygiene scans grouped | keep |
| `Tests/OpenLolaCoreTests/ReleaseHardeningTests.swift` | 5 | release hardening report; false-PASS/internal evidence checks grouped | keep |
| `Tests/OpenLolaCoreTests/ReleaseRunConfigurationContractTests.swift` | 1 | release run config and testing-index contract grouped | keep |
| `Tests/OpenLolaCoreTests/ReportSchemaInventoryTests.swift` | 3 | schema inventory; validator, coding, fixture, owner, and policy checks grouped | keep |
| `Tests/OpenLolaCoreTests/ReservedLocalUdpPorts+TestSupport.swift` | 0 | support helper | keep |
| `Tests/OpenLolaCoreTests/RmeFastestAudioPathTestFixtures+TestSupport.swift` | 0 | support helper | keep |
| `Tests/OpenLolaCoreTests/RmeFastestAudioPathTests.swift` | 6 | RME audio path report behavior; source and false-PASS checks grouped | keep |
| `Tests/OpenLolaCoreTests/RxBufferingTests.swift` | 10 | rx-buffer behavior; jitter source guard rewritten; validation, handoff, controller, simulator, and report micro-tests grouped; source-reader helper removed | keep |
| `Tests/OpenLolaCoreTests/SPSCAtomicRingTests.swift` | 2 | atomic ring behavior; source-only guard removed | keep |
| `Tests/OpenLolaCoreTests/SessionNegotiationTests.swift` | 8 | negotiation behavior; topology, profile, and rejection micro-tests grouped | keep |
| `Tests/OpenLolaCoreTests/SessionProtocolTests.swift` | 5 | session protocol behavior; identity, domain validation, control coding, state-machine, and capability-surface checks grouped | keep |
| `Tests/OpenLolaCoreTests/SharedIntegratedAvReportFixtures+TestSupport.swift` | 0 | support helper | keep |
| `Tests/OpenLolaCoreTests/SharedMeasuredFixtureBuilders+TestSupport.swift` | 0 | support helper | keep |
| `Tests/OpenLolaCoreTests/SocketHeavyTestGate+TestSupport.swift` | 0 | support helper | keep |
| `Tests/OpenLolaCoreTests/SourceNamingConventionTests.swift` | 1 | naming policy, command, and schema behavior grouped | keep |
| `Tests/OpenLolaCoreTests/SourceOwnershipInventoryTests.swift` | 4 | source ownership inventory; integrity, coverage, resolution, and policy checks grouped | keep |
| `Tests/OpenLolaCoreTests/UdpMediaTransportTests.swift` | 6 | UDP media transport behavior; source guards pruned; packet/metric micro-tests grouped | keep |
| `Tests/OpenLolaCoreTests/UdpPcmContinuousReceiverTests.swift` | 1 | UDP continuous receiver adverse schedule behavior | keep |
| `Tests/OpenLolaCoreTests/UdpPcmLoopbackLatencyTests.swift` | 11 | loopback latency, ID, and duplicate/loss behavior; source guards pruned and session mismatch checks grouped | keep |
| `Tests/OpenLolaCoreTests/UdpPcmPacketTests.swift` | 7 | packet codec behavior; source guard pruned; fixture, mode, malformed, and v2 cases grouped | keep |
| `Tests/OpenLolaCoreTests/UdpPcmRouteReportTests.swift` | 10 | UDP route/report behavior; validation, config, and socket-error micro-tests grouped | keep |
| `Tests/OpenLolaCoreTests/UdpPcmV2PacketTests.swift` | 3 | packet codec behavior; planning, wire decode, and reassembly/copy-bound checks grouped | keep |
| `Tests/OpenLolaCoreTests/ValidationPrimitivesTests.swift` | 3 | validation primitive behavior; source guards pruned | keep |
| `Tests/OpenLolaCoreTests/VerdictValidationPolicyTests.swift` | 1 | verdict policy behavior; enum-case source scanner removed | keep |
| `Tests/OpenLolaCoreTests/VerificationToolingContractTests.swift` | 10 | verification tooling behavior, remaining source/literal contract | rewrite selected guards |
| `Tests/OpenLolaCoreTests/VerificationToolingPairScriptTests.swift` | 6 | verification tooling pair/wrapper behavior | keep |
| `Tests/OpenLolaCoreTests/VideoCaptureReportTests.swift` | 6 | video capture report; frame/queue, false-PASS, parser/inventory/evidence checks grouped; AVFoundation source scanner removed | keep |
| `Tests/OpenLolaCoreTests/VideoControlDegradeMatrixTests.swift` | 4 | video control degrade matrix; fixed summary/source-helper checks pruned | keep |
| `Tests/OpenLolaCoreTests/VideoTransportReportPolicyTests.swift` | 1 | video report policy; false-PASS checks grouped | keep |
| `Tests/OpenLolaCoreTests/VideoTransportReportTests.swift` | 11 | video transport behavior; packet, reassembler, and decode micro-tests grouped | keep |
| `Tests/OpenLolaCoreTests/VideoTransportRunnerTests.swift` | 6 | video transport runner behavior; source guards pruned and parser rejections grouped | keep |
| `linux_connector/tests/test_codec.py` | 36 | protocol/media behavior, some source guards | keep, rewrite source guards |
| `linux_connector/tests/test_process_runtime.py` | 27 | process/runtime behavior, source/private guards | keep, rewrite source/private guards |
| `linux_connector/tests/test_runtime_contracts.py` | 11 | runtime behavior | keep |

Fixture accounting:

| Fixture group | Files | Classification | Action |
|---|---:|---|---|
| `Tests/OpenLolaCoreTests/Fixtures/AoipEvaluationReports/**` | 1 | report fixture | keep |
| `Tests/OpenLolaCoreTests/Fixtures/CoreAudioInventory/**` | 2 | report fixture | keep |
| `Tests/OpenLolaCoreTests/Fixtures/DriftPlcFixedTargetCertificationReports/**` | 1 | report fixture | keep |
| `Tests/OpenLolaCoreTests/Fixtures/DriftPlcReports/**` | 1 | report fixture | keep |
| `Tests/OpenLolaCoreTests/Fixtures/EndpointLoopback/**` | 2 | report fixture | keep |
| `Tests/OpenLolaCoreTests/Fixtures/ExternalConnectorReports/**` | 1 | report fixture | keep |
| `Tests/OpenLolaCoreTests/Fixtures/FieldReadyRuntimeProofs/**` | 2 | false-pass/report fixture | keep |
| `Tests/OpenLolaCoreTests/Fixtures/HardwareValidationReports/**` | 1 | report fixture | keep |
| `Tests/OpenLolaCoreTests/Fixtures/IntegratedAvReports/**` | 2 | false-pass/report fixture | keep |
| `Tests/OpenLolaCoreTests/Fixtures/IntegratedProfileReports/**` | 1 | report fixture | keep |
| `Tests/OpenLolaCoreTests/Fixtures/LatencyBenchmarkReports/**` | 6 | report fixture | keep |
| `Tests/OpenLolaCoreTests/Fixtures/LatencyTuningReports/**` | 1 | report fixture | keep |
| `Tests/OpenLolaCoreTests/Fixtures/LightingFixtureGateReports/**` | 1 | report fixture | keep |
| `Tests/OpenLolaCoreTests/Fixtures/LoLaParityDeferredLedgers/**` | 1 | report fixture | keep |
| `Tests/OpenLolaCoreTests/Fixtures/MacToMacRouteCertificationReports/**` | 1 | report fixture | keep |
| `Tests/OpenLolaCoreTests/Fixtures/MeasurementReports/**` | 10 | report fixture | keep |
| `Tests/OpenLolaCoreTests/Fixtures/NativeAppShellReports/**` | 1 | report fixture | keep |
| `Tests/OpenLolaCoreTests/Fixtures/NetworkAoipCertificationReports/**` | 1 | report fixture | keep |
| `Tests/OpenLolaCoreTests/Fixtures/OscCueReports/**` | 1 | report fixture | keep |
| `Tests/OpenLolaCoreTests/Fixtures/PackagingFieldTests/**` | 6 | false-pass/report fixture | keep |
| `Tests/OpenLolaCoreTests/Fixtures/RealtimeAudioEngineReports/**` | 2 | false-pass/report fixture | keep |
| `Tests/OpenLolaCoreTests/Fixtures/RecordingSessionArtifacts/**` | 1 | report fixture | keep |
| `Tests/OpenLolaCoreTests/Fixtures/ReferenceRigReports/**` | 1 | report fixture | keep |
| `Tests/OpenLolaCoreTests/Fixtures/ReleaseHardeningReports/**` | 2 | false-pass/report fixture | keep |
| `Tests/OpenLolaCoreTests/Fixtures/RmeFastestAudioPathReports/**` | 1 | report fixture | keep |
| `Tests/OpenLolaCoreTests/Fixtures/UdpPcmPackets/**` | 3 | packet fixture | keep |
| `Tests/OpenLolaCoreTests/Fixtures/UdpPcmRoutes/**` | 1 | route fixture | keep |
| `Tests/OpenLolaCoreTests/Fixtures/VideoCaptureReports/**` | 1 | report fixture | keep |
| `Tests/OpenLolaCoreTests/Fixtures/VideoTransportReports/**` | 1 | report fixture | keep |

## Consolidation Ledger

This ledger records test deletions that intentionally reduce volume. Each
deletion must point to stronger remaining behavior or shared contract coverage.

| Slice | Status | Tests removed or merged | Stronger remaining coverage | Verification |
|---|---|---|---|---|
| Report JSON round-trip duplicates | done | 28 per-report encode/decode equality tests listed below | Each affected file keeps fixture decode/validate, synthetic smoke, and report-specific negative/pass-policy behavior where applicable. Shared JSON report coverage remains centralized in `ReportSchemaInventoryTests.reportJSONCodingSurfaceIsExplicitContractAndUtilityBacked()` and inventory JSON surfaces remain in `*JSONSurfaceRoundTrips()` tests. | Focused report/schema slice passed with 542 Swift Testing tests; full Swift suite now passes with 1,701 tests, down from 1,729. |
| Synthetic smoke partial wrappers | done | 23 one-report synthetic smoke wrapper tests listed below | `SyntheticSmokeReportContractTests.syntheticSmokeReportsValidateAsPartialWithoutClaimingRuntimePass()` runs the same synthetic generators, validates each report, preserves the moved smoke-specific assertions, and keeps report-specific false-PASS/pass-policy tests in their original files. | Focused synthetic-smoke/report slice passed with 459 Swift Testing tests. |
| Public inventory JSON surface wrappers | done | 10 public inventory/matrix JSON surface wrapper tests listed below | `MachineReadableSurfaceContractTests.machineReadableInventoryAndMatrixJSONSurfacesRoundTrip()` decodes and compares each public CLI data surface against its authoritative report. Private-helper report round-trip tests remain local where their fixture builders are private. | Focused machine-readable surface slice passed with 70 Swift Testing tests; full Swift suite now passes with 1,670 tests, down from 1,729 before this consolidation pass. |
| Report fixture decode wrappers | done | 27 per-report fixture decode/validate wrapper tests listed below | `ReportFixtureValidationContractTests.reportFixturesDecodeAndValidateThroughSharedContract()` decodes and validates the same report fixtures once through a shared contract, while the individual report files keep their false-PASS/pass-policy, parser, runtime, and mutation behavior tests. Literal fixture-field assertions were intentionally not carried forward unless they protect behavior elsewhere. | Focused report fixture slice passed with 550 Swift Testing tests; active Swift marker count is now 1,646 `@Test`, down from 1,729 before this consolidation pass. |
| App-shell/process source trivia | done | 5 source-shape tests listed below | App-shell importability and action-inventory checks moved into `AppShellBehaviorTests.openLolaAppSupportInitializesTheSwiftUIAppSurface()`. Existing app-shell behavior tests cover state truthfulness, evidence gating, command preview escaping/readability, log-open errors, preview disabled/stop behavior, packet monitor failures, settings port rejection, and readable metric accessibility. `ManagedProcessRunnerTests.managedProcessRunnerRunsProcessToExitAndCapturesOutput()` keeps actual process execution coverage. | Focused app-shell/process slice passed with 23 Swift Testing tests; active Swift marker count is now 1,641 `@Test`. |
| Current evidence matrix count trivia | done | 2 fixed-count/crosswalk tests listed below | `CurrentEvidenceStatusMatrixReport.validate()` remains the validator for lane/task coverage and summary consistency, and `MachineReadableSurfaceContractTests.machineReadableInventoryAndMatrixJSONSurfacesRoundTrip()` still checks the public JSON surface. The file retains non-source-completable gate assertions, false-PASS rejection, and validator-output behavior. | Focused current-evidence slice passed with 6 Swift Testing tests; active Swift marker count is now 1,639 `@Test`. |
| Inventory summary count/source-helper trivia | done | 5 inventory summary/helper tests listed below | Shared machine-readable surface coverage still round-trips these public inventory JSON surfaces. The individual files retain owner/source/doc existence checks, CLI inventory coverage, required command/validator checks, false-PASS rejection, and evidence-boundary policy behavior. | Focused inventory-summary slice passed with 16 Swift Testing tests; active Swift marker count is now 1,634 `@Test`. |
| Command/source ownership summary trivia | done | 2 summary-count tests listed below | `commandInventoryReportMatchesRegisteredEntries()` still compares the public inventory report against the registered entries, and `sourceOwnershipInventoryCoversEveryCurrentSourceFile()` still verifies every current source file is owned. Shared machine-readable surface coverage still round-trips both inventory reports. | Focused command/source ownership slice passed with 23 Swift Testing tests; active Swift marker count is now 1,632 `@Test`. |
| Goal/schema summary and JSON trivia | done | 5 duplicate mapping/round-trip tests listed below | `GoalRuntimePreflightReport.validate()` still enforces deliverable coverage and false-PASS rejection; `GoalCompletionAuditReport.validate()` still enforces goal/runtime/release/verification coverage, next-action consistency, and blocker truthfulness; `ReportSchemaInventoryTests` keeps CLI validator mapping, fixture/smoke linkage, owner/test path checks, LoLa UDP evidence, parity validation-only policy, shared JSON coding, and strict validator failures. | Focused goal/schema slice passed with 26 Swift Testing tests. |
| Drift PLC fixed-target validator micro-tests | done | 17 one-field negative validator tests merged into `driftPlcFixedTargetCertificationRejectsInvalidPassEvidence()` | The merged test still mutates each former pass-candidate failure mode and asserts the same specific validation errors; the PASS candidate test remains separate. | Focused Drift PLC slice passed with 4 Swift Testing tests. |
| Latency tuning validator micro-tests | done | 10 one-field negative validator tests merged into `latencyTuningRejectsInvalidPassEvidence()` | The merged test still covers synthetic pass, hardware/route mismatch, zero duration, fastest/stable/rollback checks, baseline requirement, promoted latency regression, and missing low-buffer profile evidence. Positive tie-break and 16-frame rollback-profile behavior remain separate. | Focused latency-tuning slice passed with 6 Swift Testing tests. |
| Realtime audio engine validator micro-tests | done | 18 one-field negative validator tests merged into `realtimeAudioEngineRejectsInvalidPassEvidence()` | The merged test still covers callback safety, RME/route evidence, mode mismatches, direct RX-buffer evidence, runtime RX-buffer mismatch, ring capacity, packet handoff, late packets, artifact path, unbounded handoff, and callback-period enforcement. Realtime ring, playout, packet handoff, source-safety, RX-buffer, and PASS behavior remain separate. | Focused realtime-audio engine slice passed with 46 Swift Testing tests. |
| Integrated AV validator micro-tests | done | 30 one-field negative validator tests merged into `integratedAvReportRejectsInvalidPassEvidence()` | The merged test still covers run duration/window, P04 proof fields, audio/video/control proof gates, audio-master/no-blocking sync, frame timing, stale video, audio impact, pre-audio degradation, UI ownership, and non-pass audio baseline. Parser, runner, invalid frame range, sync-policy, scalar validation, and partial-report behavior remain separate. | Focused Integrated AV slice passed with 11 Swift Testing tests. |
| Hardware validation validator micro-tests | done | 12 one-field negative validator tests merged into `hardwareValidationRejectsInvalidPassEvidence()` | The merged test still covers measured-run, synthetic evidence, placeholder hardware fields, missing campus route, field-run route linkage, RME/Blackmagic/ATEM identity, and fastest-profile latency acceptance. Required route derivation, PASS duration tolerance, partial aggregation, path privacy, and PASS behavior remain separate. | Focused hardware-validation slice passed with 9 Swift Testing tests. Current raw Swift declarations are 1,543 `@Test` and 5,836 `#expect`. |

Removed in the report JSON round-trip duplicate slice:

- `videoCaptureReportJSONRoundTripPreservesReport`
- `macToMacRouteCertificationJSONRoundTripPreservesReport`
- `aoipEvaluationReportJSONRoundTripPreservesReport`
- `integratedAvReportJSONRoundTripPreservesReport`
- `performanceAuditJSONRoundTripPreservesReport`
- `integratedProfileJSONRoundTripPreservesReport`
- `latencyBenchmarkJSONRoundTripPreservesReport`
- `endpointLoopbackReportJSONRoundTripPreservesReport`
- `udpPcmRouteReportJSONRoundTripPreservesReport`
- `latencyTuningJSONRoundTripPreservesReport`
- `packagingFieldTestJSONRoundTripPreservesReport`
- `driftPlcFixedTargetCertificationJSONRoundTripPreservesReport`
- `lightingFixtureGateJSONRoundTripPreservesReport`
- `nativeAppShellJSONRoundTripPreservesReport`
- `nativeAppShellSurfaceProbeJSONRoundTripPreservesReport`
- `externalConnectorJSONRoundTripPreservesReport`
- `videoTransportReportJSONRoundTripPreservesReport`
- `recordingSessionJSONRoundTripPreservesReport`
- `openSourceReleaseReadinessJSONRoundTripPreservesReport`
- `e2eBenchmarkJSONRoundTripPreservesReport`
- `lolaParityDeferredLedgerJSONRoundTripPreservesReport`
- `releaseHardeningJSONRoundTripPreservesReport`
- `fieldReadyRuntimeJSONRoundTripPreservesReport`
- `realtimeAudioEngineJSONRoundTripPreservesReport`
- `driftPlcReportJSONRoundTripPreservesReport`
- `hardwareValidationJSONRoundTripPreservesReport`
- `networkAoipCertificationJSONRoundTripPreservesReport`
- `oscCueReportJSONRoundTripPreservesReport`

Removed in the synthetic smoke partial wrapper slice:

- `videoCaptureSyntheticSmokeEmitsPartialReport`
- `nativeAppShellSyntheticSmokeEmitsPartialReport`
- `macToMacRouteCertificationSyntheticSmokeEmitsPartialReport`
- `aoipSyntheticSmokeEmitsPartialReport`
- `performanceAuditSyntheticSmokeEmitsPartialReport`
- `packagingFieldTestSyntheticSmokeEmitsPartialReport`
- `externalConnectorSyntheticSmokeCoversRequestedConnectors`
- `hardwareValidationSyntheticSmokeEmitsPartialReport`
- `videoTransportSyntheticSmokeEmitsPartialReport`
- `driftPlcFixedTargetCertificationSyntheticSmokeEmitsPartialReport`
- `lightingFixtureGateSyntheticSmokeEmitsPartialReport`
- `fieldReadyRuntimeSyntheticSmokeEmitsPartialReport`
- `networkAoipCertificationSyntheticSmokeEmitsPartialReport`
- `recordingSessionSyntheticSmokeEmitsPartialReport`
- `latencyTuningSyntheticSmokeEmitsPartialReport`
- `integratedProfileSyntheticSmokeEmitsPartialReport`
- `integratedHeadlessAvSyntheticSmokeEmitsPartialReport`
- `latencyBenchmarkSyntheticSmokeEmitsPartialReport`
- `e2eBenchmarkSyntheticSmokeEmitsPartialReport`
- `releaseHardeningSyntheticSmokeEmitsPartialReport`
- `fasterThanLoLaClosureSyntheticSmokeEmitsPartialReport`
- `realtimeAudioEngineSyntheticSmokeEmitsPartialReport`
- `driftPlcSyntheticSmokeEmitsPartialReport`

Removed in the public inventory JSON surface wrapper slice:

- `commandInventoryJSONSurfaceRoundTrips`
- `reportSchemaInventoryJSONSurfaceRoundTrips`
- `fixtureSmokeMatrixJSONSurfaceRoundTrips`
- `videoControlDegradeMatrixJSONSurfaceRoundTrips`
- `networkRouteCommandMatrixJSONSurfaceRoundTrips`
- `goalCodewiseClosureJSONSurfaceRoundTrips`
- `currentEvidenceStatusMatrixJSONSurfaceRoundTrips`
- `sourceOwnershipInventoryJSONSurfaceRoundTrips`
- `goalRuntimeEvidenceTemplateJSONSurfaceRoundTrips`
- `realtimeAudioPathInventoryJSONSurfaceRoundTrips`

Removed in the report fixture decode wrapper slice:

- `aoipEvaluationReportFixtureDecodesAndValidates`
- `coreAudioInventoryFixtureDecodesAndValidates`
- `driftPlcFixedTargetCertificationPartialFixtureDecodesAndValidates`
- `driftPlcReportFixtureDecodesAndValidates`
- `endpointLoopbackReportFixtureDecodesAndValidates`
- `externalConnectorReportFixtureDecodesAndValidates`
- `fieldReadyRuntimeProofFixtureDecodesAndValidates`
- `hardwareValidationFixtureDecodesAndValidates`
- `integratedAvReportFixtureDecodesAndValidates`
- `integratedProfileFixtureDecodesAndValidates`
- `latencyBenchmarkPartialFixtureDecodesAndValidates`
- `latencyTuningFixtureDecodesAndValidates`
- `lightingFixtureGateFixtureDecodesAndValidates`
- `lolaParityDeferredLedgerFixtureDecodesAndValidates`
- `macToMacRouteCertificationPartialFixtureDecodesAndValidates`
- `nativeAppShellFixtureDecodesAndValidates`
- `networkAoipCertificationPartialFixtureDecodesAndValidates`
- `oscCueReportFixtureDecodesAndValidates`
- `packagingFieldTestFixtureDecodesAndValidates`
- `realtimeAudioEnginePartialFixtureDecodesAndValidates`
- `recordingSessionArtifactFixtureDecodesAndValidates`
- `referenceRigPartialFixtureDecodesAndValidates`
- `releaseHardeningFixtureDecodesAndValidates`
- `rmeFastestAudioPathPartialFixtureDecodesAndValidates`
- `udpPcmRouteReportFixtureDecodesAndValidates`
- `videoCaptureReportFixtureDecodesAndValidates`
- `videoTransportReportFixtureDecodesAndValidates`

Removed in the app-shell/process source trivia slice:

- `appShellSourceContractHasImportableBehaviorCoverage`
- `appShellMainEntrypointPublishesForegroundActivationBeforeSwiftUIScenes`
- `appShellUiSourceContractsCoverPlanUiRemediations`
- `appShellSettingsTabsAreSplitFromSettingsBindings`
- `appAndTwoPeerSupervisorUseManagedProcessRunner`

Removed in the current evidence matrix count trivia slice:

- `currentEvidenceStatusMatrixMapsEveryLaneAndRealWorldTask`
- `currentEvidenceStatusMatrixKeepsAllTaskReferencesKnown`

Removed in the inventory summary count/source-helper trivia slice:

- `realtimeAudioPathInventorySummaryMatchesEntries`
- `goalRuntimeEvidenceTemplateMapsEveryRuntimeDeliverable`
- `networkRouteCommandMatrixSummaryMatchesEntries`
- `videoControlDegradeMatrixSummaryMatchesEntries`
- `videoControlDegradeMatrixHelperRequiresExplicitAudioProtection`

Removed in the command/source ownership summary trivia slice:

- `commandInventorySummaryMatchesEntries`
- `sourceOwnershipInventorySummaryMatchesEntries`

Removed or merged in the goal/schema summary and JSON trivia slice:

- `reportSchemaInventorySummaryMatchesEntries`
- `goalRuntimePreflightMapsEveryRuntimeDeliverable`
- `goalRuntimePreflightJSONSurfaceRoundTrips`
- `goalCompletionAuditMapsAllSourceAndRuntimeRequirements`
- `goalCompletionAuditJSONSurfaceRoundTrips`

Merged in the Drift PLC fixed-target validator micro-test slice:

- `driftPlcFixedTargetCertificationRejectsPassWithoutMeasuredRun`
- `driftPlcFixedTargetCertificationRejectsPassWithoutRouteCertification`
- `driftPlcFixedTargetCertificationRejectsPassWithoutDriftReport`
- `driftPlcFixedTargetCertificationRejectsPassWithoutRealtimeEngineReport`
- `driftPlcFixedTargetCertificationRejectsPassWithoutAcceptedRealtimeEngineReport`
- `driftPlcFixedTargetCertificationRejectsPassWithoutAcceptedRouteCertification`
- `driftPlcFixedTargetCertificationRejectsPassWithoutAcceptedDriftReport`
- `driftPlcFixedTargetCertificationRejectsPassWithRealtimeRouteMismatch`
- `driftPlcFixedTargetCertificationRejectsPassWithPacketModeMismatch`
- `driftPlcFixedTargetCertificationRejectsPassWithRouteMismatch`
- `driftPlcFixedTargetCertificationRejectsPassWithoutLolaBaselineComparison`
- `driftPlcFixedTargetCertificationRejectsPassWithoutMeasuredLolaBaseline`
- `driftPlcFixedTargetCertificationRejectsPassWithLolaPacketModeMismatch`
- `driftPlcFixedTargetCertificationRejectsPassWithLolaRouteMismatch`
- `driftPlcFixedTargetCertificationRejectsPassWithTrailingLolaBaseline`
- `driftPlcFixedTargetCertificationRejectsPassWithoutRunArtifactPath`
- `driftPlcFixedTargetCertificationRejectsPassWithPlaceholderEvidence`

Merged in the latency tuning validator micro-test slice:

- `latencyTuningRejectsPassWithoutMeasuredRun`
- `latencyTuningRejectsIncludedHardwareMismatch`
- `latencyTuningRejectsIncludedRouteMismatch`
- `latencyTuningRejectsZeroDurationCandidate`
- `latencyTuningRejectsSelectedCandidateThatIsNotFastestStable`
- `latencyTuningRejectsPassWithUnstableSelectedCandidate`
- `latencyTuningRejectsPromotedChangeWithoutLatencyWin`
- `latencyTuningRejectsIneligibleRollbackCandidateWithSpecificError`
- `latencyTuningRejectsPassWithoutBaselineComparison`
- `latencyTuningRejectsSixteenFrameSelectedPassWithoutProfileEvidence`

Merged in the realtime audio engine validator micro-test slice:

- `realtimeAudioEngineRejectsPassWithCallbackAllocation`
- `realtimeAudioEngineRejectsPassWithoutMeasuredRmePath`
- `realtimeAudioEngineRejectsPassWithoutAcceptedRmeFastestAudioReport`
- `realtimeAudioEngineRejectsPassWithoutAcceptedRouteCertification`
- `realtimeAudioEngineRejectsPassWithRmeModeMismatch`
- `realtimeAudioEngineRejectsPassWithRouteModeMismatch`
- `realtimeAudioEngineRejectsPassWhenRoutePointsAtDifferentEngineReport`
- `realtimeAudioEngineRejectsPassWithBufferedPlayoutTarget`
- `realtimeAudioEngineRejectsPassWithRuntimeOnlyAdaptiveRxBuffer`
- `realtimeAudioEngineRejectsPassWithRuntimeRxBufferPolicyMismatch`
- `realtimeAudioEngineRejectsPassWithoutRuntimeRxBufferSnapshot`
- `realtimeAudioEngineRejectsPassWithoutExplicitRxBufferAccounting`
- `realtimeAudioEngineRejectsPassWithRingCapacityMismatch`
- `realtimeAudioEngineRejectsPassWithPacketHandoffMismatch`
- `realtimeAudioEngineRejectsPassWithLatePackets`
- `realtimeAudioEngineRejectsPassWithoutRunArtifactPath`
- `realtimeAudioEngineRejectsPassWithUnboundedHandoff`
- `realtimeAudioEngineRejectsPassWhenCallbackMaxExceedsPeriod`

Merged in the Integrated AV validator micro-test slice:

- `integratedAvReportRejectsPassRunShorterThanThirtyMinutes`
- `integratedAvReportRejectsPassWithoutRunWindow`
- `integratedAvReportRejectsPassWithInsufficientAudioVideoOverlap`
- `integratedAvReportRejectsPassWithAudioBaselineMismatch`
- `integratedAvReportRejectsPassWithIntegratedReportMismatch`
- `integratedAvReportRejectsPassWithoutAudioRoutePacketCapturePoint`
- `integratedAvReportRejectsPassWithoutVideoCaptureReportId`
- `integratedAvReportRejectsPassWithoutVideoTransportReportId`
- `integratedAvReportRejectsPassWithoutVideoTransportPacketCapturePoint`
- `integratedAvReportRejectsPassWithPlaceholderProofField`
- `integratedAvReportRejectsPassWithoutP04Proof`
- `integratedAvReportRejectsPassWithoutAudioOnlyBaselineFirst`
- `integratedAvReportRejectsPassWithoutRmeAudioDevice`
- `integratedAvReportRejectsPassWithoutVideoCapture`
- `integratedAvReportRejectsPassWithoutVideoTransportOrPreview`
- `integratedAvReportRejectsPassWithoutOscPolling`
- `integratedAvReportRejectsPassWithoutAtemReadOnlyPolling`
- `integratedAvReportRejectsPassWithAtemCommandsArmed`
- `integratedAvReportRejectsPassWithChangedRouteVerdict`
- `integratedAvReportRejectsNonAudioMasterClock`
- `integratedAvReportRejectsAudioBlockingForVideo`
- `integratedAvReportRejectsPassWithNonMonotonicVideoFrameTiming`
- `integratedAvReportRejectsPassWithDuplicateVideoFrameIdentities`
- `integratedAvReportRejectsPassWithStaleVideoRenderedPastBoundary`
- `integratedAvReportRejectsPassWhenVideoHoldsAudio`
- `integratedAvReportRejectsPassWithAudioP99Increase`
- `integratedAvReportRejectsPassWithPlayoutTargetChange`
- `integratedAvReportRejectsPassWithoutPreAudioDegradation`
- `integratedAvReportRejectsPassWhenUiOwnsRealtimePaths`
- `integratedAvReportRejectsPassWithNonPassAudioBaseline`

Merged in the hardware validation validator micro-test slice:

- `hardwareValidationRejectsPassWithoutMeasuredRun`
- `hardwareValidationRejectsPassWithSyntheticEvidence`
- `hardwareValidationRejectsPassWithSyntheticHardwareIdentity`
- `hardwareValidationRejectsPassWithHyphenatedNotSuppliedHardwareField`
- `hardwareValidationUsesSharedPhysicalEvidencePlaceholderProfile`
- `hardwareValidationRejectsPassWithoutCampusRoute`
- `hardwareValidationRejectsFieldRunRouteLabelWithoutMatchingRoute`
- `hardwareValidationRejectsPassWithoutRmeMadiIdentity`
- `hardwareValidationRejectsSubstringOnlyRmeMadiIdentity`
- `hardwareValidationRejectsPassWithoutBlackmagicAtemIdentity`
- `hardwareValidationRejectsSubstringOnlyBlackmagicAtemIdentity`
- `hardwareValidationRejectsPassWithoutFastestProfileLatencyAcceptance`

Retained deliberately:

- Report-specific false-PASS/pass-policy negative tests, parser checks,
  runtime mutation behavior, and hard-to-observe safety guards remain because
  those protect runtime gates and no-fake-success behavior.
- `appReceiverPreviewAudioMeterPublishesCallbackStateBeforeStartAndKeepsIOProcLockFree`
  remains as a temporary source guard for CoreAudio callback ordering and
  lock-free IOProc safety until the app shell has a narrow behavior seam for
  that invariant.

## Recommended Remediation Order

1. Rewrite source-text guards in `VerificationToolingContractTests`,
   `ReleaseArtifactHygieneContractTests`, and Python source guards first. These
   have high brittleness and lower runtime blast radius.
2. Merge report/schema/fixture duplicate checks into one authoritative matrix
   while preserving false-pass negative fixtures.
3. Rewrite runtime source guards in UDP/P2P and realtime audio files into
   behavioral seams one subsystem at a time.
4. Add deterministic adverse packet schedules and concurrent audio graph probes.
5. Rerun full Swift/Python/docs verification after each slice.

## Verification Notes

This audit document was produced from read-only inventory and source inspection.
Verification run after writing:

| Command | Result |
|---|---|
| `bash scripts/verify-docs.sh` | FAIL: `docs/testing` rejects unexpected active detail docs: `test-quality-audit.md`. |
| `python3 -m scripts.verify_docs` | FAIL: same docs-authority rejection as above. |
| `PYTHONDONTWRITEBYTECODE=1 python -m pytest -p no:cacheprovider linux_connector` | PASS: 90 collected, 88 passed, 2 skipped. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --quiet` | PASS: 1,749 Swift tests passed after the current release/tooling, fixture/schema pruning, adverse handoff schedule, DirectPeer source-guard pruning, and UDP packet codec source-guard rewrite slices. |

The docs failure is an active documentation-authority policy blocker, not a
Markdown syntax failure. This audit-only pass did not update
`docs/testing/README.md` or the docs verifier because the requested edit scope
was limited to this audit document.

The intended verification for a remediation pass that chooses to make this
audit document an active docs surface is:

```bash
bash scripts/verify-docs.sh
python3 -m scripts.verify_docs
PYTHONDONTWRITEBYTECODE=1 python -m pytest -p no:cacheprovider linux_connector
swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel
```

SwiftPM may need to run outside the sandbox if manifest sandboxing fails. Do not
call the active test suite fully green unless the Swift and Python checks both
complete successfully.

Remediation slice verification:

| Command | Result |
|---|---|
| `PYTHONDONTWRITEBYTECODE=1 python -m pytest -p no:cacheprovider linux_connector/tests/test_codec.py linux_connector/tests/test_process_runtime.py` | PASS: 75 passed, 2 skipped. |
| `ruff check linux_connector scripts/verify_docs scripts/lib/*.py` | PASS: all checks passed. |
| `PYTHONDONTWRITEBYTECODE=1 python -m pytest -p no:cacheprovider linux_connector` | PASS: 87 collected, 85 passed, 2 skipped. |
| `PYTHONDONTWRITEBYTECODE=1 python -m pytest -p no:cacheprovider linux_connector/tests/test_runtime_contracts.py linux_connector/tests/test_process_runtime.py` | PASS: 47 collected, 45 passed, 2 skipped. |
| `python3 -m scripts.verify_docs` | PASS: documentation verification passed. |
| `bash scripts/verify-docs.sh` | PASS: documentation verification passed. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel` | PASS: 1,759 Swift tests passed after the current release/tooling and fixture/schema pruning slice. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --filter 'ReportSchemaInventoryTests\|GoalRuntimePreflightTests\|GoalCompletionAuditTests\|MachineReadableSurfaceContractTests\|CodeLineBudgetTests\|ValidateAssertionContractTests'` | PASS: 26 Swift Testing tests after goal/schema summary and JSON trivia pruning. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --filter 'DriftPlcFixedTargetCertificationTests\|CodeLineBudgetTests\|ValidateAssertionContractTests'` | PASS: 4 Swift Testing tests after Drift PLC validator micro-test consolidation. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --filter 'LatencyTuningReportTests\|CodeLineBudgetTests\|ValidateAssertionContractTests'` | PASS: 6 Swift Testing tests after latency-tuning validator micro-test consolidation. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --filter 'RealtimeAudioEngineTests\|RxBufferingTests\|CodeLineBudgetTests\|ValidateAssertionContractTests'` | PASS: 46 Swift Testing tests after realtime-audio engine validator micro-test consolidation. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --filter 'IntegratedAvReportTests\|CodeLineBudgetTests\|ValidateAssertionContractTests'` | PASS: 11 Swift Testing tests after Integrated AV validator micro-test consolidation. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --filter 'HardwareValidationReportTests\|CodeLineBudgetTests\|ValidateAssertionContractTests'` | PASS: 9 Swift Testing tests after hardware-validation validator micro-test consolidation. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --quiet` | PASS: 1,543 Swift Testing tests after the current cumulative consolidation pass. |
| `PYTHONDONTWRITEBYTECODE=1 python -m pytest -p no:cacheprovider linux_connector` | PASS: 87 collected, 85 passed, 2 skipped after the current cumulative consolidation pass. |
| `bash scripts/verify-docs.sh` | PASS: documentation verification passed after the current cumulative consolidation pass. |
| `python3 -m scripts.verify_docs` | PASS: documentation verification passed after the current cumulative consolidation pass. |
| `git diff --check` | PASS: no whitespace errors after the current cumulative consolidation pass. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --filter ReleaseArtifactHygieneContractTests` | PASS: 10 tests passed after merging duplicate UltraGrid policy coverage and pruning duplicate release-readiness hygiene-gate coverage. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --filter VerificationToolingContractTests` | PASS: 10 tests passed. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --filter 'FixtureSmokeMatrixTests\|ReportSchemaInventoryTests'` | PASS: 19 tests passed after pruning two source-shape guards. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --filter 'FixtureSmokeMatrixTests\|ReportSchemaInventoryTests'` | PASS: 19 tests passed after replacing fixed fixture/schema summary totals with derived active-tree and inventory-entry checks. |
| `python3 -m scripts.verify_docs` | PASS: documentation verification passed after the fixture/schema literal-count ledger update. |
| `bash scripts/verify-docs.sh` | PASS: documentation verification passed after the fixture/schema literal-count ledger update. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --filter RealtimeAudioPacketHandoffTests` | PASS: 23 tests passed after adding deterministic loss/reorder/duplicate/underrun/overrun handoff schedule coverage. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel` | PASS: 1,760 Swift tests passed after adding the adverse handoff schedule. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --filter UdpMediaTransportTests` | PASS: 22 tests passed after adding the `[1, 3, 2, 2, 5]` adverse UDP media schedule. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --filter DirectPeerRealtimeAudioGraphTests` | PASS: 13 tests passed after adding a bounded concurrent capture producer / payload consumer probe and pruning 12 source-string guards. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --quiet` | FAIL: 1,762 tests executed, but `CodeLineBudgetTests.scopedCodeFilesStayWithinLineBudget()` reported `DirectPeerRealtimeAudioGraphTests.swift` at 786/720 lines before source-guard pruning. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --quiet` | PASS: 1,750 Swift tests passed after DirectPeer source-guard pruning restored the line budget. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --filter 'ReleaseArtifactHygieneContractTests\|VerificationToolingContractTests\|DocsVerifierPolicyTests'` | PASS: 23 docs/release/verification contract tests passed after the final ledger update. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --filter UdpPcmPacketTests` | PASS: 16 packet codec tests passed after replacing source reads with codec round-trip behavior. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --quiet` | PASS: 1,749 Swift tests passed after the UDP packet codec source-guard rewrite. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --filter AppBundleScriptSourcePolicyTests` | PASS: 2 app bundle script behavior tests passed after replacing source substring checks with temp-root script executions. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --quiet` | PASS: 1,749 Swift tests passed after the app bundle script source-policy rewrite. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --filter DocsVerifierPolicyTests` | PASS: 3 docs verifier policy tests passed after replacing the constants source guard with runtime verifier imports. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --quiet` | PASS: 1,749 Swift tests passed after the docs verifier constants source-guard rewrite. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --filter UdpPcmRouteReportTests` | PASS: 39 UDP route report/configuration tests passed after replacing configuration validation source checks with behavior assertions. |
| `python3 -m scripts.verify_docs` | PASS: documentation verification passed after the UDP route configuration ledger update. |
| `bash scripts/verify-docs.sh` | PASS: documentation verification passed after the UDP route configuration ledger update. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --quiet` | PASS: 1,749 Swift tests passed after the UDP route configuration source-guard reduction. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --filter ValidationPrimitivesTests` | PASS: 3 validation primitive tests passed after replacing source inventory assertions with direct validator and percentile-ordering behavior. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --filter 'SourceNamingConventionTests|ValidationPrimitivesTests'` | PASS: 6 source naming and validation primitive tests passed after pruning the two-peer prototype TODO source sentinel. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --filter SourceNamingConventionTests` | PASS: 2 source naming tests passed after consolidating policy-document assertions into one focused naming contract. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --filter UdpPcmRouteReportTests` | PASS: 39 UDP route report/configuration tests passed after replacing packet-age source-body checks and zero-byte receive source guards with behavior assertions. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --filter UdpPcmRouteReportTests` | PASS: 39 UDP route report/configuration tests passed after replacing deadline, integer-bound, and fcntl source guards with behavior assertions. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --filter UdpPcmRouteReportTests` | PASS: 39 UDP route report/configuration tests passed after replacing socket-readiness helper and source-address receive source guards with loopback socket behavior. |
| `python3 -m scripts.verify_docs` | PASS: documentation verification passed after the UDP route source-guard ledger update. |
| `bash scripts/verify-docs.sh` | PASS: documentation verification passed after the UDP route source-guard ledger update. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --quiet` | PASS: 1,747 Swift tests passed after the latest UDP route source-guard reductions and release-readiness script test seam. |
| `PYTHONDONTWRITEBYTECODE=1 python -m pytest -p no:cacheprovider linux_connector` | PASS: 85 Python connector tests passed, 2 skipped, after the latest test-quality remediation. |
| `git diff --check` | PASS: no whitespace errors after the latest test-quality remediation. |
| `python3 -m scripts.verify_docs` | PASS: documentation verification passed after the validation primitive and source naming ledger update. |
| `bash scripts/verify-docs.sh` | PASS: documentation verification passed after the validation primitive and source naming ledger update. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --quiet` | PASS: 1,749 Swift tests passed after the validation primitive source-guard rewrite and source naming TODO sentinel pruning. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --filter AudioOpusCeltLowDelayPacketTests` | PASS: 3 Opus low-delay packet tests passed after replacing the checked-reader source guard with malformed packet decode behavior. |
| `python3 -m scripts.verify_docs` | PASS: documentation verification passed after the Opus packet ledger update. |
| `bash scripts/verify-docs.sh` | PASS: documentation verification passed after the Opus packet ledger update. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --quiet` | PASS: 1,749 Swift tests passed after the Opus packet source-guard rewrite. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --filter OpusCELTLowDelayCodecTests` | PASS: 4 Opus CELT low-delay codec tests passed after replacing source guards with caller-owned scratch-buffer capacity behavior. |
| `python3 -m scripts.verify_docs` | PASS: documentation verification passed after the Opus codec ledger update. |
| `bash scripts/verify-docs.sh` | PASS: documentation verification passed after the Opus codec ledger update. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --filter DirectPeerSessionOpusCLITests` | PASS: 5 Opus direct-P2P CLI tests passed after replacing the hidden legacy audio-compression source guard with executable CLI behavior. |
| `python3 -m scripts.verify_docs` | PASS: documentation verification passed after the Opus CLI ledger update. |
| `bash scripts/verify-docs.sh` | PASS: documentation verification passed after the Opus CLI ledger update. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --quiet` | PASS: 1,748 Swift tests passed after the Opus codec and Opus CLI source-guard rewrites. |
| `shellcheck scripts/verify-release-readiness.sh` | PASS: edited release-readiness script remains shellcheck-clean after adding the sourceable `main` guard. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --filter VerificationToolingContractTests` | PASS: 10 verification tooling tests passed after replacing the manual-gate source guard with sourced helper behavior. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --filter 'UdpPcmRouteReportTests\|CLICommandInventoryTests'` | PASS: 49 UDP route report and CLI inventory tests passed after replacing the UDP route help source scan with executable help behavior. |
| `python3 -m scripts.verify_docs` | PASS: documentation verification passed after the UDP route help ledger update. |
| `bash scripts/verify-docs.sh` | PASS: documentation verification passed after the UDP route help ledger update. |
| `git diff --check` | PASS: no whitespace errors after the UDP route help source-guard rewrite. |
| `PYTHONDONTWRITEBYTECODE=1 python -m pytest -p no:cacheprovider linux_connector` | PASS: 85 Python connector tests passed, 2 skipped, after the UDP route help source-guard rewrite. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --quiet` | PASS: 1,747 Swift tests passed after the UDP route help source-guard rewrite and current ledger update. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --filter UdpPcmRouteReportTests` | PASS: 39 UDP route report/configuration tests passed after replacing the continuous receiver duplicate/loss source guard with loopback receiver behavior and fixing duplicate-aware route validation. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --quiet` | FAIL: 1,748 tests executed, but `CodeLineBudgetTests` reported `UdpPcmRouteReportTests.swift` at 785/720 lines and `ValidateAssertionContractTests` flagged a validator-only duplicate-accounting test. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --filter 'UdpPcmRouteReportTests\|udpPcmContinuousReceiverReportsLossFromUniqueSequences\|CodeLineBudgetTests\|ValidateAssertionContractTests'` | PASS: 40 route, receiver, line-budget, and assertion-contract tests passed after moving the continuous receiver probe to `UdpPcmContinuousReceiverTests.swift` and removing the redundant validator-only test. |
| `python3 -m scripts.verify_docs` | PASS: documentation verification passed after the continuous receiver ledger update. |
| `bash scripts/verify-docs.sh` | PASS: documentation verification passed after the continuous receiver ledger update. |
| `git diff --check` | PASS: no whitespace errors after the continuous receiver split and validator fix. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --quiet` | PASS: 1,747 Swift tests passed after the continuous receiver split and duplicate-aware route validation fix. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --filter 'UdpPcmRouteReportTests\|udpPcmContinuousReceiverReportsLossFromUniqueSequences\|CodeLineBudgetTests\|ValidateAssertionContractTests'` | PASS: 39 route, receiver, line-budget, and assertion-contract tests passed after folding wrong-mode packet rejection into the continuous receiver behavior test and removing the remaining receiver-accounting source-order guard. |
| `python3 -m scripts.verify_docs` | PASS: documentation verification passed after removing the receiver mode source-order guard. |
| `bash scripts/verify-docs.sh` | PASS: documentation verification passed after removing the receiver mode source-order guard. |
| `git diff --check` | PASS: no whitespace errors after removing the receiver mode source-order guard. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --quiet` | PASS: 1,746 Swift tests passed after removing the receiver mode source-order guard. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --filter 'UdpPcmRouteReportTests\|CodeLineBudgetTests\|ValidateAssertionContractTests'` | PASS: 38 route, line-budget, and assertion-contract tests passed after replacing the UDP socket buffer source guard with runtime socket option readback. |
| `python3 -m scripts.verify_docs` | PASS: documentation verification passed after the UDP socket buffer ledger update. |
| `bash scripts/verify-docs.sh` | PASS: documentation verification passed after the UDP socket buffer ledger update. |
| `git diff --check` | PASS: no whitespace errors after the UDP socket buffer ledger update. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --filter 'ReportSchemaInventoryTests\|CodeLineBudgetTests\|ValidateAssertionContractTests'` | PASS: 14 report schema, line-budget, and assertion-contract tests passed after pruning report-validator source-shape guards. |
| `python3 -m scripts.verify_docs` | PASS: documentation verification passed after the report-validator source-shape pruning ledger update. |
| `bash scripts/verify-docs.sh` | PASS: documentation verification passed after the report-validator source-shape pruning ledger update. |
| `git diff --check` | PASS: no whitespace errors after the report-validator source-shape pruning ledger update. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --quiet` | PASS: 1,744 Swift tests passed after pruning report-validator source-shape guards. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --filter 'UdpPcmRouteReportTests\|CodeLineBudgetTests\|ValidateAssertionContractTests'` | PASS: 36 route, line-budget, and assertion-contract tests passed after pruning the final UDP caller-readiness source-placement guards. |
| `python3 -m scripts.verify_docs` | PASS: documentation verification passed after closing the UDP route configuration source-guard ledger row. |
| `bash scripts/verify-docs.sh` | PASS: documentation verification passed after closing the UDP route configuration source-guard ledger row. |
| `git diff --check` | PASS: no whitespace errors after closing the UDP route configuration source-guard ledger row. |
| `PYTHONDONTWRITEBYTECODE=1 python -m pytest -p no:cacheprovider linux_connector` | PASS: 85 Python connector tests passed, 2 skipped, after the latest test-quality remediation. |
| `ruff check linux_connector scripts/verify_docs scripts/lib/*.py` | PASS: all Python lint checks passed after the latest test-quality remediation. |
| `shellcheck scripts/verify-release-readiness.sh` | PASS: edited release-readiness script remains shellcheck-clean. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --quiet` | PASS: 1,742 Swift tests passed after pruning the final UDP caller-readiness source-placement guards and updating this ledger. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --filter 'VerificationToolingContractTests\|CodeLineBudgetTests\|ValidateAssertionContractTests'` | PASS: 13 verification-tooling, line-budget, and assertion-contract tests passed after replacing the native UltraGrid connection-metrics helper source reference with direct metrics-writer execution. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --filter 'UdpPcmLoopbackLatencyTests\|CodeLineBudgetTests\|ValidateAssertionContractTests'` | PASS: 18 loopback, line-budget, and assertion-contract tests passed after fixing duplicate-echo loss accounting in the UDP PCM loopback sender. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --filter 'UdpPcmLoopbackLatencyTests\|CodeLineBudgetTests\|ValidateAssertionContractTests'` | PASS: 17 loopback, line-budget, and assertion-contract tests passed after pruning the UDP PCM loopback default/UUID/bound-port source scans. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --filter 'VerificationToolingContractTests\|ReleaseArtifactHygieneContractTests\|CodeLineBudgetTests\|ValidateAssertionContractTests'` | PASS: 22 release/tooling, line-budget, and assertion-contract tests passed after pruning the duplicate local UltraGrid Docker source/literal checklist from `VerificationToolingContractTests.swift`. |
| `python3 -m scripts.verify_docs` | PASS: documentation verification passed after pruning the duplicate local UltraGrid Docker source/literal checklist. |
| `bash scripts/verify-docs.sh` | PASS: documentation verification passed after pruning the duplicate local UltraGrid Docker source/literal checklist. |
| `git diff --check` | PASS: no whitespace errors after pruning the duplicate local UltraGrid Docker source/literal checklist. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --quiet` | PASS: 1,742 Swift tests passed before the native app bundle helper documentation source-scan pruning baseline. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --filter 'VerificationToolingContractTests\|AppBundleScriptSourcePolicyTests\|NativeAppShellTests\|CodeLineBudgetTests\|ValidateAssertionContractTests'` | PASS: 44 verification, app-bundle, native-shell, line-budget, and assertion-contract tests passed after pruning the native app bundle helper documentation source scan. |
| `python3 -m scripts.verify_docs` | PASS: documentation verification passed after pruning the native app bundle helper documentation source scan. |
| `bash scripts/verify-docs.sh` | PASS: documentation verification passed after pruning the native app bundle helper documentation source scan. |
| `git diff --check` | PASS: no whitespace errors after pruning the native app bundle helper documentation source scan. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --filter 'VerificationToolingContractTests\|CodeLineBudgetTests\|ValidateAssertionContractTests'` | PASS: 12 verification-tooling, line-budget, and assertion-contract tests passed after replacing native UltraGrid wrapper source checks with fake-executable behavior and fixing the wrapper's macOS Bash lowercase compatibility. |
| `shellcheck scripts/open-lola-ultragrid-native-client.sh` | PASS: native UltraGrid wrapper shell remains shellcheck-clean after replacing Bash 4 lowercase expansion with `tr`. |
| `python3 -m scripts.verify_docs` | PASS: documentation verification passed after the native UltraGrid wrapper behavior-test ledger update. |
| `bash scripts/verify-docs.sh` | PASS: documentation verification passed after the native UltraGrid wrapper behavior-test ledger update. |
| `git diff --check` | PASS: no whitespace errors after the native UltraGrid wrapper behavior-test ledger update. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --quiet` | PASS: 1,742 Swift tests passed after the native UltraGrid wrapper behavior test and macOS Bash compatibility fix. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --filter 'VerificationToolingContractTests\|CodeLineBudgetTests\|ValidateAssertionContractTests'` | PASS: 13 verification-tooling, line-budget, and assertion-contract tests passed after replacing UltraGrid Docker wrapper role source checks with fake-docker behavior. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --filter 'VerificationToolingContractTests\|CodeLineBudgetTests\|ValidateAssertionContractTests'` | PASS: 14 verification-tooling, line-budget, and assertion-contract tests passed after replacing paired JackTrip RX/TX role source checks with fake `open-lola` and fake `docker` behavior. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --filter 'VerificationToolingContractTests\|CodeLineBudgetTests\|ValidateAssertionContractTests'` | PASS: 15 verification-tooling, line-budget, and assertion-contract tests passed after replacing paired UltraGrid Docker RX/TX role source checks with fake `open-lola` and fake `docker` behavior. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --filter 'VerificationToolingContractTests\|VerificationToolingPairScriptTests\|CodeLineBudgetTests\|ValidateAssertionContractTests'` | PASS: 16 verification-tooling, pair-script, line-budget, and assertion-contract tests passed after adding the paired native UltraGrid RX/TX preflight behavior test and splitting pair-script behavior tests under the line budget. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --filter 'VerificationToolingContractTests\|VerificationToolingPairScriptTests\|CodeLineBudgetTests\|ValidateAssertionContractTests'` | PASS: 17 verification-tooling, pair-script, line-budget, and assertion-contract tests passed after replacing the native UltraGrid preflight failure source guard with fake-preflight behavior. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --filter 'VerificationToolingContractTests\|VerificationToolingPairScriptTests\|CodeLineBudgetTests\|ValidateAssertionContractTests'` | PASS: 17 verification-tooling, pair-script, line-budget, and assertion-contract tests passed after pruning UltraGrid Docker helper-internal source checks covered by the fake paired-run behavior. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --filter 'ExternalConnectorProcessGroupTests\|VerificationToolingContractTests\|VerificationToolingPairScriptTests\|CodeLineBudgetTests\|ValidateAssertionContractTests'` | PASS: 29 external-connector process group, verification-tooling, pair-script, line-budget, and assertion-contract tests passed after replacing the external connector role environment source guard with real-runner fake-executable behavior. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --filter 'ExternalConnectorProcessGroupTests\|VerificationToolingContractTests\|VerificationToolingPairScriptTests\|CodeLineBudgetTests\|ValidateAssertionContractTests'` | PASS: 28 external-connector process group, verification-tooling, pair-script, line-budget, and assertion-contract tests passed after pruning the process-group implementation-symbol source scan. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --filter 'VerificationToolingContractTests\|VerificationToolingPairScriptTests\|CodeLineBudgetTests\|ValidateAssertionContractTests'` | PASS: 17 verification-tooling, pair-script, line-budget, and assertion-contract tests passed after replacing the release-readiness matrix source scan with a sourceable `main` orchestration probe. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --quiet` | PASS: 1,747 Swift tests passed after the external-connector and release-readiness source-guard remediation slices. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --filter 'VerificationToolingContractTests\|VerificationToolingPairScriptTests\|CodeLineBudgetTests\|ValidateAssertionContractTests'` | PASS: 18 verification-tooling, pair-script, line-budget, and assertion-contract tests passed after replacing UltraGrid parity metrics writer source checks with direct metrics-writer execution and Python 3.9-compatible endpoint pairing. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --filter 'VerificationToolingContractTests\|VerificationToolingPairScriptTests\|CodeLineBudgetTests\|ValidateAssertionContractTests'` | PASS: 18 verification-tooling, pair-script, line-budget, and assertion-contract tests passed after pruning duplicate JackTrip helper source scans already covered by fake pair-script and Docker behavior tests. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --filter 'VerificationToolingContractTests\|VerificationToolingPairScriptTests\|CodeLineBudgetTests\|ValidateAssertionContractTests'` | PASS: 19 verification-tooling, pair-script, line-budget, and assertion-contract tests passed after replacing UltraGrid comparator/stress source scans with Docker pass-summary and native preflight-failure stress-script behavior. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --filter 'AudioLoopbackRunTests\|CodeLineBudgetTests\|ValidateAssertionContractTests'` | PASS: 28 audio-loopback, line-budget, and assertion-contract tests passed after pruning the microseconds-per-second naming source guard. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --quiet` | PASS: 1,748 Swift tests passed after the UltraGrid stress-script and AudioLoopback source-guard pruning slices. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --filter 'ReleaseArtifactHygieneContractTests\|CodeLineBudgetTests\|ValidateAssertionContractTests'` | PASS: 12 release-hygiene, line-budget, and assertion-contract tests passed after replacing UltraGrid Dockerfile substring checks with deterministic Dockerfile instruction parsing. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --filter 'DirectPeerSessionCLITests\|VideoTransportRunnerTests\|MultiVideoTransportTests\|CodeLineBudgetTests\|ValidateAssertionContractTests'` | PASS: 27 direct-P2P CLI, video transport, line-budget, and assertion-contract tests passed after replacing direct-P2P/video source guards with executable parser/report/runtime behavior and pruning duplicate implementation-shape tests. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --filter 'UdpMediaTransportTests\|CodeLineBudgetTests\|ValidateAssertionContractTests'` | PASS: 22 UDP media, line-budget, and assertion-contract tests passed after replacing UDP media source guards with malformed nested-payload behavior and retaining the adverse loss/reorder/duplicate schedule. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --filter 'LatencyBenchmarkReportTests\|CodeLineBudgetTests\|ValidateAssertionContractTests'` | PASS: 26 latency benchmark, line-budget, and assertion-contract tests passed after pruning redundant methodology source scans and replacing the fail-fast validation source guard with behavior. |
| `python3 -m scripts.verify_docs` | PASS: documentation verification passed after the direct-P2P/video, UDP media, latency benchmark, and ledger status updates. |
| `bash scripts/verify-docs.sh` | PASS: documentation verification passed after the direct-P2P/video, UDP media, latency benchmark, and ledger status updates. |
| `git diff --check` | PASS: no whitespace errors after the direct-P2P/video, UDP media, latency benchmark, and ledger status updates. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --quiet` | PASS: 1,742 Swift tests passed after the direct-P2P/video, UDP media, latency benchmark, and ledger status updates. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --filter 'E2EBenchmarkReportTests\|CodeLineBudgetTests\|ValidateAssertionContractTests'` | PASS: 18 E2E benchmark, line-budget, and assertion-contract tests passed after replacing E2E source guards with report/parser/executable behavior and removing the duplicate threshold source scan. |
| `python3 -m scripts.verify_docs` | PASS: documentation verification passed after the E2E benchmark ledger update. |
| `bash scripts/verify-docs.sh` | PASS: documentation verification passed after the E2E benchmark ledger update. |
| `git diff --check` | PASS: no whitespace errors after the E2E benchmark ledger update. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --filter 'DriftPlcReportTests\|CodeLineBudgetTests\|ValidateAssertionContractTests'` | PASS: 30 Drift PLC report, line-budget, and assertion-contract tests passed after replacing selected Drift PLC source guards with fixed-target and parser behavior. |
| `python3 -m scripts.verify_docs` | PASS: documentation verification passed after the Drift PLC ledger update. |
| `bash scripts/verify-docs.sh` | PASS: documentation verification passed after the Drift PLC ledger update. |
| `git diff --check` | PASS: no whitespace errors after the Drift PLC ledger update. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --filter 'IntegratedAvReportTests\|CodeLineBudgetTests\|ValidateAssertionContractTests'` | PASS: 46 Integrated AV report, line-budget, and assertion-contract tests passed after replacing the Integrated AV parser source guard with key-value parser behavior. |
| `python3 -m scripts.verify_docs` | PASS: documentation verification passed after the Integrated AV ledger update. |
| `bash scripts/verify-docs.sh` | PASS: documentation verification passed after the Integrated AV ledger update. |
| `git diff --check` | PASS: no whitespace errors after the Integrated AV ledger update. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --filter 'HardwareValidationReportTests\|CodeLineBudgetTests\|ValidateAssertionContractTests'` | PASS: 23 Hardware Validation report, line-budget, and assertion-contract tests passed after replacing the required-route source guard with route-enforcement behavior. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --filter 'ReferenceRigReportTests\|CodeLineBudgetTests\|ValidateAssertionContractTests'` | PASS: 19 Reference Rig report, line-budget, and assertion-contract tests passed after replacing the stable-buffer source guard with threshold-target behavior. |
| `python3 -m scripts.verify_docs` | PASS: documentation verification passed after the Reference Rig ledger update. |
| `bash scripts/verify-docs.sh` | PASS: documentation verification passed after the Reference Rig ledger update. |
| `git diff --check` | PASS: no whitespace errors after the Reference Rig ledger update. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --filter 'RmeFastestAudioPathTests\|CodeLineBudgetTests\|ValidateAssertionContractTests'` | PASS: 24 RME fastest-path report, line-budget, and assertion-contract tests passed after replacing selected implementation scans with helper and validation behavior. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --filter 'IntegratedProfileRunEvidenceTests\|CodeLineBudgetTests\|ValidateAssertionContractTests'` | PASS: 6 Integrated Profile runtime-evidence, line-budget, and assertion-contract tests passed after replacing source scans with combined-metric behavior. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --filter 'IntegratedAvReportTests\|CodeLineBudgetTests\|ValidateAssertionContractTests'` | PASS: 43 Integrated AV report, line-budget, and assertion-contract tests passed after replacing validation/helper source scans with sync-policy and scalar-field behavior. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --filter 'DirectPeerTwoPeerPrototypeReportTests\|CodeLineBudgetTests\|ValidateAssertionContractTests'` | PASS: 9 Direct Peer two-peer prototype, line-budget, and assertion-contract tests passed after replacing selected source/comment scans with hash, SSRC, digest, and frame-proof behavior. |
| `python3 -m scripts.verify_docs` | PASS: documentation verification passed after the direct peer prototype ledger update. |
| `bash scripts/verify-docs.sh` | PASS: documentation verification passed after the direct peer prototype ledger update. |
| `git diff --check` | PASS: no whitespace errors after the direct peer prototype ledger update. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --filter 'DirectPeerTwoPeerRunPlanTests\|CodeLineBudgetTests\|ValidateAssertionContractTests'` | PASS: 25 Direct Peer two-peer run-plan, line-budget, and assertion-contract tests passed after replacing the peer-ID extraction source guard with builder behavior. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --quiet` | PASS: 1,736 Swift tests passed after the Direct Peer prototype and two-peer run-plan source-guard rewrites. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --filter 'CoreAudioInventoryTests\|CodeLineBudgetTests\|ValidateAssertionContractTests'` | PASS: 14 CoreAudio inventory, line-budget, and assertion-contract tests passed after pruning fallback-cache and property-address source-shape guards. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --filter 'DebugTraceTests\|CodeLineBudgetTests\|ValidateAssertionContractTests'` | PASS: 10 DebugTrace, line-budget, and assertion-contract tests passed after replacing the file-backed trace source scan with temp-file write behavior. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --filter 'DirectPeerAudioPayloadRingTests\|CodeLineBudgetTests\|ValidateAssertionContractTests'` | PASS: 10 DirectPeer audio payload ring, line-budget, and assertion-contract tests passed after replacing private-helper and alignment source scans with public ring behavior. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --filter 'BlackmagicReceiveRenderTests\|CodeLineBudgetTests\|ValidateAssertionContractTests'` | PASS: 13 Blackmagic receive/render, line-budget, and assertion-contract tests passed after replacing the latency-buffer source scan with rolling-window metrics behavior. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --filter 'PeerSessionMetricsAndControlTests\|CodeLineBudgetTests\|ValidateAssertionContractTests'` | FAIL then PASS: first behavior attempt exposed peer ID slash validation; after switching to CLI-safe hyphenated IDs, 7 PeerSession metrics/control, line-budget, and assertion-contract tests passed. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --quiet` | PASS: 1,734 executed Swift Testing tests passed after the DirectPeer payload ring, Blackmagic receive/render, and PeerSession metrics/control source-guard rewrites. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --filter 'LoLaLiveUdpMediaRoutingTests\|SwiftTestingDiscoveryTests\|CodeLineBudgetTests\|ValidateAssertionContractTests'` | FAIL then PASS: first behavior replacement used nonexistent `.audioOnly`; after switching to `.audio`, 4 LoLa live-routing, discovery, line-budget, and assertion-contract tests passed. |
| `python3 -m scripts.verify_docs` | PASS: documentation verification passed after the LoLa live-routing ledger update. |
| `bash scripts/verify-docs.sh` | PASS: documentation verification passed after the LoLa live-routing ledger update. |
| `git diff --check` | PASS: no whitespace errors after the LoLa live-routing ledger update. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --filter 'LoLaCompatibilityRawLinkAndUdpMediaTests\|LoLaCompatibilityMediaSessionSupportTests\|SwiftTestingDiscoveryTests\|CodeLineBudgetTests\|ValidateAssertionContractTests'` | PASS: 23 raw-link/UDP-media, support, discovery, line-budget, and assertion-contract tests passed after replacing the BPF source-offset guard with captured-length/header-length packet-extraction behavior. |
| `python3 -m scripts.verify_docs` | PASS: documentation verification passed after the LoLa raw-link BPF ledger update. |
| `bash scripts/verify-docs.sh` | PASS: documentation verification passed after the LoLa raw-link BPF ledger update. |
| `git diff --check` | PASS: no whitespace errors after the LoLa raw-link BPF ledger update. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --quiet` | PASS: 1,734 executed Swift Testing tests passed after the LoLa live-routing, raw-link BPF, and control-socket source-guard rewrites. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --filter 'LoLaCompatibilityControlSocketTests\|SwiftTestingDiscoveryTests\|CodeLineBudgetTests\|ValidateAssertionContractTests'` | PASS: 9 control-socket, discovery, line-budget, and assertion-contract tests passed after replacing the bind-errno source guard with socket behavior. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --filter 'LoLaQuickConnectFallbackTests\|SwiftTestingDiscoveryTests\|CodeLineBudgetTests\|ValidateAssertionContractTests'` | PASS: 12 quick-connect fallback, discovery, line-budget, and assertion-contract tests passed after pruning the duplicate parser source guard. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --filter 'RmeFastestAudioPathTests\|SwiftTestingDiscoveryTests\|CodeLineBudgetTests\|ValidateAssertionContractTests'` | PASS: 25 RME fastest-path, discovery, line-budget, and assertion-contract tests passed after replacing the remaining placeholder checklist source guard with validator behavior. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --filter 'KeyValueArgumentParserTests\|SwiftTestingDiscoveryTests\|CodeLineBudgetTests\|ValidateAssertionContractTests'` | PASS: 12 parser, discovery, line-budget, and assertion-contract tests passed after pruning parser source-comment guards. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --quiet` | PASS: 1,732 Swift Testing tests passed after the KeyValue parser and MediaClock source-guard remediations. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --quiet` | PASS: 1,732 Swift Testing tests passed after pruning the DirectPeer manual-validation source guard. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --quiet` | FAIL then PASS: first Opus defaults replacement exposed that persisted Opus is rejected unless the stored audio shape is Opus-compatible; after setting channel count, sample rate, frame count, and sample format in the test defaults, 1,732 Swift Testing tests passed. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --quiet` | FAIL then PASS: first LoLa UDP media socket replacement assumed duplicate UDP bind failure and exposed macOS reuse semantics; after switching to unassigned-host fallback behavior, 1,732 Swift Testing tests passed. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --quiet` | PASS: 1,732 Swift Testing tests passed after replacing the Rx impairment deterministic-jitter source guard with seeded output behavior. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --filter 'MacToMacRouteCertificationTests\|LoLaParityDeferredFeaturesTests\|RecordingSessionArtifactTests\|CodeLineBudgetTests\|ValidateAssertionContractTests'` | PASS: 48 report, recording-session, line-budget, and assertion-contract tests passed after replacing low-signal source-shape checks with report validation and parser behavior. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --filter 'SourceOwnershipInventoryTests\|VideoTransportReportTests\|CodeLineBudgetTests\|ValidateAssertionContractTests'` | PASS: 40 source-ownership, video-transport, line-budget, and assertion-contract tests passed after replacing duplicate source-shape checks with inventory resolution and video transport behavior. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --filter 'FixtureSmokeMatrixTests\|ReportSchemaInventoryTests\|CodeLineBudgetTests\|ValidateAssertionContractTests'` | PASS: 19 fixture/schema matrix, line-budget, and assertion-contract tests passed after making fixture false-pass ownership derive from `ReportSchemaInventory`. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --filter 'FixtureSmokeMatrixTests\|ReportSchemaInventoryTests\|DirectPeerSessionReportAVPassTests\|ExternalConnectorAvMatrixTests\|FasterThanLoLaClosureTests\|FieldReadyRuntimeProofTests\|GoalCompletionAuditTests\|IntegratedProfileReportTests\|LatencyTuningReportTests\|LightingFixtureGateTests\|LoLaParityDeferredFeaturesTests\|MacToMacRouteCertificationTests\|OscCueReportTests\|RecordingSessionArtifactPolicyTests\|RecordingSessionArtifactTests\|ReleaseHardeningTests\|SourceOwnershipInventoryTests\|VideoCaptureReportTests\|VideoTransportReportPolicyTests\|VideoTransportReportTests\|CodeLineBudgetTests\|ValidateAssertionContractTests'` | PASS: 361 affected report/schema/fixture merge-scope tests passed. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --quiet` | PASS: 1,729 Swift Testing tests passed after closing the broader report/schema fixture merge row. |
| `bash scripts/verify-docs.sh` | PASS: documentation verification passed after marking the broader report/schema fixture merge row done. |
| `python3 -m scripts.verify_docs` | PASS: documentation verification passed after the final broader report/schema fixture merge ledger update. |
| `PYTHONDONTWRITEBYTECODE=1 python -m pytest -p no:cacheprovider linux_connector` | PASS: 85 Python connector tests passed, 2 skipped, after the final broader report/schema fixture merge ledger update. |
| `git diff --check` | PASS: no whitespace errors after the final broader report/schema fixture merge ledger update. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --filter 'VideoCaptureReportTests\|MacToMacRouteCertificationTests\|AoipEvaluationReportTests\|IntegratedAvReportTests\|PerformanceAuditTests\|IntegratedProfileReportTests\|LatencyBenchmarkReportTests\|EndpointLoopbackReportTests\|UdpPcmRouteReportTests\|LatencyTuningReportTests\|PackagingFieldTestTests\|DriftPlcFixedTargetCertificationTests\|LightingFixtureGateTests\|NativeAppShellPolicyTests\|ExternalConnectorReportTests\|VideoTransportReportPolicyTests\|RecordingSessionArtifactPolicyTests\|OpenSourceReleaseReadinessTests\|E2EBenchmarkReportTests\|LoLaParityDeferredFeaturesTests\|ReleaseHardeningTests\|FieldReadyRuntimeProofTests\|RealtimeAudioEngineTests\|DriftPlcReportTests\|HardwareValidationReportTests\|NetworkAoipCertificationTests\|OscCueReportTests\|ReportSchemaInventoryTests\|CodeLineBudgetTests\|ValidateAssertionContractTests'` | PASS: 542 affected report/schema, line-budget, and assertion-contract tests passed after removing 28 duplicate per-report JSON round-trip equality tests. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --quiet` | PASS: 1,701 Swift Testing tests passed after the report JSON round-trip duplicate consolidation. |
| `PYTHONDONTWRITEBYTECODE=1 python -m pytest -p no:cacheprovider linux_connector` | PASS: 87 Python connector tests collected; 85 passed, 2 skipped after the report JSON round-trip duplicate consolidation. |
| `bash scripts/verify-docs.sh` | PASS: documentation verification passed after adding the consolidation ledger. |
| `python3 -m scripts.verify_docs` | PASS: documentation verification passed after adding the consolidation ledger. |
| `git diff --check` | PASS: no whitespace errors after the report JSON round-trip duplicate consolidation. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --filter 'SyntheticSmokeReportContractTests\|VideoCaptureReportTests\|NativeAppShellTests\|MacToMacRouteCertificationTests\|AoipEvaluationReportTests\|PerformanceAuditTests\|PackagingFieldTestTests\|ExternalConnectorReportTests\|HardwareValidationReportTests\|VideoTransportRunnerTests\|DriftPlcFixedTargetCertificationTests\|LightingFixtureGateTests\|FieldReadyRuntimeProofTests\|NetworkAoipCertificationTests\|RecordingSessionArtifactTests\|LatencyTuningReportTests\|IntegratedProfileReportTests\|IntegratedAvReportTests\|LatencyBenchmarkReportTests\|E2EBenchmarkReportTests\|ReleaseHardeningTests\|FasterThanLoLaClosureTests\|RealtimeAudioEngineTests\|DriftPlcReportTests\|CodeLineBudgetTests\|ValidateAssertionContractTests'` | PASS: 459 affected synthetic-smoke, report, line-budget, and assertion-contract tests passed after merging 23 synthetic smoke wrapper tests into one matrix. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --filter 'MachineReadableSurfaceContractTests\|CLICommandInventoryTests\|ReportSchemaInventoryTests\|FixtureSmokeMatrixTests\|VideoControlDegradeMatrixTests\|NetworkRouteCommandMatrixTests\|GoalCodewiseClosureTests\|CurrentEvidenceStatusMatrixTests\|SourceOwnershipInventoryTests\|GoalRuntimeEvidenceTemplateTests\|RealtimeAudioPathInventoryTests\|CodeLineBudgetTests\|ValidateAssertionContractTests'` | PASS: 70 affected machine-readable surface, line-budget, and assertion-contract tests passed after merging 10 public JSON surface wrapper tests into one matrix. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --quiet` | PASS: 1,670 Swift Testing tests passed after the synthetic-smoke and public JSON surface matrix consolidations. |
| `PYTHONDONTWRITEBYTECODE=1 python -m pytest -p no:cacheprovider linux_connector` | PASS: 87 Python connector tests collected; 85 passed, 2 skipped after the latest consolidation. |
| `bash scripts/verify-docs.sh` | PASS: documentation verification passed after the latest consolidation ledger update. |
| `python3 -m scripts.verify_docs` | PASS: documentation verification passed after the latest consolidation ledger update. |
| `git diff --check` | PASS: no whitespace errors after the latest consolidation. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --filter 'ReportFixtureValidationContractTests\|AoipEvaluationReportTests\|CoreAudioInventoryTests\|DriftPlcFixedTargetCertificationTests\|DriftPlcReportTests\|EndpointLoopbackReportTests\|ExternalConnectorReportTests\|FieldReadyRuntimeProofTests\|HardwareValidationReportTests\|IntegratedAvReportTests\|IntegratedProfileReportTests\|LatencyBenchmarkReportTests\|LatencyTuningReportTests\|LightingFixtureGateTests\|LoLaParityDeferredFeaturesTests\|MacToMacRouteCertificationTests\|NativeAppShellTests\|NetworkAoipCertificationTests\|OscCueReportTests\|PackagingFieldTestTests\|RealtimeAudioEngineTests\|RecordingSessionArtifactTests\|ReferenceRigReportTests\|ReleaseHardeningTests\|RmeFastestAudioPathTests\|UdpPcmRouteReportTests\|VideoCaptureReportTests\|VideoTransportReportTests\|CodeLineBudgetTests\|ValidateAssertionContractTests'` | FAIL then PASS: first shared fixture test used the logical fixture subdirectory without the SwiftPM resource-root fallback and had no explicit assertion for the assertion-contract guard; after adding the fallback and a nonempty case-name assertion, 550 affected report-fixture, line-budget, and assertion-contract tests passed. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --quiet` | PASS: 1,644 Swift Testing tests passed after the report fixture decode wrapper consolidation. |
| `PYTHONDONTWRITEBYTECODE=1 python -m pytest -p no:cacheprovider linux_connector` | PASS: 87 Python connector tests collected; 85 passed, 2 skipped after the report fixture decode wrapper consolidation. |
| `bash scripts/verify-docs.sh` | PASS: documentation verification passed after the report fixture decode wrapper consolidation. |
| `python3 -m scripts.verify_docs` | PASS: documentation verification passed after the report fixture decode wrapper consolidation. |
| `git diff --check` | PASS: no whitespace errors after the report fixture decode wrapper consolidation. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --filter 'AppShellBehaviorTests\|AppShellSourceContractTests\|ManagedProcessRunnerTests\|CodeLineBudgetTests\|ValidateAssertionContractTests'` | PASS: 23 app-shell behavior/source-safety, process-runner, line-budget, and assertion-contract tests passed after pruning five source-trivia tests. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --filter 'CurrentEvidenceStatusMatrixTests\|MachineReadableSurfaceContractTests\|CodeLineBudgetTests\|ValidateAssertionContractTests'` | PASS: 6 current-evidence, shared machine-readable-surface, line-budget, and assertion-contract tests passed after pruning duplicate count/crosswalk trivia. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --filter 'RealtimeAudioPathInventoryTests\|GoalRuntimeEvidenceTemplateTests\|NetworkRouteCommandMatrixTests\|VideoControlDegradeMatrixTests\|MachineReadableSurfaceContractTests\|CodeLineBudgetTests\|ValidateAssertionContractTests'` | PASS: 16 inventory, shared machine-readable-surface, line-budget, and assertion-contract tests passed after pruning duplicate fixed summary-count/source-helper trivia. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --filter 'SourceOwnershipInventoryTests\|CLICommandInventoryTests\|MachineReadableSurfaceContractTests\|CodeLineBudgetTests\|ValidateAssertionContractTests'` | PASS: 23 command/source-ownership inventory, shared machine-readable-surface, line-budget, and assertion-contract tests passed after pruning duplicate summary-count trivia. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --filter 'NativeAppShellTests\|CodeLineBudgetTests\|ValidateAssertionContractTests'` | PASS: 16 selected native app shell, line-budget, and assertion-contract tests passed after grouping low-signal app-shell validation tests and pruning one source-comment guard. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --filter 'OscCueReportTests\|CodeLineBudgetTests\|ValidateAssertionContractTests'` | PASS: 23 selected OSC/ATEM, line-budget, and assertion-contract tests passed after grouping malformed/config rejection tests and pruning low-signal source-helper scans. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --filter 'ExternalConnectorSessionTests\|CodeLineBudgetTests\|ValidateAssertionContractTests'` | PASS: 16 selected external connector session, socket-heavy LoLa loopback, line-budget, and assertion-contract tests passed after grouping launch-plan/report/parser rejection tests. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --filter 'RecordingSessionArtifactTests\|CodeLineBudgetTests\|ValidateAssertionContractTests'` | PASS: 16 selected recording-session artifact, line-budget, and assertion-contract tests passed after grouping parser, baseline-failure, and live-capture source-contract checks. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --filter 'SessionNegotiationTests\|CodeLineBudgetTests\|ValidateAssertionContractTests'` | PASS: 21 selected session negotiation/protocol, line-budget, and assertion-contract tests passed after grouping negotiation rejection contracts. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --filter 'UdpPcmV2PacketTests\|CodeLineBudgetTests\|ValidateAssertionContractTests'` | PASS: 14 selected UDP PCM v2 packet, line-budget, and assertion-contract tests passed after grouping malformed decode and planner overflow checks. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --filter 'DirectPeerTwoPeerRunPlanTests\|CodeLineBudgetTests\|ValidateAssertionContractTests'` | PASS: 20 selected DirectPeer two-peer plan, line-budget, and assertion-contract tests passed after grouping invalid pass/plan contract checks. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --filter 'EndpointLoopbackReportTests\|CodeLineBudgetTests\|ValidateAssertionContractTests'` | PASS: 3 selected endpoint-loopback, line-budget, and assertion-contract tests passed after grouping certification validation checks. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --filter 'NativeAppShellPolicyTests\|MacToMacRouteCertificationTests\|ExternalConnectorReportTests\|AoipEvaluationReportTests\|CodeLineBudgetTests\|ValidateAssertionContractTests'` | PASS: 7 selected small report-policy, line-budget, and assertion-contract tests passed after grouping invalid-PASS policy suites. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --filter 'MeasurementReportFixtureTests\|LoLaParityDeferredFeaturesTests\|ReleaseHardeningTests\|GoalCompletionAuditTests\|CodeLineBudgetTests\|ValidateAssertionContractTests'` | PASS: 16 selected fixture/release-ledger, line-budget, and assertion-contract tests passed after grouping invalid fixture, deferred-feature, release-hardening, and goal-audit checks. |
| `python3 -m pytest --collect-only -q linux_connector` | PASS: 87 Python connector tests collected after the current Swift-side ledger update; Python implementation was not changed in this slice. |
| `bash scripts/verify-docs.sh` | PASS: documentation verification passed after refreshing current counts, file accounting, and latest consolidation ledger rows. |
| `python3 -m scripts.verify_docs` | PASS: documentation verification passed after refreshing current counts, file accounting, and latest consolidation ledger rows. |
| `git diff --check` | PASS: no whitespace errors after the latest consolidation and ledger update. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --filter 'RealtimeAudioPacketHandoffTests\|CodeLineBudgetTests\|ValidateAssertionContractTests'` | PASS: 7 selected realtime packet-handoff, line-budget, and assertion-contract tests passed after grouping capture/drop, receive/fallback/rejection, and V2 pre-send mismatch micro-tests. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --filter 'LightingFixtureGateTests\|CodeLineBudgetTests\|ValidateAssertionContractTests'` | PASS: 12 selected lighting fixture gate, line-budget, and assertion-contract tests passed after grouping unsafe-output and parser rejection checks. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --filter 'ExternalConnectorAvMatrixTests\|ExternalConnectorConnectionPlanTests\|CodeLineBudgetTests\|ValidateAssertionContractTests'` | PASS: 29 selected external connector AV/connection-plan, line-budget, and assertion-contract tests passed after grouping invalid connector input and connection-plan artifact checks. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --filter 'VideoTransportRunnerTests\|UdpPcmLoopbackLatencyTests\|CodeLineBudgetTests\|ValidateAssertionContractTests'` | PASS: 19 selected video transport runner, UDP PCM loopback latency, line-budget, and assertion-contract tests passed after grouping parser and session mismatch checks. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --filter 'SessionProtocolTests\|CodeLineBudgetTests\|ValidateAssertionContractTests'` | PASS: 14 selected session protocol, line-budget, and assertion-contract tests passed after grouping stable identity and capability validation checks. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --filter 'NatFriendlyRouteTests\|CodeLineBudgetTests\|ValidateAssertionContractTests'` | PASS: 20 selected NAT route, line-budget, and assertion-contract tests passed after grouping parser, registration-helper, and invalid-evidence checks. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --filter 'LatencyBenchmarkReportTests\|CodeLineBudgetTests\|ValidateAssertionContractTests'` | PASS: 15 selected latency benchmark, line-budget, and assertion-contract tests passed after grouping summary and jitter validation checks. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --filter 'UdpPcmRouteReportTests\|CodeLineBudgetTests\|ValidateAssertionContractTests'` | PASS: 19 selected UDP PCM route, line-budget, and assertion-contract tests passed after grouping DSCP, parser, socket invalid-receive, and localhost partial smoke checks. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --filter 'IntegratedAvReportTests\|CodeLineBudgetTests\|ValidateAssertionContractTests'` | PASS: 8 selected Integrated AV report, line-budget, and assertion-contract tests passed after grouping parser and partial-field validation checks. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --filter 'LoLaControlHandshakeValidationTests\|CodeLineBudgetTests\|ValidateAssertionContractTests'` | PASS: 9 selected LoLa control handshake, line-budget, and assertion-contract tests passed after grouping duplicate UDP/TCP handshake rejection cases. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --filter 'LoLaCompatibilityMediaEnvelopeValidationTests\|CodeLineBudgetTests\|ValidateAssertionContractTests'` | PASS: 9 selected LoLa media envelope validation, line-budget, and assertion-contract tests passed after grouping duplicate video envelope rejection cases. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --filter 'UdpPcmPacketTests\|CodeLineBudgetTests\|ValidateAssertionContractTests'` | PASS: 15 selected UDP PCM packet, line-budget, and assertion-contract tests passed after grouping fixture decode and malformed parser checks. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --filter 'LoLaCompatibilityMediaCodecTests\|CodeLineBudgetTests\|ValidateAssertionContractTests'` | PASS: 16 selected LoLa media codec, line-budget, and assertion-contract tests passed after grouping audio codec micro-tests. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --filter 'VideoTransportReportTests\|CodeLineBudgetTests\|ValidateAssertionContractTests'` | PASS: 23 selected video transport, line-budget, and assertion-contract tests passed after grouping duplicate reassembler and malformed fragment decode checks. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --filter 'VideoCaptureReportTests\|CodeLineBudgetTests\|ValidateAssertionContractTests'` | PASS: 18 selected video capture, line-budget, and assertion-contract tests passed after grouping timestamp, inventory, production-evidence, and parser rejection checks. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --filter 'UdpMediaTransportTests\|CodeLineBudgetTests\|ValidateAssertionContractTests'` | PASS: 17 selected UDP media transport, line-budget, and assertion-contract tests passed after grouping packet mismatch/malformed payload and sequence-metric checks. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --filter 'OscCueReportTests\|CodeLineBudgetTests\|ValidateAssertionContractTests'` | PASS: 19 selected OSC/ATEM, line-budget, and assertion-contract tests passed after grouping parser, report, and network-probe micro-tests. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --filter 'RxBufferingTests\|CodeLineBudgetTests\|ValidateAssertionContractTests'` | PASS: 20 selected RX buffering, line-budget, and assertion-contract tests passed after grouping policy-validation and deterministic simulator boundary cases. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --filter 'KeyValueArgumentParserTests\|SessionNegotiationTests\|ExternalConnectorConnectionPlanTests\|CodeLineBudgetTests\|ValidateAssertionContractTests'` | PASS: 32 selected parser, negotiation, connection-plan, line-budget, and assertion-contract tests passed after grouping parser edge cases, pruning the redundant negotiation source-order guard, and grouping connection-plan port/preflight checks. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --filter 'MadiReceiveTests\|MadiFullDuplexSessionTests\|MultichannelTransportTests\|DriftPlcReportTests\|CodeLineBudgetTests\|ValidateAssertionContractTests'` | FAIL then PASS: first merge had local variable-name collisions in MADI receive and Drift PLC invalid-packet cases; after renaming the merged locals, 63 selected MADI, multichannel, drift/PLC, line-budget, and assertion-contract tests passed. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --filter 'AppShellBehaviorTests\|CodeLineBudgetTests\|ValidateAssertionContractTests'` | PASS: 16 selected app-shell behavior, line-budget, and assertion-contract tests passed after grouping AppShell state/evidence, latency metrics, command preview, validation-failure, and preview idle checks. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --filter 'PeerSessionRunnerTests\|CodeLineBudgetTests\|ValidateAssertionContractTests'` | FAIL then PASS: first merged lifecycle expectation assumed shutdown added a second media-stop boundary after recovery; after restoring the observed idempotent boundary contract, 15 selected peer-session runner, line-budget, and assertion-contract tests passed. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --filter 'PeerSessionAVSupportTests\|CodeLineBudgetTests\|ValidateAssertionContractTests'` | PASS: 17 selected peer-session AV support, line-budget, and assertion-contract tests passed after grouping decoded-RX source safety, malformed audio RX drop cases, and AV socket-runner source-safety checks. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --filter 'VideoTransportReportTests\|CodeLineBudgetTests\|ValidateAssertionContractTests'` | PASS: 13 selected video transport, line-budget, and assertion-contract tests passed after grouping packet/wire-format, reassembler, wrap-ordering, and malformed decode/encoding micro-tests. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --filter 'LoLaCompatibilityRawLinkAndUdpMediaTests\|CodeLineBudgetTests\|ValidateAssertionContractTests'` | PASS: 14 selected LoLa raw-link/UDP media, line-budget, and assertion-contract tests passed after grouping BPF extraction, raw-link receive timeout/configuration, UDP retry, and UDP receive failure-report micro-tests. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --filter 'DirectPeerTwoPeerRunPlanTests\|CodeLineBudgetTests\|ValidateAssertionContractTests'` | PASS: 12 selected DirectPeer two-peer plan/report, line-budget, and assertion-contract tests passed after grouping measured PASS, planner/parser, validator-surface, local-run, and receive-proof artifact micro-tests. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --filter 'NatFriendlyRouteTests\|CodeLineBudgetTests\|ValidateAssertionContractTests'` | PASS: 13 selected NAT route, line-budget, and assertion-contract tests passed after grouping parser, source-safety, and duplicate rendezvous smoke checks. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --filter 'UdpPcmRouteReportTests\|CodeLineBudgetTests\|ValidateAssertionContractTests'` | PASS: 12 selected UDP PCM route, line-budget, and assertion-contract tests passed after grouping route validation, configuration, packet-count, and socket-error micro-tests. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --filter 'RealtimeAudioEngineTests\|CodeLineBudgetTests\|ValidateAssertionContractTests'` | PASS: 15 selected realtime audio engine, line-budget, and assertion-contract tests passed after grouping playout boundary and zero-block direct-RX policy micro-tests. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --filter 'RxBufferingTests\|CodeLineBudgetTests\|ValidateAssertionContractTests'` | FAIL then PASS: first merged latency benchmark test reused a local `report` name; after renaming the pass candidate, 16 selected RX buffering, line-budget, and assertion-contract tests passed after grouping controller/report/benchmark micro-tests. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --filter 'OscCueReportTests\|CodeLineBudgetTests\|ValidateAssertionContractTests'` | FAIL then PASS: first merged ATEM probe test reused a local `report` name; after renaming the unavailable report, 14 selected OSC/ATEM, line-budget, and assertion-contract tests passed after grouping parser, UDP receive, OSC validation, and ATEM probe report micro-tests. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --filter 'MadiReceiveTests\|CodeLineBudgetTests\|ValidateAssertionContractTests'` | PASS: 15 selected MADI receive, line-budget, and assertion-contract tests passed after grouping transport-mode mismatch and pending-deadline/ready-pool boundary micro-tests. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --filter 'AudioLoopbackRunTests\|CodeLineBudgetTests\|ValidateAssertionContractTests'` | PASS: 13 selected audio-loopback, line-budget, and assertion-contract tests passed after grouping parser success, low-buffer opt-in, and parser rejection micro-tests. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --filter 'VideoCaptureReportTests\|CodeLineBudgetTests\|ValidateAssertionContractTests'` | PASS: 14 selected video capture, line-budget, and assertion-contract tests passed after grouping AVFoundation source-contract micro-tests. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --filter 'ExternalConnectorAvMatrixTests\|CodeLineBudgetTests\|ValidateAssertionContractTests'` | PASS: 13 selected external connector AV matrix, line-budget, and assertion-contract tests passed after grouping role and module matrix variants. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --filter 'ExternalConnectorSessionTests\|CodeLineBudgetTests\|ValidateAssertionContractTests'` | PASS: 9 selected external connector session, socket-heavy LoLa loopback, line-budget, and assertion-contract tests passed after grouping launch-plan, parser/rejection, dry-run/process-run, and runtime source-contract variants. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --filter 'RecordingSessionArtifactTests\|CodeLineBudgetTests\|ValidateAssertionContractTests'` | PASS: 11 selected recording-session artifact, line-budget, and assertion-contract tests passed after grouping parser mode variants and injected raw-artifact variants. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --filter 'MultichannelTransportTests\|CodeLineBudgetTests\|ValidateAssertionContractTests'` | PASS: 8 selected multichannel transport, line-budget, and assertion-contract tests passed after grouping negotiation, planner, packetizer/reassembler, receiver-mix, and RME metadata variants. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --filter 'UdpMediaTransportTests\|CodeLineBudgetTests\|ValidateAssertionContractTests'` | PASS: 8 selected UDP media transport, line-budget, and assertion-contract tests passed after grouping envelope, malformed-payload, packetizer, DSCP, and adverse metric schedules. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --filter 'SourceNamingConventionTests\|CodeLineBudgetTests\|ValidateAssertionContractTests'` | PASS: 3 selected source-naming, line-budget, and assertion-contract tests passed after grouping naming policy with public command/schema coverage. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --filter 'ReleaseRunConfigurationContractTests\|CodeLineBudgetTests\|ValidateAssertionContractTests'` | PASS: 3 selected release-run configuration, line-budget, and assertion-contract tests passed after grouping source-doc and testing-index contracts. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --filter 'LoLaCompatibilityMediaCodecTests\|CodeLineBudgetTests\|ValidateAssertionContractTests'` | PASS: 8 selected LoLa media codec, line-budget, and assertion-contract tests passed after grouping JPEG, audio, video, generated-payload, and reassembly variants. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --filter 'ExternalConnectorLoLaCompatibilityTests\|CodeLineBudgetTests\|ValidateAssertionContractTests'` | PASS: 9 selected external connector LoLa compatibility, line-budget, and assertion-contract tests passed after grouping wire-frame and control-message variants. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --filter 'NativeAppShellTests\|CodeLineBudgetTests\|ValidateAssertionContractTests'` | PASS: 11 selected native app shell, line-budget, and assertion-contract tests passed after grouping packet-monitor, operator command/plan, surface-probe, and runtime-smoke variants. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --filter 'MadiFullDuplexSessionTests\|CodeLineBudgetTests\|ValidateAssertionContractTests'` | PASS: 11 selected MADI full-duplex session, socket-runtime, line-budget, and assertion-contract tests passed after grouping configuration, render, drift, and source-safety variants. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --filter 'DriftPlcReportTests\|CodeLineBudgetTests\|ValidateAssertionContractTests'` | PASS: 11 selected Drift PLC report, line-budget, and assertion-contract tests passed after grouping report validator, parser, runner, jitter-buffer, and drift-clock behavior. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --filter 'PeerSessionAVSupportTests\|CodeLineBudgetTests\|ValidateAssertionContractTests'` | FAIL then PASS: merged metrics publish/report behavior first expected the isolated report count; after updating it for the already-drained metrics message, 11 selected AV support, line-budget, and assertion-contract tests passed. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --filter 'SessionNegotiationTests\|CodeLineBudgetTests\|ValidateAssertionContractTests'` | PASS: 13 selected session/Opus negotiation, line-budget, and assertion-contract tests passed after grouping negotiation acceptance, topology, profile, and rejection variants. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --filter 'RealtimeAudioEngineTests\|CodeLineBudgetTests\|ValidateAssertionContractTests'` | PASS: 10 selected realtime audio engine, line-budget, and assertion-contract tests passed after grouping report evidence, playout classification, and handoff receive variants. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --filter 'UdpPcmPacketTests\|CodeLineBudgetTests\|ValidateAssertionContractTests'` | PASS: 9 selected UDP PCM packet, line-budget, and assertion-contract tests passed after grouping fixture, mode, malformed, and v2 packet variants. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --filter 'LatencyBenchmarkReportTests\|CodeLineBudgetTests\|ValidateAssertionContractTests'` | PASS: 9 selected latency benchmark, line-budget, and assertion-contract tests passed after grouping sampling, invalid-report, and low-buffer evidence variants. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --filter 'DirectPeerRealtimeAudioGraphTests\|CodeLineBudgetTests\|ValidateAssertionContractTests'` | PASS: 11 selected direct-peer realtime graph, line-budget, and assertion-contract tests passed after grouping capture, playout/drop, RX-buffer reorder, and zero-channel variants. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --filter 'RxBufferingTests\|CodeLineBudgetTests\|ValidateAssertionContractTests'` | PASS: 13 selected RX buffering plus graph RX-buffering, line-budget, and assertion-contract tests passed after grouping handoff policy and simulator jitter/duplicate variants. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --filter 'RealtimeAudioPacketHandoffTests\|CodeLineBudgetTests\|ValidateAssertionContractTests'` | PASS: 7 selected realtime packet-handoff, line-budget, and assertion-contract tests passed after grouping capture/drop, receive/fallback/rejection, and V2 pre-send mismatch micro-tests. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --filter 'MadiReceiveTests\|CodeLineBudgetTests\|ValidateAssertionContractTests'` | PASS: 10 selected MADI receive, line-budget, and assertion-contract tests passed after grouping receive/render recovery, late/future/overflow rejection, RX-buffer, and ready-ring guard scenarios. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --filter 'AppShellBehaviorTests\|CodeLineBudgetTests\|ValidateAssertionContractTests'` | FAIL then PASS: first app-shell helper merge reused local validation names; after renaming the passing evidence locals, 11 selected app-shell, line-budget, and assertion-contract tests passed. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --filter 'PeerSessionRunnerTests\|CodeLineBudgetTests\|ValidateAssertionContractTests'` | PASS: 10 selected peer-session runner, socket-heavy role/AV route, line-budget, and assertion-contract tests passed after grouping preflight, state/lifecycle, topology, and runtime validation scenarios. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --filter 'PeerSessionRunnerNegotiationTests\|CodeLineBudgetTests\|ValidateAssertionContractTests'` | FAIL then PASS: first helper signature used the wrong video-compression type/order; after switching to `DirectPeerSessionVideoCompression` and matching proposal argument order, 6 selected negotiation, line-budget, and assertion-contract tests passed. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --filter 'VideoCaptureReportTests\|CodeLineBudgetTests\|ValidateAssertionContractTests'` | FAIL then PASS: first inventory/evidence merge reused a local generic-device fixture name; after renaming it, 9 selected video capture, line-budget, and assertion-contract tests passed. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --filter 'SessionProtocolTests\|CodeLineBudgetTests\|ValidateAssertionContractTests'` | FAIL then PASS: first control-message merge reused the `message` local; after renaming metadata coding locals, 7 selected session protocol, line-budget, and assertion-contract tests passed. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --filter 'PeerSessionAVSupportVideoTests\|CodeLineBudgetTests\|ValidateAssertionContractTests'` | PASS: 9 selected AV video support, line-budget, and assertion-contract tests passed after grouping preview, sync-policy, frame-helper, and fragment-budget scenarios. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --filter 'PackagingFieldTestTests\|CodeLineBudgetTests\|ValidateAssertionContractTests'` | PASS: 7 selected packaging field-test, line-budget, and assertion-contract tests passed after grouping parser, fixture, and invalid-PASS policy scenarios. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --filter 'LoLaCompatibilityRawLinkAndUdpMediaTests\|CodeLineBudgetTests\|ValidateAssertionContractTests'` | FAIL then PASS: first UDP receive merge reused a local `source` name; after renaming the invalid receive source, 9 selected raw-link/UDP media, line-budget, and assertion-contract tests passed. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --filter 'OscCueReportTests\|CodeLineBudgetTests\|ValidateAssertionContractTests'` | FAIL then PASS: first ATEM merge reused a local `report` name; after renaming the timeout report, 8 selected OSC/ATEM, line-budget, and assertion-contract tests passed. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --filter 'BlackmagicReceiveRenderTests\|CodeLineBudgetTests\|ValidateAssertionContractTests'` | PASS: 5 selected Blackmagic receive/render, line-budget, and assertion-contract tests passed after grouping reassembler, renderer, boundary, and physical-evidence scenarios. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --filter 'CoreAudioInventoryTests\|CodeLineBudgetTests\|ValidateAssertionContractTests'` | PASS: 6 selected CoreAudio inventory, line-budget, and assertion-contract tests passed after grouping validation, model, fallback identity, and retained source-contract scenarios. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --filter 'ExternalConnectorProcessGroupTests\|CodeLineBudgetTests\|ValidateAssertionContractTests'` | PASS: 8 selected external connector process-group, line-budget, and assertion-contract tests passed after grouping injected-runner, failure-report, and host-readiness scenarios. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --filter 'SourceOwnershipInventoryTests\|CodeLineBudgetTests\|ValidateAssertionContractTests'` | PASS: 6 selected source-ownership inventory, line-budget, and assertion-contract tests passed after grouping integrity, resolution, and policy scenarios. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --filter 'ReportSchemaInventoryTests\|CodeLineBudgetTests\|ValidateAssertionContractTests'` | PASS: 5 selected report-schema inventory, line-budget, and assertion-contract tests passed after grouping validator, fixture, owner, and policy scenarios. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --filter 'NetworkDiagnosticsTests\|CodeLineBudgetTests\|ValidateAssertionContractTests'` | PASS: 6 selected network diagnostics, line-budget, and assertion-contract tests passed after grouping parser, report-policy, and process-runner scenarios. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --filter 'UdpPcmV2PacketTests\|CodeLineBudgetTests\|ValidateAssertionContractTests'` | FAIL then PASS: first reassembler/packetizer merge reused a local `mode` name; after renaming the invalid-copy mode, 5 selected UDP PCM v2 packet, line-budget, and assertion-contract tests passed. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --filter 'LightingFixtureGateTests\|CodeLineBudgetTests\|ValidateAssertionContractTests'` | PASS: 7 selected lighting fixture gate, line-budget, and assertion-contract tests passed after grouping policy, parser, runner, and capture-truthfulness scenarios. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --filter 'E2EBenchmarkReportTests\|CodeLineBudgetTests\|ValidateAssertionContractTests'` | PASS: 7 selected E2E benchmark, line-budget, and assertion-contract tests passed after grouping smoke/runner, parser, pass-policy, and tolerance scenarios. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --filter 'ReleaseArtifactHygieneContractTests\|CodeLineBudgetTests\|ValidateAssertionContractTests'` | FAIL then PASS: first hygiene-scan merge reused live-scan result names for candidate scans; after renaming candidate result locals, 7 selected release-hygiene, line-budget, and assertion-contract tests passed. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --filter 'AudioLoopbackRunTests\|CodeLineBudgetTests\|ValidateAssertionContractTests'` | PASS: 6 selected audio-loopback, line-budget, and assertion-contract tests passed after grouping parser, runtime metric/source-safety, preflight, and report validation scenarios. |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-test-audit-build --no-parallel --filter 'SwiftTestingDiscoveryTests\|ReleaseHardeningTests\|DirectPeerTwoPeerRunPlanTests\|CodeLineBudgetTests\|ValidateAssertionContractTests'` | PASS: 18 selected discovery, release-hardening, DirectPeer two-peer, line-budget, and assertion-contract tests passed after folding two unannotated top-level functions into adjacent tests without increasing the raw declaration count. |
| `python -m pytest -p no:cacheprovider linux_connector` | PASS: 85 passed, 2 skipped. |
| `ruff check linux_connector scripts/verify_docs scripts/lib/extract-preflight-executable.py` | PASS: all checks passed. |
| `python -m mypy --strict linux_connector/lola_connector scripts/verify_docs scripts/lib/extract-preflight-executable.py` | PASS: no issues in 20 source files. |
| `bash scripts/verify-docs.sh` | PASS: documentation verification passed. |
| `python3 -m scripts.verify_docs` | PASS: documentation verification passed. |
| `git diff --check` | PASS: no whitespace errors. |
| `swift test --build-path /private/tmp/open-lola2-semantic-prune-build --no-parallel` | PASS: 468 Swift Testing tests passed after the semantic-prune pass. Raw Swift declaration inventory is 470 `@Test`, below the 500-test target. |
| `PYTHONDONTWRITEBYTECODE=1 python -m pytest -p no:cacheprovider linux_connector` | PASS: 85 passed, 2 skipped after the semantic-prune audit refresh. |
| `bash scripts/verify-docs.sh` | PASS: documentation verification passed after the semantic-prune audit refresh. |
| `git diff --check` | PASS: no whitespace errors after removing a trailing blank line left by the semantic-prune rewrite. |

VERDICT: PASS
