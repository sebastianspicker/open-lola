# Current State

Date: 2026-08-13
Status: experimental source alpha
Verdict: PARTIAL

Open LoLa is a macOS SwiftPM project with a separate Python Linux
compatibility connector. The current dirty integration tree passes its Swift,
Python, Rust-companion, documentation, shell, and first-party static gates.
Physical interoperability, field security, distribution, and publication
requirements remain open.

## Implemented surfaces

The Swift package defines:

- `OpenLolaCore`, which owns media, transport, connector, timing, platform,
  evidence, and validation logic;
- `OpenLolaContracts`, which contains framework-independent report contracts;
- `OpenLolaAppSupport`, which contains the SwiftUI application surface;
- `open-lola`, the command-line executable;
- `open-lola-app`, the application executable.

Implemented behavior includes:

- direct-peer session negotiation and UDP audio/video transport;
- Core Audio inventory and realtime audio paths;
- UDP PCM, Opus CELT low-delay, and AES67/ST 2110-30 audio modes;
- multichannel packetization, reassembly, receiver-local routing, drift
  handling, and receive-buffer policies;
- AVFoundation video capture, raw and JPEG XS transport, frame reassembly,
  timing, and multiple-stream staging;
- LoLa, UltraGrid/MVTP, and JackTrip connector models, runners, reports, and
  validators;
- a SwiftUI Signal Desk for configuration, guarded execution, status,
  diagnostics, and report review;
- report schema, fixture, command, source ownership, and release-boundary
  inventories.

Recent B10 source work adds retained LoLa terminal control, decoded receive
audio playout, UltraGrid raw-video preview, duration-bounded connector runs,
plan-bound fresh direct-peer preflight, shared LoLa wire fixtures, path
containment, bounded codesign capture, NAT/UDP/metrics/stream-admission
validation, observed reply endpoints and process trust in the Python connector,
and line-budget structural splits. These are source and localhost contracts,
not physical-route, reference-peer, audible, visible, or field evidence.

The Python package under `linux_connector/` provides:

- LoLa control exchange;
- synthetic bidirectional audio and video;
- status, listen, and connect modes;
- subprocess-backed audio and video adapters;
- packet inspection and WSL laboratory helpers.

## Verified local checks

The following checks were run on 2026-08-13 in the current dirty integration
checkout:

| Check | Result | Scope |
|---|---|---|
| Pinned Swift build, test, and TSan | Passed under Xcode 26.6 (17F113) and Swift 6.3.3 | Full serialized run passed 1,660 tests in 8 suites with 0 failures in 172.481 seconds. A separate fresh-scratch TSan run passed 20 tests with no findings (3 + 4 + 13 filtered tests). |
| Locked primary Python suite | 307 tests passed | Ruff, strict mypy, lock checks, documentation, source-documentation, and the connector CLI self-test passed. |
| Standalone Rust compatibility workspace | 252 passed, 0 failed, 3 intentionally ignored | Formatting, strict Clippy, the Windows target check, live Python wire-oracle comparison, and both Python-connector directions passed. The crate remains outside the curated source candidate and has no physical Windows-peer or hardware proof. |
| Documentation verification | Passed | Public links, source paths, required topics, and documentation policy. |
| Source documentation verification | Passed | First-party source documentation coverage. |
| Shell and PowerShell | Passed | Shell syntax, ShellCheck, PSScriptAnalyzer, and 5 Pester tests. |
| First-party Semgrep | B8 historical evidence only | It completed over 1,076 routed files without analyzer errors; it was not rerun as part of B10. |
| Tracked boundary | Passed | Current tracked-file policy. |
| Candidate-inspection hygiene | Passed for 1,585 allowlisted regular files | Aggregate SHA-256 `80942af4f8f1aaac7f77d521e6d706a18f46466ba36d6fdc373fd30d62ac9fe4`; explicitly `DIRTY_INSPECTION_ONLY` and nonpublishable. |
| Unified readiness aggregate and probes | Wrapper exited 0 in 215.65 seconds against that candidate | Source gate passed; product/runtime and overall readiness remained `PARTIAL`; the headless interactive-app probe was explicitly skipped. |
| Open-source readiness | `PARTIAL` with 6 blockers | Not publication approval. |
| Raw-checkout release hygiene | Failed at preserved local residue | Preserved ignored `.DS_Store` and dirty/user residue keep the integration checkout from being a release candidate. |
| Native app smoke | Partial | An external ad-hoc app passed strict codesign, Launch Services status 0, process, and visible 1280×840-window checks. Two clean launch attempts had `accessibilityWindows=0` and `frontmost=false`; screenshot capture also failed. No accessibility hierarchy is claimed. |

