# Architecture And Flow Map

Date: 2026-05-16
Scope: current source, docs, tests, scripts, and manifests in this checkout.
Verdict: PARTIAL because real hardware/runtime/release evidence remains outside
this source map.

This document maps runtime structure and contracts that future cleanup must not
break. It does not infer product intent beyond code, docs, tests, configuration,
and names. Items marked UNCLEAR need a focused source/runtime audit before
refactor.

## Runtime Structure

Primary products from `Package.swift`:

- `OpenLolaContracts`: small shared Swift contract target for measurement
  verdicts, methodology, pretty JSON, and RX-buffer profile names.
- `OpenLolaCore`: main macOS-only Swift library. It links AppKit,
  AVFoundation, CoreAudio, CoreGraphics, CoreImage, ImageIO, CoreMedia, and
  UniformTypeIdentifiers, plus local C targets.
- `open-lola`: CLI executable. It dispatches commands from
  `Sources/open-lola/main.swift` and `Sources/open-lola/Commands/**`.
- `OpenLolaAppSupport`: SwiftUI/AppKit app support target under
  `Sources/open-lola-app/`.
- `open-lola-app`: app executable entry point in
  `Sources/open-lola-app-main/OpenLolaAppMain.swift`.
- `COpenLolaAtomics`, `COpus`, and `CJpegXSReference`: local C targets used by
  realtime rings and codec/reference bridge paths.

The Python `linux_connector/` package is separate from SwiftPM packaging. It is
the Linux/WSL LoLa compatibility seed and is run with
`python -m linux_connector.lola_connector.cli`.

Important directories:

- `Sources/OpenLolaCore/Audio`: Core Audio inventory, realtime graph,
  MADI/RME, routing, packet handoff, and audio codecs.
- `Sources/OpenLolaCore/Network`: UDP packet contracts, direct P2P, NAT,
  diagnostics, RTP/AES67, and route reports.
- `Sources/OpenLolaCore/Connectors`: external connector process planning and
  LoLa compatibility control/media code.
- `Sources/OpenLolaCore/Video`: AVFoundation capture, raw/JPEG XS transport,
  reassembly, preview/rendering, and video reports.
- `Sources/OpenLolaCore/Control`: OSC cue, ATEM read-only, and lighting gate
  report/control surfaces.
- `Sources/OpenLolaCore/Integration`: aggregate A/V and profile reports.
- `Sources/OpenLolaCore/Release`: release, packaging, recording, field proof,
  and current evidence/status report surfaces.
- `Sources/open-lola-app`: operator console UI, settings, execution controller,
  report views, inventory, preview, and app storage.
- `linux_connector/lola_connector`: Python protocol, media, connector,
  runtime, backends, raw Ethernet helper, CLI, and self-test modules.
- `scripts`: verification, release hygiene/export, Docker/native connector
  helper scripts.

## Dependency Boundaries

- `OpenLolaCore` is the domain/runtime library. CLI and app should call into it
  rather than duplicating protocol/report logic.
- `open-lola` owns argument parsing and process-facing command dispatch.
  Runtime validation belongs in core configuration/report types where possible.
- `open-lola-app` is a UI and process supervisor. It derives commands from core
  app-shell/operator state and launches `open-lola`; it must not invent runtime
  success without validated report artifacts.
- `OpenLolaContracts` must remain framework-light and shared-contract oriented.
- `linux_connector` is authoritative for the validated Linux LoLa seed but is
  not merged into SwiftPM. Drift between Python LoLa facts and Swift LoLa
  compatibility code is high risk.
- Vendored codec/reference roots are fenced by the release manifest. Routine
  cleanup should not edit upstream Opus or JPEG XS internals; local bridge code
  is the allowed integration point.
- Release scripts are policy gates, not runtime code. They encode public
  release boundaries and generated-output rules.

## Domain Primitives

- Verdicts: `MeasurementVerdict` uses `pass`, `partial`, `fail`, and `notRun`.
  Many reports validate that `PASS` requires physical or attached evidence.
- Reports: Swift report types conform to `ReportValidatingArtifact`, decode
  from JSON, validate fields/pass policy, then print `VERDICT: ...`.
