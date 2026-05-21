# Architecture And Flow Map

Date: 2026-05-20
Scope: source, docs, tests, scripts, and config inspected for runtime structure
before cleanup or refactor.
Verdict: PARTIAL

This map is descriptive, not a redesign plan. It records what the current
checkout exposes through code, docs, tests, scripts, and configuration. Where a
flow was not fully traced, it is marked `UNCLEAR`.

## Runtime Structure

Open LoLa is a macOS SwiftPM workspace with a separate Python compatibility
seed:

- `OpenLolaContracts`: shared verdict, report, run-mode, JSON, and RX-buffer
  contract types.
- `OpenLolaCore`: protocol, audio, video, network, connector, evidence,
  release, timing, support, and app-shell contract logic.
- `open-lola`: Swift CLI executable that routes commands to `OpenLolaCore`.
- `OpenLolaAppSupport`: SwiftUI/AppKit macOS operator shell and execution
  controller.
- `open-lola-app`: thin SwiftUI `@main` executable.
- `COpenLolaAtomics`, `COpus`, and `CJpegXSReference`: C bridge/vendor targets
  used by realtime rings and codec wrappers.
- `linux_connector`: Python LoLa compatibility seed and Windows/WSL lab helper
  area.
- `scripts` and the singular `script` directory: docs, release, parity, app
  bundle, and verification helpers.

`Package.swift` sets macOS 14 as the Swift platform, declares no external
SwiftPM package dependencies, links Apple media/UI frameworks into
`OpenLolaCore`, and includes test fixtures as SwiftPM resources.

## Dependency Boundaries

The main intended dependency direction is:

```text
open-lola CLI -> OpenLolaCore -> OpenLolaContracts
open-lola-app -> OpenLolaAppSupport -> OpenLolaCore -> OpenLolaContracts
OpenLolaCore -> COpenLolaAtomics / COpus / CJpegXSReference
scripts -> built CLI, SwiftPM, Python tools, Docker/native tools, app script
linux_connector -> Python stdlib asyncio/socket/subprocess plus its own modules
Tests -> OpenLolaCore, OpenLolaContracts, OpenLolaAppSupport, fixtures
```

Important boundaries:

- `OpenLolaContracts` is public report vocabulary. Raw values and JSON behavior
  are compatibility contracts.
- `OpenLolaCore` owns source-level runtime/report logic. CLI and app should
  call into it instead of duplicating protocol rules.
- `OpenLolaAppSupport` supervises CLI processes and report validation; it does
  not own realtime audio/video processing.
- `linux_connector` is not merged into SwiftPM packaging; it remains a Python
  compatibility seed included in source release candidates.
- Vendored codec/reference roots are not first-party refactor targets. The
  compiled subset is defined by `Package.swift`.

## Runtime Entry Points

| Entry point | Runtime role | Primary code | Contract risk |
|---|---|---|---|
| `.build/debug/open-lola <command>` | CLI for probes, reports, validators, and runtime sessions | `Sources/open-lola/main.swift`, `Sources/open-lola/Commands/**` | Command names, flags, output text, JSON paths, verdict lines |
| `.build/debug/open-lola-app` | macOS app executable | `Sources/open-lola-app-main/OpenLolaAppMain.swift` | App launch behavior and menu/window contracts |
| Staged `dist/OpenLoLa.app` | Verified app bundle | `script/build_and_run.sh` | Signing, bundle layout, accessibility/menu evidence |
| Python connector | LoLa compatibility seed CLI | `linux_connector/lola_connector/cli.py` | LoLa control/media compatibility, async runtime semantics |
| Release wrapper | Local/CI source gate | `scripts/verify-release-readiness.sh` | Source-gate truthfulness vs product readiness |
| Release candidate export | Public source artifact staging | `scripts/export-release-candidate.sh` | Allowlist, vendor trimming, forbidden artifact policy |
| Docs verifier | Public docs policy gate | `scripts/verify-docs.sh`, `scripts/verify_docs/main.py` | Link/path/topic/public-candidate policy |

## Important Domain Primitives

