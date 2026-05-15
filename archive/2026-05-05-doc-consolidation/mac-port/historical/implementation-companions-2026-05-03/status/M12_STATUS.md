# M12 Status

## Current status

- Status: Partial.
- Verdict: PARTIAL 2026-05-03.
- Canonical milestone: [M12 sACN Art-Net Fixture Gate](../milestones/M12_SACN_ARTNET_FIXTURE_GATE.md)
- Validation report: [M12 Lighting Fixture Gate Validation Report](../reports/M12_LIGHTING_FIXTURE_GATE_2026-05-02.md)

Canonical objective:

Gate sACN, Art-Net, and fixture work behind current standards, isolated network
tests, one-universe probes, blackout/hold/drop policy, and no audio impact.

Canonical assumptions:

- OSC from M11 remains the first show-control path.
- sACN/Art-Net direct output is disabled until the gate passes.
- Fixture metadata lookup is setup-time only, never realtime audio.

Canonical dependencies:

- M11 OSC cue probe.
- Isolated lighting network.
- OLA or QLC+ interop target.
- Current standards/spec access and licensing review.

## Completed work

- Added `LightingFixtureGateReport` with standards evidence, safety policy,
  one-universe probe request, packet-capture report, fixture metadata policy,
  audio-impact metrics, and PASS/PARTIAL verdict validation.
- Added `LightingSafetyPolicy.decision(for:)` so direct output is blocked
  unless standards are reviewed, network isolation is verified, explicit arming
  is present, the universe is allowed, and broadcast/multicast policy permits
  the requested mode.
- Added PASS guards for reviewed standards, explicit arm/isolation,
  one-universe packet capture, blackout/hold/drop/drop-on-audio-impact policy,
  setup-only fixture metadata, unchanged audio p99/max, unchanged playout
  target, zero underruns, and no hidden audio impact.
- Added a synthetic PARTIAL lighting gate fixture.
- Added CLI validation with `open-lola validate-lighting-gate-report <path>`.
- Added CLI smoke output with `open-lola lighting-gate-synthetic-smoke`.
- Added `LightingGateRunConfiguration` and `LightingGateRunner` for a bounded
  `open-lola lighting-gate-run` PARTIAL handoff report that records protocol,
  interop target, universe, network mode, explicit arming, packet-capture setup
  fields, and the required audio baseline report ID without sending packets.
- Added `audioImpact.baselineReportId` so M12 handoff reports can point back to
  the audio route baseline used for later audio-active comparison.
- Added [../reports/M12_LIGHTING_FIXTURE_GATE_2026-05-02.md](../reports/M12_LIGHTING_FIXTURE_GATE_2026-05-02.md).

## Verified work

- Red test run failed before implementation because M12 lighting gate types did
  not exist.
- `swift test --filter LightingFixtureGate` passed with 14 tests.
- `swift test` passed with 265 tests.
- `swift build` passed after rerunning outside the SwiftPM sandbox failure.
- The synthetic PARTIAL lighting gate fixture passed CLI validation.
- The synthetic smoke command emits a PARTIAL report.
- The bounded `lighting-gate-run` command writes and validates a PARTIAL
  safety handoff with `can-transmit: false` while output is not explicitly
  armed.
- Documentation verification passed.
- Shellcheck passed for the docs verifier script.

## Partially completed work

- Source validation exists for the M12 safety model, standards evidence shape,
  explicit arming gate, allowed universe policy, broadcast/multicast refusal,
  one-universe packet-capture requirement, setup-only fixture metadata, and
  audio-impact PASS guards.
- PASS-level runtime evidence is not complete because no OLA/QLC+ output, real
  packet capture, isolated lighting network, fixture target, or audio-active
  lighting run has been recorded.

## Deferred work

- Choose the Q009 isolated lighting target.
- Run one configured sACN universe against QLC+ or OLA on loopback or an
  isolated network.
- Run one configured Art-Net universe against QLC+ or OLA if Art-Net remains a
  required output.
- Capture packets at the selected capture point.
- Compare audio callback p99/max and playout target with lighting off/on.
- Verify Art-Net credit/OEM-code requirements before any product release.
- Validate actual fixture metadata only as setup-time tooling.

## Open tasks

Canonical progress checklist:

- [x] Record standards/spec notes.
- [x] Define allowed universe and network policy.
- [x] Add safety state tests.
- [x] Add bounded lighting-gate-run safety handoff.
- [ ] Run one-universe OLA or QLC+ probe.
- [ ] Capture packets.
- [ ] Compare audio metrics.
- [x] Update [../PROGRESS.md](../PROGRESS.md).

SOTA 2026 routing:

- Rows: Q009, SOTA049, SOTA050, SOTA051, SOTA052, SOTA053, SOTA054, SOTA055, SOTA056, SOTA057, SOTA060, SOTA061, SOTA062, SOTA063, SOTA064, SOTA065, SOTA066, SOTA067, SOTA068, SOTA071, SOTA072, SOTA085 in [../SOTA_2026_OPEN_QUESTION_MATRIX.md](../SOTA_2026_OPEN_QUESTION_MATRIX.md).
- Closure rule: direct sACN or Art-Net output remains blocked until Q009 names
  the isolated target and a measured report proves one configured universe,
  packet capture, blackout/hold/drop behavior, and unchanged audio timing.