- Capabilities/session: `CapabilitySet`, `SessionProposal`,
  `SessionConfiguration`, `SessionControlMessage`, and `SessionStateMachine`
  define direct peer control contracts.
- Latency/RX policy: `SessionLatencyProfile`,
  `SessionLatencyProfilePolicy`, and `RxBufferProfile` bind profiles to
  allowed RX buffering and video pressure behavior.
- Audio/video stream contracts: `AudioStreamDescription`,
  `VideoStreamDescription`, `UdpPcmPacket`, `UdpPcmV2Packet`,
  `UdpMediaPacket`, `VideoTransportFragment`, LoLa media packets, RTP L24, and
  Opus/JPEG XS bridge surfaces.
- Evidence primitives: hardware identity, route identity, timing/loss metrics,
  DSCP/PTP/capture artifacts, live device inventories, and report validators.
- App primitives: `NativeAppShellOperatorPrototypeState`,
  `NativeAppShellExecutionSettings`, `NativeAppShellSurfaceContract`,
  `AppExecutionPhase`, and `AppSessionState`.
- Python connector primitives: `MediaSettings`, `ControlMessage`, `Session`,
  `RuntimeStats`, LoLa `Fragment`, `VideoPrelude`, `AudioFrame`, `VideoFrame`,
  and `MediaReassembler`.

## Configuration Sources

- Swift CLI: command-line flags parsed in `Sources/open-lola/main.swift` and
  command support files.
- Swift app: `UserDefaults` via `AppSettings` and `AppShellStoredDefaults`;
  `SceneStorage` stores the selected UI section.
- Swift runtime/app paths: operator-entered executable/report/plan paths,
  cache-directory log paths, and optional ready/evidence artifact paths.
- Python connector: argparse flags in `linux_connector/lola_connector/cli.py`.
- Scripts: environment variables such as `OPEN_LOLA_RELEASE_CANDIDATE`,
  `OPEN_LOLA_RELEASE_HYGIENE_LIVE_ROOT`, `OPEN_LOLA_BIN`,
  `OPEN_LOLA_OUTPUT_DIR`, connector Docker/native image and port variables,
  and release-readiness app-launch evidence variables.
- SwiftPM/package config: `Package.swift` target lists, linked Apple
  frameworks, C target source lists, entitlements, and Info.plist link flags.
- CI: `.github/workflows/release-readiness.yml` runs the release wrapper and
  selected TSan smokes.
- Docker/WSL lab: `linux_connector/env/compose.yaml` and helper scripts.

## Storage And File-System Interactions

- CLI report commands write JSON atomically through `writeJSONData`, creating
  parent directories.
- Validators and aggregate commands read JSON through `BoundedFileReader` and
  `ReportValidatingArtifact.readValidated`, with a default 100 MB limit.
- Direct P2P commands may write ready files, receive-proof artifacts, auto
  evidence artifacts, and supervisor reports.
- App execution writes stdout/stderr logs under the user cache directory and
  may write direct-peer plan artifacts.
- Recording/packaging/release flows write artifact manifests, package
  directories, recording side-lane files, release reports, and staged release
  candidates.
- Release export must stage outside the repository and removes generated
  metadata/cache files from the candidate.
- Python connector stores no database state. It uses sockets, process pipes,
  memory sinks, optional subprocess backends, and local docs/process artifacts.
- There is no database or migration system in this checkout.

## External APIs And Third-Party Dependencies

- Apple frameworks: CoreAudio, AVFoundation, AppKit, SwiftUI, CoreGraphics,
  CoreImage, ImageIO, CoreMedia, UniformTypeIdentifiers.
- Darwin/POSIX: UDP sockets, `posix_spawn`, process groups, `waitpid`, signals,
  kqueue, file descriptors, and local process execution.
- Vendored C: Opus 1.5.2 and JPEG XS reference code selected by `Package.swift`.
- External connector tools: LoLa compatibility peer, UltraGrid/MVTP, JackTrip,
  Docker helpers, WSL/Npcap relay, optional process media commands.
