# Simplification Audit

Date: 2026-05-16
Status: FRESH CURRENT-TREE AUDIT
Verdict: PARTIAL

This audit was created from the current live checkout, not from archived audit,
ledger, plan, or status files. It inspected the active SwiftPM package
manifest, source layout, largest Swift files, protocol inventory, current
deadline/error patterns, app design-system surface, NAT route code, app-shell
tests, line-budget tests, and active public docs that describe NAT and
mac-to-mac routing.

Success criteria for this pass:

- record confirmed simplification findings from active files only;
- separate safe cleanup from compatibility or runtime-risk investigation;
- implement one small slice without changing public behavior;
- preserve the product verdict as `PARTIAL`.

Scope covered:

- `Package.swift`
- `Sources/OpenLolaCore/`
- `Sources/open-lola/`
- `Sources/open-lola-app/`
- `Sources/open-lola-app-main/`
- `Sources/OpenLolaContracts/`
- `Tests/OpenLolaCoreTests/`
- `docs/architecture/`, `docs/mac-port/`, `docs/current-state.md`, and
  `docs/testing/README.md` where they describe affected public contracts

Scope not fully covered:

- vendored Opus and JPEG XS internals;
- every SwiftUI view branch and every CLI command branch;
- real hardware, Windows LoLa field interoperability, signing/notarization,
  clean-Mac install, and field-runtime evidence.

## Findings

### FS-001

- ID: FS-001
- Category: unnecessary abstraction
- Location: `Sources/open-lola-app/AppDesignSystem.swift`
- Evidence: current inspection before SP-001 showed a private `AppColorTheme`
  protocol with a single concrete palette implementation in the same file and
  no external conformers. After SP-001, live source contains only the concrete
  private `AppColorTheme` struct and no matching protocol declaration.
- Why it is harmful: the protocol implies a theme plug-in surface that does not
  exist, hides the concrete palette, and adds a layer to a core UI readability
  surface.
- What could break if changed: app colors, contrast constants, and SwiftUI
  compilation if the palette API changes accidentally.
- Suggested action: inline by deleting the protocol and using the concrete
  palette type directly.
- Risk level: low
- Verification needed: app support compilation and an app-shell behavior test
  that exercises the design-system contrast contract.

### FS-002

- ID: FS-002
- Category: weak error handling / unclear state
- Location:
  `Sources/OpenLolaCore/Network/NAT/NatRendezvousRelayRunners.swift` and
  `Sources/OpenLolaCore/Network/NAT/NatFriendlyRouteSmokes.swift`
- Evidence: current code still uses `Date().addingTimeInterval(...)` and
  `while Date() < deadline` in NAT rendezvous, rendezvous client, relay, and
  failed-direct smoke loops, while `MonotonicDeadline` already exists and is
  used by connector process and LoLa media/control waits.
- Why it is harmful: wall-clock changes can stretch or shorten bounded network
  waits, making NAT route probes less deterministic.
- What could break if changed: timeout duration, smoke-test timing, and
  rendezvous/relay loop exit behavior.
- Suggested action: replace these loops with `MonotonicDeadline` in a dedicated
  runtime slice.
- Risk level: medium
- Verification needed: `NatFriendlyRouteTests`, focused NAT launcher/smoke
  tests, and source search for remaining NAT wall-clock deadlines.

### FS-003

- ID: FS-003
- Category: stale compatibility
- Location:
  `Sources/open-lola/Commands/Network/DirectP2PSessionRunCommandSupport.swift`,
  `Sources/open-lola-app/AppShellStoredDefaults.swift`, and
  `Sources/OpenLolaCore/Network/P2P/DirectPeerSessionAVRuntimeReport.swift`
- Evidence: current code and tests still preserve hidden
  `--audio-compression`, stored `audioCompression`, and report
  `audioCompression` compatibility beside canonical `audioTransport`.
- Why it is harmful: old names keep parser, settings, report, and migration
  branches alive beside the current transport contract.
