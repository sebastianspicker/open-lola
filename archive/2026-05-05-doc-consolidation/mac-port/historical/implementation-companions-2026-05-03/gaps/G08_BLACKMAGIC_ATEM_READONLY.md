# G08 Blackmagic ATEM Readonly

## LoLa Comparison

LoLa 2.0 supports multicamera switching. The Mac prototype separates this into
a safe ATEM read-only lane first. Switching or SDK-backed control is not part of
the fastest path until read-only monitoring proves it does not affect audio.

## Current Repo State

- Related prototype: [../prototype/P03_BLACKMAGIC_ATEM_PATH.md](../prototype/P03_BLACKMAGIC_ATEM_PATH.md)
- Live status: [../prototype/status/P03_STATUS.md](../prototype/status/P03_STATUS.md)
- Existing source can validate ATEM read-only reports and run a bounded
  `atem-readonly-probe` reachability check with host, port, timeout, polling
  interval, network interface, same-network-as-audio flag, connection duration,
  error text, and `armedCommandsAllowed=false`.
- Missing piece: real ATEM protocol or SDK-backed read-only model, firmware,
  program/preview, tally, and audio mixer evidence from hardware.

## Implementation Plan

1. Record ATEM model, firmware, IP address, network interface, and whether the
   path is the same or isolated from audio media.
2. Keep the first probe read-only: connection status, program/preview state
   where available, polling interval, packet timing, errors, and audio impact.
3. Do not link mandatory Blackmagic SDK code into generic builds. Add optional
   adapters only behind build flags or separate modules if needed.
4. Add an explicit future arm gate before any switching command. Default reports
   must show `armedCommandsAllowed=false`.
5. Feed read-only status into the integrated A/V proof only after G07 capture
   evidence exists.

## Acceptance Tests

- `validate-atem-control-report` accepts read-only report.
- PASS rejects any armed command state.
- PASS rejects placeholder ATEM model, firmware, program/preview, tally, audio
  mixer, protocol, or network-interface evidence.
- Generic `swift build` and `swift test` pass without Blackmagic SDK installed.
- Audio metrics are unchanged while polling.

## Blockers / TODO(human)

- TODO(human): [ATEM read-only probe] -> Provide ATEM IP/model and confirm control mode should stay read-only -> [read-only only / future explicit arm after proof / defer ATEM]
- Requires ATEM network access.

## Verification Commands

```bash
swift run open-lola atem-readonly-probe --host <atem-ip> --port 9910 --timeout-milliseconds 250 --poll-interval-milliseconds 1000 --network-interface <ifname> --same-network-as-audio false --output mac-port/reports/<atem>.json
swift run open-lola validate-atem-control-report mac-port/reports/<atem>.json
swift build
swift test
```

## Resume here

Probe ATEM read-only reachability only after the capture path can report a
concrete state. Keep G08/P03 PARTIAL until real ATEM model, firmware,
program/preview, tally, audio mixer, and audio-impact evidence exist.

VERDICT: PARTIAL
