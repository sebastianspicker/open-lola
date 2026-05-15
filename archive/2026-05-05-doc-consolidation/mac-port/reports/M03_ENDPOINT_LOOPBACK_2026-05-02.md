# M03 Endpoint Loopback Validation Report

Date: 2026-05-02  
Milestone: [M03 Endpoint Loopback Fastest Mode](../milestones/M03_ENDPOINT_LOOPBACK_FASTEST_MODE.md)  
Status: PARTIAL

## Scope

This report validates the M03 software evidence contract. It does not claim a
real fastest endpoint mode because no physical analog loopback matrix or
30-minute stability run was executed in this session.

## Implemented Gate

The M03 report contract now requires:

- explicit 48 kHz, 96 kHz, and 192 kHz sample-rate disposition;
- 16/32/64/128 frame rows for every supported sample rate;
- accepted/rejected mode state with rejection reasons;
- callback p50/p95/p99/max, missed deadline, underrun, and overrun metrics for
  accepted modes;
- reported device latency, safety offset, measured analog round trip, corrected
  one-way latency, and hidden-buffer-growth state for accepted modes;
- selected mode to be accepted and stable;
- selected mode to have a 30-minute stability run;
- no hidden buffer growth and no dropout events for closure.

## Commands

```bash
swift test
swift build
swift run open-lola
swift run open-lola device-inventory
swift run open-lola validate-loopback-report Tests/OpenLolaCoreTests/Fixtures/EndpointLoopback/valid/endpoint-loopback-valid.json
swift run open-lola validate-loopback-report Tests/OpenLolaCoreTests/Fixtures/EndpointLoopback/invalid/missing-32-frame.json
bash scripts/verify-docs.sh
shellcheck scripts/*.sh
```

The valid fixture passed. The invalid fixture failed with the expected missing
32-frame row validation error. The local device inventory probe still captured
3 Core Audio devices.

## Blocker

M03 still requires a physical analog loopback path and target input/output
device selection before it can select a fastest stable mode.

TODO(human): [M03 analog loopback setup] -> Provide the physical loopback path and target input/output device UID for Q002-Q003 -> [built-in acoustic probe only / USB or Thunderbolt interface analog loopback / defer M03 measurement]

## Verdict

M03 source validation is implemented, but measurement closure is blocked on
hardware setup and runtime capture.

VERDICT: PARTIAL

## Resume here

Run `swift run open-lola device-inventory`, pick the target input/output device,
connect the analog loopback path, then fill a real M03 report using the
validated fixture schema.
