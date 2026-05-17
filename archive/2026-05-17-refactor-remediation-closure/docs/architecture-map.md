# Architecture And Flow Map

Date: 2026-05-17
Status: source-level map from live code/docs/tests inventory
Verdict: PARTIAL

This map describes the current runtime structure and contracts that future
cleanup must preserve. It is not a field-readiness claim. The product remains
`PARTIAL`: localhost, synthetic, built-in-device, archived, dry-run, or
placeholder evidence must not be promoted to product `PASS`.

## Runtime Structure

The Swift package is macOS-first. `Package.swift` exposes:

- `OpenLolaContracts`: shared report/verdict contracts.
- `OpenLolaCore`: runtime, protocols, reports, validators, audio/video/network
  paths, release harnesses, and C/vendor integrations.
- `OpenLolaAppSupport`: SwiftUI app support and app-side command execution.
- `open-lola`: CLI entry point.
- `open-lola-app`: macOS app executable.
- `COpenLolaAtomics`, `CJpegXSReference`, and `COpus`: C integration surfaces.

Dependency direction is intended to remain one-way:

```text
open-lola / open-lola-app
  -> OpenLolaAppSupport
  -> OpenLolaCore
  -> OpenLolaContracts + C/vendor targets
```

The Python Linux connector under `linux_connector/` is a separate compatibility
seed. It is not a SwiftPM target, but it is an active interoperability surface.
Scripts wrap Swift, Python, docs, shell, release, Docker/native connector, and
hygiene checks.

## Main Runtime Entry Points

- CLI: `.build/debug/open-lola <command>`, dispatched by
  `Sources/open-lola/main.swift`.
- App: `.build/debug/open-lola-app`, using `OpenLolaAppSupport` and
  `AppExecutionController` to build and run CLI commands.
- Python connector:
  `python -m linux_connector.lola_connector.cli ...`.
- Release and verification scripts: `scripts/verify-docs.sh`,
  `scripts/verify-release-readiness.sh`, `scripts/verify-release-hygiene.sh`,
  `scripts/export-release-candidate.sh`, and `script/build_and_run.sh`.
- Report validators: many CLI commands named `validate-*-report` and
  `validate-*`.

## Important Domain Primitives

- Verdicts and report contracts: `MeasurementVerdict`,
  `MeasurementMethodology`, `PrettyJSONCodable`, `ReportValidatingArtifact`,
  JSON report coders, and report validators.
- Runtime evidence: `Goal*Report`, `CurrentEvidenceStatusMatrixReport`,
  release/readiness reports, route reports, direct-peer reports, external
  connector reports, and native app shell reports.
- Network/session primitives: `PeerIdentity`, `SessionProtocol`,
  `SessionControlMessage`, `SessionNegotiation`, `SessionConfiguration`,
  `DirectPeerSession*`, `SessionNetworkEndpoint`, UDP PCM v1/v2 packets,
  direct media envelopes, video transport packets, and RX buffer profiles.
- Audio/video primitives: Core Audio inventory and realtime graph types,
  sample formats, Opus/CELT low-delay codec bridge, AES67/ST 2110 L24 RTP
  profile, AVFoundation raw frame source, video reassembly, preview sinks, and
  MADI path reports.
- Compatibility primitives: `ExternalConnectorSessionConfiguration`,
  `ExternalConnectorLaunchPlan`, LoLa control exchange/report types,
  `LoLaCompatibilityMediaSessionReport`, JackTrip/UltraGrid plans, and the
  Python `MediaSettings`/`LolaConnector`/`LolaLinuxRuntime` classes.

## Storage And File-System Interactions

There is no database or migration system in the inspected source.

Active file-system contracts include:

- CLI `--output <path>` report writes, usually pretty JSON with atomic file
  writes and parent directory creation.
- Validator commands that read report JSON or packet fixtures.
- App support paths under user Application Support, especially
  `OpenLoLa/MacToMac/plan.json`, `supervisor.json`, and
  `connection-preflight.json`.
