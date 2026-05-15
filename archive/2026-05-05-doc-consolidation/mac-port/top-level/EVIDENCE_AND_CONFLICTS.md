# Evidence And Conflicts

Date: 2026-05-02  
Status: canonical decision ledger for the Mac port roadmap

## Evidence Labels

Use these labels in implementation notes, milestone reports, and future code
comments that cite evidence.

| Label | Meaning |
|---|---|
| Static fact | Directly visible in files, metadata, imports, strings, inventories, source docs, or checked artifacts. |
| Strong inference | Multiple static facts point to the behavior, but runtime observation is absent. |
| Medium inference | Evidence exists, but reachability or semantics remain partially uncertain. |
| Runtime gap | Requires live hardware, peer execution, packet capture, standards access, or measurement. |
| Research decision | Chosen from the canonical research set and benchmark roadmap. |
| Implementation assumption | Temporary assumption allowed only until a milestone test replaces it with measurement. |

## Architectural Decisions

| Decision | Label | Source |
|---|---|---|
| Fastest default uses Core Audio HAL/AUHAL or direct `AudioDeviceIOProc`. | Research decision | [../research/RESEARCH_AUDIO_ENGINE_2026.md](../research/RESEARCH_AUDIO_ENGINE_2026.md) |
| The audio callback must avoid allocation, locks, logging, sockets, file I/O, UI dispatch, and unbounded work. | Research decision | [../research/RESEARCH_AUDIO_ENGINE_2026.md](../research/RESEARCH_AUDIO_ENGINE_2026.md) |
| Fastest default uses one UDP PCM datagram per audio block. | Research decision | [../research/RESEARCH_AUDIO_ENGINE_2026.md](../research/RESEARCH_AUDIO_ENGINE_2026.md) |
| Default receive target is zero or one block; retransmission waits and adaptive comfort buffers are rejected. | Research decision | [../research/RESEARCH_AUDIO_ENGINE_2026.md](../research/RESEARCH_AUDIO_ENGINE_2026.md) |
| DSCP, PTP, AVB, TSN, AES67, RAVENNA, Dante, and ST 2110 require route or profile validation before acceptance. | Research decision | [../research/RESEARCH_NETWORK_TIMING_2026.md](../research/RESEARCH_NETWORK_TIMING_2026.md) |
| Blackmagic/ATEM is the first production video target after audio is stable; AVFoundation remains the generic harness and fallback when macOS exposes the capture path. | Research decision | [../research/RESEARCH_VIDEO_PIPELINE_2026.md](../research/RESEARCH_VIDEO_PIPELINE_2026.md) |
| VideoToolbox is a bandwidth-constrained probe, not a default audio dependency. | Research decision | [../research/RESEARCH_VIDEO_PIPELINE_2026.md](../research/RESEARCH_VIDEO_PIPELINE_2026.md) |
| OSC is the first high-level show-control probe. | Research decision | [../research/RESEARCH_LIGHTING_SHOW_CONTROL_2026.md](../research/RESEARCH_LIGHTING_SHOW_CONTROL_2026.md) |
| sACN, Art-Net, DMX/RDM/RDMnet, ACN, and OTP require standards and isolated-network gates. | Research decision | [../research/RESEARCH_LIGHTING_SHOW_CONTROL_2026.md](../research/RESEARCH_LIGHTING_SHOW_CONTROL_2026.md) |
| Windows LoLa remains evidence only, not a Mac compatibility requirement. | Strong inference | [../reverse-engineering/REVERSE_ENGINEERING_EVIDENCE_MATRIX_2026.md](../reverse-engineering/REVERSE_ENGINEERING_EVIDENCE_MATRIX_2026.md) |
| SOTA 2026 open questions are closed only by milestone-owned policy, measurement, deferral, or explicit human handoff. | Research decision | [SOTA_2026_OPEN_QUESTION_MATRIX.md](SOTA_2026_OPEN_QUESTION_MATRIX.md) |

## Conflict Ledger

| Conflict | Chosen interpretation | Label | Follow-up |
|---|---|---|---|
| [historical/AUDIO_FIRST_LATENCY_PLAN.md](historical/AUDIO_FIRST_LATENCY_PLAN.md) includes Windows LoLa interop assumptions. | The newer [../MAC_PORT_PLAN.md](../MAC_PORT_PLAN.md) controls: Mac-native fastest mode first. | Research decision | Reintroduce LoLa wire compatibility only as a separately scoped milestone. |
| Windows LoLa uses WinPcap/raw Ethernet paths. | Treat as evidence for packet immediacy and low queueing, not as a Mac API requirement. M04 defines a native versioned UDP PCM packet contract instead of copying the Windows wire grammar. | Strong inference | M05 measures packet age, loss, jitter, and route behavior. |
| Windows LoLa recovered path shows 64-frame int16 behavior. | Treat as benchmark baseline; Mac target probes 16/32/64/128 frames and native formats. | Strong inference | M03 records hardware-supported fastest stable mode. |
| v2.0 package centers XIMEA camera files. | XIMEA is historical evidence only; first production Mac camera target is Blackmagic/ATEM, with AVFoundation as the fallback/generic harness when macOS exposes the capture path. | Strong inference | M08 starts with Blackmagic/ATEM inventory, AVFoundation fallback, and test-pattern sources. |
| v1.5 CUDA/GPUJPEG and v2.0 MJPEG paths exist. | They are historical video branches; native defaults are raw/intra-frame and later VideoToolbox probes. | Static fact | M09 compares native options under audio load. |
| 48 kHz strings exist in Windows LoLa. | 48 kHz Windows interop remains unproven; Mac rates are measured independently. | Runtime gap | M01-M03 record accepted rates per device. |

## Non-Negotiable Hard Rule

No PLC, codec, video, lighting, QoS, UI, recording, or retransmission feature may
increase default audio playout latency. This is inherited from
[../research/RESEARCH_COMPANION_2026.md](../research/RESEARCH_COMPANION_2026.md)
and validated through
[../research/RESEARCH_BENCHMARK_ROADMAP_2026.md](../research/RESEARCH_BENCHMARK_ROADMAP_2026.md).

Resume here: when an implementation decision conflicts with an older plan, add
one row to this ledger before writing code, then check
[SOTA_2026_OPEN_QUESTION_MATRIX.md](SOTA_2026_OPEN_QUESTION_MATRIX.md) for the
owning milestone gate.
