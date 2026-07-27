# Multichannel Audio Routing

Date: 2026-05-21
Status: source-level multichannel routing and receiver-local mix contract implemented; physical RME output evidence pending
Verdict: PARTIAL

## Evidence Labels

| Design choice | Label |
|---|---|
| Core Audio stream configuration, channel maps, and device UIDs | `public API` |
| MADI channel-count expectations, direct LAN, DSCP, and PTP terminology | `public standard` |
| Stable channel descriptors, metadata revisions, and receiver-local mix snapshots | `original open-lola design` |
| Physical send-all-channels and receiver-mix validation | `experimentally derived requirement` |
| User-supplied labels when driver metadata is unavailable | `implementation hypothesis` |

## Objective

Define a stable MADI-scale channel model that can send all selected channels,
receive all negotiated channels, and route/mix them locally at the receiver
without forcing sender-side downmix.

## Current State

Implemented source contracts:

- `AudioChannelDescriptor` has stable source index, label, and source kind.
- `AudioChannelSet` can create default input/output sets and sort by stable
  source index.
- `AudioTransportNegotiation` selects v2 channel order and warns on v1 stereo
  fallback.
- `ReceiverMixSnapshot` prepares gain/mute/pan/route maps outside the callback.
- `MadiReceiveEngine` applies the prepared receiver mix before the
  callback-facing render step consumes a ready playout block.
- `madi-full-duplex-run --receiver-mix swap-stereo` records configured
  receiver-mix evidence in the socket-backed MADI full-duplex report.
- `RmeMatrixMetadata.swift` stores optional matrix metadata and revisions.

Missing live behavior:

- no peer control exchange for channel descriptors;
- no live RME TotalMix or user metadata import;
- no physical Core Audio output renderer proof for multichannel RME MADI RX;
- no CLI config for arbitrary selected channels or arbitrary receiver route
  maps beyond the bounded `identity|swap-stereo` proof mode;
- no physical proof of send-all-channels and receiver-local mix modes.

## Channel Ordering

Ordering rule:

1. Use Core Audio stream configuration order as the stable physical order.
2. Attach labels from documented public driver metadata or user configuration.
3. Never use labels to reorder channels.
4. Transmit `metadataRevision` so receivers can detect changed labels/routes.
5. Reject a media packet whose channel count or metadata revision does not match
   the accepted session unless a control-plane revision update has been accepted.

## Routing Modes

| Mode | Purpose | PASS boundary |
|---|---|---|
| identity | selected input N maps to output N | required first |
| selected subset | transmit only selected channels in stable order | requires metadata and sample proof |
| receiver local mix | receiver applies gain/mute/pan/route | requires snapshot revision proof |
| explicit downmix | receiver downmixes many channels to fewer outputs | requires operator opt-in |
| metadata absent | numbered channels only | valid if order is stable |

## Receiver Mix Runtime

Receiver mix data must be prepared away from the callback:

- parse and validate route map on control thread;
- build a contiguous, immutable prepared snapshot;
- atomically publish snapshot pointer/revision;
- callback reads the current snapshot without allocation or blocking;
- invalid or stale snapshot keeps the previous accepted route.

## Affected Files

- `Sources/OpenLolaCore/Audio/Routing/ReceiverMixSnapshot.swift`
- `Sources/OpenLolaCore/Audio/MADI/MadiReceive.swift`
- `Sources/OpenLolaCore/Audio/MADI/RmeMatrixMetadata.swift`
- `Sources/OpenLolaCore/Network/UDP/MultichannelTransport.swift`
- `Sources/OpenLolaCore/Protocol/SessionNegotiation.swift`
- `Sources/open-lola/Commands/Audio/MadiFullDuplexCommands.swift`
- `Tests/OpenLolaCoreTests/MadiReceiveTests.swift`
- `Tests/OpenLolaCoreTests/MultichannelTransportTests.swift`

Not active standalone source files:

- `MadiAudioEngine.swift` remains a physical Core Audio ownership concept, not
  a checked-in source contract.
- Receiver mix and RME metadata coverage currently lives in the active MADI,
  multichannel transport, and session tests rather than standalone files named
  `ReceiverMixSnapshotTests.swift` or `RmeMatrixMetadataTests.swift`.

## Tests

- channel descriptor order is stable and label-independent;
- duplicate source indexes are rejected during session acceptance;
- v2 negotiation selects all requested MADI channels;
- v1 fallback emits explicit stereo warning;
- metadata revision mismatch rejects media until control update;
- identity mix produces one-to-one routes;
- destructive downmix requires explicit policy;
- snapshot replacement increments revision and preserves previous route on error;
- 64-channel RX depacketization preserves stable channel order;
- receiver-local routing maps remote channel N to local output M before render;
- socket-backed `madi-full-duplex-run --receiver-mix swap-stereo` records route
  count, revision, output channels, rendered blocks, and callback-safe policy;
- 64-channel route map can be prepared without callback allocation.

## Benchmarks

- snapshot preparation time for 64 and 128 routes;
- callback mix cost for identity, selected subset, and downmix;
- memory footprint of prepared snapshots;
- channel metadata update rate under control load;
- audio callback p99/max before and after route changes.

VERDICT: PARTIAL