- Python standard library: asyncio, socket, subprocess/process I/O, struct,
  argparse, logging. Dev tools are pytest, pytest-asyncio, ruff, and mypy.
- Optional Python pcap dependency: scapy, declared under `pyproject.toml`
  optional `pcap`.

## State Transitions

Direct peer control state is explicit:

```text
idle -> helloReceived -> capabilitiesReceived -> proposed -> accepted
accepted/running/paused --audioMetadata/metrics--> same state
accepted/running/paused --mediaStart--> running
running --mediaPause--> paused
helloReceived/capabilitiesReceived/proposed/accepted/running/paused --reject/error--> failed
any --shutdown--> stopped
```

App execution state is explicit in `AppExecutionPhase`:

```text
idle -> planWritten -> dryRunRunning|supervisorRunning -> runFinished|runFailed|stopRequested
idle/finished -> validationRunning -> validationPassed|validationFailed
blocked starts -> failedToStart
```

Python LoLa runtime state is implicit in asyncio tasks and events:

- `start()` requires an active connector session and no existing tasks.
- `_audio_tx_enabled` and `_video_tx_enabled` gate TX loops.
- `MESG_SEND_AUDIO_SIGNAL` enables prepared TX; `MESG_STOP_AUDIO_SIGNAL`
  disables it.
- `MESG_DISCONNECT` sets the stop event.
- `stop()` cancels tasks, closes sockets, closes backends, and raises an
  `ExceptionGroup` if task cleanup fails.

UNCLEAR: several Swift realtime/audio/video loops have internal state spread
across helpers. Their complete transition map needs a focused runtime audit
before broad simplification.

## Error Handling Strategy

- Swift CLI commands throw typed or generic errors. Top-level CLI catches,
  prints `error: ...` to stderr, and exits with status 1.
- Report validators throw validation errors and only print valid/verdict lines
  after successful decode and validation.
- Runtime report builders often convert runtime failures into explicit report
  fields with `FAIL` or `PARTIAL` rather than silently claiming success.
- App execution records `lastError`, `errorLog`, status text, phase, exit code,
  validation exit code, and report paths. Validation is blocked while a run is
  active or when the report artifact is missing.
- External connector process runners capture stdout/stderr prefixes, terminate
  process groups after bounded durations, and surface launch/early-exit errors
  in reports.
- Python connector ignores malformed/unrecognized UDP control/media packets in
  live receive loops after logging/counting them, but raises on invalid local
  configuration, missing sessions, failed startup cleanup, or bounded parser
  errors where callers need failure.

## Compatibility And Deprecation Layers

- LoLa compatibility is explicit under `Sources/OpenLolaCore/Connectors/LoLa`
  and `linux_connector/`. It includes recovered control messages, port facts,
  padded audio payloads, video prelude offsets, raw-link and UDP media paths,
  UDP/TCP control variants, and Windows LoLa probe commands.
- Python `linux_connector` is a compatibility seed, not the native Swift
  runtime path.
- The Swift app has explicit `windowsLoLa` mode and direct Mac peer mode.
- `DirectPeerSessionAudioTransport.legacyAudioCompression` preserves hidden
  legacy audio-compression mapping for migration; do not expand it without
  evidence.
- OSC15 support exists in Python control parsing/building for older LoLa/tester
  dialects.
- Archived docs are historical trace evidence only. Current implementation work
  should use live docs and source.

## Public Contracts That Must Not Break

- CLI command names and machine-readable `VERDICT: ...` output.
- JSON report schemas, validators, and `ReportValidatingArtifact` behavior.
- `MeasurementVerdict` values and PASS/PARTIAL semantics.
- Direct peer session protocol messages, state-machine transitions, capability
  negotiation, latency profile/RX-buffer policy combinations, and MTU bounds.
- UDP PCM v1/v2 packet layout, LoLa media/control packet layout, RTP L24/AES67
  packet contracts, Opus and JPEG XS bridge behavior.
- LoLa compatibility facts documented under `linux_connector/docs/` and mirrored
  by Swift LoLa compatibility tests.
- App-shell surface actions, settings keys, command generation, and report-backed
  UI truthfulness.
