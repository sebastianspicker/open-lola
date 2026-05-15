# Risk Register

Date: 2026-05-04  
Status: repository audit risk register  
Scope: current filesystem snapshot  
Verdict: PARTIAL

| Risk | Severity | Likelihood | Affected files | Mitigation | Priority |
|---|---|---:|---|---|---|
| Generated `.build/` tree is present in the checkout. | high | high | `.build/` | Exclude from exports; delete after explicit approval; C12 now fails staged candidates that include generated output. | P0 |
| Repository is not a Git worktree. | medium | high | whole directory | State filesystem-only evidence; restore/copy into Git before branch/diff/CI workflow. | P1 |
| Public/internal docs boundary is dense and easy to misread. | high | medium | `docs/`, `mac-port/`, `research/`, `reverse-engineering/`, `docs/review/` | Maintain release manifest; classify `docs/review/`; avoid public links to raw evidence. | P0 |
| `docs/review/` may be mistaken for public documentation. | medium | medium | `docs/review/` | C12 excludes `docs/review/**` by default; still decide long-term internal-only/public-safe/excluded status. | P1 |
| Root license and notices are pending/draft. | high | high | `LICENSE`, `THIRD_PARTY_NOTICES.md`, `docs/compliance/*` | Human/legal sign-off before public release. | P0 |
| Windows corpus redistribution/license uncertainty. | high | high | `win-compiled/**`, vendor DLLs/installers/camera configs | Preserve internal-only; exclude from public release unless explicitly approved. | P0 |
| Reverse-engineering contamination risk. | high | medium | `reverse-engineering/**`, `win-compiled/**`, protocol/public docs | Keep clean-room design docs separate; public claims require sanitized docs or measured reports. | P0 |
| Generated RE evidence package may be stale. | medium | medium | `reverse-engineering/evidence-packages/folder-analysis-20260503-1747/**` | Add generation manifest, tool/version notes, and retention policy. | P2 |
| Stale documentation may be reused as active plan. | medium | high | `docs/historical/**`, `mac-port/historical/**`, deprecated research/RE folders | Add archive policy and active-source-of-truth pointers. | P2 |
| Duplicated roadmap/milestone material increases confusion. | medium | high | `MAC_PORT_PLAN.md`, `docs/roadmap/`, `mac-port/`, historical snapshots | Maintain reading order and consolidate status in active companions. | P2 |
| Mostly flat `Sources/OpenLolaCore/` still hides runtime ownership. | medium | medium | `Sources/OpenLolaCore/*.swift`, `Sources/OpenLolaCore/Core/*.swift` | C02 created an executable source/test/doc crosswalk and moved only low-risk Core support; continue one reviewed batch at a time. | P1 |
| Large CLI command routers are hard to test. | medium | low | `Sources/open-lola/main.swift`, `MilestoneCommands.swift`, `MilestoneValidationCommands.swift`, `NetworkCommands.swift` | C01 added an executable command index, owner/test-path checks, and validator routing cleanup; keep updating the index with new commands. | P1 |
| Direct-route, NAT, relay, diagnostics, and localhost evidence may be conflated. | high | low | `UdpPcm*`, `Nat*`, `NetworkDiagnostics.swift`, `NetworkCommands.swift`, `NetworkRouteCommandMatrix.swift` | C05 added an executable route matrix and NAT-friendly PASS guards; keep route commands synchronized with the matrix. | P1 |
| Performance-critical audio/buffering code lacks real hardware benchmarks. | high | medium | `RealtimeAudio*`, `Rx*`, `Latency*`, `Madi*`, `Rme*`, `RealtimeAudioPathInventory.swift` | C06 labels the realtime path and blocks runtime/config RX drift for PASS; add measured benchmark ledger and hardware reports. | P1 |
| Video/control paths could hide audio latency impact. | high | medium | `Video*`, `Atem*`, `Osc*`, `Lighting*`, `IntegratedAv*` | Require integrated reports that prove audio baseline stability. | P1 |
| App shell source readiness could be mistaken for a launched app PASS. | medium | medium | `OpenLolaApp.swift`, `NativeAppShell.swift`, `NativeAppShellSurface.swift`, `native-app-shell-surface-probe` | C11 keeps the probe `PARTIAL` until real launched-window evidence is recorded; keep C09 package/signing gates separate. | P1 |
| Source-level validators may be mistaken for runtime PASS. | high | medium | `*Validation.swift`, `*SyntheticSmoke.swift`, `mac-port/reports/*`, `ReportSchemaInventory.swift`, `RealtimeAudioPathInventory.swift` | Keep `VERDICT: PARTIAL` until real hardware/signing/route evidence exists; use the C03 evidence-class inventory and C06 realtime path inventory to identify measured proof requirements. | P0 |
| CI workflow exists but has no live read-back from this filesystem snapshot. | medium | medium | `.github/workflows/release-readiness.yml`, missing Git context | C10 adds a read-only local-parity workflow; verify it in GitHub after the directory is attached to a Git worktree. | P1 |
| Fixture provenance and public-safety classification incomplete. | medium | medium | `Tests/OpenLolaCoreTests/Fixtures/**`, `docs/compliance/fixture-provenance.md` | Create fixture index with provenance and release status. | P1 |
| Dependency/license uncertainty across Apple frameworks and Windows/vendor corpus. | high | medium | `Package.swift`, `win-compiled/**`, `THIRD_PARTY_NOTICES.md` | C12 blocks SwiftPM dependency/notice drift and excludes Windows/vendor corpus; final dependency/license review still needs human signoff. | P0 |
| Release export allowlist could drift from release decisions. | high | medium | `scripts/export-release-candidate.sh`, `scripts/verify-release-hygiene.sh`, `docs/compliance/release-manifest.md` | Keep the export script allowlist synchronized with the release manifest and require C12 scanning with `OPEN_LOLA_RELEASE_CANDIDATE`. | P0 |
| Fragile local-only docs gate if review docs add broken links. | medium | low | `scripts/verify_docs/`, `docs/review/**` | Run `bash scripts/verify-docs.sh`; add policy checks if needed. | P1 |
| Missing human-confirmed module owners. | low | medium | `SourceOwnershipInventory.swift`, source/test/doc crosswalk | C02 added inferred owner labels; human-confirm before larger moves. | P2 |
| Unknown current Git publication state. | medium | high | whole directory | Do not report branch/diff/CI status from this checkout; verify in a real worktree. | P1 |

## Highest-Risk Areas

1. Release/publication boundary: license, notices, Windows corpus, reverse
   engineering, and `docs/review/` classification.
2. False-green readiness: source validators and synthetic smokes are useful but
   do not replace real hardware/signing/clean-Mac evidence.
3. Generated artifact hygiene: C12 blocks `.build/`, package artifacts,
   internal evidence, and vendor binaries from staged release candidates.
4. Source ownership: C02 reduced uncertainty by adding an executable crosswalk
   and moving the low-risk `Core/` support group. The remaining runtime-critical
   areas still need incremental move batches with test, fixture, command, and
   documentation validation.

VERDICT: PARTIAL