- Verdict and report contracts: `MeasurementVerdict`, `MeasurementMethodology`,
  `ReportRunMode`, `PrettyJSONCodable`, `JSONReportCoder`,
  `ReportValidatingArtifact`, `ReportValidatorSurface`, and
  `VerdictValidationPolicy`.
- Session/control primitives: `PeerIdentity`, `CapabilitySet`,
  `SessionProposal`, `SessionConfiguration`, `SessionControlMessage`,
  `SessionRuntimeState`, `SessionStateMachine`, and
  `PeerSessionLifecycleState`.
- Media/protocol primitives: `UdpPcmPacket`, `UdpPcmV2Packet`,
  `UdpMediaPacket`, `UdpMediaTransport`, `VideoTransportFragment`,
  `RTPPacket`, `AES67ST2110L24Transport`, `RxBufferProfile`,
  `DirectPeerSessionAudioTransport`, and `DirectPeerSessionVideoCompression`.
- Direct P2P runtime primitives: `PeerSessionRunner`,
  `DirectPeerSessionSocketRunner`, `DirectPeerSessionAVRunConfiguration`,
  `DirectPeerSessionAVRuntimeMetrics`, `DirectPeerRealtimeAudioGraph`, and
  `DirectAudioMediaRouter`.
- External connector primitives: `ExternalConnectorSessionConfiguration`,
  `ExternalConnectorLaunchPlan`, `ExternalConnectorSessionReport`,
  `LoLaCompatibility*`, `UltraGridCompatibility*`, `JackTrip*`, and
  `ExternalConnectorNmp*`.
- App primitives: `NativeAppShell*`, `AppExecutionController`,
  `AppExecutionPhase`, `AppValidationResult`, `AppRuntimeEvidenceScope`,
  `AppSettings`, `AppShellStoredDefaults`, and `AppStorageKeys`.
- Python connector primitives: `MediaSettings`, `ControlMessage`,
  `LolaConnector`, `Session`, `QuickConnResult`, `StatusCheckResult`,
  `LolaLinuxRuntime`, and `RuntimeStats`.

## Storage And File System

There is no database or migration system in this checkout.

Important file-system interactions:

- CLI report commands write pretty JSON to explicit `--output` paths, creating
  parent directories and using atomic writes in the top-level helper.
- Validator commands read JSON or packet fixtures through bounded readers and
  print a valid line plus `VERDICT: ...`.
- Direct P2P commands can write report JSON, ready files, receive-proof
  artifacts, and auto-evidence artifacts.
- The app writes execution logs under the user caches directory, writes
  two-peer run plans, writes session-token sidecars for runtime evidence, reads
  report artifacts before validation, and stores settings/defaults through app
  storage/defaults helpers.
- The app bundle verifier stages `dist/OpenLoLa.app` and can write launch
  evidence under `OPEN_LOLA_APP_LAUNCH_EVIDENCE_DIR`.
- Release candidate export writes outside the checkout and then runs release
  hygiene against the staged tree.
- Python connector process artifacts belong under `linux_connector` local
  artifact areas and must not become release proof without review.
- Tests consume JSON and hex fixtures under `Tests/OpenLolaCoreTests/Fixtures`.

## External APIs And Dependencies

- Apple APIs/frameworks: AppKit, SwiftUI, AVFoundation, CoreAudio,
  CoreGraphics, CoreImage, CoreMedia, CoreVideo, ImageIO, UniformTypeIdentifiers,
  Security, CryptoKit, Darwin sockets, Dispatch, and Foundation.
- C/vendor integrations: C11 atomics, Opus 1.5.2 through `COpus`, and JPEG XS
  reference code through `CJpegXSReference`.
- Python tooling: Python 3.11+, pytest, pytest-asyncio, ruff, mypy, and optional
  Scapy for packet-capture tools.
- Shell/tools: bash, SwiftPM, ShellCheck, Docker, codesign, osascript,
  screencapture, external UltraGrid/JackTrip tools when parity scripts are used.
- Network/protocol standards and compatibility lanes: UDP, RTP/AES67-shaped
  audio, LoLa control/media compatibility, UltraGrid/MVTP RTP, JackTrip packet
  modes, NAT/rendezvous/relay helpers, OSC/ATEM/lighting probes.

