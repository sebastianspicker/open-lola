# Progress

Date: 2026-05-05  
Status: M00, M02, and M04 complete; consolidated implementation companion active; GOAL.md codewise closure source report, CLI surface, validator, required docs areas, and final report artifact are implemented with real-world measurements assumed pending; public MXX multichannel, low-buffer, and RX-buffer source contracts are source-implemented but physical-evidence partial; release source export staging runs the C12 hygiene scan; M01, M03, G03/P02, M05, M06, M07, M08, M09, M10, M11, M12, M13, M14, M15, G16, and F10 source validation partial; Q001-Q006, Q009-Q010, M06-M15 runtime gates, F10 benchmark evidence, and release reviewer/signoff gates remain open

## Completion Rule

A milestone is complete only when all of these are true:

- implementation exists;
- tests pass;
- validation report exists;
- relevant docs are updated;
- this file marks the milestone complete with a dated verdict.

## Milestone Status

| ID | Status | Verdict | Notes |
|---|---|---|---|
| M00 | Complete | PASS 2026-05-02 | Minimal Swift package, core model, CLI summary, tests, docs, and smoke probe pass. |
| M01 | Partial | PARTIAL 2026-05-02 | Report schema, G01 reference-rig validator, fixtures, PASS guards, and Swift validation pass; exact hardware and route labels remain Q001. |
| M02 | Complete | PASS 2026-05-02 | Core Audio inventory model, CLI JSON output, fixture tests, validation report, and local device probe pass. |
| M03 | Partial | PARTIAL 2026-05-02 | Endpoint loopback contract, G02 RME fastest-audio validator, fixtures, tests, and CLI validation pass; physical RME matrix and 30-minute stability run remain open. |
| M04 | Complete | PASS 2026-05-02 | Versioned UDP PCM packet contract, parser/serializer, fixtures, malformed-packet tests, CLI validator, and localhost smoke pass. |
| M05 | Partial | PARTIAL 2026-05-03 | Route report schema, G04 certification wrapper, fixture validation, localhost route smoke, sender/receiver CLIs with physical evidence fields, byte-exact UDP PCM loopback diagnostics, F11 session agreement, ICMP/traceroute comparison, NAT-friendly source handoff, timestamp validation, and physical-route PASS guards pass; direct-link, switch, campus packet-capture, and real NAT/ISP reports remain open. |
| M06 | Partial | PARTIAL 2026-05-03 | Drift/PLC report schema, G05 certification wrapper, accepted F02/F03 source gates, LoLa baseline comparison contract, fixture validation, same-deadline PLC invariant tests, and synthetic smoke pass; accepted realtime-engine evidence, accepted physical route, 60-minute fixed-target run, measured same-hardware LoLa baseline, and artifact notes remain open. |
| M07 | Partial | PARTIAL 2026-05-02 | AoIP evaluation report schema, G06 certification wrapper, fixture validation, PTP/baseline/stress PASS guards, and synthetic smoke pass; real hardware, PTP lock, standards/vendor profiles, and WCRT stress remain open. |
| M08 | Partial | PARTIAL 2026-05-03 | Video capture report schema, test-pattern source, latest-frame queue, Blackmagic/ATEM-first source policy, AVFoundation fallback source, production capture PASS gates, video-only run CLI, fixture validation, audio-impact PASS guards, and synthetic smoke pass; target Blackmagic/ATEM inventory and audio-on/video-on proof remain open. |
| M09 | Partial | PARTIAL 2026-05-03 | Video transport report schema, raw frame packetization, encoded bounded fragments, complete/current-frame reassembly, stale incomplete-frame drops, latest-frame receiver accounting, raw `video-transport-run`, degradation PASS guards, VideoToolbox policy gates, fixture validation, and synthetic smoke pass; physical packet-captured route, VideoToolbox runtime, and audio-plus-video stress remain open. |
| M10 | Partial | PARTIAL 2026-05-03 | Integrated A/V report schema, synthetic headless runner, bounded `integrated-av-run`, ownership/degradation PASS guards, 30-minute duration and overlap gates, subordinate report/capture-point cross-reference gates, fixture validation, and synthetic smoke pass; measured 30-minute stress remains open. |
| M11 | Partial | PARTIAL 2026-05-03 | OSC cue packet contract, synthetic/live loopback timing, bounded `osc-cue-external-run`, G08 ATEM read-only reachability, fixture validation, audio-impact PASS guards, and synthetic smoke pass; live external OSC peer, real ATEM status, and audio-active evidence remain open. |
| M12 | Partial | PARTIAL 2026-05-03 | Lighting fixture gate report schema, OSC-first cue workflow gates, safety policy, standards evidence, explicit-arm/isolation gates, packet-capture PASS guards, audio-impact PASS guards, fixture validation, synthetic smoke, and bounded `lighting-gate-run` handoff pass; live QLC+/OLA output and packet/audio evidence remain open. |
| M13 | Partial | PARTIAL 2026-05-03 | Native app shell report schema, immutable config boundary, read-only metrics observer, realtime ownership PASS guards, SwiftUI target, fixture validation, synthetic smoke, and bounded `native-app-runtime-smoke` handoff pass; public hardware-validation aggregate schema, PASS guards, fixture validation, synthetic smoke, and bounded `hardware-validation-run` pass; launched GUI/app-bundle, field app-vs-CLI metrics, and physical hardware matrix evidence remain open. |
| M14 | Partial | PARTIAL 2026-05-03 | Recording/session artifact report schema, side-lane policy, simulated slow-writer drop/gap counters, media-impact PASS guards, fixture validation, synthetic smoke, and bounded `recording-session-run` artifact handoff pass; real media writer, disk-pressure stress, and recording-off baseline comparison remain open. |
| M15 | Partial | PARTIAL 2026-05-03 | Packaging field-test report schema, package contents, signing/notarization/entitlement readiness fields, clean-Mac probe fields, field-report PASS guards, fixture validation, synthetic smoke, bounded `packaging-field-run`, P05 `field-runtime-proof-run`, and composite F09 `field-readiness-run` pass; Q010 signing identity, Developer ID package, notarization, Gatekeeper, and clean-Mac field evidence remain open. |

