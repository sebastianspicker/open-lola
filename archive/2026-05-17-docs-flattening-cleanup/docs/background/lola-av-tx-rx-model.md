# LoLa-Style AV TX/RX Model

Date: 2026-05-15  
Status: publication-safe conceptual model  
Scope: transmit/receive responsibilities without proprietary detail

## Evidence Boundary

Withheld internal notes were used only to identify conceptual TX/RX
responsibilities; this model does not expose recovered packet or symbol detail.

Evidence references in this document use safe labels only: internal static
analysis notes, timing measurement, open-lola implementation test,
fixture-based validation, or future controlled interoperability test.

## Conceptual Pipeline

| Responsibility | Publication-safe model | Evidence label | open-lola handling |
|---|---|---|---|
| Capture/input | Audio and video enter through explicit device-facing paths. | internal static analysis notes | Capture reports must record hardware, sample/frame format, and timing assumptions. |
| Preprocessing | Work before transport is bounded and deadline-aware. | inferred from internal static analysis notes | Avoid unbounded transforms inside realtime paths. |
| Encoding/raw transport | Audio remains low overhead; video may use CPU JPEG-like or raw/near-raw handling where evidence permits. | strongly supported by internal static analysis notes | Prefer measured, simple formats first; treat codec upgrades as optional lanes. |
| Packetization | Media is split for packet transport without publishing byte layouts. | internal static analysis notes | open-lola packet fixtures document only open formats under project control. |
| Transport | Media uses a direct, loss-sensitive path separate from higher-level session work. | internal static analysis notes | Route certification records path class, loss, jitter, and verdict. |
| Receive/depacketization | RX reconstructs usable media only when timing still allows it. | inferred | Late or incomplete data may be dropped or marked rather than delaying audio. |
| Buffering | Small fixed buffers are the relevant low-latency design lesson. | open-lola implementation test | Validate zero or one receive-block targets before accepting larger buffers. |
| Decoding/unpacking | Unpacking must not push audio past its deadline. | open-lola design decision | Video work degrades first when deadlines conflict. |
| Playback/rendering | Audio playback is the primary deadline; video render follows available timing. | validated by open-lola reports | Integrated AV proof must preserve the audio baseline. |
| Synchronization | Synchronization is constrained by the audio deadline, not by perfect video completeness. | inferred | Drift and PLC logic must fit inside the already-due audio block. |

## TX Model

The transmit side is modeled as a narrow chain:

1. Capture the smallest useful audio block and the current video frame.
2. Perform only bounded processing needed for the selected mode.
3. Emit packetized media promptly.
4. Keep status/session work outside the realtime media deadline.

The 2026-05-15 Swift Windows LoLa probe reinforced the need for independent
audio and video transmit pacing. A single mixed send loop allowed raw-video
fragment bursts to starve audio, which showed up on Windows as frequent audio
buffer realignment. Splitting Swift live TX into separate paced audio and video
loops preserved visible generated video and reduced Windows-side realignments by
roughly 90% for the tested peer session.

## RX Model

The receive side is modeled as a deadline filter:

1. Accept media for the active session.
2. Reassemble or unpack only what can still be presented on time.
3. Feed a small playout/render buffer.
4. Preserve audio timing when video or control work is late.

## Compatibility Boundary

This model is suitable for open-lola design and testing. It is not a published
packet grammar and not a drop-in compatibility claim.

VERDICT: PARTIAL