## Configuration Sources

- SwiftPM and build surface: `Package.swift`, target Info.plists, entitlements,
  and linked frameworks.
- CLI flags: parsed by command handlers and `KeyValueArgumentParser`; many
  flags are public contracts once documented or tested.
- Report fixtures and validators: JSON schemas are encoded in Swift types,
  fixtures, validator commands, and schema inventory.
- App settings: `AppSettings`, `AppShellStoredDefaults`, app storage keys,
  default report paths, executable path resolution, and operator state.
- Python connector CLI args: `argparse` in `linux_connector/lola_connector/cli.py`
  plus `pyproject.toml` dependency groups.
- Environment variables: app launch evidence, release candidate path, release
  hygiene live root, reference peer host, connector executable/image overrides,
  parity timing/port values, and Swift release-wrapper timeouts.
- Docs/release policy: release boundary docs, release manifest, hygiene policy
  file, docs verifier constants, and CI workflow.

## State Transitions

Session control state:

```text
idle -> helloReceived -> capabilitiesReceived -> proposed -> accepted
accepted/running/paused -> running on mediaStart
running -> paused on mediaPause
accepted/running/paused -> failed on error
accepted/running/paused/stopped -> stopped on shutdown
```

`SessionStateMachine` rejects invalid message ordering.

Direct peer lifecycle state:

```text
idle -> handshaking -> configured -> mediaStarting -> running
running -> recovering -> mediaStarting -> running
running/configured -> shuttingDown -> closed
any accepted/running/paused fatal error path -> failed
```

`PeerSessionRunner` owns this state and records media boundaries, shutdowns,
remote metrics, and control transcript entries.

App execution state:

```text
idle -> planWritten
idle/planWritten -> dryRunRunning or supervisorRunning
running -> stopRequested, runFinished, or runFailed
idle/report-ready -> validationRunning -> validationPassed or validationFailed
invalid start -> failedToStart
configuration change after evidence -> idle with validation invalidated
```

Unsupported app connector modes are selectable for planning, but the app launch
path currently throws an invalid command-field error for JackTrip and UltraGrid
execution.

Python connector state:

```text
no session -> status probe, listen, or connect
QuickConn ACK/accepted QuickConn -> Session
runtime start -> audio/video/control tasks and socket ownership
disconnect/control stop/runtime stop -> sockets/tasks/backends cleaned up
```

The Python runtime is documented in code as a single-event-loop object; its
events must not be mutated from another thread or loop.

## Error Handling Strategy

- CLI top-level catches thrown errors, writes `error: ...` to stderr, and exits
  1. Successful commands usually print a final `VERDICT: ...` line.
- Report validators decode JSON, call `validate()`, and return a deterministic
  valid line plus verdict line.
- Report builders generally keep unsupported, synthetic, missing, or external
  evidence as `PARTIAL` or `FAIL` instead of promoting to `PASS`.
- External connector sessions use structured `ExternalConnectorSessionError`
  cases, runtime-error fields, process result objects, and pass-evidence checks
  that reject dry-run or missing media evidence as `PASS`.
- Direct P2P transport throws for invalid packet counts, invalid hosts/ports,
  timeout bounds, duplicate ports, malformed media packets, unsupported payload
  shapes, accepted-stream mismatches, and missing required control messages.
- UDP media transport records malformed, lost, late, reordered, duplicate, clock
  skew, jitter, packetization, and depacketization metrics.
- App execution reports failed launches, failed validation, stale/missing report
  artifacts, unreadable evidence, partial runtime evidence, and process exit
  status in controller state and logs.
- Release scripts fail fast through shell helpers and explicit timeout wrappers.
- Python connector functions return structured status/quick-connect results for
  non-ack cases, raise for hard start/runtime errors, and count malformed media
  or control datagrams where the runtime can continue.

## Public Contracts That Must Not Break

- Verdict vocabulary and casing: `PASS`, `PARTIAL`, `FAIL`, and report raw
  values.