- App stdout/stderr log files prepared by `AppExecutionController`.
- App storage keys and stored defaults, including legacy migration paths.
- Release candidate export output and hygiene scans.
- Fixtures, snapshots, and generated evidence under tests/docs/private/archive.
- Python connector subprocess command IO and optional process-backed capture or
  playback/display commands.

`archive/` is historical trace evidence, not active authority. `private/` is
local/private evidence and must not be promoted into public release surfaces
without explicit review.

## External APIs And Dependencies

Swift runtime dependencies include Foundation, Darwin sockets/process APIs,
Dispatch, AppKit, AVFoundation, CoreAudio, CoreGraphics, CoreImage, ImageIO,
CoreMedia, and UniformTypeIdentifiers. C integration includes repo-local atomics,
vendored Opus, and vendored/reference JPEG XS code.

Python connector dependencies are standard-library heavy (`argparse`, `asyncio`,
`logging`, `math`, sockets/subprocesses via internal modules) with optional
external tooling documented in connector scripts. Verification depends on SwiftPM,
pytest, ruff, mypy, shellcheck, Docker/native helper scripts where relevant, and
external media tools such as LoLa, JackTrip, UltraGrid, WSL/Npcap, or hardware
only for manual compatibility evidence.

## Configuration Sources

- CLI arguments and command-specific parsers.
- `Package.swift`, `pyproject.toml`, GitHub workflow files, shell scripts, and
  release hygiene configuration.
- App settings, app storage keys, stored defaults, run-directory paths, and
  Info.plist/entitlements.
- Docs that define active verification and protocol policy, especially
  `docs/current-state.md`, `docs/testing/README.md`,
  `docs/architecture/open-lola-protocol.md`,
  `docs/architecture/p2p-networking.md`, and source-contract docs.
- Environment flags observed in source, such as
  `OPEN_LOLA_DISABLE_APPKIT_PREVIEW` and release-candidate hygiene variables.
- Hardware/operator inputs: audio/video device UIDs, hosts, ports, peer IDs,
  route labels, report paths, payload modes, and explicit SSH fallback fields.

## Major Flows

### 1. CLI Dispatch And Report Validation

| Question | Answer |
|---|---|
| What starts the flow? | A user or script invokes `open-lola <command>`. |
| Trusted/untrusted inputs | CLI args and file paths are untrusted. Static registry entries and compiled report types are trusted source. |
| Validation | Top-level dispatch checks command shape. Specific parsers reject unknown/duplicate/missing args. Validators decode bounded JSON and call report `validate()`. |
| State read | Command registry, source constants, input reports/fixtures, hardware inventories for device commands. |
| State written | stdout/stderr, JSON reports at `--output`, optional debug traces. |
| What can fail? | Unknown commands, invalid args/ports, unreadable files, invalid reports, hardware inventory errors, runtime errors. |
| Failure surface | CLI writes `error: ...` to stderr and exits nonzero; validators print success and `VERDICT` only after validation. |
| Tests protecting it | Swift tests around command inventory, report schemas, validators, packet/report fixtures, and command-specific tests listed in `docs/testing/README.md`. |
| Wrong-result risk | A command can finish without proving field readiness if its report is synthetic, dry-run, localhost, or partial; callers must honor report verdict and evidence labels. |

### 2. Direct P2P Audio/Video Session

| Question | Answer |
|---|---|
| What starts the flow? | `direct-p2p-session-run`, directly from CLI or via app/supervisor command builders. |
| Trusted/untrusted inputs | Peer IDs, hosts, ports, device UIDs, media settings, report path, SDP path, and quality policy are untrusted operator input. |
| Validation | Argument parser bounds integers, rejects scoped AV-only args in audio mode, validates audio transport shapes, parses AoIP SDP input, validates manual network shape, device/video fields, profile/buffer policy, packet budgets, accepted audio/video streams, and optional useful-media policy. |
| State read | Core Audio inventory, selected device UIDs, AVFoundation video device/source, local capability set, SDP input, sockets. |
| State written | UDP control/audio/video/metrics traffic, optional SDP output, preview sink, JSON direct-peer report, runtime metrics. |
| What can fail? | Bind/connect errors, bad profile/media shape, missing devices, AVFoundation start failure, Opus/AES67 shape failure, handshake mismatch, timeout, corrupt/oversize/late fragments, no useful media moved. |
| Failure surface | Throws to CLI/app; report is not written when early validation/runtime throws. App records failure in execution report/logs. |
| Tests protecting it | Direct peer session, compatibility codec/media session, RX buffer, AES67/ST2110, packet/reassembly, report validator, and focused compatibility tests. |
| Wrong-result risk | Structural runs can pass code paths while moving no useful real media unless `--quality-policy require-useful-media` and physical evidence are used. Synthetic fixture mode cannot certify production device behavior. |