- Release allowlist/exclusion policy, vendor fence, generated-output hygiene,
  and release-candidate staging outside the raw checkout.
- Test fixtures and report fixture expectations under `Tests/OpenLolaCoreTests/Fixtures`.

## Hidden Coupling

- CLI inventory tests couple command names, docs, and dispatch behavior.
- App menu actions must match `NativeAppShellSurfaceContract` action IDs and
  `AppMenuActionHandling.handledActionIDs`.
- App validation truth depends on report files written by the CLI at configured
  paths; stale or missing paths can make the UI look idle but not valid.
- Direct peer AV profile names map to exact RX-buffer policy combinations and
  raw video fragment budgets.
- Swift LoLa compatibility and Python Linux connector must agree on ports,
  media settings, frame IDs, padding, prelude offsets, and control dialects.
- Release hygiene depends on `.gitignore`, release manifest text,
  `scripts/release-boundary-policy.txt`, `THIRD_PARTY_NOTICES.md`, and export
  script allowlists staying aligned.
- Source ownership/inventory tests can fail when files move even if runtime
  behavior is unchanged.
- SwiftPM package target source lists fence vendored C code; changing vendor
  paths has build, notice, and release-hygiene effects.

## Major Flows

### 1. CLI Dispatch And Report Commands

- Starts with: `open-lola <command> ...`.
- Trusted inputs: none from CLI arguments; paths, ports, hosts, report files,
  and flags are untrusted.
- Validation: command-specific parsers reject unknown, duplicate, missing, and
  malformed arguments; reports call `validate()` before writing or accepting.
- Reads: CLI args, JSON reports, packet fixture files, current time, host
  inventory for selected commands.
- Writes: JSON reports, debug traces, ready/evidence artifacts, stdout/stderr.
- Can fail: bad args, invalid ports/paths, oversized files, malformed JSON,
  report validation, socket/process/device errors.
- Failure surfaced: thrown error reaches top-level `error: ...` and exit 1;
  some runtime commands write `FAIL`/`PARTIAL` reports before returning.
- Tests: `CLICommandInventoryTests`, command-specific tests,
  `ReportValidatorSurfaceTests`, validation/report fixture tests.
- Wrong-result risk: a command can produce a structurally valid `PARTIAL`
  report that operators misread as product success; validators must keep PASS
  gates strict.

### 2. Report Validation And Evidence Aggregation

- Starts with: `validate-*` commands, aggregate report commands, app validation,
  release-readiness probes, or tests.
- Trusted inputs: report schemas from source; external report files are
  untrusted.
- Validation: bounded file read, JSON decode, report-specific `validate()`,
  pass-policy checks, subordinate report validation.
- Reads: JSON report files and fixture files.
- Writes: validation console output; aggregate commands write new JSON reports.
- Can fail: missing files, oversized files, decode errors, invalid fields,
  subordinate `FAIL`/`PARTIAL`, missing physical artifacts.
- Failure surfaced: validation throws; CLI exits nonzero; app records validation
  failure and incomplete evidence.
- Tests: report fixture tests, validator tests, release/field/packaging tests,
  current evidence matrix tests.
- Wrong-result risk: aggregate reports can hide subordinate partial evidence if
  pass rules are loosened or if synthetic fixtures are promoted as physical
  evidence.

### 3. Direct P2P Audio Session

- Starts with: `direct-p2p-session-run` in audio mode or localhost smoke.
- Trusted inputs: local generated defaults and validated configurations only;
  remote UDP/control traffic is untrusted.
- Validation: manual host/port shape, packet count, channel count, timeout,
  session capability negotiation, expected control source checks, report
  validation.
- Reads: CLI args, local network sockets, current time, optional measured
  evidence paths.
- Writes: session report JSON, ready/evidence artifacts, UDP control/media
  datagrams.
- Can fail: bind errors, invalid hosts, duplicate ports, timeouts, unexpected
  control source, missing handshake messages, packet loss, invalid evidence.
- Failure surfaced: thrown errors for runtime failure; report validation rejects
  false PASS.