- CLI command names, hidden compatibility flags, public flags, help output where
  tested, final verdict line format, and validator output.
- Report schema field names, fixture names, schema inventory entries, and
  validators.
- Direct P2P session control JSON ordering, state-machine transitions, endpoint
  topology validation, UDP media envelope, payload type IDs, packet guards, and
  nested payload validation.
- `audioTransport` is canonical for Direct P2P audio transport. Legacy
  `audioCompression` / `--audio-compression` is an active hidden compatibility
  path until a future audit proves it can be removed.
- Split `inputDeviceUID` and `outputDeviceUID` are canonical realtime graph
  device fields. Legacy single-device `audioDeviceUID` remains a compatibility
  bridge for current callers.
- `direct-p2p-two-peer-report` and
  `validate-direct-p2p-two-peer-report` are the canonical Direct P2P two-peer
  aggregate CLI surfaces. `DirectPeerTwoPeerPrototypeReport` and the
  prototype-named command/validator remain compatibility paths.
- LoLa, UltraGrid/MVTP, and JackTrip connector report schemas, observed/missing
  evidence classes, and pass-evidence gates.
- App storage keys, settings defaults, generated CLI argument lists, UI action
  identifiers, accessibility/menu labels checked by app bundle probes, and
  session-token evidence checks.
- Release allowlist/exclude policy, vendor fence policy, generated artifact
  rejection, and raw-checkout-is-not-release boundary.
- Python connector control message names, default LoLa ports, media settings
  field names, packet sizes, and ASCII/OSC15 dialect behavior.

## Compatibility And Deprecation Layers

- Direct P2P legacy `audioCompression` / `--audio-compression` remains hidden
  compatibility for old CLI args, stored app defaults, initializer fallback,
  and report decoding.
- Direct P2P legacy `audioDeviceUID` remains a compatibility accessor/initializer
  for split input/output UID migration.
- Direct P2P prototype-named report/command is active compatibility terminology,
  not proof that the path is dead.
- LoLa compatibility paths include control UDP/TCP, raw-link media, UDP media,
  capture decoders, video payload providers, Windows/WSL lab helpers, and Python
  seed behavior.
- UltraGrid and JackTrip Docker/native helpers are reference/parity evidence
  tools, not primary product runtime paths.
- `archive` is trace evidence only; current public authority is the flat active
  docs surface.
- The singular `script` directory looks legacy but is active for app/CLI bundle
  assembly.

## Hidden Coupling

- CLI registry, `CLICommandInventory`, docs, tests, report schema inventory, and
  release-readiness probes must stay aligned.
- Report fixtures, validators, release reports, false-pass fixtures, and docs
  together enforce evidence boundaries; changing one without the others can
  create false success.
- App UI state is coupled to generated CLI command arguments and validator
  commands. A status badge can become false if report/session-token logic drifts.
- The app verifier and tests depend on literal menu/action/accessibility labels.
- Machine-readable CLI tests depend on a fixed binary path under `/private/tmp`
  in the current baseline.
- Release candidate export includes `docs`, so docs can break release hygiene
  even when source builds.
- Release candidate export includes `linux_connector`; Python source and docs
  are part of source-release posture.
- C bridge headers and Swift wrappers are ABI boundaries for realtime rings and
  codecs.
- `OpenLolaCore` reexports/aliases some `OpenLolaContracts` concepts; contract
  changes can ripple through CLI, app, tests, and fixtures.
- Parity scripts depend on environment variables, Docker image policy, local
  executables, ports, timing defaults, and the `external-connector-session-run`
  report schema.

## Major Flow Map

### CLI Dispatch And Report Validation

