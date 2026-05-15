# Open Lola Video Pipeline Research 2026
Verdict: PARTIAL

Back to companion: [RESEARCH_COMPANION_2026.md](RESEARCH_COMPANION_2026.md)

Date: 2026-05-02  
Status: internal research ledger, current after public background-lane restructure
Evidence: [RESEARCH_EVIDENCE_MATRIX_2026.md](RESEARCH_EVIDENCE_MATRIX_2026.md),
matters 39-48 and 82-84

Source refresh checked 2026-05-02: Apple AVFoundation,
`AVCaptureVideoDataOutput`, frame-duration, Core Media I/O, and VideoToolbox
docs still support AVFoundation/test-pattern as the generic capture harness and
VideoToolbox only after explicit latency/isolation probes. The active
implementation priority is Blackmagic/ATEM production capture first, using the
macOS-exposed AVFoundation path when available and a Desktop Video SDK adapter
only after measured need. See
[../mac-port/sota-open-question-matrix.md](../mac-port/sota-open-question-matrix.md)
for milestone routing.

## Hard Rule

No video capture, codec, transport, retransmission, FEC, display, recording, or
UI feature may increase default audio playout latency.

## Video Decision

Video is a best-effort presence and cueing lane. It must be timestamped,
degradable, and schedulable outside the audio callback. If CPU, GPU, network, or
display pressure competes with audio, video drops frames, reduces quality, or
turns off first.

| Topic | Decision | Implementation rule |
|---|---|---|
| Blackmagic/ATEM capture | defer | First production video target after audio baseline is stable. |
| AVFoundation capture | defer | Generic harness and fallback for macOS-exposed Blackmagic/ATEM/UVC capture paths. |
| AVCaptureVideoDataOutput | defer | Use direct sample-buffer handling and drop late frames. |
| VideoToolbox | defer | Use only for bandwidth-constrained video after realtime probes. |
| JPEG XS | defer | Candidate for low-latency professional video, not audio timing. |
| JPEG XS RTP packetization | implementation gate | Re-check IETF/RFC status before implementation. |
| UltraGrid | defer | Useful academic A/V reference, not a dependency for fastest audio. |
| RIST/SRT | defer | WAN video fallback only; retransmission latency stays out of audio. |
| Video-gated audio scheduling | reject | Video must never determine audio playout. |

## Mac Capture Contract

The first production video adapter should identify the Blackmagic/ATEM path.
When macOS exposes that device through AVFoundation, use AVFoundation through a
narrow `CameraSource` boundary. Add Desktop Video SDK support only after
measured need.

- AVFoundation camera source;
- file-pattern source;
- synthetic test-pattern source;
- optional Core Media I/O camera source;
- optional Desktop Video SDK source only if the macOS-exposed path is absent or
  not fast enough.

Video capture must record frame timestamps, frame age, dropped frames, capture
format, queue depth, and display age. The video queue policy should be "latest
useful frame", not "preserve every frame".

## Codec And Transport Constraints

Raw or simple intra-frame video is the local low-latency baseline. VideoToolbox
H.264/HEVC and JPEG XS are benchmark candidates for bandwidth-constrained or
professional paths.

VideoToolbox probes must explicitly test:

- realtime encode/decode mode;
- frame reordering disabled where required;
- encoder queue depth;
- CPU/GPU pressure while Core Audio runs at target frame sizes;
- glass-to-glass latency;
- behavior when frames are late.

JPEG XS probes must explicitly test:

- codec implementation availability on macOS;
- RTP payload behavior against current RFC/draft status;
- FEC overhead;
- CPU/GPU/FPGA isolation from audio;
- whether line/frame latency claims survive full capture-to-display testing.

RIST/SRT and similar reliable video transports belong only in later WAN video
modes. Their retransmission/FEC latency must be pinned and must not alter the
audio playout target.

## UltraGrid Reference Use

UltraGrid is valuable as an academic low-latency A/V reference for capture,
RTP, codec, and display patterns. It should be run side-by-side during later
video tests, not embedded into the first audio engine.

Required UltraGrid comparison:

- same camera where possible;
- same display path where possible;
- audio load running simultaneously;
- packet capture and frame-age report;
- proof that video activity does not increase audio callback p99/max.

## Required Probes

1. Blackmagic/ATEM inventory: concrete model, exposed capture path, formats,
   and whether AVFoundation is sufficient.
2. AVFoundation capture-only fallback: frame age, dropped frames, callback
   timing, and CPU load while audio runs.
3. Local video transport: raw/intra-frame latency and bandwidth under audio
   stress.
4. VideoToolbox: realtime mode, no frame reordering, queue depth, and
   glass-to-glass latency.
5. JPEG XS: implementation availability, RTP/FEC behavior, and isolation from
   audio deadlines.
6. Failover: prove video degradation happens before audio buffer growth.