- Tests: `DirectPeerSessionCLITests`, `PeerSessionRunnerTests`,
  `PeerSessionRunnerLifecycleTests`, `SessionProtocolTests`,
  `SessionNegotiationTests`, `DirectPeerSessionReportAVPassTests`.
- Wrong-result risk: localhost or same-host socket success can be mistaken for
  physical two-Mac evidence; PASS requires physical measured artifacts.

### 4. Direct P2P Audio/Video Session

- Starts with: `direct-p2p-session-run --media audio-video`.
- Trusted inputs: none from CLI; explicit device UIDs, video device ID,
  dimensions, ports, AV profile, RX-buffer profile, and media source mode are
  untrusted until validated.
- Validation: AV profile/RX-buffer policy resolution, raw video fragment
  budget, manual network shape, audio/video device fields, pixel format,
  frame rate, Opus/AES67 shape, production CoreAudio preflight, accepted stream
  matching, useful-media policy, report PASS evidence.
- Reads: CoreAudio inventory for production mode, AVFoundation/CoreAudio media,
  UDP sockets, current time, optional SDP/evidence files.
- Writes: UDP control/audio/video/metrics, reports, receive-proof artifacts,
  optional SDP/evidence artifacts.
- Can fail: unsupported profile combination, unsafe raw packet budget, missing
  devices, AVFoundation permission/device errors, audio graph preflight, no
  useful media moved, accepted stream mismatch, socket failures.
- Failure surfaced: throws runtime errors; report validation prevents PASS when
  production media/evidence is missing.
- Tests: `DirectPeerSessionAVRXBufferProfileTests`,
  `DirectPeerRealtimeAudioGraphTests`, `DirectPeerRealtimeAudioGraphRxBufferingTests`,
  `PeerSessionAVFastestTests`, `PeerSessionAVSupportTests`,
  `VideoTransportRunnerTests`, `AVTimestampAlignmentTests`.
- Wrong-result risk: synthetic fixture media can exercise structure without
  proving device I/O, AV sync, preview, or physical packet timing.

### 5. UDP PCM Route And Loopback

- Starts with: `udp-pcm-send-once`, `udp-pcm-receive-once`,
  `udp-pcm-route-run`, `udp-pcm-loopback-run`, and related smokes/validators.
- Trusted inputs: no network packets or CLI flags are trusted.
- Validation: port parsing, packet decode, route report validation, session-pair
  validation, debug-traced failure handling.
- Reads: CLI args, UDP sockets, packet fixture files, route report files.
- Writes: UDP packets, route/loopback reports, optional debug traces.
- Can fail: invalid packet bytes, bind/send/receive errors, route timeout,
  byte mismatch, malformed report pairs.
- Failure surfaced: thrown errors, `loopback run failed: ...`, debug traces,
  report verdicts.
- Tests: `UdpPcmPacketTests`, `UdpPcmV2PacketTests`,
  `UdpPcmLoopbackLatencyTests`, `UdpPcmRouteReportTests`,
  `UdpMediaTransportTests`.
- Wrong-result risk: local loopback validates serialization/timing shape but
  not physical route behavior, DSCP, PTP, jitter, or loss under real load.

### 6. MADI/RME And Realtime Audio

- Starts with: MADI synthetic smokes, `madi-full-duplex-run`,
  audio-loopback commands, direct AV production mode, and realtime audio
  synthetic smokes.
- Trusted inputs: device UIDs, channel counts, sample format, route metadata,
  and runtime metrics are untrusted until captured/validated.
- Validation: channel/sample/rate/frame counts, RX-buffer profile, receiver mix,
  CoreAudio inventory/preflight, report validators, fastest-path PASS policy.
- Reads: CoreAudio devices, UDP sockets, CLI flags, report files.
- Writes: runtime reports, UDP media, packet handoff metrics.
- Can fail: device not found, unsupported buffer size, callback timing, socket
  loss, drift, underrun/overrun, invalid channel maps.
- Failure surfaced: report validators, runtime errors, partial blocker reports.
- Tests: `MadiFullDuplexSessionTests`, `MadiReceiveTests`,
  `MadiTransmitTests`, `RealtimeAudioEngineTests`,
  `RealtimeAudioPacketHandoffTests`, `RmeFastestAudioPathTests`.
