# Review Companion Index

Date: 2026-05-04  
Status: companion index for review milestones and next actions  
Scope: code release-readiness companion layer  
Verdict: PARTIAL

This directory gives every review milestone and concrete next action its own
companion file. The primary track is now the code release-readiness milestone
track. Boundary/governance companions remain prerequisites, but the actual goal
is code quality, release readiness, and safe refactoring.

These companions are planning and handoff documents. C01, C02 first batch, C03,
C04, C05, C06, C07, C08, C09, C10, C11, and C12 now also record implemented source
guards, executable matrices, command ownership inventories, source ownership
inventories, report schema inventories, network route matrices, realtime path
inventories, video/control degrade matrices, app-shell surface probes,
verification parity tooling, and release artifact hygiene tooling. The remaining
companions do not authorize
file moves, deletion, public release, or cleanup.

## Code Release-Readiness Track

Start here:

- [CODE_RELEASE_READINESS_ROADMAP.md](CODE_RELEASE_READINESS_ROADMAP.md)
- [CODE_IMPROVEMENT_MILESTONES.md](CODE_IMPROVEMENT_MILESTONES.md)

| Milestone | Companion | Primary code surface | Priority |
|---|---|---|---|
| C01 | [C01_CLI_COMMAND_ROUTER_AND_ARGUMENT_PARSING.md](C01_CLI_COMMAND_ROUTER_AND_ARGUMENT_PARSING.md) | `Sources/open-lola/*.swift` | P1 completed |
| C02 | [C02_CORE_SOURCE_OWNERSHIP_SPLIT.md](C02_CORE_SOURCE_OWNERSHIP_SPLIT.md) | `Sources/OpenLolaCore/*.swift`, `Sources/OpenLolaCore/Core/*.swift` | P1 completed first batch |
| C03 | [C03_REPORT_VALIDATOR_DEDUP_AND_EVIDENCE_SCHEMA.md](C03_REPORT_VALIDATOR_DEDUP_AND_EVIDENCE_SCHEMA.md) | report validators and fixtures | P1 completed |
| C04 | [C04_RUNTIME_CLAIM_GATES_SYNTHETIC_VS_MEASURED.md](C04_RUNTIME_CLAIM_GATES_SYNTHETIC_VS_MEASURED.md) | release/field/integrated proof validators | P0 completed |
| C05 | [C05_NETWORK_TRANSPORT_ROUTE_AND_ARGUMENTS.md](C05_NETWORK_TRANSPORT_ROUTE_AND_ARGUMENTS.md) | UDP, NAT, diagnostics, route code | P1 completed |
| C06 | [C06_REALTIME_AUDIO_BUFFERING_AND_LATENCY.md](C06_REALTIME_AUDIO_BUFFERING_AND_LATENCY.md) | realtime audio, RX, latency, MADI/RME | P1 completed |
| C07 | [C07_VIDEO_CONTROL_DEGRADE_FIRST_PATH.md](C07_VIDEO_CONTROL_DEGRADE_FIRST_PATH.md) | video, ATEM, OSC, lighting, integrated AV | P1 completed |
| C08 | [C08_TEST_FIXTURE_AND_CLI_SMOKE_MATRIX.md](C08_TEST_FIXTURE_AND_CLI_SMOKE_MATRIX.md) | tests, fixtures, CLI smokes | P1 completed |
| C09 | [C09_PACKAGING_SIGNING_CLEAN_MAC_RELEASE_GATE.md](C09_PACKAGING_SIGNING_CLEAN_MAC_RELEASE_GATE.md) | packaging, release, field readiness | P0 completed |
| C10 | [C10_VERIFICATION_TOOLING_AND_CI_PARITY.md](C10_VERIFICATION_TOOLING_AND_CI_PARITY.md) | scripts and CI workflow | P1 completed |
| C11 | [C11_MACOS_APP_SHELL_RUNTIME_READINESS.md](C11_MACOS_APP_SHELL_RUNTIME_READINESS.md) | `open-lola-app`, `NativeAppShell`, `NativeAppShellSurface` | P2 completed source-level |
| C12 | [C12_ARTIFACT_DEPENDENCY_GENERATED_OUTPUT_HYGIENE.md](C12_ARTIFACT_DEPENDENCY_GENERATED_OUTPUT_HYGIENE.md) | generated output, release artifact surfaces | P0 completed |

## Milestone Companions

| Companion | Purpose | Status |
|---|---|---|
| [M-REVIEW-01_DOCUMENTATION_AUDIT.md](M-REVIEW-01_DOCUMENTATION_AUDIT.md) | Captures the completed systematic repository review and its evidence boundaries. | completed, documentation-only |
| [M-REVIEW-02_SOURCE_TEST_DOC_CROSSWALK_AND_BOUNDARY_CLOSURE.md](M-REVIEW-02_SOURCE_TEST_DOC_CROSSWALK_AND_BOUNDARY_CLOSURE.md) | Proposed next milestone for review boundary closure and a source/test/doc crosswalk. | proposed |

## Next Action Companions

| Companion | Purpose | Priority |
|---|---|---|
| [N01_REVIEW_BOUNDARY_DECISION.md](N01_REVIEW_BOUNDARY_DECISION.md) | Decide whether `docs/review/` is internal-only, public-safe, or release-excluded. | P1 |
| [N02_GENERATED_OUTPUT_HYGIENE.md](N02_GENERATED_OUTPUT_HYGIENE.md) | Handle `.build/` generated-output cleanup or exclusion without deleting anything in this planning pass. | P0 |
| [N03_RELEASE_MANIFEST_POLICY.md](N03_RELEASE_MANIFEST_POLICY.md) | Record review, generated-output, Windows corpus, and internal evidence policy in release docs. | P0 |
| [N04_LICENSE_NOTICES_CLOSURE.md](N04_LICENSE_NOTICES_CLOSURE.md) | Close root license and third-party notice blockers. | P0 |
| [N05_SOURCE_TEST_DOC_CROSSWALK.md](N05_SOURCE_TEST_DOC_CROSSWALK.md) | Build the crosswalk needed before any source restructure. | P1 |
| [N06_MEASURED_EVIDENCE_LEDGER.md](N06_MEASURED_EVIDENCE_LEDGER.md) | Separate synthetic smokes from real measured hardware/signing/benchmark evidence. | P1 |
| [N07_SOURCE_RESTRUCTURE_PLAN.md](N07_SOURCE_RESTRUCTURE_PLAN.md) | Turn the source restructure proposal into a reviewed batch plan. | P1 |
| [N08_INCREMENTAL_SOURCE_MOVES.md](N08_INCREMENTAL_SOURCE_MOVES.md) | Future-only companion for moving one source area at a time after approval. | P1 |
| [N09_CI_AFTER_GIT_CONTEXT.md](N09_CI_AFTER_GIT_CONTEXT.md) | Read back C10 CI after Git context and release boundaries are settled. | P1 |

## Resume Here

Start with [CODE_RELEASE_READINESS_ROADMAP.md](CODE_RELEASE_READINESS_ROADMAP.md).
Then inspect the staged source candidate generated by
`scripts/export-release-candidate.sh`, collect real launched app evidence, or
close license/notices and reviewer decisions.
C01, C02 first batch, C03, C04, C05, C06, C07, C08, C09, C10, C11, and C12 are
implemented and remain the command-inventory, source-ownership,
schema-inventory, network-route, realtime-path, video/control, false-PASS,
matrix, app-shell surface, verification, and release-hygiene references.

VERDICT: PARTIAL