## Known blockers

- Safe universe and fixture target require user or venue coordination.
- Standards-controlled protocols may require full document access beyond public
  metadata before product claims.
- Art-Net product release requires credit/OEM-code disposition.
- Physical or virtual lighting probes need QLC+, OLA, or a safe fixture target.

TODO(human): [M12 lighting safety] -> Choose safe isolated universe, network, fixture target, and blackout behavior for Q009 -> [OLA/QLC+ virtual output / isolated physical fixture / defer live fixture output]

## Test coverage status

Canonical test plan:

Before: no universe safety model exists.

After:

- standards/spec notes exist for implemented protocol;
- one-universe isolated output probe report validates;
- blackout/hold/drop policy tests pass;
- audio metrics remain unchanged.

Coverage state: source-level M12 coverage exists for fixture decoding,
policy decisions, explicit arming, allowed universe matching, standards PASS
gates, packet-capture PASS gates, broadcast refusal, setup-only fixture
metadata, audio p99 gate, playout-target gate, synthetic smoke output, run
configuration parsing, invalid interop-target rejection, audio baseline ID
recording, bounded PARTIAL handoff generation, and JSON round trip. Live
OLA/QLC+, packet capture, fixture, and audio-active coverage are still missing.

## Relevant files touched

- [../../Sources/OpenLolaCore/LightingFixtureGate.swift](../../Sources/OpenLolaCore/LightingFixtureGate.swift)
- [../../Sources/open-lola/main.swift](../../Sources/open-lola/main.swift)
- [../../Tests/OpenLolaCoreTests/LightingFixtureGateTests.swift](../../Tests/OpenLolaCoreTests/LightingFixtureGateTests.swift)
- [../../Tests/OpenLolaCoreTests/Fixtures/LightingFixtureGateReports/valid/lighting-gate-partial.json](../../Tests/OpenLolaCoreTests/Fixtures/LightingFixtureGateReports/valid/lighting-gate-partial.json)
- [../reports/M12_LIGHTING_FIXTURE_GATE_2026-05-02.md](../reports/M12_LIGHTING_FIXTURE_GATE_2026-05-02.md)
- [../milestones/M12_SACN_ARTNET_FIXTURE_GATE.md](../milestones/M12_SACN_ARTNET_FIXTURE_GATE.md)
- [../PROGRESS.md](../PROGRESS.md)
- [../STATUS_INDEX.md](../STATUS_INDEX.md)
- [../VALIDATION_CHECKLIST.md](../VALIDATION_CHECKLIST.md)
- [../MILESTONE_INDEX.md](../MILESTONE_INDEX.md)
- [../OPEN_QUESTIONS.md](../OPEN_QUESTIONS.md)
- [../SOTA_2026_OPEN_QUESTION_MATRIX.md](../SOTA_2026_OPEN_QUESTION_MATRIX.md)
- [../RISK_REGISTER.md](../RISK_REGISTER.md)
- [../../MAC_PORT_PLAN.md](../../MAC_PORT_PLAN.md)

## Latest verification

Commands:

```bash
swift test --filter LightingFixtureGate
swift test
swift build
.build/debug/open-lola lighting-gate-run --audio-baseline m05-route-baseline-required --protocol sacn --interop-target qlcPlus --universe 1 --network-mode loopbackUnicast --destination 127.0.0.1 --port 5568 --isolated-network true --explicitly-armed false --capture-tool not-run --capture-point not-run --duration-seconds 0 --output /private/tmp/open-lola-m12-lighting-gate-run.json
.build/debug/open-lola validate-lighting-gate-report /private/tmp/open-lola-m12-lighting-gate-run.json
.build/debug/open-lola validate-lighting-gate-report Tests/OpenLolaCoreTests/Fixtures/LightingFixtureGateReports/valid/lighting-gate-partial.json
.build/debug/open-lola lighting-gate-synthetic-smoke
bash scripts/verify-docs.sh
shellcheck scripts/*.sh
```

Result:

- Focused M12 tests pass with 14 tests.
- Full Swift tests pass with 265 tests.
- Swift build passes after rerunning outside the sandbox.
- CLI bounded run, generated report validation, fixture validation, and
  synthetic smoke pass.
- Documentation verification and shellcheck pass.
- VERDICT: PARTIAL

## Next recommended steps

Answer Q009, then run QLC+ or OLA on loopback or an isolated lighting network
with exactly one configured universe and packet capture enabled.

## Resume here

Start from `LightingFixtureGate.swift` and `lighting-gate-run`. Keep direct
output blocked by default, record the Q009 handoff choices, then add the first
measured QLC+/OLA one-universe report and validate it with
`open-lola validate-lighting-gate-report <path>`. Keep M12 PARTIAL until the
report proves unchanged audio timing.
