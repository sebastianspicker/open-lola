# G16 LoLa Parity Deferred Features Validation Report

Date: 2026-05-03  
Handoff: [Implementation Companion](../IMPLEMENTATION_COMPANION.md)  
Status: PARTIAL

## Scope

This report validates the source-level deferred parity ledger for LoLa-class
features that are useful later but not required for the first fastest Mac-native
proof. It does not promote three-host operation, multicamera switching, chat,
session tools, recording tools, monitoring, bounce-back, test signals, or
Windows LoLa wire compatibility.

## Ledger Contract

`LoLaParityDeferredLedgerReport` records:

- native packet contract identity and default-protection state;
- whether G10 PASS is required before parity promotion;
- whether parity blocks the fastest path;
- one entry per deferred parity feature;
- each feature's promotion gate, required evidence, measured-report ID,
  audio-latency preservation flag, native UDP-default-change flag, UI realtime
  ownership flag, and verdict.

PASS reports require a measured ledger, no parity block on the fastest path, a
G10 promotion gate, protected native UDP PCM defaults, one measured report per
feature, preserved default audio playout latency, no native packet default
change, and no UI realtime ownership.

## Commands

```bash
swift test --filter LoLaParity
swift test
swift build
bash scripts/verify-docs.sh
shellcheck scripts/*.sh
.build/debug/open-lola validate-lola-parity-deferred-ledger Tests/OpenLolaCoreTests/Fixtures/LoLaParityDeferredLedgers/valid/lola-parity-deferred-ledger-partial.json
.build/debug/open-lola lola-parity-deferred-synthetic-smoke
```

## Results

- Red test run before implementation failed because the G16 ledger model,
  validation errors, and synthetic smoke did not exist.
- `swift test --filter LoLaParity` passed with 8 tests.
- The fixture validator passed with `VERDICT: PARTIAL`.
- The synthetic smoke command passed with `VERDICT: PARTIAL`.
- PASS guards reject duplicate feature IDs, deferred features without measured
  reports, audio-latency risk, native packet default changes, and UI realtime
  ownership.

## Deferred Evidence

G16 remains PARTIAL until a user explicitly promotes a parity item after the
fastest Mac-native proof exists and that item has its own measured report.

VERDICT: PARTIAL

## Resume here

Keep `LoLaParityDeferredFeatures.swift` as the single parity ledger. Promote one
feature at a time only after G10 PASS and explicit user direction.