| Question | Current answer |
|---|---|
| What starts the flow? | User, script, CI, or app process invokes `.build/debug/open-lola <command>`. |
| Trusted inputs | Compiled Swift code, built-in report builders, checked-in fixtures when tests run. |
| Untrusted inputs | CLI args, output paths, report paths, packet/hex files, external process paths, peer hosts/ports. |
| Validation | Top-level command lookup; per-command arg parsing; bounded readers; report `validate()` methods; packet codec validation; `ReportValidatorSurface`. |
| State read | Local hardware inventory for device commands, config defaults, fixtures, external report files, environment through scripts. |
| State written | JSON reports to `--output`, stdout/stderr verdict text, optional debug/ready/evidence files. |
| What can fail? | Unknown command, invalid args, invalid ports/hosts, malformed JSON/packet data, report validation failure, file write failure, runtime socket/process failure. |
| How failure surfaces | Thrown errors become `error: ...` plus exit 1; validators fail before printing success; reports may also encode `FAIL` or `PARTIAL`. |
| Tests protecting it | `CLICommandInventoryTests`, `ReportSchemaInventoryTests`, `ReportFixtureValidationContractTests`, command-specific Swift tests, machine-readable surface tests. |
| Wrong-result risk | A command can run and print `PARTIAL` while being mistaken for runtime proof; inventory/help/schema drift can hide missing commands; stale fixed-path CLI binaries can make tests fail or pass against old code. |

### Direct P2P Control And Media Session

| Question | Current answer |
|---|---|
| What starts the flow? | `direct-p2p-localhost-smoke`, `direct-p2p-session-run`, app-generated supervisor commands, or two-peer local-run orchestration. |
| Trusted inputs | Source capability defaults, tested packet codecs, local runner configuration after parser validation. |
| Untrusted inputs | Peer IDs, local/remote hosts, ports, DSCP, media mode, audio/video device IDs, timing values, output paths, measured-evidence paths. |
| Validation | `KeyValueArgumentParser`, positive integer bounds, media-scoped flags, manual network shape, duplicate port checks, session negotiation, state-machine ordering, accepted stream validation, packet codec validation, report validation. |
| State read | Local capabilities, optional CoreAudio inventory, optional AVFoundation device state, existing evidence artifacts, run plan files. |
| State written | Session reports, receive-proof artifacts, ready files, auto-evidence artifacts, UDP sockets/media counters, optional app logs. |
| What can fail? | Invalid host/port/timeout, missing remote capabilities, invalid control sequence, socket bind/connect/read timeout, audio/video device missing, unsupported codec shape, unsafe raw video packet budget, malformed media, no useful media under quality policy. |
| How failure surfaces | Thrown `DirectPeerSessionSocketRunnerError` or AV runtime errors, CLI exit 1, `FAIL` reports for some harnesses, app validation failure or partial evidence state. |
| Tests protecting it | `SessionProtocolTests`, `SessionNegotiationTests`, `PeerSessionRunnerTests`, `PeerSessionRunnerLifecycleTests`, `PeerSessionAVSupportTests`, `PeerSessionAVFastestTests`, `DirectPeerSessionCLITests`, `UdpMediaTransportTests`, Direct P2P report tests. |
| Wrong-result risk | Localhost/synthetic runs can look healthy but are not physical peer proof; `structural` quality policy can complete without useful media; evidence attach/promote logic can overstate results if stale or wrong report paths are accepted. |

### UDP Media Transport And Packet Codecs

| Question | Current answer |
|---|---|
| What starts the flow? | Direct P2P sessions, UDP PCM route/loopback commands, media runners, packet validators, and tests. |
| Trusted inputs | Packet encoders, stream descriptions, known fixture bytes. |
| Untrusted inputs | Raw UDP datagrams, hex fixture files, peer timing/sequence values, DSCP and socket endpoints. |
| Validation | Magic/version/header guard, payload type, stream ID, timestamp, payload length, nested packet re-encode byte count, sequence/timestamp/stream match, max byte counts. |
| State read | Socket readiness, transport continuity state, recent sequence windows, jitter state. |
| State written | Socket send/receive, packet/loss/jitter/malformed metrics, receive continuity maps. |
| What can fail? | Malformed datagram, unsupported payload type/version, payload too large, closed socket, clock skew, reordered/lost/duplicate packets. |
| How failure surfaces | Throws packet/route errors, records malformed/loss/jitter metrics, direct runner reports stay `PARTIAL` unless measured pass gates close. |
| Tests protecting it | `UdpMediaTransportTests`, UDP PCM packet/route/loopback tests, Direct P2P support tests, packet fixture validation tests. |
| Wrong-result risk | Metrics can be misread as field quality if run on localhost; clock skew events and late/duplicate counters need interpretation; packet validation does not prove audio device playout. |

