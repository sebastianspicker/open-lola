# G16 LoLa Parity Deferred Features

## LoLa Comparison

LoLa includes features beyond the fastest two-host audio proof: three-host
connection, multicamera switching, local/remote rendering windows, network
monitoring, buffer tuning, connect/disconnect negotiation, bounce-back,
audio/video test signals, chat, session save/load, recording tools, and Windows
LoLa wire compatibility. These features are useful, but they are not blockers
for the Mac-native fastest path.

## Current Repo State

- Current roadmap explicitly treats Windows LoLa compatibility as evidence, not
  a default design constraint.
- Several parity-adjacent pieces already have subordinate milestones:
  recording in G14, app runtime in G13, video capture/transport in G07-G09, and
  control in G11-G12.
- Existing source has `LoLaParityDeferredLedgerReport`, a fixture-backed G16
  ledger, `validate-lola-parity-deferred-ledger`, and
  `lola-parity-deferred-synthetic-smoke`.
- The ledger prevents deferred parity features from sneaking into the fastest
  path without their own measured reports.
- Missing piece: measured parity feature reports, but those remain explicitly
  out of scope until the fastest Mac-native proof exists and the user promotes
  a parity item.

## Implementation Plan

1. Keep this companion as the single backlog for LoLa parity features that are
   not needed for the first faster Mac proof. Done with the G16 deferred ledger.
2. After G10 PASS, split each requested parity feature into its own milestone or
   explicit sub-gap only when the user asks for it.
3. For three-host support, require a new topology report and prove audio target
   does not grow with fanout.
4. For multicamera switching, require G07/G08/G09 evidence first and keep
   switching outside audio deadlines.
5. For chat, bounce-back, test signals, session save/load, and network monitor,
   use app/runtime or CLI surfaces only after G13 proves read-only observation.
6. For Windows LoLa wire compatibility, create a separate compatibility mode
   with packet captures against a live Windows peer. Do not change the
   Mac-native UDP PCM default.

## Acceptance Tests

- No deferred parity feature can mark PASS unless it has its own measured report
  and preserves default audio playout latency.
- Compatibility mode must not alter native packet contract defaults.
- UI parity features must not own realtime paths.

## Blockers / TODO(human)

- TODO(human): [Deferred LoLa parity] -> Choose whether any parity feature should be promoted after the fastest Mac proof -> [three-host / multicamera / chat-session-monitoring / Windows compatibility]
- Depends on G10 for most parity work.

## Verification Commands

```bash
swift run open-lola validate-lola-parity-deferred-ledger Tests/OpenLolaCoreTests/Fixtures/LoLaParityDeferredLedgers/valid/lola-parity-deferred-ledger-partial.json
swift run open-lola lola-parity-deferred-synthetic-smoke
swift test --filter LoLaParity
bash scripts/verify-docs.sh
swift test
```

## Resume here

Start from `LoLaParityDeferredFeatures.swift` only after the first measured
Mac-native audio and integrated A/V proof is complete and the user explicitly
promotes one parity feature.

VERDICT: PARTIAL