- What could break if changed: old CLI scripts, old user defaults, old JSON
  reports, and downstream report consumers.
- Suggested action: keep for now; require a compatibility evidence slice before
  any deletion.
- Risk level: high
- Verification needed: CLI parser tests, app stored-default migration tests,
  report decode/encode tests, fixture inventory, and docs/release notes.

### FS-004

- ID: FS-004
- Category: weak error handling
- Location: `Sources/open-lola-app/AppOperatorPlanViews.swift`
- Evidence: `try? configuration?.get()`, `try? $0.get()` for the direct-peer
  report, and `try? $0.get()` for the Windows LoLa command can collapse
  failed result state into nil in the plan view.
- Why it is harmful: operator UI can lose the reason a plan/report/command is
  unavailable, which is risky in a console that must not hide failures.
- What could break if changed: existing view rendering for absent optional data
  and preview/test fixtures that assume nil means unavailable.
- Suggested action: investigate and, if current model exposes errors, surface
  explicit error text instead of nil-only absence.
- Risk level: medium
- Verification needed: app-shell UI/model tests for missing, failed, and
  successful result states.

### FS-005

- ID: FS-005
- Category: overengineering / mixed responsibility
- Location: large active Swift files near the 720-line code budget, including
  `DirectPeerRealtimeAudioGraph.swift`, `UdpMediaTransport.swift`,
  `AppExecutionController.swift`, `VideoCaptureAVFoundation.swift`,
  `DirectPeerSessionAVSocketRunner.swift`, and
  `ExternalConnectorSession.swift`
- Evidence: current `wc -l` inventory shows these files between 685 and 713
  physical lines. `CodeLineBudgetTests` enforces a 720-line general budget.
- Why it is harmful: files near the budget are harder to review and make small
  feature work likely to trigger mechanical extraction under pressure.
- What could break if changed: high-risk audio/video/network/app state behavior
  if extraction crosses runtime boundaries.
- Suggested action: no broad rewrite; extract only when a real change naturally
  isolates a cohesive helper with behavior tests.
- Risk level: medium-high
- Verification needed: targeted tests for the affected subsystem and
  `CodeLineBudgetTests`.

### FS-006

- ID: FS-006
- Category: weak error handling
- Location:
  `Sources/OpenLolaCore/Audio/Realtime/RealtimeAudioBuffers.swift`,
  `Sources/OpenLolaCore/Audio/Realtime/DirectPeerAudioPayloadRing.swift`,
  `Sources/OpenLolaCore/Audio/MADI/MadiReceiveBuffers.swift`, and related
  realtime constructors
- Evidence: current source search shows public or shared runtime constructors
  still enforce invalid sizes with `precondition(...)`.
- Why it is harmful: a future unvalidated caller could crash rather than return
  a reportable validation error.
- What could break if changed: realtime setup contracts, hot-path assumptions,
  and tests that rely on traps for impossible internal states.
- Suggested action: investigate call chains first; convert only externally
  reachable invalid input paths to typed errors.
- Risk level: high
- Verification needed: call-chain audit, targeted invalid-configuration tests,
  realtime buffer/ring tests, and full Swift tests before claiming closure.

## Current Remediation Choice

Remediation status for this audit:

- FS-001: complete; the private single-use app color theme protocol was
  inlined.
- FS-002: complete; NAT rendezvous, client, relay, and failed-direct smoke
  loops now use `MonotonicDeadline` instead of wall-clock deadline comparisons.
- FS-003: complete as a compatibility decision; the legacy audio-compression
  name remains hidden but retained because active CLI, app migration, and
  report decode contracts still exercise it.
- FS-004: complete; app operator plan construction no longer uses `try?` to
  collapse failed result state into nil.
- FS-005: no standalone extraction performed; the line-budget finding remains
  a guardrail for future cohesive edits, and `CodeLineBudgetTests` remains the
  verifier.
- FS-006: complete for externally supplied realtime handoff and direct audio
  graph configurations; invalid user-derived buffer settings now produce typed
  validation errors before low-level realtime rings are constructed.
