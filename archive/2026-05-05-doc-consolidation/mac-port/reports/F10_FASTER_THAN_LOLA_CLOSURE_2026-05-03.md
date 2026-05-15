# F10 Faster Than LoLa Closure Validation Report

Date: 2026-05-03  
Companion: [F10 Faster Than LoLa Closure](../implementation-companions/F10_FASTER_THAN_LOLA_CLOSURE.md)  
Status: PARTIAL

## Scope

This report validates the source-level F10 closure ledger for any future
"faster than LoLa" claim. It implements the report contract, PASS guards,
synthetic smoke, bounded handoff writer, CLI validator, and tests. It does not
claim that Open LoLa is faster than LoLa, because the required physical F01-F04
audio evidence and same-hardware LoLa baseline do not exist yet.

## Ledger Contract

`FasterThanLoLaClosureReport` records:

- exact claim scope: audio-only, audio+video, audio+video+lighting, or
  field-ready;
- F01-F09 evidence references required by that scope;
- per-lane verdict, measured state, physical or clean-Mac proof state,
  packet-capture or artifact proof state, and notes;
- same-hardware Open LoLa versus LoLa baseline comparison;
- packet mode, fixed playout target, duration, latency percentiles, loss, late
  packets, underruns, drift, artifacts, and comparison result;
- G16 parity ledger identity and deferral flags.

PASS reports require a measured run, every required lane at PASS, physical or
clean-Mac evidence, packet-capture or artifact evidence, a measured LoLa
baseline on the same hardware and route, Open LoLa faster on every latency
metric, at least a 60-minute fixed-target run, no loss, no late packets, no
underruns, no artifacts, and no parity feature blocking the fastest path.

## Commands

```bash
swift test --filter FasterThanLoLa
swift test --filter LoLaParity
swift test
swift build
bash scripts/verify-docs.sh
shellcheck scripts/*.sh
.build/debug/open-lola faster-than-lola-closure-run --claim-scope audioOnly --f01-report m01-rme-hardware-required --f02-report m02-realtime-engine-required --f03-report m05-direct-route-required --f04-report m06-drift-lola-baseline-required --output /private/tmp/open-lola-f10-faster-than-lola-closure.json
.build/debug/open-lola validate-faster-than-lola-closure /private/tmp/open-lola-f10-faster-than-lola-closure.json
.build/debug/open-lola faster-than-lola-closure-synthetic-smoke
```

## Results

- Red test run before implementation failed because the F10 closure report,
  validation errors, synthetic smoke, run configuration, and runner did not
  exist.
- `swift test --filter FasterThanLoLa` passed with 12 tests.
- `swift test --filter LoLaParity` passed with 8 tests.
- `swift test` passed with 354 tests.
- `bash scripts/verify-docs.sh` passed.
- `shellcheck scripts/*.sh` passed.
- `swift build` failed inside the sandbox with SwiftPM manifest
  `sandbox-exec: sandbox_apply: Operation not permitted`, then passed outside
  the sandbox.
- The bounded audio-only closure writer generated a valid PARTIAL F10 report.
- The generated F10 report validator passed with `VERDICT: PARTIAL`.
- The F10 synthetic smoke command passed with `VERDICT: PARTIAL`.
- PASS guards reject synthetic PASS claims, missing required evidence, partial
  evidence, missing measured LoLa baseline, non-faster Open LoLa comparison,
  missing percentile wins, short runs, packet loss, late packets, underruns,
  artifacts, and parity blocks on the fastest path.

## Deferred Runtime Evidence

F10 cannot be marked PASS until real reports exist for:

- F01 RME MADI hardware baseline;
- F02 realtime duplex audio engine;
- F03 direct peer-to-peer UDP PCM route;
- F04 60-minute drift/PLC run and same-hardware measured LoLa baseline;
- F05-F09 if the claim includes video, lighting, recording, app runtime,
  packaging, or field readiness.

## Verdict

F10 source validation is complete, but the measured benchmark evidence remains
open.

VERDICT: PARTIAL

## Resume here

Use `open-lola faster-than-lola-closure-run` for bounded PARTIAL handoffs while
evidence is incomplete. Use `open-lola validate-faster-than-lola-closure <path>`
for the first measured benchmark ledger after F01-F04 PASS. Keep G16 parity
deferred until the fastest Mac-native proof is already measured.
