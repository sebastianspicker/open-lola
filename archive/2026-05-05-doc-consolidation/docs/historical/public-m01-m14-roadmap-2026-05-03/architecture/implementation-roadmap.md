# Implementation Roadmap

Date: 2026-05-03  
Status: M01 roadmap summary  
Verdict: PARTIAL

## Evidence Labels

| Design choice | Label |
|---|---|
| Audio-first milestone ordering | `original open-lola design` |
| Public M01-M14 documentation surface | `original open-lola design` |
| Hardware, route, video, and lighting closure gates | `experimentally derived requirement` |
| Rollback by disabling features instead of increasing default audio latency | `original open-lola design` |

## Ordering

Implementation order follows the latency product requirement:

1. Clean-room requirements and docs harness.
2. Latency budget and benchmark harness.
3. RME/Core Audio hardware path.
4. Audio TX/RX loopback.
5. Direct P2P UDP audio.
6. Drift, fixed jitter target, and same-deadline PLC.
7. Latency tuning and comparison.
8. Blackmagic/ATEM video capture.
9. Low-latency video transport.
10. AV sync.
11. Lighting/control.
12. Integrated profile.
13. Real hardware validation.
14. Public docs and release hardening.

## Milestone Summary

| ID | Objective | Acceptance |
|---|---|---|
| [M01](../milestones/M01-clean-room-requirements.md) | Clean-room requirements and public docs harness | Public/private boundary clean; docs verifier requires the public architecture and milestone set |
| [M02](../milestones/M02-latency-budget-benchmarks.md) | Latency budget and benchmark schema | reports include latency, jitter, loss, CPU, allocation, and verdict fields |
| [M03](../milestones/M03-audio-device-abstraction.md) | Audio device abstraction | RME or compatible path measured and fastest stable mode selected |
| [M04](../milestones/M04-audio-loopback.md) | Audio TX/RX local loopback | fixed one-block target and no realtime allocation |
| [M05](../milestones/M05-p2p-audio-transport.md) | Direct P2P audio transport | two-Mac direct UDP route PASS |
| [M06](../milestones/M06-jitter-clock-drift.md) | Jitter and drift handling | no hidden buffer growth over long run |
| [M07](../milestones/M07-latency-tuning.md) | Latency tuning | selected fastest measured profile |
| [M08](../milestones/M08-video-capture.md) | Blackmagic/ATEM capture | production capture measured without audio impact |
| [M09](../milestones/M09-video-transport.md) | Video transport | physical route and video degradation policy proven |
| [M10](../milestones/M10-av-sync.md) | AV sync | audio remains master in integrated run |
| [M11](../milestones/M11-lighting-control.md) | Lighting/control | OSC timing and isolated lighting gate proven |
| [M12](../milestones/M12-integrated-profile.md) | Integrated profile | fastest-audio default, optional profile cost, subordinate verdict aggregation, and full matrix measured together |
| [M13](../milestones/M13-hardware-validation.md) | Hardware validation | physical rig evidence recorded |
| [M14](../milestones/M14-release-hardening.md) | Public docs/release hardening | release ledger validates and PASS stays blocked until verification is green |

## Rollback Rule

Rollback is feature disablement to the previous PASS profile. Do not preserve a
feature by increasing default audio latency.

## Resume here

M01 resumes in [../milestones/M01-clean-room-requirements.md](../milestones/M01-clean-room-requirements.md).
After it passes, start [M02](../milestones/M02-latency-budget-benchmarks.md)
and avoid source changes that are not required by the benchmark schema.

VERDICT: PARTIAL