### External Connector Session Flow

| Question | Current answer |
|---|---|
| What starts the flow? | `external-connector-session-run`, app Windows LoLa mode, NMP plan/workflow commands, or parity scripts. |
| Trusted inputs | Native connector implementation, source references embedded in plans, tested parser defaults. |
| Untrusted inputs | Connector kind, role, peer host, executable paths, media/control modes, ports, codec/profile flags, Docker/native wrapper behavior, external endpoint responses. |
| Validation | Allowed flag set, duplicate/missing value checks, enum parsing, positive integer and port parsing, runtime input validation, connector/media compatibility checks, launch-plan source references, report pass-evidence validation. |
| State read | External executables or native connector paths, environment variables from parity scripts, optional local media devices, source references, existing output paths. |
| State written | External connector reports, process result prefixes, auxiliary process results, LoLa/UltraGrid/JackTrip media reports, runtime error fields. |
| What can fail? | Unsupported connector/mode, missing executable, process launch/cleanup/early exit, socket errors, LoLa control timeout/malformed messages, native UltraGrid/JackTrip runtime errors, missing media evidence. |
| How failure surfaces | Structured `ExternalConnectorSessionError`, `runtimeError`, `process`/auxiliary result fields, `FAIL` verdict for runtime errors, `PARTIAL` for dry-run/source-level evidence. |
| Tests protecting it | `ExternalConnectorSessionTests`, `ExternalConnectorAvMatrixTests`, `ExternalConnectorProcessGroupTests`, LoLa compatibility/control/media tests, UltraGrid tests, JackTrip tests, NMP plan/workflow tests, script pair tests. |
| Wrong-result risk | Source-level native connector evidence can be mistaken for reference-peer interoperability; dry runs intentionally cannot pass; local Docker/native parity is not field-route evidence; missing external tools produce skip/blocker states, not proof. |

### Native App Operator Flow

| Question | Current answer |
|---|---|
| What starts the flow? | Launching `open-lola-app` or staged app bundle; user menu/sidebar/settings actions. |
| Trusted inputs | App support code, app-shell contracts, default stored settings after validation. |
| Untrusted inputs | Stored defaults, user-edited paths/settings, imported remote inventory, generated report paths, selected executable path, external report contents. |
| Validation | App action disabled-reason policies, executable path resolution, direct peer settings validation, plan configuration checks, runtime evidence session-token checks, validator command execution, report loading/validation. |
| State read | Stored defaults, app settings, operator surface state, local/remote inventory, report files, session-token sidecars, process status, stdout/stderr logs. |
| State written | App state, run plans, logs, session tokens, previous evidence snapshots, status/phase/error fields, optional preview/window state. |
| What can fail? | Missing executable/report, stale report token, validation while running, unsupported connector mode, process launch failure, nonzero validator exit, partial report evidence, log open failure. |
| How failure surfaces | Disabled controls/help text, `lastError`, `errorLog`, status text, `AppExecutionPhase`, validation result, execution report, confirmation dialogs. |
| Tests protecting it | `NativeAppShellTests`, `NativeAppShellPolicyTests`, `NativeAppShellWindowsLoLaTests`, `NativeAppShellOpusCommandTests`, `AppShellBehaviorTests`, `AppShellSlice05Tests`, `AppExecutionControllerValidationTests`, app bundle script policy tests. |
| Wrong-result risk | UI can show optimistic state if decoupled from report evidence; stored settings can generate stale commands; unsupported JackTrip/UltraGrid modes are planning-only in app execution; screenshots/manual focus/contrast gates are not covered by source tests alone. |

### Python LoLa Connector Flow

