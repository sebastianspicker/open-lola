# Code Improvement Milestones

Date: 2026-05-04  
Status: code-aware improvement milestone index  
Scope: code-aware improvement milestone index  
Verdict: PARTIAL

This index corrects the review handoff: the code was inspected, so the next
milestones are concrete code improvement milestones tied to actual Swift source,
tests, fixtures, and CLI surfaces. The earlier `Nxx` companions remain useful
as boundary and release-policy prerequisites, but they are not a substitute for
code improvement planning.

## Code Milestone Order

| Milestone | Companion | Primary code surface | Priority |
|---|---|---|---|
| C01 | [C01_CLI_COMMAND_ROUTER_AND_ARGUMENT_PARSING.md](C01_CLI_COMMAND_ROUTER_AND_ARGUMENT_PARSING.md) | `Sources/open-lola/main.swift`, command files | P1 completed |
| C02 | [C02_CORE_SOURCE_OWNERSHIP_SPLIT.md](C02_CORE_SOURCE_OWNERSHIP_SPLIT.md) | `Sources/OpenLolaCore/*.swift`, `Sources/OpenLolaCore/Core/*.swift` | P1 completed first batch |
| C03 | [C03_REPORT_VALIDATOR_DEDUP_AND_EVIDENCE_SCHEMA.md](C03_REPORT_VALIDATOR_DEDUP_AND_EVIDENCE_SCHEMA.md) | report/validation files and validator CLI cases | P1 completed |
| C04 | [C04_RUNTIME_CLAIM_GATES_SYNTHETIC_VS_MEASURED.md](C04_RUNTIME_CLAIM_GATES_SYNTHETIC_VS_MEASURED.md) | release, field proof, packaging, integrated proof code | P0 completed |
| C05 | [C05_NETWORK_TRANSPORT_ROUTE_AND_ARGUMENTS.md](C05_NETWORK_TRANSPORT_ROUTE_AND_ARGUMENTS.md) | UDP PCM, NAT, diagnostics, route config code | P1 completed |
| C06 | [C06_REALTIME_AUDIO_BUFFERING_AND_LATENCY.md](C06_REALTIME_AUDIO_BUFFERING_AND_LATENCY.md) | realtime audio, RX buffering, latency, MADI/RME code | P1 completed |
| C07 | [C07_VIDEO_CONTROL_DEGRADE_FIRST_PATH.md](C07_VIDEO_CONTROL_DEGRADE_FIRST_PATH.md) | video, ATEM, OSC, lighting, integrated AV code | P1 completed |
| C08 | [C08_TEST_FIXTURE_AND_CLI_SMOKE_MATRIX.md](C08_TEST_FIXTURE_AND_CLI_SMOKE_MATRIX.md) | tests, fixtures, CLI smoke matrix | P1 completed |
| C09 | [C09_PACKAGING_SIGNING_CLEAN_MAC_RELEASE_GATE.md](C09_PACKAGING_SIGNING_CLEAN_MAC_RELEASE_GATE.md) | packaging, release, field readiness code | P0 completed |
| C10 | [C10_VERIFICATION_TOOLING_AND_CI_PARITY.md](C10_VERIFICATION_TOOLING_AND_CI_PARITY.md) | scripts, docs verifier, CI workflow | P1 completed |
| C11 | [C11_MACOS_APP_SHELL_RUNTIME_READINESS.md](C11_MACOS_APP_SHELL_RUNTIME_READINESS.md) | SwiftUI app shell, native shell report, app-shell surface probe | P2 completed source-level |
| C12 | [C12_ARTIFACT_DEPENDENCY_GENERATED_OUTPUT_HYGIENE.md](C12_ARTIFACT_DEPENDENCY_GENERATED_OUTPUT_HYGIENE.md) | generated-output, dependency, and release artifact surfaces | P0 completed |

## Dependency Order

1. C04 source guards are implemented; do not claim real release PASS without
   measured evidence.
2. C09 packaging/signing/clean-Mac source gates are implemented; do not claim
   real release PASS without real Developer ID, notarization, Gatekeeper,
   clean-Mac install, and hash evidence.
3. C08 fixture and CLI smoke matrix is implemented.
4. C01 before CLI feature additions. Implemented as executable command
   inventory and validator routing cleanup.
5. C03 report validator surface and schema/evidence inventory are implemented;
   keep updating the inventory when adding validators or report schemas.
6. C02 first ownership batch is implemented; high-risk runtime moves remain
   deferred to later incremental batches.
7. C06 realtime path inventory and RX PASS guards are implemented; keep C06 as
   the audio-risk baseline for C07 and later source moves.
8. C05 route matrix and NAT PASS guards are implemented; keep C05 as the
   route-risk baseline for C07 and integrated AV route claims.
9. C07 video/control degrade matrix and integrated guard tests are implemented;
   keep C07 as the AV/control baseline for C02, C10, C11, and C12.
10. C10 local/CI parity tooling is implemented; live CI read-back remains
    blocked until this filesystem is attached to a Git worktree.
11. C11 app-shell surface contract and CLI probe are implemented; real launched
    window evidence remains a product-release gate.
12. C12 artifact/dependency/generated-output hygiene is implemented; any future
    release candidate export must run the C12 candidate scan before
    publication.
13. `scripts/export-release-candidate.sh` implements the source candidate
    staging path and runs the C12 scan before inspection.

## Resume Here

Resume with real launched app evidence, staged candidate inspection, license
and notices closure, or reviewer signoff. C01, C02 first batch, C03, C04, C05,
C06, C07, C08, C09, C10, C11, C12, and source candidate staging are implemented
at source/tooling level.

VERDICT: PARTIAL
