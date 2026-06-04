# Mac-To-Mac Connection Establishment Goal

Date: 2026-05-22
Status: active source-level goal
Verdict: PARTIAL

## Goal

Mac-to-mac setup must default to IP/NAT-aware peer reachability and route
probing before any direct P2P media path is reported as ready. Direct UDP/IP is
preferred only when measured route evidence supports it. SSH remains an
explicit advanced/lab fallback and must never be selected silently.

## Current Evidence

- `NetworkDiagnosticsReport` records ping, traceroute, blocked traceroute
  reasons, process failures, packet loss, and RTT thresholds.
- `NatFriendlyRouteReport` records rendezvous, direct traversal, relay fallback,
  raw route preference, loopback evidence, added latency, and raw-route RTT.
- `MacToMacRouteCertificationReport` and `UdpPcmRouteReport` remain physical
  measured route gates for later PASS claims.
- `DirectPeerTwoPeerRunPlanReport` still builds manual-address media commands
  and remains `PARTIAL` until measured subordinate reports exist, but its
  evidence gates now require `mac-to-mac-connection-preflight-run` first.
- `NativeAppShellOperatorPrototypeState.localDirectPeerCommandHandoff()` now
  hands operators to `mac-to-mac-connection-preflight-run` instead of launching
  direct media.
- `direct-p2p-two-peer-local-run --execute true --require-preflight true`
  requires a passing mac-to-mac connection preflight report before launching
  child media processes.
- The native app workflow selector presents Mac-to-Mac as the default IP/NAT
  preflight-first path, LoLa as a separate external connector path, and
  JackTrip/UltraGrid as app-launchable native external connector workflows
  backed by `external-connector-session-run` reports.

## Default Setup Contract

Normal mac-to-mac setup is `ipNatProbe`:

1. run or consume network diagnostics for the peer address;
2. consume NAT-friendly route evidence for the same setup session;
3. select direct UDP/IP only when diagnostics and NAT traversal both pass;
4. surface NAT, firewall, policy, permission, relay, and missing-evidence
   blockers;
5. emit a preflight report before direct media launch.

Manual direct IP setup is an explicit lab path. SSH is an explicit advanced
fallback. Neither path may produce a setup `PASS`.

Normal app controls expose only the workflow, required endpoints, device
selection, and truthful validation/status surfaces. Advanced controls expose
ports, route/report paths, SSH fallback, buffers, and codec/profile tuning.
Mac-to-Mac advanced controls include the wired Opus/CELT low-delay audio
transport and JPEG-XS video compression options; LoLa advanced controls expose
the existing AVFoundation JPEG-XS payload option.

## Bounded Slices

| ID | Slice | Status | Verification |
|---|---|---|---|
| M2M-01 | Add `MacToMacConnectionEstablishmentReport` schema and validation rules for IP/NAT default setup, selected route, blockers, and explicit SSH fallback intent. | done, source-level | `MacToMacConnectionEstablishmentTests` |
| M2M-02 | Add CLI validator and preflight runner that consumes diagnostics and NAT route evidence. | done, source-level | `ReportSchemaInventoryTests`, `CLICommandInventoryTests`, `NetworkRouteCommandMatrixTests` |
| M2M-03 | Keep `direct-p2p-two-peer-plan-run` as manual/lab planning and add an evidence gate requiring preflight before media readiness is trusted. | done, source-level | direct two-peer plan tests |
| M2M-04 | Map app/operator handoff and supervisor settings to the preflight report before displaying connected/ready/healthy language. | done, source-level; launched-app probe deferred | app-shell tests |
| M2M-05 | Wire direct media launch to accepted preflight evidence. | done, source-level; physical proof deferred | app-shell and two-peer supervisor tests |
| M2M-06 | Collect real institutional/NAT/firewall field evidence. | deferred | manual route matrix and packet capture |

## Affected Contracts

- CLI: add `mac-to-mac-connection-preflight-run` and
  `validate-mac-to-mac-connection-establishment-report`.
- Report schema: add `MacToMacConnectionEstablishmentReport`.
- Runtime: no realtime audio/video callback changes in the source-level slice.
- Supervisor launch: `--require-preflight true` requires
  `--connection-preflight-report` and refuses to execute media unless that
  report validates with `PASS`.
- UI: must not show connected, ready, healthy, streaming, or PASS from this
  setup layer until preflight evidence supports it.
- UI: Normal mode must not expose SSH, route report paths, ports, buffers, or
  codec tuning; Advanced mode may expose those controls only where the selected
  workflow wires them into the generated command or plan.
- UI: JackTrip and UltraGrid are selectable and runnable from the app through
  the native external connector runner. Their app start path must remain report
  validated after the run and must not imply reference-peer interoperability
  without the separate parity gates.
- Fallback: SSH requires explicit operator intent, a non-empty reason, and
  operator-owned SSH targets.

## Verification Plan

Automated checks:

- parser rejects missing values, unknown arguments, duplicate arguments, and
  non-positive counts;
- setup PASS is rejected without IP/NAT mode, diagnostics, direct NAT route, and
  no blockers;
- relay and SSH fallback remain `PARTIAL`;
- blocked diagnostics and missing NAT route evidence are surfaced as blockers;
- schema and CLI inventories include the new public contract.
- app/operator handoff defaults to `mac-to-mac-connection-preflight-run`, not
  `direct-p2p-session-run`;
- SSH supervisor mode rejects missing explicit fallback selection and missing
  fallback reason.

Manual checks:

- run diagnostics and NAT route probes between two Macs on the same LAN;
- repeat across campus/institutional firewall and ISP/NAT paths;
- record packet capture point, DSCP observation, NAT behavior, permission
  blockers, and route labels before promoting any physical route claim.

## Resume here

Continue with physical field evidence before promoting this beyond source-level
completion. The source contract blocks default media launch without preflight,
but real two-Mac PASS still requires measured LAN, institutional firewall, and
NAT route captures.

VERDICT: PARTIAL