| Question | Current answer |
|---|---|
| What starts the flow? | `python -m linux_connector.lola_connector.cli ...` with `selftest`, `status`, `listen`, or `connect`. |
| Trusted inputs | Python package modules, checked-in tests, generated memory/process backends. |
| Untrusted inputs | CLI args, remote IP/SID, media settings fields, process backend commands, UDP control/media datagrams. |
| Validation | `argparse` choices, numeric range checks, `MediaSettings.validate`, audio block size bounds, control datagram parse, remote peer/IP/SID checks, compatibility check on QuickConn accept. |
| State read | Active connector session, socket state, process backend streams, capture/playback/display backends, incoming UDP datagrams. |
| State written | Async session state, UDP sockets, audio/video/control runtime tasks, stats counters, subprocess I/O, stdout status/runtime stats. |
| What can fail? | Timeout, reject, malformed/wrong-peer/unexpected control datagrams, incompatible media settings, socket bind/send/receive errors, backend process cleanup errors, malformed media, runtime already started. |
| How failure surfaces | Structured `StatusCheckResult`/`QuickConnResult`, raised `TimeoutError`/`RuntimeError`, logger warnings, stats counters, CLI parser errors, printed runtime stats. |
| Tests protecting it | `linux_connector/tests/test_codec.py`, `test_runtime_contracts.py`, `test_process_runtime.py`, `test_process_backends.py`. |
| Wrong-result risk | Synthetic selftests and memory backends can pass without Windows/field proof; async tasks can continue while malformed packets are counted and ignored; process backend behavior is host-command dependent. |

### Release Readiness And Candidate Flow

| Question | Current answer |
|---|---|
| What starts the flow? | Local/CI call to `bash scripts/verify-release-readiness.sh`, candidate export, or release hygiene scan. |
| Trusted inputs | Checked-in scripts, release boundary docs, manifest, source tree, package manifest, CI workflow. |
| Untrusted inputs | Environment timeout overrides, candidate output parent, external tools, app launch environment, Docker/native peer environment. |
| Validation | Docs verifier, shellcheck, ruff, pytest, mypy, live hygiene scan, Swift build/test, CLI verdict probes, app launch probe, release allowlist and forbidden artifact scan. |
| State read | Source tree, docs, fixtures, `.gitignore`, release policy file, candidate tree, built CLI/app, manual gate docs. |
| State written | Temporary logs/reports under a temp dir, staged release candidate, staged app bundle/evidence when app probe runs. |
| What can fail? | Docs policy, lint/type errors, Swift build/test failures, timeout, app bundle launch/probe failure, missing candidate paths, forbidden artifacts, missing external tools, manual evidence blockers. |
| How failure surfaces | Shell `fail`, nonzero exit, last 80 timeout log lines, `HYGIENE_VERDICT: PASS` only on hygiene success, wrapper final `VERDICT: PARTIAL` when source gate passes but product remains blocked. |
| Tests protecting it | `VerificationToolingContractTests`, `ReleaseArtifactHygieneContractTests`, app bundle script tests, docs verifier tests, CI workflow. |
| Wrong-result risk | The wrapper can pass source gates while product readiness remains `PARTIAL`; release-candidate hygiene must be run on the exact staged tree; current baseline records a release-candidate docs-verifier failure from `docs/code-index.md`. |

### Documentation Verification Flow

| Question | Current answer |
|---|---|
| What starts the flow? | `bash scripts/verify-docs.sh`, `python3 -m scripts.verify_docs`, release wrapper, or release candidate hygiene. |
| Trusted inputs | Docs verifier Python modules and constants, active docs list, archive topology metadata. |
| Untrusted inputs | Markdown edits, relative links, backticked source paths, public/internal references, stale active docs. |
| Validation | Link existence outside code fences, backticked source path existence, required topics, ASCII for selected docs, archive topology, public planning/token rules, internal corpus checks when available. |
| State read | Active docs, archive/private context presence, source file paths, verifier constants. |
| State written | No intended repository writes; stdout/stderr result text. |
| What can fail? | Broken links, nonexistent backticked source paths, missing required topics, forbidden public tokens, stale active doc topology. |
| How failure surfaces | Lists each docs error and exits nonzero; public-candidate checks skip internal corpus checks when private/archive context is absent. |
| Tests protecting it | `DocsVerifierPolicyTests`, `VerificationToolingContractTests`, docs verifier source tests where present, release hygiene contract tests. |
| Wrong-result risk | Docs can pass live checkout checks but fail in a staged candidate if they mention paths excluded from the release allowlist; code fences are excluded from some checks. |

