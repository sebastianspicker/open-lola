# F08 Lighting P2P Workflow

Date: 2026-05-03
Status: required lighting safety and cue workflow
Verdict: PARTIAL

## Finding

Lighting should start as high-level peer-to-peer cue transport, not raw fixture
streaming across the performance link. Local fixture output stays behind an
explicit arm, one allowed universe, isolated network evidence, packet capture,
and audio-impact proof. The source gate now rejects PASS unless the lighting
report cross-references an OSC cue report, names the local fixture-output owner,
and proves direct fixture streaming is not on the performance link.

## Current Surface

- [../../Sources/OpenLolaCore/OscCueProbe.swift](../../Sources/OpenLolaCore/OscCueProbe.swift)
  validates OSC cue reports and loopback/external-peer handoffs.
- [../../Sources/OpenLolaCore/LightingFixtureGate.swift](../../Sources/OpenLolaCore/LightingFixtureGate.swift)
  validates sACN/Art-Net fixture-gate reports with explicit arm and isolation
  rules plus OSC-first cue workflow evidence.
- `open-lola osc-cue-external-run` and `open-lola lighting-gate-run` are the
  current bounded entry points.

## Workflow Rule

First path:

1. open-lola sends or receives OSC cues peer-to-peer.
2. A local venue-side tool such as QLC+ or OLA owns fixture output.
3. sACN or Art-Net output is enabled only after explicit arm.
4. The allowed universe and network are fixed for the run.
5. Lighting timing and packet capture are reported outside audio deadlines.

## Required Evidence

- live OSC peer identity and cue jitter;
- OSC cue report ID cross-referenced by the lighting gate;
- selected local output target: OLA, QLC+, or deferred physical output;
- proof that fixture output is owned locally by OLA/QLC+ instead of streamed
  directly over the performance link;
- one allowed universe;
- isolated network or documented loopback-only virtual output;
- packet capture point;
- blackout, hold, or drop behavior;
- audio metrics with lighting off and lighting on.

## PASS Criteria

- Lighting never touches audio callback deadlines.
- Fixture output cannot run without explicit arm.
- PASS cannot bypass the OSC P2P cue workflow.
- Campus or broadcast output cannot PASS without isolation and policy evidence.
- Audio timing is unchanged while cue/output traffic runs.

## Resume here

Prefer live OSC cue P2P first. Fill Q009 in
[../OPEN_QUESTIONS.md](../OPEN_QUESTIONS.md) before any real sACN or Art-Net
output.

VERDICT: PARTIAL
