# UltraGrid and JackTrip Connector Remediation Ledger

Date: 2026-05-18
Status: active
Verdict: PARTIAL

This ledger tracks execution of root `plan.md`. Detailed audit evidence remains
in `plan-draft.md`.

| ID | Slice | Status | Evidence | Remaining work |
| --- | --- | --- | --- | --- |
| CONN-00 | Restore verification trust | done | `swift test --filter ReportSchemaInventoryTests` passed after removing unrelated private-evidence triggers from release-hardening fixtures and smoke builder. | None for this slice. |
| CONN-01 | Harden evidence and report contracts | done | External connector source reports expose observed and missing evidence classes for synthetic, local loopback, reference-peer, live-device, and field-route evidence. Fixture and validator tests passed. | None for this source-level report contract slice; measured peer/route evidence remains under CONN-07. |
| CONN-02 | Complete JackTrip DEFAULT packet correctness | done | JackTrip DEFAULT channel sentinels, 16-bit-only packet validation, redundancy datagram modeling, and stop-control accounting are implemented. `swift test --filter JackTripCompatibilityTests` passed. | None for this bounded source-level slice; measured peer evidence remains under CONN-07. |
| CONN-03 | Complete JackTrip UDP runtime semantics | done | Local UDP receiver coverage proves peer endpoint learning; reports expose redundancy recovery, unrecovered gaps, duplicate packets, primary-packet reordering, and explicit network service-class status. `swift test --filter JackTripCompatibilityTests` passed. | None for this bounded source-level slice; measured reference-peer and route evidence remain under CONN-07. |
| CONN-04 | Complete UltraGrid RTP/MVTP receive analysis | done | Reports expose RTP loss, duplicate packets, reordering, SSRC changes, timestamp regressions, jitter-like timestamp delta changes, and raw-video frame reassembly failures. `swift test --filter UltraGridCompatibilityTests` passed. | None for this bounded receive-analysis slice; unsupported advanced modes remain under CONN-09. |
| CONN-05 | Make UltraGrid generated payloads field-realistic | done | Generated UltraGrid video uses full configured raw frame byte counts and reports audio/video/RTP payload byte counters. A 640x360 RGB focused test covers fragment count and reassembly. | None for this generated-frame sizing slice. |
| CONN-06 | Integrate shared live media providers | done | JackTrip builders accept injected audio providers; UltraGrid builders accept injected audio/video providers; focused tests prove deterministic provider bytes reach encoded packets. | Optional live-device smokes remain separate from real-world peer evidence and must not promote connector verdicts to `PASS`. |
| CONN-07 | Add measured reference-peer parity gates | done | `scripts/run-reference-peer-parity-gate.sh` writes a machine-readable readiness/command-plan artifact for Swift/reference directions and exits `77` with explicit missing prerequisites. | Actual external peer runs, route capture, live media, and field thresholds remain required before any real-world `PASS`. |
| CONN-08 | Keep app and docs truthful | done | Active docs/script index describe the new connector runtime/report contracts, and focused app-shell tests preserve CLI/planning-only connector status. | Recheck whenever connector public contracts change again. |
| CONN-09 | Keep UltraGrid advanced modes fail-loud | done | FEC, encryption, JPEG/H.264, dynamic RTP, codec-specific payloads, and advanced control APIs remain explicitly unsupported; focused UltraGrid codec tests prove unsupported payloads fail loud. | Future implementation requires scoped public packet evidence and mode-specific tests. |
| CONN-10 | Defer UltraGrid NAT/server-client topology | deferred | The native UltraGrid path remains direct-peer only, and direct reference-peer parity has not produced measured evidence yet. | Revisit after direct Swift/reference parity passes with route evidence. |
| CONN-11 | Keep JackTrip hub/TCP/auth modes fail-loud | done | JackTrip hub, TCP/auth, WebRTC, WebTransport, JACK backend, plugin, JamLink, empty-header, and non-PCM modes remain listed as unsupported and covered by focused tests. | Future implementation requires explicit scope, handshake fixtures, and behavior tests. |
| CONN-12 | Keep JackTrip non-16-bit audio fail-loud | done | JackTrip DEFAULT packet validation rejects 8-bit, 24-bit, and 32-bit payloads explicitly rather than treating unsupported audio as valid. | Implement conversion only with public behavior fixtures. |
| CONN-13 | Resolve release hygiene with active root plan docs | done | Release hygiene tests now allow complete active root remediation companions during a live `/goal` checkout and require release-candidate scans to reject root plan artifacts. The focused Swift release hygiene tests and live hygiene script pass. | Archive the active plan bundle after this `/goal` run ends; keep release artifacts free of root plan files. |

No open connector-plan findings remain. Do not promote product status beyond
`PARTIAL` until measured external peer, route, live media, and field evidence
exists.
