# App Release And Field Companion

Date: 2026-05-05
Status: active domain companion for app, recording, packaging, field, and closure work
Verdict: PARTIAL

Canonical status lives in
[../IMPLEMENTATION_COMPANION.md](../IMPLEMENTATION_COMPANION.md). This file
collects M13-M15, F09-F10, G16, runtime closure, release-hardening, and field
readiness details.

## Scope

Covered lanes:

- M13 native SwiftUI app shell and hardware-validation aggregate.
- M14 recording/session artifacts.
- M15 packaging, signing, notarization, Gatekeeper, clean-Mac field test, and
  Q010.
- F09 field-readiness chain.
- F10 faster-than-LoLa closure ledger.
- G16 deferred LoLa parity ledger.
- Codewise and runtime completion surfaces.

## Current Source Surfaces

| Area | Source-level state | PASS blocker |
|---|---|---|
| App shell | SwiftUI target, immutable config boundary, read-only metrics observer, runtime smoke, app-shell surface probe, full operator console sections, persistent operator defaults for every direct-peer command field, audio/video preview controls, dedicated receiver window, execution arming, supervised CLI dry-run/start/stop, validator command handoff, report paths, and log paths exist. SwiftUI launches existing CLI supervisor commands but still does not own realtime media paths. | Launched app bundle, permission prompts, app-vs-CLI metrics comparison, and physical two-Mac evidence. |
| Hardware validation | Aggregate validator and PASS guards exist. | Physical RME, route, Blackmagic/ATEM, lighting, packet-capture, and field evidence. |
| Recording | Recording/session schema, side-lane policy, simulated slow-writer drop/gap counters, bounded writer, opt-in raw audio input, and opt-in AVFoundation raw video frame artifacts exist. Default runs no longer emit fake media artifacts. | Physical recording-off/on comparison, long-run disk-pressure stress, and accepted hardware evidence. |
| Packaging | Ad-hoc packaging handoff, packaged permission/entitlement surface, field-runtime proof, composite field-readiness run, signing/notarization fields, and Gatekeeper fields exist. | Developer ID identity, notarization, hardened runtime, reviewed entitlements, Gatekeeper acceptance, and clean-Mac run. |
| Faster-than-LoLa | Closure validator, ledger, synthetic smoke, and bounded handoff exist. | Measured F01-F04 PASS evidence and same-hardware LoLa baseline. |
| Parity deferral | G16 ledger prevents compatibility creep into fastest mode. | Explicit promotion of one feature at a time with measured evidence. |
| Runtime closure | Codewise closure is PASS; runtime blockers are documented. | Real-world product completion evidence. |

## Next Action

1. Use the app execution panel for supervised CLI dry-runs before any armed
   execution.
2. Launch the app bundle only after the headless integrated proof exists.
3. Compare app metrics with CLI metrics before calling the UI field-ready.
4. Run raw recording only as an opt-in M14 evidence pass after integrated A/V is stable.
5. Fill Q010 before any signed/notarized packaging claim.
6. Use F10 only for bounded PARTIAL handoffs until measured F01-F04 and LoLa
   baseline evidence exists.

## Archive Pointers

The old report notes and F09/F10/G16 detail are preserved under
[../../archive/2026-05-05-doc-consolidation/mac-port/](../../archive/2026-05-05-doc-consolidation/mac-port/).

## Resume here

Resume here: app, recording, packaging, clean-Mac, and faster-than-LoLa closure
remain downstream of accepted audio, route, drift, video, and integrated A/V
evidence.

VERDICT: PARTIAL