## Public Source Contract Status

| ID | Status | Verdict | Notes |
|---|---|---|---|
| MXX multichannel routing | Source complete | PARTIAL 2026-05-04 | UDP PCM v2 fragments, exact reassembly, receiver-local mix snapshots, and optional public/user-provided RME matrix metadata exist; physical RME/MADI evidence remains open. |
| MXX ultra-low-buffer profiles | Source complete | PARTIAL 2026-05-04 | Explicit 16-frame and experimental 8-frame contracts, profile latency accounting, and PASS guards exist; physical RME/direct-route 16-frame and long-run 8-frame evidence remain open. |
| MXX RX buffering | Source complete | PARTIAL 2026-05-04 | Direct, Small, Adaptive, and Stable/WAN RX policies, deterministic impairment simulation, hidden-growth rejection, and latency-cost report fields exist; physical direct and impaired-route comparisons remain open. |
| GOAL.md codewise closure | Codewise complete | PASS 2026-05-05 | Source report, CLI writer, validator, schema inventory, tests, required docs areas, and final report artifact exist; real-world verdict remains PARTIAL because physical measurements are only assumed pending. |
| GOAL.md runtime completion | Runtime audit complete | PARTIAL 2026-05-05 | [reports/GOAL_RUNTIME_COMPLETION_BLOCKERS_2026-05-05.md](reports/GOAL_RUNTIME_COMPLETION_BLOCKERS_2026-05-05.md) maps every runtime goal item to field artifacts and exact measurement commands; local probes show no RME/MADI target, no production video device, no Developer ID identity, and source-level app surface only. |

## Documentation Refresh Checklist

- [x] Preserve previous `MAC_PORT_PLAN.md` under `mac-port/historical/`.
- [x] Rewrite root `MAC_PORT_PLAN.md` as roadmap overview.
- [x] Add evidence, conflict, risk, validation, progress, open-question, and
  milestone index files.
- [x] Add M00-M15 milestone continuation docs.
- [x] Preserve pre-harness `mac-port/README.md` and `mac-port/PROGRESS.md`
  under `mac-port/historical/`.
- [x] Add harness entry points, status companions, templates, and docs verifier.
- [x] Run `bash scripts/verify-docs.sh`.
- [x] Run `shellcheck scripts/*.sh`.
- [x] Add SOTA 2026 open-question matrix and route Q001-Q010 plus 85 SOTA
  probes to milestone gates.
- [x] Complete M00 implementation.
- [x] Complete M01/G01 source validation with Q001 still open.
- [x] Complete M02 Core Audio inventory implementation.
- [x] Complete M03/G02 source validation with physical RME loopback measurement still open.
- [x] Complete G03/P02 source validation with measured RME callback ownership and packet handoff still open.
- [x] Complete M04 UDP PCM packet contract implementation.
- [x] Complete M05/G04 source validation with physical route certification still open.
- [x] Complete M06/G05 source validation with accepted F02/F03 source gates,
  measured LoLa baseline contract, and 60-minute drift/PLC run still open.
