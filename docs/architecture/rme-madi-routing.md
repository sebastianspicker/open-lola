# RME MADI Routing Plan

Date: 2026-05-04  
Status: source implementation complete; physical RME evidence pending  
Verdict: PARTIAL

## Evidence Labels

| Design choice | Label |
|---|---|
| RME device visibility through Core Audio | `public API` |
| TotalMix OSC/MIDI metadata where documented | `public API` |
| User-provided matrix snapshots | `compatibility requirement` |
| Real MADI route PASS only from hardware evidence | `experimentally derived requirement` |

## Clean-Room Boundary

RME routing support must use documented public behavior only:

- Core Audio device, stream, clock, buffer, and latency properties;
- documented TotalMix OSC or MIDI remote control/status where the operator
  enables it;
- user-provided snapshots, labels, screenshots, or CSV/JSON exports;
- open-lola's own measurements.

It must not parse private workspaces, copy proprietary behavior, depend on
undocumented packet fields, or use decompiled logic.

## Current RME State

The current RME lane now has validation and source metadata support:

- `RmeFastestAudioPathReport` records driver package, driver version,
  firmware, TotalMix snapshot text, clock source, sample-rate source,
  sample-rate conversion state, and routing notes;
- PASS rejects non-RME MADI paths, aggregate devices, sample-rate conversion,
  class-compliant fallback, missing clock domain, hidden buffers, unsupported
  rates, and selected channel counts that exceed device channels;
- endpoint loopback validates the 16/32/64/128 frame matrix;
- `RmeMatrixMetadataSnapshot` records optional Core Audio, documented TotalMix
  OSC/MIDI, user-provided, or unavailable metadata;
- metadata snapshots are revisioned and rate-limited for the control channel;
- metadata is advisory and `requiresMetadataForPlayback` remains false;
- real hardware matrix transport is still a physical-evidence task.

## Send-All-Channels Baseline

The first professional route is not a TotalMix clone. It is a transport mode:

1. discover all available Core Audio input channels;
2. let the user select all channels or a contiguous/non-contiguous subset;
3. send selected channels in stable source order;
4. let the receiver monitor, mute, pan, gain, and route locally;
5. use metadata only to make labels and routing clearer.

This keeps the audio path useful when matrix metadata is unavailable, stale, or
legally out of scope.

The source implementation now packetizes selected channels as UDP PCM v2
channel-range fragments and prepares receiver-local mix state outside the audio
callback. The legacy v1 path remains available for explicit stereo fallback.

## Matrix Metadata

Matrix metadata can improve monitoring but cannot be a dependency.

| Provider | Allowed fields | Confidence |
|---|---|---|
| Core Audio | stream order, counts, labels if available | high for channel order |
| Documented TotalMix OSC/MIDI | public routing, gain, mute, pan, names where exposed | medium until measured |
| User-provided snapshot | operator labels and route intent | operator-confirmed |
| Unavailable | no matrix metadata | explicit fallback |

Metadata is revisioned and rate-limited on the control channel. Audio media
packets carry only the metadata revision needed to correlate a fragment with a
control-plane snapshot.

## Channel Naming

Default naming:

- `input-1` through `input-N` from Core Audio stream order;
- `output-1` through `output-N` for receiver outputs.

Optional naming:

- user labels for ensemble roles, microphones, instruments, and returns;
- documented TotalMix labels when available;
- bus labels for receiver monitor groups.

No sender-side name may change channel order. Stable source index is the
ordering authority.

## RME Validation Matrix

Required physical validation:

| Matrix | Required rows |
|---|---|
| sample rate | 48 kHz, 96 kHz, 192 kHz if supported |
| frame size | 8, 16, 32, 64, 128 where accepted |
| channel count | 2, 8, 16, 32, 64, max stable |
| route mode | send-all-channels, identity receiver mix, selected receiver mix |
| metadata | absent, Core Audio only, public TotalMix/user snapshot |
| RX profile | direct, small, adaptive, stable/WAN |

PASS requires measured hardware evidence. Synthetic and built-in-device runs
remain `PARTIAL`.

## Risks

- 64-channel float32 at tiny frame sizes increases packet rate and bandwidth.
- Public TotalMix metadata may be incomplete or disabled by the operator.
- A matrix snapshot can be stale relative to live audio routing.
- MADI hardware clocking and sample-rate conversion mistakes can produce false
  latency conclusions.

## Resume here

Source-level send-all-channels, receiver-local mix, and optional metadata are
implemented. Resume with physical RME MADI field evidence: metadata absent,
Core Audio only, and operator-provided/documented TotalMix metadata should all
play media before any `PASS` claim.

VERDICT: PARTIAL