State transition:

```text
parse args
  -> validate AV/manual/media shape
  -> bind control + media sockets
  -> initiator/responder handshake
  -> propose/accept session
  -> exchange audio metadata
  -> media start barrier
  -> service control, audio TX/RX, video TX/RX, metrics
  -> flush/drop incomplete buffers
  -> build/validate report
```

### 3. Two-Peer Mac Supervisor / App Mac-To-Mac Flow

| Question | Answer |
|---|---|
| What starts the flow? | App Mac-to-Mac controls or CLI `direct-p2p-two-peer-local-run`. |
| Trusted/untrusted inputs | Plan path, supervisor report path, execution mode, executable path, preflight report path, SSH/scp paths, peer workdirs, and explicit SSH fallback reason are untrusted. |
| Validation | App settings require nonempty paths, positive readiness delay, valid `open-lola` executable, explicit SSH selection/reason for SSH mode, and preflight report when required. Supervisor validators validate plan/report JSON. |
| State read | App stored settings, plan JSON, connection preflight report, executable path, local filesystem, optional remote SSH/SCP endpoints. |
| State written | Plan artifact, child reports, supervisor report, stdout/stderr logs, app execution report. |
| What can fail? | Missing/invalid executable, missing preflight, bad plan/report, child process failure, SSH/SCP failure, readiness timeout, validation failure. |
| Failure surface | App phase/status/error log; CLI nonzero; native app shell report remains partial unless execution and validation succeed. |
| Tests protecting it | Native app shell execution/settings tests, direct two-peer plan/local-run report tests, app command-preview tests, and supervisor validator tests. |
| Wrong-result risk | Dry runs and plan writes can prove command assembly but not media. SSH fallback is advanced/operator-owned and must not be silently selected. |

App execution state:

```text
idle
  -> planWritten
  -> dryRunRunning | supervisorRunning
  -> stopRequested | runFinished | runFailed | failedToStart
  -> validationRunning
  -> validationPassed | validationFailed
```

`NativeAppShellExecutionReport.validate()` rejects `PASS` without successful
process exit and successful validation.

### 4. External Connector / Windows LoLa Compatibility

| Question | Answer |
|---|---|
| What starts the flow? | CLI `external-connector-session-run` or app Windows LoLa mode. |
| Trusted/untrusted inputs | Connector kind, role, peer/local host, ports, dry-run flag, media mode, executable paths, LoLa session ID, raw-link MAC/interface, AV payload settings, and report path are untrusted. |
| Validation | Parser rejects unknown/duplicate/missing args. Runtime validation checks connector, role, media mode, ports, raw-link scope, source references, peer requirements, dry-run cannot pass, process result requirements, and nested LoLa media/control reports. |
| State read | Connector config, process executables, LoLa source references, sockets, optional AVFoundation capture commands, external processes. |
| State written | Control UDP/TCP messages, media packets, process stdout/stderr prefixes, external connector JSON report, app external connector report cache. |
| What can fail? | Invalid connector/mode/role, missing peer or executable, process launch failure, socket failure, receive timeout, malformed control messages, no decoded inbound media, dry-run pass attempt. |
| Failure surface | Report `runtimeError` and `verdict`; CLI/app nonzero or validation failure; app reports external connector evidence incomplete unless report verdict supports runtime evidence. |
| Tests protecting it | External connector session/report tests, LoLa compatibility control/media tests, app Windows LoLa command tests, Python connector tests, and current Windows probe documentation. |
| Wrong-result risk | A Windows LoLa run can show outbound/generated AV while failing to decode Windows-originated media; report verdict and notes must remain partial/fail for that gap. Dry-run plans must never become PASS. |

