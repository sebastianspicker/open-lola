# Open Lola Lighting And Show-Control Research 2026
Verdict: PARTIAL

Back to companion: [RESEARCH_COMPANION_2026.md](RESEARCH_COMPANION_2026.md)

Date: 2026-05-02  
Status: internal research ledger, current after public background-lane restructure
Evidence: [RESEARCH_EVIDENCE_MATRIX_2026.md](RESEARCH_EVIDENCE_MATRIX_2026.md),
matters 49-73 and 85

Source refresh checked 2026-05-02: ESTA published standards list identifies
ANSI E1.11-2024 as the current checked DMX512-A revision and ANSI E1.31-2025
as the current checked sACN revision. The official Art-Net site still requires
credit and OEM-code handling, and OSC 1.0 remains the first cue-loop semantics.
See
[../mac-port/sota-open-question-matrix.md](../mac-port/sota-open-question-matrix.md)
for milestone routing.

## Hard Rule

No lighting protocol, show-control cue, fixture metadata lookup, tracking
stream, UI action, discovery scan, multicast/broadcast burst, or recording
feature may increase default audio playout latency.

## Lighting Decision

Lighting and show control are separate control lanes. They may share a show
clock and timestamps, but they must never run inside the audio callback or gate
audio playout.

| Topic | Decision | Implementation rule |
|---|---|---|
| OSC 1.0 | adopt now | First high-level cue/control protocol. |
| OSC 1.1 note | adopt now | Avoid ambiguous version assumptions. |
| MIDI Show Control and MIDI 2.0 | defer | Add only for concrete venue/device needs. |
| DMX512-A, sACN, RDM, RDMnet, ACN, OTP | implementation gate | Full standard reading required before implementation. |
| Art-Net 4 | implementation gate | Public spec exists; read full spec and test OLA/QLC+ interop. |
| OLA | benchmark | Reference gateway and protocol boundary. |
| QLC+ | benchmark | Concrete operator interop target for Art-Net and sACN. |
| Open Fixture Library | defer | Setup/offline fixture metadata; never realtime audio. |
| Chataigne | benchmark | Show-control routing and cue-jitter target. |
| OpenFollow, PSN, OTP | defer | Position/tracking input later; never audio gating. |
| Lighting-triggered audio scheduling | reject | Cues can observe time, not own playout. |

## Control-Lane Shape

Start with OSC because it is public, simple, and well supported by Chataigne,
Open Stage Control, QLC+/OLA workflows, and many venue tools. OSC messages
should carry explicit cue IDs and timestamps where needed. Cue jitter is measured
separately from audio packet timing.

Lighting output should be added in this order:

1. OSC cue output to a tool such as Chataigne.
2. One-universe interop probe through OLA or QLC+.
3. Direct sACN or Art-Net only after standards review and multicast/broadcast
   policy is documented.
4. Fixture metadata through Open Fixture Library concepts after actual target
   fixtures are known.
5. RDM/RDMnet and discovery only as setup/management features.
6. OpenFollow, PSN, and OTP position streams only as timestamped control inputs.

## Protocol Gates

Paid or controlled standards are not implementation sources until the full
standard has been read. For each standard-gated protocol, record:

- document version and publication or reaffirmation date;
- clauses used for packets, timing, discovery, priority, and synchronization;
- licensing or redistribution constraints;
- conformance or interop probes;
- network isolation requirements.

This applies to DMX512-A, sACN/E1.31, RDM/E1.20, RDMnet/E1.33, ACN/E1.17,
OTP/E1.59, MIDI Show Control, and MIDI 2.0. Art-Net has a public specification,
but its licensing/OEM terms still need release review.

## Tool References

OLA provides a useful gateway model and source reference for E1.31/sACN,
Art-Net, OSC, and hardware DMX plugins.

QLC+ provides practical operator-facing Art-Net and sACN behavior that can be
used for one-universe interop tests.

Open Fixture Library provides schema and exporter ideas for fixture metadata.
Fixture lookup and schema validation are setup-time or UI-time only.

Chataigne is a practical show-control router for OSC, MIDI, DMX, Art-Net, sACN,
UDP/TCP, WebSocket, Ableton Link, and PosiStageNet workflows.

OpenFollow and PSN are position/tracking sources for later lighting, sound, and
media integration. OTP is the standards-track position/orientation protocol
gate. None of these may schedule audio playout.

## Required Probes

1. OSC cue probe: send timestamped cues, measure receive jitter in Chataigne or
   Open Stage Control, and confirm audio callback p99/max is unchanged.
2. OLA/QLC+ probe: send one Art-Net universe and one sACN universe on an
   isolated control network.
3. Multicast/broadcast probe: verify lighting traffic cannot starve or delay
   audio packets.
4. Fixture metadata probe: validate actual HfMT fixtures through OFL-compatible
   data without realtime lookup.
5. Tracking probe: map OpenFollow/PSN/OTP timestamps to show-clock events
   without audio dependency.