- Wrong-result risk: source-level and synthetic smokes do not prove RME/MADI
  hardware visibility or realtime callback safety on target hardware.

### 7. Video Capture, Transport, And Preview

- Starts with: `video-capture-inventory`, `video-capture-run`,
  `video-transport-run`, direct AV, app local preview, and synthetic smokes.
- Trusted inputs: video device IDs, dimensions, pixel formats, frame rate,
  compression mode, and raw frame data are untrusted.
- Validation: AVFoundation inventory/report validation, geometry sizing,
  packet-size checks, reassembly checks, drop/degrade policy, report PASS rules.
- Reads: AVFoundation devices/permissions, raw/JPEG XS frame sources, UDP
  packets, capture/report files.
- Writes: capture/transport reports, UDP video fragments, preview submissions.
- Can fail: denied camera permission, missing device, unsupported pixel format,
  unsafe packet budget, fragment loss/reorder/duplicates, render deadlines.
- Failure surfaced: validation errors, partial/fail reports, app preview state.
- Tests: `VideoCaptureReportTests`, `VideoTransportReportTests`,
  `VideoTransportRunnerTests`, `BlackmagicCaptureTransmitTests`,
  `BlackmagicReceiveRenderTests`, `MultiVideoTransportTests`.
- Wrong-result risk: rendered/transported synthetic frames can pass source
  contracts while real capture permissions, device timing, and audio-impact
  behavior remain unproven.

### 8. LoLa Compatibility Connector

- Starts with: Swift `external-connector-session-run --connector lola`,
  LoLa raw/UDP media commands, capture decode commands, or Python
  `linux_connector` CLI modes.
- Trusted inputs: none from peer control/media packets; recovered protocol
  facts are treated as compatibility-lane facts.
- Validation: CLI bounds, connector kind/role/media/control mode, port bounds,
  LoLa session ID, peer-required-for-TX, media shape, control parsing,
  frame/reassembly limits, report validation.
- Reads: UDP/TCP control, UDP media, optional raw-link parameters, AVFoundation
  live source, CoreAudio live bridge, pcap/capture files.
- Writes: control/media datagrams, compatibility reports, synthetic captures,
  runtime stats.
- Can fail: QuickConn timeout/reject, malformed control, media timeout,
  zero decoded inbound frames, socket errors, unsupported raw-link connector,
  payload grammar mismatch.
- Failure surfaced: Swift reports with `runtimeError` and FAIL/PARTIAL;
  Python raises, logs malformed packets, or prints status/runtime stats.
- Tests: `LoLaCompatibility*Tests`, `ExternalConnectorLoLaCompatibilityTests`,
  `ExternalConnectorLoLaMediaEvidenceTests`, Python `test_codec.py` and
  `test_runtime_contracts.py`.
- Wrong-result risk: outbound generated AV or Windows-visible status does not
  prove inbound Windows media decode or byte-for-byte LoLa interoperability.

### 9. External Process Connectors And NMP Workflow

- Starts with: `external-connector-*` commands, UltraGrid/JackTrip scripts,
  Docker/native helper scripts.
- Trusted inputs: executable paths, command args, environment variables,
  endpoint plans, and process output are untrusted.
- Validation: connector kind, required executable, media-mode support, source
  references, Docker image policy scripts, NMP plan/preflight/report validation.
- Reads: CLI args, environment, filesystem executable paths, subordinate
  reports, process stdout/stderr.
- Writes: plan/preflight/endpoint/workflow JSON reports, process logs,
  Docker/native helper outputs.
- Can fail: missing executable, mutable/latest image policy, process launch,
  early exit, timeout, auxiliary process mismatch, unsupported media mode.
- Failure surfaced: report `runtimeError`, process result fields, nonzero
  script/CLI exit.
- Tests: `ExternalConnector*Tests`, `VerificationTooling*Tests`,
  `ReleaseArtifactHygieneContractTests`.
- Wrong-result risk: a process can launch and terminate cleanly without proving
  audio/video endpoint interoperability or latency parity.

### 10. Native App Operator Console

