# Prototype Milestone Index

Date: 2026-05-02  
Status: prototype execution map

The canonical roadmap remains [../MILESTONE_INDEX.md](../MILESTONE_INDEX.md).
This index is the narrower hardware prototype path. Prototype work should
update the matching live companion under [status/](status/).

| ID | Objective | Depends on | Expected proof | Plan | Live status |
|---|---|---|---|---|---|
| P01 | Make the RME MADI hardware path visible, documented, and measurable. | M01, M02, M03 | RME device inventory plus at least one measured RME loopback row. | [P01_RME_MADI_HARDWARE_PATH.md](P01_RME_MADI_HARDWARE_PATH.md) | [P01_STATUS.md](status/P01_STATUS.md) |
| P02 | Implement the realtime Core Audio I/O loop and UDP PCM route. | P01, M04, M05, M06 | Source validator and synthetic smoke exist; PASS still needs RME loopback without callback violations plus measured wired two-Mac route. | [P02_REALTIME_AUDIO_ENGINE.md](P02_REALTIME_AUDIO_ENGINE.md) | [P02_STATUS.md](status/P02_STATUS.md) |
| P03 | Add Blackmagic/ATEM video and control as subordinate lanes. | M08, M10 | AVFoundation capture state plus ATEM read-only probe, both isolated from audio timing. | [P03_BLACKMAGIC_ATEM_PATH.md](P03_BLACKMAGIC_ATEM_PATH.md) | [P03_STATUS.md](status/P03_STATUS.md) |
| P04 | Prove RME audio plus capture/control load can coexist for 30 minutes. | P02, P03, M10 | Integrated report for at least 1,800 seconds with unchanged audio timing. | [P04_INTEGRATED_AV_PROOF.md](P04_INTEGRATED_AV_PROOF.md) | [P04_STATUS.md](status/P04_STATUS.md) |
| P05 | Make the prototype field-runnable without premature productization. | P04, M13, M14, M15 | CLI workflow and clean-Mac field report with machine-readable verdict. | [P05_FIELD_READY_RUNTIME.md](P05_FIELD_READY_RUNTIME.md) | [P05_STATUS.md](status/P05_STATUS.md) |

## Closure Order

P01 must close before P02 can claim PASS. P03 can proceed in parallel as long as
it remains read-only/control-safe and does not make audio or generic builds
depend on Blackmagic SDK availability. P04 cannot claim PASS until P02 and P03
have real reports. P05 cannot claim PASS until the prototype can produce a
valid field report.

## Prototype PASS Rule

Prototype PASS requires all of these:

- RME MADI device visible in `open-lola device-inventory`.
- RME loopback report with measured callback, latency, underrun, and
  hidden-conversion evidence.
- Core Audio callback path proven realtime-safe against the RME device.
- Wired UDP PCM route measured with packet-capture correlation.
- AVFoundation or explicit Blackmagic capture path measured.
- ATEM read-only control probe measured.
- 30-minute integrated A/V report with unchanged audio timing.

Resume here: work from [status/P01_STATUS.md](status/P01_STATUS.md), then
advance only when the matching prototype status file records a dated verdict.
