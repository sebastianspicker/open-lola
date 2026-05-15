# Improvement Roadmap

Date: 2026-05-04  
Status: active release-readiness roadmap  
Scope: C11 app-shell surface and C12 release hygiene implemented; broader restructure deferred  
Verdict: PARTIAL

Priority levels:

- P0: correctness/safety/blocking issue.
- P1: important for active development.
- P2: improves maintainability.
- P3: cleanup/nice-to-have.

## P0 Items

| Title | Affected files | Rationale | Risk | Expected benefit | Required validation | Recommended milestone | Safe to automate |
|---|---|---|---|---|---|---|---|
| Harden runtime claim gates | `ReleaseHardening.swift`, `PackagingFieldTest.swift`, `FieldReadyRuntimeProof.swift`, `IntegratedAvReport*.swift`, `E2EBenchmark*.swift` | Release-critical reports must not validate synthetic/source-only evidence as real PASS. | False-green release readiness. | Strict evidence semantics for release decisions. | Negative fixtures, `swift test`, relevant CLI validators. | C04 | No. |
| Harden packaging/signing/clean-Mac release gate | `PackagingFieldTest*`, `ReleaseHardening.swift`, `FieldReadyRuntimeProof*`, release fixtures | M15/package readiness is blocked on real signing, notarization, Gatekeeper, entitlements, and clean-Mac evidence. | Public release without valid package evidence. | Enforced release blocker in code and tests. | Packaging/release false-PASS fixtures, `swift test`, CLI validators. | C09 | No. |
| Prevent release artifact leakage | `.build/`, `.gitignore`, `Package.swift`, `scripts/verify-release-hygiene.sh`, release docs/scripts, `win-compiled/`, `reverse-engineering/` | C12 now enforces generated-output, dependency/notice, internal-review-doc, and vendor/internal evidence exclusions. | Future export script could bypass the gate if not wired to candidate staging. | Clean release candidate boundary. | `bash scripts/verify-release-hygiene.sh`, docs gate, build/test after cleanup if approved. | C12 completed; export script follow-up | Partially. |
| Exclude generated `.build/` from release/review artifacts | `.build/`, `.gitignore`, future release scripts | `.build/` contains 3919 generated files, debug symbols, binaries, indexes, and build DB state. | Public/export contamination, false inventory size, stale binaries. | Clean source/review surface and reproducible builds. | `find .build -type f -print | wc -l`; release manifest check; docs verifier still passes after cleanup. | Release hygiene before any public archive. | Yes, after human approval to delete generated files. |
| Resolve license and notices blockers | `LICENSE`, `THIRD_PARTY_NOTICES.md`, `docs/compliance/*` | Root license and notices are documented as pending/draft. | Invalid public release, unclear redistribution rights. | Release-ready legal boundary. | Maintainer/legal sign-off; docs compliance gate. | Compliance M05/M07/M10 closure. | No. |
| Keep Windows corpus internal-only by default | `win-compiled/`, `reverse-engineering/`, `docs/compliance/release-manifest.md` | PE binaries, DLLs, installers, SDK/vendor artifacts, and camera presets are not source and may be redistributability-sensitive. | License exposure and reverse-engineering contamination. | Clear public/internal separation. | Release manifest excludes `win-compiled/`; docs do not link public readers to raw evidence. | Compliance/release boundary. | Partially: checks can be automated; policy cannot. |
| Preserve `PARTIAL` verdict for hardware/signing claims | `README.md`, `mac-port/`, `docs/`, `Sources/OpenLolaCore/*Proof*`, `*Validation*` | Many validators prove source shape, not real RME/MADI, direct route, Blackmagic, signing, or clean-Mac evidence. | False-green reporting. | Honest readiness state. | Hardware/signing reports exist and validators accept them. | M15/P04/P05 and release hardening closure. | No. |
| Decide `docs/review/` publication boundary | `docs/review/`, `docs/compliance/release-manifest.md`, `scripts/verify_docs/constants.py` | The requested review lives under `docs/`, but it references internal artifacts and cleanup risks. | Public docs may accidentally include internal audit detail. | Clear review artifact policy. | Human decision recorded; release manifest updated if needed. | Before public archive. | No. |

## P1 Items

