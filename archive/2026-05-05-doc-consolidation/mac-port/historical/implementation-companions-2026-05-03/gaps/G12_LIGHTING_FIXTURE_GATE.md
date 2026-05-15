# G12 Lighting Fixture Gate

## LoLa Comparison

Lighting is outside classic LoLa media transport, but it belongs to the
performance use case. It must stay subordinate to audio and must be isolated,
armed, and measurable before any live output is allowed.

## Current Repo State

- Related milestone: [../milestones/M12_SACN_ARTNET_FIXTURE_GATE.md](../milestones/M12_SACN_ARTNET_FIXTURE_GATE.md)
- Live status: [../status/M12_STATUS.md](../status/M12_STATUS.md)
- Open question: Q009 in [../OPEN_QUESTIONS.md](../OPEN_QUESTIONS.md)
- Existing source validates lighting gate reports, explicit-arm/isolation
  policy, packet-capture guards, fixture validation, and synthetic smoke.
- Existing source also includes `lighting-gate-run`, a bounded PARTIAL handoff
  writer that records the selected protocol, interop target, universe, network
  mode, explicit arm state, packet-capture setup fields, and audio baseline
  report ID without sending sACN or Art-Net packets.
- Missing piece: live QLC+/OLA or physical fixture output with packet/audio
  evidence.

## Implementation Plan

1. Choose isolated universe, network interface, output target, fixture target,
   blackout/hold/drop behavior, and packet-capture point.
2. Prefer OLA or QLC+ virtual output before physical fixture output.
3. Review current sACN/Art-Net requirements before implementing direct packet
   output. Record standard/source version in the report.
4. Add explicit arming and isolated-network checks before any live packet is
   sent.
5. Run audio-active cue/output probe and record packet timing, fixture response,
   cue jitter, and audio p99/max.
6. Reject PASS if fixture lookup, OFL import, or file I/O enters realtime paths.

## Acceptance Tests

- `validate-lighting-gate-report` accepts measured report.
- PASS requires reviewed standards, explicit arm, isolated network, allowed
  universe, packet capture, setup-only fixture metadata, and unchanged audio.
- Broadcast output is rejected unless policy explicitly allows it.

## Blockers / TODO(human)

- TODO(human): [M12 lighting safety] -> Choose safe isolated universe, network, fixture target, and blackout behavior for Q009 -> [OLA/QLC+ virtual output / isolated physical fixture / defer live fixture output]
- Requires isolated lighting network or virtual output.

## Verification Commands

```bash
swift run open-lola lighting-gate-run --audio-baseline <report-id> --protocol sacn|artNet --interop-target none|ola|qlcPlus --universe <n> --network-mode loopbackUnicast|isolatedUnicast|isolatedMulticast|directedBroadcast|limitedBroadcast|campusNetwork --destination <host> --port <port> --isolated-network true|false --explicitly-armed true|false --capture-tool <tool> --capture-point <label> --duration-seconds <n> --output <lighting-report.json>
swift run open-lola validate-lighting-gate-report <lighting-report.json>
swift test --filter LightingFixtureGate
bash scripts/verify-docs.sh
```

## Resume here

Use `lighting-gate-run` to record the selected Q009 safety handoff first, then
run virtual OLA/QLC+ output unless the user explicitly supplies a safe physical
fixture target. Keep the gate PARTIAL until the report includes live
QLC+/OLA or fixture output, packet capture, and audio-active evidence.

VERDICT: PARTIAL
