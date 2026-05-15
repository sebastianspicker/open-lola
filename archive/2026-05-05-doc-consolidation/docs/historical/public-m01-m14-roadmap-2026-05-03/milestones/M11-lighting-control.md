# M11 Lighting Control

Date: 2026-05-03  
Status: source-level implementation complete; live evidence still required  
Verdict: PARTIAL

## Objective

Add a secondary synchronized lighting/control channel without blocking media
critical paths.

## Scope

Cover OSC cue timing first, MIDI as optional local control, and Art-Net/sACN
only behind isolated-network and explicit-arm gates.

## Affected Files

- [../architecture/lighting-control.md](../architecture/lighting-control.md)
- `Sources/OpenLolaCore/OscCueProbe.swift`
- `Sources/OpenLolaCore/OscCueRunners.swift`
- `Sources/OpenLolaCore/LightingFixtureGate.swift`
- `Sources/OpenLolaCore/LightingFixtureGateHelpers.swift`
- `Sources/OpenLolaCore/LightingFixtureGateReport.swift`
- `Sources/OpenLolaCore/LightingFixtureGateRun.swift`
- `Tests/OpenLolaCoreTests/OscCueReportTests.swift`
- `Tests/OpenLolaCoreTests/LightingFixtureGateTests.swift`
- [../../mac-port/reports/M11_LIGHTING_CONTROL_2026-05-03.md](../../mac-port/reports/M11_LIGHTING_CONTROL_2026-05-03.md)

## Implementation Tasks

- Keep OSC as the first cue/control path.
- Timestamp cues against the audio-reference timeline where useful.
- Keep scheduling local and off the audio callback path.
- Require explicit arm, isolated network, universe, destination, and blackout
  policy for Art-Net or sACN.
- Keep MIDI as a deferred local-control option until a concrete venue/device
  target exists.

## Test Plan

- OSC encode/decode tests.
- OSC loopback timing tests.
- Lighting gate validation tests.
- Negative tests for unarmed, non-isolated, or missing blackout policy output.

## Benchmark Plan

Measure OSC local jitter, external peer jitter, cue-to-output timing, lighting
network loss, and audio callback comparison with lighting off and on.

## Acceptance Criteria

- OSC cue path is measured.
- Lighting output is isolated, armed, and nonblocking.
- Audio/video critical paths show no timing regression.

## Risks

- Fixture output can create venue safety risk.
- Broadcast lighting protocols can affect shared networks.
- Cue sync can be over-tightened and accidentally block media.

## Blockers

Live PASS remains blocked on Q009 lighting safety facts, safe universe,
isolated network, and external peer or bridge availability. MIDI Show Control
is intentionally deferred until a concrete local target exists.

## Rollback Plan

Disable live lighting output and keep OSC cue reports only.

## Progress Checklist

- [x] OSC timing measured in synthetic and live UDP loopback.
- [ ] External peer selected.
- [x] Lighting safety gate filled at source level.
- [ ] Audio impact comparison recorded.
- [x] M11 report stored.

## Resume Point

Resume at M12 only after lighting/control is proven secondary and nonblocking.

VERDICT: PARTIAL
