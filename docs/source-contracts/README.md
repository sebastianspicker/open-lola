# Public Source Contracts

Date: 2026-05-11
Status: condensed source-contract index
Verdict: PARTIAL

This file is the active public source-contract summary. The older detailed MXX
contract files were superseded and archived under
`../../archive/2026-05-11-doc-condense/docs/source-contracts/`.

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

## Resume Here

For source work, inspect the current source and tests first. For public wording,
use [../current-state.md](../current-state.md) and
[../roadmap/README.md](../roadmap/README.md).

VERDICT: PARTIAL