## Evidence limits

The checks above do not establish:

- physical two-Mac latency, jitter, loss, or stability;
- RME MADI, Blackmagic, ATEM, DeckLink, or UltraStudio operation;
- Windows LoLa, UltraGrid, or JackTrip reference-peer compatibility;
- native Linux low-latency capture or playback;
- authenticated peer identity, keyed integrity, or replay protection for
  direct-peer and LoLa field traffic;
- signed distribution, notarization, Gatekeeper acceptance, or clean-Mac
  installation;
- current green status of the pinned GitHub Actions jobs.

The checked-in Signal Desk images are reproducible offline view renders. The
current local app evidence establishes only bundle construction, strict
codesign, Launch Services status 0, process, and visible-window behavior. It
does not establish accessibility hierarchy, window-scoped visual capture, live
media, or measured latency.

## Platform status

| Surface | Current status | Required evidence not present |
|---|---|---|
| macOS CLI and app | Buildable source for macOS 14+; local ad-hoc bundle passes strict codesign, Launch Services, process, and visible-window checks | Accessibility hierarchy, window-scoped visual capture, exact-candidate CI, signing, notarization, Gatekeeper, and clean-Mac installation |
| Direct peer | Source, localhost runtime tests, reports, and validators | Physical two-peer route and measured media evidence |
| Linux connector | Python compatibility connector with process-backed local I/O and localhost self-test | For any Linux-production claim: native ALSA/JACK/PipeWire and V4L2/GStreamer backends plus target-host measurements |
| Rust compatibility workspace | Standalone code-only port with operator lifecycle, bundled resources, SSN input hardening, and Python-oracle checks | Closed Windows peer, Npcap, PortAudio/ASIO, XIMEA, and target-host measurements; it is outside the curated source candidate |
| LoLa compatibility | Control and media models, probes, and partial lab tooling | Reviewed reproducible reference-peer evidence |
| UltraGrid/MVTP | Native source paths and comparison scripts | Available peer, measured route, and field evidence |
| JackTrip | Native source paths and comparison scripts | JACK graph, available peer, and measured route |
| Lighting and control | OSC, sACN, Art-Net policy and report contracts | Isolated physical output and audio-impact measurements |

## Release blockers

Publication remains blocked because:

- [LICENSE](../LICENSE) grants no rights;
- [THIRD_PARTY_NOTICES.md](../THIRD_PARTY_NOTICES.md) is not a final
  redistribution approval;
- the JPEG XS reference software requires legal review;
- fixture provenance and independent source review are incomplete;
- no clean named revision has been approved for publication;
- direct-peer and LoLa traffic has no authenticated identity, keyed integrity,
  or replay protection;
- physical, packaging, and field evidence remains incomplete, as do native
  Linux backends if Linux production support is claimed.

The source exporter creates an inspection tree. It does not approve a release
or convert a dirty checkout into release provenance.

## Related documentation

- [../README.md](../README.md) for installation and common commands
- [source-contracts.md](source-contracts.md) for module boundaries
- [testing.md](testing.md) for the verification matrix
- [release-boundary.md](release-boundary.md) for repository policy
- [RELEASING.md](RELEASING.md) for candidate and approval steps
- [open-questions.md](open-questions.md) for missing physical inputs

VERDICT: PARTIAL