Compatibility boundary: LoLa is explicit compatibility work, separate from the
clean-room open-lola protocol. JackTrip and UltraGrid are external connector
contracts and are not app-launchable in the inspected app controller.

### 5. Python Linux Connector

| Question | Answer |
|---|---|
| What starts the flow? | `python -m linux_connector.lola_connector.cli` with `selftest`, `status`, `listen`, or `connect`. |
| Trusted/untrusted inputs | CLI args, local/remote IPs, ports implied by protocol modules, media settings, subprocess capture/playback/display commands, duration, packet sizes, and control dialect are untrusted. |
| Validation | `argparse` enforces required args/choices; explicit range checks validate packet size, frame size, callback size, duration, timeout, SID, tone values, and payload bounds. |
| State read | Network sockets, process-backed capture/playback/display commands, generated media sources, protocol constants. |
| State written | UDP control/media traffic, subprocess stdin/stdout, runtime stats printed to stdout. |
| What can fail? | Bad args, malformed datagrams, wrong peer datagrams, subprocess failures, receive timeouts, oversized media frames, runtime cancellation. |
| Failure surface | Parser errors, Python exceptions, printed status/runtime stats. |
| Tests protecting it | `linux_connector` pytest suite, ruff, mypy, and selftest paths. |
| Wrong-result risk | Synthetic media and selftests only prove local connector behavior. Process-backed capture/display quality and real Windows LoLa compatibility remain external evidence. |

### 6. Release / Readiness Verification

| Question | Answer |
|---|---|
| What starts the flow? | Verification scripts, CI workflow, or CLI release/readiness report commands. |
| Trusted/untrusted inputs | Checkout contents, staged release-candidate path, tool availability, generated reports, docs links, fixtures, and private/archive boundaries are untrusted until checked. |
| Validation | Docs verifier, release hygiene, source gates, report validators, schema inventory, shell/python/static checks, Swift build/tests, release-readiness runner. |
| State read | Repo files, generated/cached files, fixtures, docs, scripts, tool versions, optional release candidate tree. |
| State written | Verification output, generated reports under caller-provided paths, tool caches unless redirected. |
| What can fail? | Broken docs links, generated artifacts in wrong boundary, Swift test failures, missing tools, sandboxed SwiftPM failure, cache artifacts, shell/python/static failures. |
| Failure surface | Nonzero script/tool exit and baseline docs; CI failure where configured. |
| Tests protecting it | `docs/testing/README.md` matrix, release-readiness workflow, report schema and release harness tests. |
| Wrong-result risk | Running only a subset can look green while broader Swift tests, release hygiene, app launch, hardware, signing, or connector evidence remain unverified. |

### 7. Hardware / Manual Evidence Flows

| Question | Answer |
|---|---|
| What starts the flow? | CLI commands such as `goal-runtime-preflight-run`, `goal-completion-audit-run`, route/run report commands, packaging/recording/field proof commands, or manual hardware procedures. |
| Trusted/untrusted inputs | Hardware labels, route labels, device IDs, report IDs, capture notes, DSCP/PTP facts, package paths, signing/notarization facts, and reviewer evidence are untrusted. |
| Validation | Report validators require nonempty fields and enforce verdict rules, but real-world truth still depends on operator-supplied evidence. |
| State read | Device inventories, route reports, existing evidence artifacts, package/signing state, docs/source matrices. |
| State written | Evidence reports and release/goal status reports. |
| What can fail? | Missing hardware, missing captures, invalid report fields, false PASS attempts, incomplete manual evidence. |
| Failure surface | Report verdict/blockers/notes; validator failure; current-state PARTIAL docs. |
| Tests protecting it | Release harness tests and report validators, not full field proof. |
| Wrong-result risk | The code can emit structurally valid reports whose evidence is only synthetic or manually incomplete. Validators are necessary but not sufficient for field readiness. |

## Public Contracts That Must Not Break

- CLI command names, flags, argument scopes, help expectations, stdout summary
  lines, and `VERDICT: PASS|PARTIAL|FAIL` behavior.
