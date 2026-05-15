# Open Lola Research Companion 2026

Canonical entry point: [RESEARCH_COMPANION_2026.md](RESEARCH_COMPANION_2026.md)

Date: 2026-05-04  
Status: canonical research companion set  
Scope: documentation and research consolidation only
Verdict: PARTIAL

## Hard Rule

No PLC, video path, lighting path, codec, retransmission, QoS rule, UI feature,
or recording feature may increase default audio playout latency.

The fastest mode is audio-first: direct Core Audio, fixed tiny playout target,
and uncompressed UDP PCM on measured wired paths. Every other subsystem is
subordinate and must degrade before audio timing changes.

## Reading Order

1. Read this companion first.
2. Read [RESEARCH_AUDIO_ENGINE_2026.md](RESEARCH_AUDIO_ENGINE_2026.md) for the
   default audio engine contract.
3. Read [RESEARCH_NETWORK_TIMING_2026.md](RESEARCH_NETWORK_TIMING_2026.md) for
   academic-network, QoS, PTP, AVB, TSN, AES67, RAVENNA, Dante, and ST 2110
   implications.
4. Read [RESEARCH_VIDEO_PIPELINE_2026.md](RESEARCH_VIDEO_PIPELINE_2026.md) only
   after the audio constraints are clear.
5. Read
   [RESEARCH_LIGHTING_SHOW_CONTROL_2026.md](RESEARCH_LIGHTING_SHOW_CONTROL_2026.md)
   for OSC, sACN, Art-Net, DMX/RDM/RDMnet, OFL, OLA, QLC+, Chataigne,
   OpenFollow, PSN, and OTP.
6. Use [RESEARCH_EVIDENCE_MATRIX_2026.md](RESEARCH_EVIDENCE_MATRIX_2026.md) as
   the source-of-truth evidence register for matters 1-85.
7. Use [RESEARCH_BENCHMARK_ROADMAP_2026.md](RESEARCH_BENCHMARK_ROADMAP_2026.md)
   to turn the research into pass/fail measurement gates.

## Document Map

| Document | Role |
|---|---|
| [RESEARCH_AUDIO_ENGINE_2026.md](RESEARCH_AUDIO_ENGINE_2026.md) | Core Audio, UDP PCM, callback safety, thread ownership, packet/playout contract, PLC, and drift. |
| [RESEARCH_NETWORK_TIMING_2026.md](RESEARCH_NETWORK_TIMING_2026.md) | Academic networks, DSCP/QoS, PTP, AVB, TSN/WCRT, AES67, RAVENNA, Dante, and ST 2110. |
| [RESEARCH_VIDEO_PIPELINE_2026.md](RESEARCH_VIDEO_PIPELINE_2026.md) | AVFoundation, VideoToolbox, JPEG XS, UltraGrid, RIST/SRT, and hardware video constraints. |
| [RESEARCH_LIGHTING_SHOW_CONTROL_2026.md](RESEARCH_LIGHTING_SHOW_CONTROL_2026.md) | OSC, sACN, Art-Net, DMX/RDM/RDMnet, OFL, OLA, QLC+, Chataigne, OpenFollow, PSN, and OTP. |
| [RESEARCH_EVIDENCE_MATRIX_2026.md](RESEARCH_EVIDENCE_MATRIX_2026.md) | Canonical source matrix with checked URLs, quality, latency implications, implementation implications, confidence, decisions, and required probes. |
| [RESEARCH_BENCHMARK_ROADMAP_2026.md](RESEARCH_BENCHMARK_ROADMAP_2026.md) | Concrete measurement gates and acceptance criteria. |

## Public Documentation

Publication-safe summaries for readers who should not see internal
reverse-engineering detail live in
[../background/README.md](../background/README.md).
The public documentation entry point is [../README.md](../README.md).
Public-safe reverse-engineering status lives under
[../reverse-engineering/](../reverse-engineering/README.md).
Internal reverse-engineering evidence remains under
[../../private/reverse-engineering/](../../private/reverse-engineering/README.md).

## Decision Summary

| Area | Decision | Reason |
|---|---|---|
| Core Audio HAL/AUHAL/IOProc | adopt now | Closest macOS path to the hardware audio deadline. |
| 16/32/64-frame buffer probing | adopt now | Accepted frame size must be measured, not assumed. |
| UDP PCM, one datagram per audio block | adopt now | Minimal direct transport for fastest wired academic paths. |
| Zero or one receive-block playout target | adopt now | Default latency cannot grow to hide network behavior. |
| Silence or same-deadline PLC on loss | benchmark | PLC is allowed only inside the already-due block deadline. |
| JackTrip, AOO, SonoBus source patterns | benchmark | Useful references, but their adaptive buffers/resends are not default policy. |
| DSCP/QoS and macOS service classes | benchmark | Path behavior must be classified as honored, rewritten, ignored, or harmful. |
| PTP, AVB, TSN/WCRT | implementation gate | Deterministic claims require full profile review and target-network measurement. |
| AES67, RAVENNA, Dante/ST 2110 | implementation gate | Useful interop lanes after direct UDP PCM is measured. |
| VideoToolbox, UltraGrid, JPEG XS | defer | Video is valuable but cannot drive audio playout timing. |
| RIST/SRT retransmission video | defer | WAN video robustness belongs outside fastest audio. |
| OSC show control | adopt now | High-level control can stay outside the audio callback. |
| sACN, Art-Net, DMX/RDM/RDMnet, OTP | implementation gate | Full standards review and isolated lighting probes are required. |
| Adaptive default jitter growth, retransmission waits, video-gated audio, lighting-triggered audio | reject | Each can increase default audio playout latency. |

Decision values are normalized to: adopt now, benchmark, defer, reject,
implementation gate.

## Historical Files

The following files are preserved for traceability but are no longer the primary
research entry point:

- [deprecated research archive](../../archive/2026-05-05-doc-consolidation/research/deprecated-research/README.md)
- [audio-first plan archive](../../archive/2026-05-05-doc-consolidation/mac-port/historical/AUDIO_FIRST_LATENCY_PLAN.md)

Their content remains useful as historical notes. Current decisions and source
status belong in the canonical companion set above.

## Source Refresh Boundary

[RESEARCH_EVIDENCE_MATRIX_2026.md](RESEARCH_EVIDENCE_MATRIX_2026.md) records
the 2026-05-02 source refresh for matters 1-85. Paid standards are cited only
from public catalog or preview metadata. Any implementation that depends on
ANSI, IEEE, AES, MIDI, SMPTE, or similar paid/member documents must read the
full current standard first and record the exact clauses used.

Third-party source repositories were snapshot outside this repo under
`/tmp/open-lola-research-sources/`. Do not vendor those sources into open-lola.
