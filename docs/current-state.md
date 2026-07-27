# Current State

Date: 2026-07-24
Status: experimental source alpha
Verdict: PARTIAL

Open LoLa is a macOS SwiftPM project with a separate Python Linux
compatibility connector. The source tree builds and its automated local tests
pass on the current host. Physical interoperability, distribution, and
publication requirements remain open.

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

The Python package under `linux_connector/` provides:

- LoLa control exchange;
- synthetic bidirectional audio and video;
- status, listen, and connect modes;
- subprocess-backed audio and video adapters;
- packet inspection and WSL laboratory helpers.

## Verified local checks

The following checks were run on 2026-07-24 in the current dirty integration
checkout:

| Check | Result | Scope |
|---|---|---|
| `swift build --disable-sandbox` | Passed | Current Swift source compiles with Swift 6.2.4 and Xcode 26.3. |
| `swift test --disable-sandbox --no-parallel` | 1,094 tests passed | Swift unit, contract, fixture, CLI, policy, socket, and runtime tests. |
| Python pytest | 147 tests passed with Python 3.11.14 and pytest 8.4.2 from an existing external environment | Linux connector behavior, outside the locked CI environment. |
| Strict mypy | Passed for 25 source files with locally installed mypy 2.3.0 | Secondary type-check evidence; CI pins mypy 1.14.1. |
| Documentation verification | Passed | Public links, source paths, required topics, and documentation policy. |
| Source documentation verification | Passed | First-party source documentation coverage. |
| Tracked-boundary and release-hygiene checks | Passed | Current index policy and live generated-residue scan. |
| ShellCheck | Passed for the repository shell scripts | Static shell analysis. |

The exact locked Python environment was not recreated offline because the
`ruff==0.15.20` wheel was not present in the local cache. Ruff 0.16.0 reported
50 lint findings in the broader dirty checkout. These results do not change the
runtime evidence classification.

## Evidence limits

The checks above do not establish:

- physical two-Mac latency, jitter, loss, or stability;
- RME MADI, Blackmagic, ATEM, DeckLink, or UltraStudio operation;
- Windows LoLa, UltraGrid, or JackTrip reference-peer compatibility;
- native Linux low-latency capture or playback;
- signed distribution, notarization, Gatekeeper acceptance, or clean-Mac
  installation;
- current green status of the pinned GitHub Actions jobs.

The checked-in Signal Desk images are reproducible offline view renders. They
do not establish app launch, accessibility, live media, or measured latency.

## Platform status

| Surface | Current status | Required evidence not present |
|---|---|---|
| macOS CLI and app | Buildable source for macOS 14+; local ad-hoc bundle helper exists | Exact-candidate CI, signing, notarization, Gatekeeper, and clean-Mac installation |
| Direct peer | Source, localhost runtime tests, reports, and validators | Physical two-peer route and measured media evidence |
| Linux connector | Python compatibility prototype and localhost self-test | Native low-latency backends and target-host measurements |
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
- physical, security, packaging, and field evidence remains incomplete.

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
