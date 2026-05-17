# Simplification Plan

Date: 2026-05-16
Status: ACTIVE CURRENT-TREE PLAN
Verdict: PARTIAL
Source audit: `docs/simplification-audit.md`

This plan is derived from the current live audit in
`docs/simplification-audit.md`. It does not treat archived audit, ledger, plan,
or status files as implementation authority.

## Slices

### SP-001: Remove single-use app color theme protocol

- Status: COMPLETE
- Findings addressed: FS-001
- Files affected:
  `Sources/open-lola-app/AppDesignSystem.swift`,
  `Tests/OpenLolaCoreTests/AppShellBehaviorTests.swift`
- Exact intended simplification: delete the private `AppColorTheme` protocol,
  use the concrete private palette type directly, and add a behavior-facing
  contrast check so the palette contract remains visible.
- Behavior affected: no intended behavior change.
- Public contracts affected: none; all affected types are app-support internals
  or private implementation details.
- Tests to add/update: app-shell behavior test for the design-system contrast
  contract.
- Verification commands:
  `swift test --build-path /private/tmp/open-lola2-current-simplification --no-parallel --filter AppShellBehaviorTests`
- Rollback strategy: restore the protocol/type annotation and remove the test
  assertion.
- Risk level: low
- Definition of Done: no `AppColorTheme` protocol remains, app-shell behavior
  tests pass, and app support still compiles.

### SP-002: Replace NAT wall-clock deadlines

- Status: COMPLETE
- Findings addressed: FS-002
- Files affected:
  `Sources/OpenLolaCore/Network/NAT/NatRendezvousRelayRunners.swift`,
  `Sources/OpenLolaCore/Network/NAT/NatFriendlyRouteSmokes.swift`,
  `Tests/OpenLolaCoreTests/NatFriendlyRouteTests.swift`
- Exact intended simplification: use `MonotonicDeadline` for NAT rendezvous,
  rendezvous-client, relay, and failed-direct smoke loops instead of wall-clock
  `Date()` comparisons.
- Behavior affected: timeout accounting becomes monotonic; no report schema
  change intended.
- Public contracts affected: NAT route timing behavior only.
- Tests to add/update: focused NAT route tests where timing can be observed
  deterministically; otherwise preserve existing smoke coverage and add source
  search evidence.
- Verification commands:
  `swift test --build-path /private/tmp/open-lola2-nat-deadlines --no-parallel --filter NatFriendlyRouteTests`
- Rollback strategy: restore previous wall-clock deadline loops.
- Risk level: medium
- Definition of Done: NAT loops no longer compare `Date()` to a deadline and
  focused NAT tests pass.

### SP-003: Decide legacy audio transport names

- Status: COMPLETE: retained with evidence
- Findings addressed: FS-003
- Files affected: CLI parser, app stored defaults, AV runtime report, fixtures,
  docs
- Exact intended simplification: do not delete yet; inventory real consumers of
  `--audio-compression` and `audioCompression` and either document retention or
  remove in a compatibility-breaking slice.
- Behavior affected: potential CLI, storage, and report compatibility.
- Public contracts affected: yes.
- Tests to add/update: CLI migration tests, stored-default migration tests,
  decode/encode fixture tests.
- Verification commands: targeted CLI/app/report tests plus full Swift tests.
- Rollback strategy: keep current compatibility paths.
- Risk level: high
- Definition of Done: deletion is either rejected with evidence or implemented
  with migration/release notes and passing compatibility tests.
- Decision: deletion rejected for this pass. The legacy name is hidden from
  help, but active CLI migration tests, app stored-default migration tests, and
  report decode compatibility still exercise it. Removing it would be a
  compatibility-breaking change, not a safe simplification slice.

### SP-004: Surface app plan result errors explicitly

- Status: COMPLETE
- Findings addressed: FS-004
- Files affected: `Sources/open-lola-app/AppOperatorPlanViews.swift` and app
  shell tests
- Exact intended simplification: replace nil-only `try?` result reads with a
  model that distinguishes missing data from failed data when the current
  surface can carry that error.
- Behavior affected: app operator plan error display.
- Public contracts affected: UI surface only.
- Tests to add/update: failed direct-peer report, failed Windows command, and
  successful result states.
- Verification commands: focused app-shell behavior/view-model tests.
- Rollback strategy: restore optional-only rendering.
- Risk level: medium
- Definition of Done: the plan view no longer hides available result errors.

### SP-005: Audit realtime constructor traps

- Status: COMPLETE for externally supplied realtime handoff and direct audio
  graph configurations
- Findings addressed: FS-006
- Files affected: realtime buffers/rings and immediate callers
- Exact intended simplification: convert only externally reachable invalid
  input paths from `precondition` traps to typed validation errors.
- Behavior affected: invalid configuration handling.
- Public contracts affected: possible runtime error contract changes.
- Tests to add/update: invalid size/capacity tests at public construction
  boundaries.
- Verification commands: targeted realtime buffer/ring tests and full Swift
  tests.
- Rollback strategy: keep existing preconditions for proven internal-only
  invariants.
- Risk level: high
- Definition of Done: no externally reachable invalid user input can crash the
  process without a reportable validation error.
- Decision: converted the externally supplied realtime packet handoff and
  direct realtime audio graph configurations to typed
  `RealtimeAudioBufferConfigurationError` validation before low-level rings are
  constructed. Low-level internal invariants that are not user-input entry
  points remain preconditions.