- [x] Complete M07/G06 source validation with physical AoIP/PTP/WCRT evidence still open.
- [x] Complete M08/G07/F05 source validation with production capture PASS gates
  and audio-on/video-on evidence still open.
- [x] Complete M09/F06 source validation with fragmentation/reassembly gates,
  physical video route and audio-plus-video evidence still open.
- [x] Complete M10/F07 source validation plus bounded integrated report writer,
  A/V overlap gate, and report/capture-point cross-reference gates with measured
  30-minute integrated A/V stress still open.
- [x] Complete M11/G08 source validation plus bounded external-peer handoff with live external OSC peer, real ATEM status, and audio-impact evidence still open.
- [x] Complete M12/F08 source validation plus bounded lighting handoff writer,
  OSC-first cue workflow gates, and local fixture-owner guards with live
  QLC+/OLA lighting output, packet capture, fixture, and audio-impact evidence
  still open.
- [x] Complete M13 source validation plus bounded runtime handoff with launched GUI/app-bundle, permission, and field app-vs-CLI metrics evidence still open.
- [x] Complete public M13 hardware-validation source contract with aggregate
  PASS guards, fixture validation, synthetic smoke, and bounded report writer
  while real RME, Blackmagic/ATEM, lighting, route, packet-capture, and field
  evidence remain open.
- [x] Complete M14 source validation plus bounded artifact handoff with real media writer, disk-pressure stress, and recording-off baseline comparison still open.
- [x] Complete M15/F09 source validation plus bounded ad-hoc package, P05 proof,
  and composite field-readiness handoffs with Q010 signing identity, Developer
  ID package, notarization, Gatekeeper, and clean-Mac field evidence still
  open.
- [x] Complete G16 deferred parity ledger source validation with all LoLa parity features kept outside the fastest path until explicit promotion and measured evidence exist.
- [x] Complete F10 faster-than-LoLa closure source validation with closure
  report contract, PASS guards, validator, synthetic smoke, and bounded PARTIAL
  handoff writer; measured benchmark evidence remains open.
- [x] Complete public M14 release-hardening source validation with release
  ledger contract, PASS guards, docs verifier release-surface checks, validator,
  synthetic smoke, and bounded PARTIAL handoff writer; measured benchmark,
  packaging, signing, and clean-Mac evidence remain open.
- [x] Complete F11 network loopback diagnostics source validation with
  byte-exact UDP PCM loopback, ICMP ping comparison, traceroute hop parsing,
  bounded debug trace, CLI validator, session agreement validator, reciprocal
  command output, and localhost smoke; two-Mac physical evidence remains open.
- [x] Complete F12 NAT/ISP-friendly route source validation with self-hosted
  rendezvous listener/client registration, observed endpoint capture, peer
  endpoint discovery, simultaneous direct traversal keepalives, F11 loopback on
  the established traversal socket, added-latency accounting against raw-route
  RTT, bounded self-hosted UDP forwarder/relay fallback after failed direct
  traversal, combined rendezvous/forwarder launcher with performance warning,
  relay compatibility evidence classification, raw-P2P preference PASS guards,
  CLI validator, and localhost/LAN-interface smoke; two-physical-client
  rendezvous/forwarder deployment and NAT/ISP evidence remain open.
- [x] Consolidate active `gaps/`, `prototype/`, and `status/` companions into
  [IMPLEMENTATION_COMPANION.md](IMPLEMENTATION_COMPANION.md), with prior detail
  archived under `mac-port/historical/implementation-companions-2026-05-03/`.
- [x] Add active F01-F10 implementation companions for RME audio, realtime
  duplex audio, P2P routing, drift/PLC/benchmark, Blackmagic/ATEM capture,
  video transport, integrated A/V, lighting cue/output, field readiness, and
  faster-than-LoLa closure.
- [x] Move superseded top-level planning docs into archive lanes and update
  active links to the canonical roadmap, research companion, and historical
  locations.
- [x] Trim the public docs surface so `docs/` contains publication-safe docs and
  internal reverse-engineering evidence lives under `reverse-engineering/`.
- [x] Move the superseded public milestone planning surface under
  `docs/historical/` and keep active publication-safe docs focused on
  architecture, research, and current state.
