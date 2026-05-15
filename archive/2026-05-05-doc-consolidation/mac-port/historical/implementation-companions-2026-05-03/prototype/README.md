# Prototype Hardware Path

Date: 2026-05-02  
Status: focused prototype execution layer

This directory adds a prototype-focused execution layer on top of the canonical
[M00-M15 milestone roadmap](../MILESTONE_INDEX.md). It does not replace the
canonical milestone plans, status companions, or SOTA question routing.
The cross-milestone missing-feature order is tracked in
[../gaps/README.md](../gaps/README.md).

## Purpose

The prototype path turns the broad roadmap into five hardware-facing passes:

1. Prove the RME MADI hardware path.
2. Prove the realtime Core Audio and UDP PCM engine.
3. Add Blackmagic/ATEM video and control only as subordinate lanes.
4. Run an integrated A/V proof where video/control degrade before audio timing
   changes.
5. Make the prototype field-runnable without prematurely productizing it.

## Operating Rules

- Headless CLI first; app/runtime work is downstream of measured headless
  evidence.
- RME MADI is the professional audio reference path.
- Built-in Mac audio and synthetic video are smoke fixtures only.
- Audio timing is the acceptance gate for video, control, recording, UI,
  signing, and field runtime decisions.
- ATEM and Blackmagic work must not make generic Swift builds or tests depend
  on optional vendor SDKs.
- Video/control must degrade, pause, or disable before callback timing,
  underruns, packet age, or playout targets worsen.

## Files

| File | Purpose |
|---|---|
| [P00_PROTOTYPE_INDEX.md](P00_PROTOTYPE_INDEX.md) | Prototype milestone index and execution order. |
| [P01_RME_MADI_HARDWARE_PATH.md](P01_RME_MADI_HARDWARE_PATH.md) | RME MADI visibility, driver, routing, and loopback measurement. |
| [P02_REALTIME_AUDIO_ENGINE.md](P02_REALTIME_AUDIO_ENGINE.md) | Core Audio I/O loop and UDP PCM route implementation target. |
| [P03_BLACKMAGIC_ATEM_PATH.md](P03_BLACKMAGIC_ATEM_PATH.md) | AVFoundation, optional Blackmagic, and ATEM read-only path. |
| [P04_INTEGRATED_AV_PROOF.md](P04_INTEGRATED_AV_PROOF.md) | 30-minute RME audio plus video/control coexistence proof. |
| [P05_FIELD_READY_RUNTIME.md](P05_FIELD_READY_RUNTIME.md) | CLI-first field runtime, permissions, artifacts, and clean-Mac smoke. |
| [status/](status/) | Live companions for P01-P05. |
| [../gaps/](../gaps/) | Ordered missing-feature companion plans that include prototype closures. |

## Verification

Run the general gates after documentation or source changes:

```bash
swift build
swift test
bash scripts/verify-docs.sh
shellcheck scripts/*.sh
```

Run hardware-specific gates only when the required hardware and reports exist:

```bash
swift run open-lola device-inventory
swift run open-lola validate-loopback-report <path>
swift run open-lola validate-realtime-audio-engine-report <path>
swift run open-lola realtime-audio-synthetic-smoke
swift run open-lola validate-route-report <path>
swift run open-lola validate-drift-plc-report <path>
swift run open-lola validate-video-capture-report <path>
swift run open-lola validate-integrated-av-report <path>
```

Resume here: open [P00_PROTOTYPE_INDEX.md](P00_PROTOTYPE_INDEX.md), then start
with [status/P01_STATUS.md](status/P01_STATUS.md) until an RME MADI device is
visible and at least one RME loopback row is measured.