- JSON report schemas, fixture names, enum raw values, verdict vocabulary,
  validator behavior, and `PrettyJSONCodable` output expectations.
- `OpenLolaContracts` public types and report validation semantics.
- UDP PCM v1/v2 packet formats, direct media envelope, AES67/ST 2110 L24 RTP
  shape, video fragment format, session control message names, and accepted
  session configuration rules.
- App storage keys, stored-default migrations, settings fields, command preview
  behavior, run/log/report path defaults, and app status semantics.
- Python connector CLI options, protocol settings, control/media behavior, and
  package importability from the checkout.
- Release-candidate export boundary, release hygiene expectations, and docs
  authority surfaces.
- Clean-room boundary: open-lola protocol fields and names must remain original;
  LoLa compatibility must stay optional and explicitly labeled.

## Error-Handling Strategy

Swift CLI paths generally throw typed errors, convert them to `error: ...` on
stderr, and exit nonzero. Report-producing commands validate before writing or
before claiming a verdict. App execution records phase, status, exit code,
stdout/stderr paths, validator command, validation exit code, and partial/fail
notes. External connector reports require `runtimeError` on `FAIL` and reject
dry-run `PASS`. Python connector uses parser errors for invalid CLI input,
exceptions for runtime failures, and printed structured status/runtime stats for
successful runs.

Do not replace these explicit failures with silent fallback, optimistic state,
or compatibility shims unless active evidence proves the old behavior is still
required.

## Compatibility And Deprecation Layers

- `--audio-compression` remains a legacy compatibility flag mapped to
  `--audio-transport`; conflicting values are rejected.
- Legacy single `audioDeviceUID` paths are bridged to input/output UIDs for v1
  audio-video mode.
- NAT rendezvous/relay/friendly-route paths are compatibility/fallback evidence,
  not the default fastest media path.
- LoLa compatibility lives in explicit Swift external-connector and Python
  connector surfaces; it must not be blended into the clean-room protocol.
- JackTrip and UltraGrid are external connector contracts; app launching remains
  unsupported in the inspected app controller.
- Archived plans/evidence are historical, not active behavior authority.

## Hidden Coupling

- CLI registry, command inventory, docs, validators, report schema inventory,
  fixtures, and tests must change together.
- App command builders depend on exact CLI command names and report paths.
- App status/validation depends on report verdicts and files created by CLI
  child processes.
- Report validators and release scripts depend on stable JSON field names and
  enum raw values.
- Swift LoLa compatibility reports and Python connector protocol settings must
  stay aligned enough for documented compatibility probes.
- Direct P2P audio/video correctness couples Core Audio preflight, media
  profile validation, UDP socket timing, RX buffer policy, video reassembly,
  preview sinks, and report metrics.
- Release hygiene couples `.gitignore`, generated caches, release candidate
  export, docs, scripts, and CI.
- Source-line budget tests can fail due file size even when behavior is
  otherwise unchanged.

## Not Fully Understood / Coverage Gaps

- UNCLEAR: full Core Audio callback timing and thread-safety behavior was not
  audited line by line for this map.
- UNCLEAR: full SwiftUI view reachability, visual states, and every menu/action
  path were not exercised in a running app.
- UNCLEAR: vendored Opus and JPEG XS internals were treated as integration
  surfaces, not independently audited.
- UNCLEAR: Docker/native helper flows, JackTrip, UltraGrid, WSL/Npcap, and real
  Windows LoLa inbound media behavior were not run in this pass.
- UNCLEAR: hardware/manual flows for RME/MADI, two-Mac packet capture,
  Blackmagic/ATEM, OSC/sACN/Art-Net, signing, notarization, Gatekeeper, and
  clean-Mac launch remain documentation/report contracts until fresh evidence
  is collected.

## Recommended Next Audit Targets

1. Direct P2P AV runtime around Core Audio callback ownership, socket polling,
   RX buffer policy, and useful-media verdict rules.
2. App operator state and command preview versus actual launched CLI arguments.
3. External LoLa connector inbound media decode/report verdict path.
4. Report schema and validator coupling for all CLI commands that can print or
   write `PASS`.
5. Release hygiene and generated artifact boundaries after any new tool runs.