- [x] Keep Swift source, script, and test files within the 550 LOC cleanup
  budget after the source/test split.
- [x] Move active public MXX source-contract docs out of the superseded
  `docs/milestones/` lane and into `docs/source-contracts/`.
- [x] Add active benchmark and source-contract indexes plus archive indexes for
  deprecated research and reverse-engineering notes.
- [x] Move the remaining superseded public milestone implementation-plan lane
  under `docs/historical/` and update the active public documentation indexes.
- [x] Move superseded M05/F12 report snapshots under
  `mac-port/historical/reports-2026-05-03/` and keep active reports under
  `mac-port/reports/`.
- [x] Add `scripts/export-release-candidate.sh` to stage an allowlisted source
  candidate outside the raw checkout and run the C12 hygiene scan before
  archive inspection.
- [x] Complete GOAL.md codewise closure with `GoalCodewiseClosureReport`,
  `goal-codewise-closure`, `goal-codewise-closure-run`,
  `validate-goal-codewise-closure-report`, required docs areas, and
  [reports/GOAL_CODEWISE_CLOSURE_2026-05-05.md](reports/GOAL_CODEWISE_CLOSURE_2026-05-05.md);
  keep the real-world verdict PARTIAL until measured evidence replaces the
  assumptions.
- [x] Add the GOAL.md runtime completion blocker audit with prompt-to-artifact
  checklist, local probe evidence, and exact field command templates in
  [reports/GOAL_RUNTIME_COMPLETION_BLOCKERS_2026-05-05.md](reports/GOAL_RUNTIME_COMPLETION_BLOCKERS_2026-05-05.md);
  keep the real-world verdict PARTIAL until hardware, route, video, lighting,
  signing, notarization, Gatekeeper, and clean-Mac evidence exists.
- [x] Rerun the full local release-readiness wrapper after the runtime blocker
  audit: sandboxed SwiftPM failed with the known `sandbox-exec` manifest issue,
  then the unsandboxed `bash scripts/verify-release-readiness.sh` passed docs,
  shellcheck, release hygiene, `swift build`, `swift test` with 742 tests,
  GOAL codewise closure, and release-readiness CLI probes while preserving the
  manual hardware/signing/clean-Mac gates.

Resume here: inspect the staged release source candidate, validate the
GOAL.md codewise closure CLI surface, close license/notices
and reviewer decisions, or answer Q001 in [OPEN_QUESTIONS.md](OPEN_QUESTIONS.md)
to close M01 fully, finish M03 by providing the physical analog loopback path and target
input/output device UID, continue G03 by wiring the measured RME callback owner,
or continue M05/G04/F11 by running the sender/receiver plus byte-exact
sender/looper on two Macs, recording direct-link packet age, UDP echo RTT, ICMP
RTT, traceroute hops, loss, jitter, DSCP, and packet capture, then validating
the G04 route-certification wrapper. Use F12 NAT-friendly mode only after raw
route evidence exists and keep relay fallback outside fastest-path closure. Run
the UDP forwarder only after direct traversal fails, mark it compatibility
evidence, and retain the launcher warning that it may degrade performance. Use
that stable route and accepted F02
realtime-engine proof for the M06 60-minute fixed-target drift/PLC run, measured
LoLa baseline comparison, and G05 certification wrapper, then M07
physical AoIP/PTP/WCRT evaluation and G06 certification wrapper, then use the
resulting baseline for the M08 Blackmagic/ATEM inventory plus AVFoundation fallback video-only run and audio-on/video-on measurement, M09
physical video transport stress, and M10 30-minute integrated headless A/V
stress before marking those milestones PASS. Use that baseline for M11 live
OSC cue-loop measurement and G08 ATEM read-only polling,
M12 bounded lighting handoff plus one-universe QLC+/OLA lighting probe, and M13
bounded runtime handoff plus launched app-vs-CLI metrics comparison, then M14 bounded recording handoff plus recording-on disk-pressure stress before marking M11, M12,
M13, or M14 PASS. Answer Q010 and run a signed/notarized clean-Mac field test
before marking M15 PASS. Keep G16 parity features deferred until G10 PASS and
explicit user promotion of one feature at a time. Use the F10 closure runner for
bounded PARTIAL handoffs only; do not mark faster-than-LoLa PASS until F01-F04
and the same-hardware LoLa baseline are measured.
Use [SOTA_2026_OPEN_QUESTION_MATRIX.md](SOTA_2026_OPEN_QUESTION_MATRIX.md)
before closing any later milestone.