### Hardware, Control, Benchmark, And Report Harnesses

| Question | Current answer |
|---|---|
| What starts the flow? | Many CLI commands under network, audio, milestone, benchmark, integration, release, and control handlers. |
| Trusted inputs | Swift report types, fixture validators, source-level synthetic smokes. |
| Untrusted inputs | Hardware labels, route labels, capture notes, file paths, report paths, peer endpoints, external control device states. |
| Validation | Per-report `validate()` methods, nested report validation, false-pass fixture tests, schema inventory, command-specific parser checks. |
| State read | Optional hardware inventory, prior reports, fixtures, route/device metadata, local runtime probes. |
| State written | JSON reports and command stdout verdict lines. |
| What can fail? | Missing required measured evidence, invalid nested reports, malformed inputs, missing hardware/external devices, source-level synthetic pass attempts. |
| How failure surfaces | `PARTIAL`/`FAIL` reports, validator exceptions, CLI exit 1, release blocker lists. |
| Tests protecting it | Report-specific tests across `Tests/OpenLolaCoreTests`, fixture validation tests, release hardening/current evidence tests. |
| Wrong-result risk | Synthetic report coverage can be mistaken for field proof; some harnesses are source policy/inventory checks rather than runtime checks; exact runtime behavior for every harness was not fully traced in this pass. |

## Areas Not Fully Understood

- Full per-file control/data flow for every Swift report harness in
  `Sources/OpenLolaCore/Release`, `Benchmarks`, `Integration`, `Control`,
  `Timing`, and `Network/NAT` was not traced. They are represented as the
  hardware/control/benchmark/report harness flow above.
- Full UI rendering, minimum-window layout, contrast, keyboard focus, and every
  settings/sidebar interaction were not manually exercised.
- Physical RME/MADI, Blackmagic/ATEM, physical peer route, packet-capture,
  signing, notarization, Gatekeeper, clean-Mac, and reference-peer paths were
  not run.
- Docker/native UltraGrid and JackTrip script internals were sampled only
  through current docs, script names, and references. Environment-specific
  behavior remains `UNCLEAR` without live runs.
- Vendored Opus and JPEG XS internals were not semantically audited. Treat them
  as vendor/reference code unless a task explicitly targets bridge or license
  boundaries.
- Python connector backend implementations were not fully line-by-line traced.
  Process backend failure modes need a focused audit before runtime cleanup.
- NMP plan/preflight/workflow internals were not fully mapped beyond their
  command/config/report role and tests.

## Highest-Risk Boundaries

1. Direct P2P AV runtime loops, realtime audio graph callbacks, UDP media
   transport, and RX buffering.
2. External connector pass-evidence gates for LoLa, UltraGrid/MVTP, and
   JackTrip.
3. App execution validation and session-token evidence gating, because false UI
   success is user-visible.
4. Release candidate export/hygiene, because docs/source drift can produce a
   public artifact with missing or forbidden surfaces.
5. Python connector async runtime and process backends, because synthetic
   success can hide field incompatibility.
6. C bridge/vendor codec boundaries, because ABI, pointer, and memory-order
   mistakes can affect realtime paths.

## Recommended Next Audit Targets

1. Direct P2P AV runtime: trace state transitions, loop deadlines, teardown,
   packet loss handling, and quality policy from CLI args to final report.
2. App execution truthfulness: prove every start/stop/validate/status label
   reflects current report evidence and stale-token state.
3. External connector evidence gates: verify dry-run/source/local/reference/live
   evidence classes cannot be promoted accidentally.
4. Release-candidate docs path policy: fix or explicitly account for current
   baseline release-export verifier failures before publication work.
5. Python connector process backend lifecycle: audit subprocess cleanup, socket
   closure, malformed packet handling, and stats trustworthiness.

VERDICT: PARTIAL
