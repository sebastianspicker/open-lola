# Public Source Contracts

Date: 2026-05-11
Status: condensed source-contract index
Verdict: PARTIAL

This file is the active public source-contract summary. The older detailed MXX
contract files were superseded and archived under
`../archive/2026-05-11-doc-condense/docs/source-contracts/`.

## Active Contracts

| Contract | Source-level state | Real-world gate |
|---|---|---|
| Multichannel/RME routing | UDP PCM v2 fragments, selected channel maps, receiver-local mix snapshots, and RME metadata boundaries exist in source/tests. | Physical RME/MADI route evidence, receiver-local mix proof, and metadata provenance. |
| Ultra-low buffer profiles | 32/64-frame safe profiles, 16-frame opt-in, and 8-frame experimental policy exist as guarded source behavior. | Same-hardware low-buffer stability and long-run benchmark evidence. |
| RX buffering | Direct, small, adaptive, and stable-WAN receive profiles exist with visible latency cost. | Same-route measurements showing when each profile is justified. |
| Direct P2P AV | Audio-first direct P2P audio/video report surfaces exist with explicit UIDs and measured-evidence fields. | Physical two-Mac proof, packet capture, and fastest audio baseline comparison. |
| External connectors | LoLa, MVTP/UltraGrid, and JackTrip process/report surfaces exist. | Measured interoperability with selected endpoints. |

## Rules

- Source contracts can be `PASS` only for implemented source/test/doc coverage.
- Product or release claims remain `PARTIAL` until measured hardware and field
  evidence exists.
- Do not use archived MXX files as current implementation instructions.

## Compatibility Horizon

- `audioTransport` is the canonical Direct P2P audio transport contract.
  Legacy `audioCompression` / `--audio-compression` remains a hidden
  compatibility path for old CLI arguments, stored app defaults, initializer
  fallback, and report decoding. Keep it out of public help. Do not remove it
  unless a future audit proves no active fixtures, stored defaults, reports, or
  external scripts still require the legacy name and adds explicit migration or
  breaking-change coverage.
- `inputDeviceUID` and `outputDeviceUID` are the canonical realtime audio graph
  device fields. Legacy single-device `audioDeviceUID` remains a decode-only
  migration fallback and compatibility initializer/accessor for old full-duplex
  configs. New encoded graph configs must write split UIDs, not the legacy key.
  Do not remove this fallback without old-config inventory evidence and an
  explicit migration or breaking-change test.
- `DirectPeerTwoPeerPrototypeReport` and
  `direct-p2p-two-peer-prototype-report` are active measured public contracts
  despite the prototype name. The name is retained for existing report/validator
  compatibility until a promoted replacement schema and command exist. Treat the
  name as compatibility terminology, not as evidence that the path is dead.

## External Connector Classification

| Surface | Classification | Current boundary |
|---|---|---|
| JackTrip connector | Active comparison contract | Used for source-level launch plans, process reports, Docker parity helpers, and NMP comparison. Not a default Open LoLa media path and not app-launchable unless explicitly wired later. |
| UltraGrid / MVTP connector | Active comparison contract | Used for audio/video external connector planning, process reports, Docker/native helper scripts, and NMP comparison. It is side-by-side reference/comparison evidence, not a replacement for direct Open LoLa routing. |
| NMP plan/preflight/endpoint/workflow reports | Active verification surface | Orchestrates LoLa, UltraGrid, and JackTrip comparison plans, executable preflight, endpoint runs, and workflow reports. Keep while CLI, schema inventory, scripts, and tests reference it. |
| External executable preflight | Active safety gate | Validates selected external tools before process-backed connector runs. It does not prove runtime interoperability by itself. |

Do not delete connector modes, report schemas, validators, or helper scripts
unless a connector-specific audit proves no active command, schema inventory
entry, test, script, or documented comparison workflow still depends on them.

## Resume Here

For source work, inspect the current source and tests first. For public wording,
use [current-state.md](current-state.md) and
[implementation-handoff.md](implementation-handoff.md).

VERDICT: PARTIAL
