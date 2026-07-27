# Public Source Contracts

Date: 2026-07-24
Status: active public source-contract index
Verdict: PARTIAL

This file is the public source-contract summary. Source code, tests, schemas,
and the documents listed here define the implementation authority.

## Active Contracts

| Contract | Source-level state | Real-world gate |
|---|---|---|
| Multichannel/RME routing | UDP PCM v2 fragments, selected channel maps, receiver-local mix snapshots, and RME metadata boundaries exist in source/tests. | Physical RME/MADI route evidence, receiver-local mix proof, and metadata provenance. |
| Ultra-low buffer profiles | 32/64-frame safe profiles, 16-frame opt-in, and 8-frame experimental policy exist as guarded source behavior. | Same-hardware low-buffer stability and long-run benchmark evidence. |
| RX buffering | Direct, small, adaptive, and stable-WAN receive profiles exist with visible latency cost. | Same-route measurements showing when each profile is justified. |
| Direct P2P AV | Audio-first direct P2P audio/video report surfaces exist with explicit UIDs, measured-evidence fields, DSCP PASS guards, useful-media proof policy, and evidence-bundle artifact verification. | Physical two-Mac proof, packet capture, artifact hash verification, and fastest audio baseline comparison. |
| External connectors | LoLa, native MVTP/UltraGrid, and native JackTrip report surfaces exist with source-level runtime support, observed/missing evidence classes, bounded media sinks, topology reports, connector-scoped flag rejection, derived runtime evidence state, and evidence-gated validators. External helper scripts remain reference/parity tooling. | Measured interoperability with selected endpoints, live devices, packet/media quality, teardown, timing, and field-route evidence. |

## Rules

- Source contracts can be `PASS` only for implemented source/test/doc coverage.
- Product or release claims remain `PARTIAL` until measured hardware and field
  evidence exists.
- Do not use archived MXX files as current implementation instructions.
- `OpenLolaContracts` is the canonical framework-free module for shared report
  contracts. `OpenLolaCore/Core/OpenLolaContractsAliases.swift` intentionally
  keeps a small source-compatibility alias set for existing callers; new shared
  contracts should be added to `OpenLolaContracts` first and aliased in core
  only when compatibility requires it.

## Compatibility Horizon

- `audioTransport` is the canonical Direct P2P audio transport contract.
  Legacy `audioCompression` / `--audio-compression` remains a hidden
  compatibility path for old CLI arguments, stored app defaults, initializer
  fallback, and report decoding. Keep it out of public help. Do not remove it
  unless a future audit proves no active fixtures, stored defaults, reports, or
  external scripts still require the legacy name and adds explicit migration or
  breaking-change coverage.
- `inputDeviceUID` and `outputDeviceUID` are the canonical realtime audio graph
  device fields. Legacy single-device `audioDeviceUID` remains a compatibility
  initializer/accessor for in-source full-duplex callers, but decoded graph
  configs must provide split UIDs. New encoded graph configs must write split
  UIDs, not the legacy key.
- `direct-p2p-two-peer-report` and
  `validate-direct-p2p-two-peer-report` are the canonical CLI surfaces for the
  measured two-peer aggregate report. `DirectPeerTwoPeerPrototypeReport`,
  `direct-p2p-two-peer-prototype-report`, and
  `validate-direct-p2p-two-peer-prototype-report` remain compatibility
  contracts for existing reports, fixtures, scripts, and validator callers.
  Treat the prototype name as compatibility terminology, not as evidence that
  the path is dead.

## External Connector Classification

| Surface | Classification | Current boundary |
|---|---|---|
| JackTrip connector | Active comparison contract | Uses Swift-native DEFAULT, JAMLINK, EMPTY-header, WebRTC data-channel, WebTransport datagram, hub/topology, TCP handshake, auth/TLS frame, plugin-boundary, and Opus-extension packet models for source-level JackTrip reports. Native reports expose provider selection, explicit `coreaudio`/`jack-graph` backend selection, bounded decoded PCM sink counters, redundancy recovery, learned source endpoint, sequence quality counters, stop-control datagram counts, explicit network service-class status, and 8/16/24/32-bit DEFAULT PCM packet support. `jack-graph` dry runs use deterministic local frames; measured JACK graph support still requires local JACK capture evidence before any field-readiness claim. Live-device provider evidence remains separate from real-world peer evidence. Reference-peer parity remains blocked by missing `OPEN_LOLA_REFERENCE_PEER_HOST` and no local `jacktrip` executable. Docker/native `jacktrip` helpers are reference/parity evidence tools, not the primary runtime path. |
| UltraGrid / MVTP connector | Active comparison contract | Uses a Swift-native RTP/MVTP media path for PT 20 raw video and PT 21 PCM audio reports, dynamic RTP payload mappings, local JPEG/H.264 validation, local FEC/encryption behavior, topology reports, and control-command modeling. Generated raw-video packets cover the full configured frame size and report byte counters. Native reports expose provider selection, bounded decoded PT21 PCM and reassembled PT20 raw-video sink counters, RTP loss, duplicates, reordering, SSRC changes, timestamp regressions, jitter-like timestamp deltas, raw-video reassembly failures, and evidence-gated validation. Live-device provider evidence remains separate from real-world peer evidence. Reference-peer parity remains blocked by missing `OPEN_LOLA_REFERENCE_PEER_HOST`. Public `uv` helpers remain side-by-side reference/parity evidence, not the primary runtime path. |
| NMP plan/preflight/endpoint/workflow reports | Active verification surface | Orchestrates LoLa, UltraGrid, and JackTrip comparison plans, executable preflight, endpoint runs, and workflow reports. Keep while CLI, schema inventory, scripts, and tests reference it. |
| External executable preflight | Active safety gate | Validates selected external reference tools before parity/helper runs. It does not prove runtime interoperability by itself. |

External connector source reports must name observed evidence classes and the
missing evidence classes required for real-world `PASS`. Source-level synthetic
evidence, local loopback, reference-peer evidence, live-device evidence, and
field-route evidence are separate classes; none should be silently promoted into
another.

## Structure Boundary

Connector and report structure is intentionally conservative. Keep LoLa,
MVTP/UltraGrid, JackTrip, NMP, and external-executable preflight sources under
`Sources/OpenLolaCore/Connectors/` while their public CLI/report schemas share
the current connector validators. Keep `DirectPeerSessionReport` under
`Sources/OpenLolaCore/Network/P2P/` while it remains the direct P2P route and
AV evidence contract.

Do not split connector families or move Direct P2P reports only to make the
tree look more symmetrical. A future structure change must first document the
new owner, preserve existing command/report decoding, keep schema inventory and
fixtures stable, and add path/API compatibility tests before moving files.

Do not delete connector modes, report schemas, validators, or helper scripts
unless a connector-specific reference scan proves no active command, schema
inventory entry, test, script, or documented comparison workflow still depends
on them.

VERDICT: PARTIAL
