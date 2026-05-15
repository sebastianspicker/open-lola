# Code Release Readiness Roadmap

Date: 2026-05-04  
Status: code-quality release-readiness roadmap  
Scope: code release-readiness roadmap  
Verdict: PARTIAL

## Purpose

This is the actual code improvement roadmap produced from the repository audit.
It turns the indexed source, test, fixture, CLI, and tooling surfaces into
release-readiness milestones.

The generic `Nxx` companions are prerequisites and governance gates. The `Cxx`
milestones are the code-quality, refactoring, hardening, and enhancement work.

## Release Readiness Definition

Release readiness means:

- source structure is understandable and owned,
- CLI commands are testable and stable,
- validators cannot produce false PASS claims,
- synthetic evidence is separated from real measured evidence,
- realtime audio latency paths are protected,
- video/control lanes degrade before audio latency changes,
- fixtures and tests prove the release-critical contracts,
- packaging, signing, notarization, and clean-Mac gates are represented in code
  and reports,
- local verification and future CI run the same meaningful gates,
- public release artifacts exclude generated output and internal/vendor
  evidence.

## Code Milestone Phases

| Phase | Milestones | Release-readiness goal |
|---|---|---|
| Phase 1: Safety gates | C04, C09, C12 | Prevent false PASS, generated artifact leakage, and package/signing ambiguity. C04, C09, and C12 gates are implemented. |
| Phase 2: Testability | C01, C03, C08 | Make CLI, validators, fixtures, and smokes testable before refactors. C01, C03, and C08 are implemented. |
| Phase 3: Runtime-critical paths | C05, C06, C07 | Harden network, realtime audio, buffering, video, and control contracts. C05, C06, and C07 are implemented. |
| Phase 4: Structure | C02, C11 | Split ownership and app shell surfaces only after coverage is explicit. C02 first batch and C11 source-level app surface are implemented. |
| Phase 5: Automation | C10, release export | Align local tooling and future CI with release gates. C10 is implemented, and the source candidate export script now runs C12 hygiene. |

## Milestone Table

| ID | Milestone | Affected code | Release blocker addressed | Priority |
|---|---|---|---|---|
| C01 | [CLI command router and argument parsing](C01_CLI_COMMAND_ROUTER_AND_ARGUMENT_PARSING.md) | `Sources/open-lola/*.swift`, command parsers | Executable command inventory and validator routing cleanup implemented; broader runtime command splits remain later work. | P1 completed |
| C02 | [Core source ownership split](C02_CORE_SOURCE_OWNERSHIP_SPLIT.md) | `Sources/OpenLolaCore/*.swift`, `Sources/OpenLolaCore/Core/*.swift` | Executable ownership crosswalk and first low-risk Core support split implemented; high-risk runtime source moves remain later batches. | P1 completed first batch |
| C03 | [Report validator dedup and evidence schema](C03_REPORT_VALIDATOR_DEDUP_AND_EVIDENCE_SCHEMA.md) | report validators, CLI validator cases, fixtures | Shared validator surface and executable schema/evidence inventory implemented. | P1 completed |
| C04 | [Runtime claim gates](C04_RUNTIME_CLAIM_GATES_SYNTHETIC_VS_MEASURED.md) | release/field/integrated proof validators | Source guards implemented; real release evidence remains partial. | P0 completed |
| C05 | [Network transport route and arguments](C05_NETWORK_TRANSPORT_ROUTE_AND_ARGUMENTS.md) | UDP, NAT, diagnostics, route code | Executable route command matrix and NAT-friendly false-PASS guards implemented. | P1 completed |
| C06 | [Realtime audio buffering and latency](C06_REALTIME_AUDIO_BUFFERING_AND_LATENCY.md) | realtime audio, RX buffering, MADI/RME, latency code | Realtime path inventory and runtime RX PASS guards implemented; physical RME/MADI evidence remains partial. | P1 completed |
| C07 | [Video/control degrade-first path](C07_VIDEO_CONTROL_DEGRADE_FIRST_PATH.md) | video, ATEM, OSC, lighting, integrated AV | Executable degrade matrix and stricter integrated-profile/integrated-AV guards implemented. | P1 completed |
| C08 | [Test fixture and CLI smoke matrix](C08_TEST_FIXTURE_AND_CLI_SMOKE_MATRIX.md) | tests, fixtures, CLI smokes | Executable matrix implemented; future refactors now have fixture/smoke ownership coverage. | P1 completed |
| C09 | [Packaging signing clean-Mac release gate](C09_PACKAGING_SIGNING_CLEAN_MAC_RELEASE_GATE.md) | packaging, release, field readiness code | Source gate implemented; real signed/notarized/clean-Mac evidence still required for release PASS. | P0 completed |
| C10 | [Verification tooling and CI parity](C10_VERIFICATION_TOOLING_AND_CI_PARITY.md) | scripts, workflow, SwiftPM gates | Local and future CI gates share `bash scripts/verify-release-readiness.sh`; live CI read-back still needs Git context. | P1 completed |
| C11 | [macOS app shell runtime readiness](C11_MACOS_APP_SHELL_RUNTIME_READINESS.md) | `open-lola-app`, `NativeAppShell.swift`, `NativeAppShellSurface.swift` | Core-owned app surface and probe implemented; real launched app evidence remains product-release work. | P2 completed source-level |
| C12 | [Artifact dependency and generated-output release hygiene](C12_ARTIFACT_DEPENDENCY_GENERATED_OUTPUT_HYGIENE.md) | `.gitignore`, scripts, release manifest, dependency surfaces | Executable release hygiene gate implemented; candidate scans now reject `.build`, internal RE, review docs, generated outputs, and vendor binaries. | P0 completed |

## Execution Order

1. C04 source guards are implemented.
2. C09 packaging/signing/clean-Mac source gates are implemented for packaging
   field reports.
3. C08 fixture and CLI smoke matrix is implemented.
4. C01 command inventory and validator routing cleanup are implemented.
5. C03 report validator surface and schema/evidence inventory are implemented.
6. C06 realtime path inventory and runtime RX PASS guards are implemented.
7. C05 route matrix and NAT-friendly PASS guards are implemented.
8. C07 video/control degrade matrix and guard tests are implemented.
9. C02 first ownership batch is implemented after C08/C01/C03/C05/C06/C07.
10. C10 local/CI parity tooling is implemented.
11. C11 source-level app shell surface contract and probe are implemented.
12. C12 artifact/dependency/generated-output hygiene is implemented.

## Verification Baseline

Every implementation milestone must end with at least:

```bash
swift build
swift test
bash scripts/verify-docs.sh
shellcheck scripts/*.sh
```

Add milestone-specific CLI smokes listed in each companion.

## Resume Here

Resume with real launched app evidence, staged candidate inspection, license
and notices closure, or reviewer signoff. The approved source export script now
stages a candidate and runs `scripts/verify-release-hygiene.sh` against it.
C01, C02 first batch, C03, C04, C05, C06, C07, C08, C09, C10, C11, C12, and
source candidate staging are implemented and source-verified. Product release
readiness remains `PARTIAL` until real
signing, notarization, Gatekeeper, clean-Mac, hardware, and benchmark evidence
exists.

VERDICT: PARTIAL