- Starts with: launching `open-lola-app` or app menu/actions.
- Trusted inputs: no user-entered settings, executable paths, report paths, or
  imported inventories are trusted.
- Validation: operator state command generation, execution arming, plan write,
  validation readiness, report existence and report validation.
- Reads: `UserDefaults`, SceneStorage, cache logs, local media inventory,
  report files, executable paths.
- Writes: `UserDefaults`, app cache logs, plan artifacts, command intent/state,
  preview state.
- Can fail: invalid paths, missing executable, failed plan write, process
  launch failure, missing report, validation failure, stale app state.
- Failure surfaced: app status, phase, `lastError`, error log, disabled menu
  actions, validation phase.
- Tests: `AppShellBehaviorTests`, `AppShellSlice05Tests`,
  `NativeAppShell*Tests`, `MachineReadableSurfaceContractTests`.
- Wrong-result risk: UI can show a comfortable state from cached/synthetic
  reports unless it remains tied to validated runtime artifacts.

### 11. Release, Packaging, Recording, And Field Proof

- Starts with: `recording-session-run`, `packaging-field-run`,
  `field-readiness-run`, `field-runtime-proof-run`,
  `release-hardening-run`, `open-source-release-readiness-run`, release export,
  and release readiness scripts.
- Trusted inputs: none from reports, artifact paths, signing state, or
  generated packages until validated.
- Validation: subordinate report validation, artifact manifests, generated
  residue scan, release allowlist/exclusion policy, vendor fence, PASS evidence
  rules.
- Reads: report files, docs/manifests, release-boundary policy, `.gitignore`,
  notices, source tree, signing/package evidence paths.
- Writes: aggregate reports, recording/package artifacts, release candidates
  outside the repo, hygiene output.
- Can fail: missing subordinate reports, partial gates, generated residue,
  forbidden release paths, missing signing/notarization/Gatekeeper evidence,
  docs verifier failure.
- Failure surfaced: report verdicts, script `fail`, nonzero release wrapper.
- Tests: `PackagingFieldTestTests`, `RecordingSession*Tests`,
  `ReleaseHardeningTests`, `OpenSourceReleaseReadinessTests`,
  `ReleaseArtifactHygieneContractTests`.
- Wrong-result risk: source-release readiness reports are blockers, not
  publication approval; raw checkout must not be treated as a release artifact.

### 12. Linux Connector Runtime

- Starts with: `python -m linux_connector.lola_connector.cli` modes
  `selftest`, `status`, `listen`, and `connect`.
- Trusted inputs: CLI-local bounds after validation; Windows/peer control and
  media packets are untrusted.
- Validation: argparse choices, numeric ranges, media settings bounds, audio
  block size, LoLa control parser, media frame/fragment limits, compatible
  audio check on QuickConn.
- Reads: UDP control/media sockets, optional process audio/video commands,
  synthetic media sources.
- Writes: UDP control/media, runtime stats to stdout, subprocess stdin,
  memory sinks, logs.
- Can fail: invalid CLI values, socket bind errors, QuickConn/status timeout,
  incompatible media settings, malformed packets, runtime task cleanup errors,
  subprocess backend failures.
- Failure surfaced: Python exceptions, argparse errors, logs, runtime stats,
  status_ack output.
- Tests: `linux_connector/tests/test_codec.py`,
  `test_process_runtime.py`, `test_runtime_contracts.py`.
- Wrong-result risk: Python compatibility success is not native Swift success;
  WSL/timer/process behavior can differ from production Linux devices.

## Not Fully Understood

- Complete internal state transitions of `DirectPeerRealtimeAudioGraph` and its
  Core Audio callback helpers.
- Full timing/concurrency behavior of `DirectPeerSessionAVAudioLoops`,
  `DirectPeerSessionAVVideoLoops`, and metrics services under real load.
- All subprocess/Docker helper failure modes outside the scripts sampled here.
- Exact clean-Mac, signing, notarization, Gatekeeper, and hardware evidence
  collection path; docs state the gates, but this map did not run them.
- Full UI visual/runtime behavior; this map read app state/command code but did
  not launch the app.

VERDICT: PARTIAL