| Title | Affected files | Rationale | Risk | Expected benefit | Required validation | Recommended milestone | Safe to automate |
|---|---|---|---|---|---|---|---|
| Build test/fixture/CLI smoke matrix | `Tests/OpenLolaCoreTests/`, `Tests/OpenLolaCoreTests/Fixtures/`, `Sources/open-lola/*.swift` | Future refactors need explicit fixture, validator, and CLI smoke coverage. | Refactors pass unit tests but break release CLI behavior. | Concrete safety net for code changes. | `swift test`, docs gate, selected CLI smokes. | C08 | Partially. |
| Stabilize CLI router and argument parsing | `Sources/open-lola/main.swift`, `MilestoneCommands.swift`, `MilestoneValidationCommands.swift`, `NetworkCommands.swift`, command parsers | Command ownership and fixed-arity validator routing needed an executable index. | CLI regressions, inconsistent errors, hard-to-test behavior. | Testable command ownership and safer CLI growth. | `CLICommandInventoryTests`, command inventory CLI probe, representative smokes. | C01 completed | No. |
| Deduplicate report validators carefully | command validator cases, `*Report*.swift`, `*Validation*.swift`, fixtures | Shared decode-validate-print behavior and schema/evidence inventory are now centralized. Keep report-specific validation strict. | Validator drift if new schemas bypass the inventory. | Smaller, stricter validation surface. | Report validator tests, schema inventory tests, and fixtures. | C03 completed | No. |
| Harden realtime audio buffering and latency paths | `RealtimeAudio*`, `Rx*`, `Latency*`, `Madi*`, `Rme*` | Audio latency is the release-critical runtime path; C06 now provides a path inventory and runtime RX PASS guards. | Hidden latency increase or performance regression if future work bypasses the inventory. | Protected audio-first behavior. | `swift test`, latency/realtime/MADI smokes, realtime path inventory CLI probe. | C06 completed | No. |
| Harden network route and NAT boundaries | `UdpPcm*`, `Nat*`, `NetworkDiagnostics.swift`, `NetworkCommands.swift`, `NetworkRouteCommandMatrix.swift` | Direct-fastest and NAT/WAN-stable claims needed separate evidence semantics. | Misleading route claims. | Executable route matrix and NAT-friendly false-PASS guards. | `NetworkRouteCommandMatrixTests`, `NatFriendlyRouteTests`, direct/NAT localhost smokes. | C05 completed | No. |
| Harden video/control degrade-first behavior | `Video*`, `Atem*`, `Osc*`, `Lighting*`, `IntegratedAv*`, `IntegratedProfile*`, `VideoControlDegradeMatrix.swift` | Video/control must degrade before audio latency changes. | Integrated AV silently harms audio. | Executable video/control matrix plus stricter integrated-profile and integrated-AV guards. | `VideoControlDegradeMatrixTests`, integrated/profile/video/control tests and CLI validators. | C07 completed | No. |
| Create source/test/doc crosswalk | `Sources/OpenLolaCore/`, `Tests/OpenLolaCoreTests/`, `docs/architecture/`, `docs/source-contracts/` | C02 now provides an executable ownership inventory; remaining batches must keep it current. | Future edits miss tests/docs if the inventory drifts. | Faster safe development and review. | `SourceOwnershipInventoryTests`, docs gate, sample module trace verified. | C02 completed first batch. | Partially. |
| Split command ownership before CLI growth | `Sources/open-lola/main.swift`, `MilestoneCommands.swift`, command files | C01 split validator ownership and C03 stabilized report validator semantics; runtime command domains are still broad. | Buggy flags, duplicated parsing, hard-to-test CLI behavior. | More maintainable CLI surface. | Swift tests for parser behavior and key CLI smokes. | After C02 planning. | No. |
| Introduce functional source folders | `Sources/OpenLolaCore/` | C02 moved only the low-risk `Core/` support group; the rest is still mostly flat. | Refactor churn or merge conflicts if done casually. | Clear module boundaries and easier navigation. | `swift build`, `swift test`, source ownership CLI smoke, docs crosswalk. | C02 follow-up batches. | Partially: moves can be scripted after a reviewed map. |
| Add generated-output hygiene check | `scripts/verify-release-hygiene.sh`, `scripts/export-release-candidate.sh` | `.build/` exists locally despite ignore rules. | Accidental archive/public export contamination if an export bypasses C12. | Reproducible release hygiene and source candidate staging. | C12 check fails on generated/internal/vendor paths in staged candidates; export script runs that scan. | C12 and release export completed; inspection/signoff follow-up. | Yes. |
| Add fixture provenance index | `Tests/OpenLolaCoreTests/Fixtures/`, `docs/compliance/fixture-provenance.md` | Fixtures are active test inputs and may enter public review. | Unknown data provenance or contaminated examples. | Clear public-safe/internal fixture boundary. | Fixture index reviewed by compliance docs. | Compliance/test milestone. | Partially. |
| Add CI once Git context exists | `.github/workflows/release-readiness.yml`, local scripts | C10 adds a read-only workflow that runs the local release-readiness script; live CI read-back still needs Git context. | Workflow drift if future changes bypass the local script. | Repeatable checks. | `bash scripts/verify-release-readiness.sh` locally and in CI. | C10 completed; read-back after Git worktree restoration. | Yes, after policy decisions. |
| Keep app shell runtime ownership read-only | `OpenLolaApp.swift`, `NativeAppShell.swift`, `NativeAppShellSurface.swift`, `MilestoneCommands.swift`, `MilestoneValidationCommands.swift` | C11 now makes the app surface core-owned and validates that SwiftUI cannot claim realtime ownership or field-ready launch evidence. | UI code could drift into audio/video/control ownership or claim readiness without a launched-window record. | Safer native UI evolution and clearer release blocker state. | `NativeAppShellTests`, `native-app-shell-surface-probe`, release-readiness script. | C11 completed source-level; launched-app evidence follow-up. | No. |
| Add benchmark result ledger | `docs/benchmarks/`, `mac-port/reports/`, benchmark source files | Methodology and synthetic smokes exist; measured results are not centralized. | Performance claims drift or get overstated. | Clear separation of synthetic and measured evidence. | Ledger links to accepted reports and verdicts. | Benchmark/performance milestone. | Partially. |

