# Audio Routing Roadmap

Date: 2026-05-04  
Status: source implementation complete; physical route evidence pending  
Verdict: PARTIAL

## Evidence Labels

| Design choice | Label |
|---|---|
| Core Audio channel and stream inventory | `public API` |
| Send-all-channels plus receiver-local monitoring | `original open-lola design` |
| RME Matrix metadata only from public or user-provided sources | `clean-room requirement` |
| Physical multichannel acceptance on RME MADI hardware | `experimentally derived requirement` |

## Current State Assessment

The active implementation already has the minimum shape needed to avoid a
stereo-only future, but the runtime path still behaves mostly like a stereo
proof:

- audio device abstraction exists in `CoreAudioInventory.swift` and
  `CoreAudioInventoryReader.swift`;
- Core Audio inventory records input/output stream channel counts, total
  channel counts, labels, sample rates, buffer ranges, latencies, safety
  offsets, and clock domain;
- realtime configuration has `channelCount`, `inputChannelMap`, and
  `outputChannelMap`;
- UDP PCM v1 headers carry `channelCount`, frames per packet, sample rate,
  sender frame index, sender host time, sequence number, sample format, and
  payload byte count;
- multichannel control-plane models exist in `MultichannelTransport.swift`,
  `UdpPcmV2FragmentPlanner.swift`, `ReceiverMixSnapshot.swift`, and
  `RmeMatrixMetadata.swift`;
- UDP PCM v2 packets now encode/decode channel-range fragments with metadata
  revision and guard validation;
- `UdpPcmV2Packetizer` sends all selected channels as MTU-safe fragments and
  `UdpPcmV2FragmentReassembler` reconstructs complete deadlines while
  accounting for missing fragments;
- `RealtimeAudioPacketHandoff.sendNextV2Packets(mode:)` is the source-level
  runtime hook for v2 fragment emission;
- tests cover 64-channel v2 negotiation, explicit stereo v1 fallback,
  MTU-safe v2 fragment planning, v2 packet round trips, exact reassembly,
  lost-fragment accounting, receiver mix preparation, and optional RME metadata.

## Channel Assumptions

Current stereo or fixed-channel assumptions to classify before runtime wiring:

| Area | Current assumption | Required action |
|---|---|---|
| UDP packet fixtures | valid fixtures are stereo v1 packets | classified as legacy v1 compatibility; v2 round-trip tests added |
| localhost smokes | `channelCount: 2` | classified as v1/synthetic smoke; v2 packetizer/reassembler tests added |
| realtime synthetic config | `channelCount: 2`, maps `[0, 1]` | classified as fixture; 64-channel v2 handoff test added |
| audio loopback runtime | synthetic reports use stereo maps | classified as hardware-evidence boundary |
| route and certification fixtures | stereo packet mode | classified as existing certification fixture lane |
| latency tuning candidates | stereo modes | classified as measured-hardware follow-up |
| RME fastest path | validates selected channel count fits device | preserved as PASS guard for future 64-channel evidence |

The audit milestone must not blindly replace every `2`. Some are correct
legacy compatibility tests. The ledger must classify each fixed count as
legacy v1, synthetic fixture, default profile, or bug.

## Routing Model

Routing has two independent layers:

1. media path: selected channel samples travel in stable source order;
2. control path: channel labels, matrix hints, receiver mix, and profile
   choices travel outside the audio callback.

The sender should not be required to downmix for the receiver. For professional
RME/MADI, ensemble, or monitoring workflows, the sender advertises the selected
input channels and sends either all selected channels or a negotiated subset.
The receiver builds its own monitor mix locally.

## Send-All-Channels Mode

Send-all-channels is the primary multichannel design:

- discover input/output channel counts and labels from Core Audio;
- derive default labels as `input-1`, `input-2`, and so on;
- allow user labels and public TotalMix-derived labels as metadata only;
- negotiate protocol v2, sample rate, frame size, sample format, MTU, fragment
  budget, latency profile, RX profile, and selected channel range;
- sort channel descriptors by stable source index;
- packetize one audio deadline into channel-range fragments;
- reassemble only complete deadlines and account for missing/duplicate
  fragments separately;
- keep sequence numbers and sender frame indices deadline-based;
- keep fragment identifiers separate from deadline sequence;
- default receiver mix is identity where output channels exist;
- no destructive downmix unless explicitly configured by the receiver.

## Matrix-Metadata Mode

Matrix metadata is advisory. It must never be required for media playback.

Allowed providers:

- `coreAudioOnly`: stream order, labels, and channel counts from Core Audio;
- `documentedTotalMixOscOrMidi`: public TotalMix OSC/MIDI/remote surfaces only;
- `userProvidedSnapshot`: operator-provided labels and routing notes;
- `unavailable`: no matrix metadata.

Forbidden providers:

- private TotalMix workspace parsing;
- proprietary packet fields;
- decompiled LoLa or vendor-internal behavior;
- audio-callback matrix queries.

Metadata shape:

- source channel and destination bus identifiers;
- gain in dB, mute, solo, pan, stereo pair, and label where available;
- snapshot ID, source kind, captured timestamp, legal basis, and confidence;
- revision number used by the control channel and by v2 fragment headers.
- control-channel updates are rate-limited and stale revisions are rejected.

## Receiver Mix Requirements

Receiver-local mix state is non-realtime control data. The audio callback may
only read a precomputed, immutable mix snapshot or preallocated scalar tables.

Required controls:

- select source channels;
- mute and gain each source;
- pan mono sources across stereo outputs;
- route source channels to local output channels;
- preserve identity routing for matching channel counts;
- reject hidden downmix if the receiver has fewer outputs and no explicit
  downmix policy.

The socket-backed `madi-full-duplex-run --receiver-mix swap-stereo` path records
configured receiver-mix evidence in `MadiFullDuplexReport.receiverMix`. That is
runtime source evidence only; `PASS` still requires a physical RME receive run
proving the same receiver-local mix on real output channels.

## Compatibility

UDP PCM v1 remains the fixed legacy path. If a peer only supports v1:

- fall back to explicit stereo v1;
- emit a machine-readable warning;
- do not silently discard channel metadata;
- do not claim multichannel PASS.

UDP PCM v2 is required for MADI-scale operation. It carries channel-range
fragments under the configured MTU and uses the control channel for metadata.

## Tests And Benchmarks

Tests first:

- channel-count negotiation;
- v1 stereo fallback;
- v2 MTU fragment planning;
- receiver identity mix;
- channel metadata serialization;
- non-destructive downmix rejection;
- `madi-full-duplex-run --receiver-mix swap-stereo` report validation;
- stale matrix metadata fallback.

Benchmarks:

- packetization CPU for 8/16/32/64 frame deadlines;
- max stable channel count at 8/16/32/64 frames;
- callback p99/max under identity mix;
- MADI loopback and two-machine P2P route with packet capture.

## Resume here

Source-level M01-M05 is implemented. Resume at physical evidence: run real
RME MADI/Core Audio inventory, v2 two-machine packet capture, physical
receiver-local mix proof, and metadata-absent/metadata-present field trials
before claiming `PASS`.

VERDICT: PARTIAL