## P2 Items

| Title | Affected files | Rationale | Risk | Expected benefit | Required validation | Recommended milestone | Safe to automate |
|---|---|---|---|---|---|---|---|
| Archive policy for deprecated/historical docs | `research/deprecated-research/`, `reverse-engineering/deprecated-reverse-engineering/`, `docs/historical/`, `mac-port/historical/` | Historical material is valuable but duplicates active docs. | Stale claims reused accidentally. | Clear current-vs-archive navigation. | Archive README updated; docs links pass. | Documentation hygiene. | Partially. |
| Add diagram index | `docs/architecture/`, `reverse-engineering/evidence-packages/**/diagrams.md`, `docs/review/module-responsibility-map.md` | Diagrams are scattered across public/internal/generated areas. | Readers miss the current architecture diagram. | Easier onboarding. | Link check and audience classification. | Documentation restructure. | No. |
| Normalize report lane naming | `mac-port/reports/`, `docs/compliance/`, `mac-port/implementation-companions/` | M/F/G/MXX report lanes are powerful but dense. | New contributors confuse active, historical, gap, and feature lanes. | Better navigation and lower onboarding cost. | Report index updated; no links broken. | Mac-port docs cleanup. | Partially. |
| Add module owner labels | Source/test/doc crosswalk | Ownership is inferable but not recorded. | Ambiguous responsibility. | Cleaner review routing. | Human-approved labels. | After source crosswalk. | No. |
| Consider typed CLI parser extraction | `Sources/open-lola/*Commands.swift` | Manual parsing appears repeated. | Over-abstraction if done too early. | Less duplication and better validation if duplication is confirmed. | Parser tests and CLI smoke. | After command audit. | No. |

## P3 Items

| Title | Affected files | Rationale | Risk | Expected benefit | Required validation | Recommended milestone | Safe to automate |
|---|---|---|---|---|---|---|---|
| File size dashboard | Source and tests | Large files are known from `wc -l`; trend tracking would help. | Low. | Better refactor targeting. | Regenerate dashboard after source moves. | Maintenance. | Yes. |
| Keep `.build/` size notes out of normal docs | `docs/review/` only | Generated counts are useful for audit, not daily docs. | Low. | Less noise in public docs. | None beyond docs gate. | Cleanup. | Yes. |
| Freeze deprecated docs | Deprecated/historical folders | Avoid accidental edits to superseded material. | Low. | Better traceability. | Link check. | Archive cleanup. | Partially. |

## Recommended Sequence

1. C04, C08, C09, C01, C02 first batch, C03, C05, C06, C07, C10, C11, and
   C12 source/tooling gates/matrices/inventories are implemented.
2. Inspect the staged source candidate generated by
   `scripts/export-release-candidate.sh` and record release-review decisions.
3. Continue C02 follow-up source moves only through scoped, tested batches.
4. C10 local/CI parity tooling is implemented; rerun
   `bash scripts/verify-release-readiness.sh` after each release-critical batch.
5. Keep hardware/signing/benchmark PASS claims blocked until real evidence
   exists.

VERDICT: PARTIAL
