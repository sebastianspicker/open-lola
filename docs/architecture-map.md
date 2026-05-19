# Architecture Map

_Established: 2026-05-19. Based on source code, tests, docs, and configuration — no behavior is inferred beyond what the code demonstrates._

---

## 1. Repository Structure

```
open-lola2/
├── Package.swift                        SwiftPM manifest (5 products, 6 targets)
├── Sources/
│   ├── OpenLolaContracts/               Shared verdict/report primitives (library)
│   ├── OpenLolaCore/                    All domain logic (library)
│   ├── open-lola/                       CLI executable
│   ├── open-lola-app/                   SwiftUI macOS app (library; no @main)
│   ├── open-lola-app-main/              App entry point (@main; thin wrapper)
│   ├── COpenLolaAtomics/                C atomics bridge (lock-free SPSC support)
│   ├── xs_ref_sw_ed2/                   JPEG-XS reference codec (C, vendored)
│   └── opus-1.5.2/                      Opus audio codec (C, vendored)
├── Tests/OpenLolaCoreTests/             Swift Testing suite (~727 tests)
├── linux_connector/                     Python LoLa compatibility seed
├── scripts/                             Release, verification, Docker helpers
└── script/                             Legacy app bundle helpers (not in release export)
```

**No external Swift package dependencies.** All third-party code is vendored.

---

## 2. Runtime Entry Points

### 2.1 CLI — `open-lola`

**File:** `Sources/open-lola/main.swift`

**Startup flow:**
1. Read `CommandLine.arguments`.
2. Call `runOpenLolaCommand(arguments)`.
3. Dispatch to one of two routing layers:
   - _Imperative handlers_ (`handleNetworkCommand`, `handleMadiReceiveCommand`, `handleMadiFullDuplexCommand`, `handleLatencyProfileCommand`, `handlePerformanceCommand`, `handleE2EBenchmarkCommand`, `handleMilestoneCommand`) — each checks argument patterns and returns `true` if consumed.
   - _Registry lookup_ — `openLolaCommandRegistry()` maps command name → `RegisteredCommand`. Each `RegisteredCommand` checks exact argument count; throws `CommandError.invalidArgument` otherwise.
4. Output is written to stdout. Errors are written to stderr. Exit code: 0 = success, 1 = error.

**All commands are synchronous.** There are no async/await entry points in the CLI binary. Long-running operations (audio loopback, UDP PCM route) block the main thread for their duration.

**Command categories:**
| Category | Commands |
|----------|---------|
| Capability / inventory | `session-capabilities`, `command-inventory`, `source-ownership-inventory`, `fixture-smoke-matrix`, `report-schema-inventory`, `realtime-audio-path-inventory`, `network-route-command-matrix`, `video-control-degrade-matrix` |
| Goal / release | `goal-codewise-closure[-run]`, `goal-runtime-evidence-template[-run]`, `goal-runtime-preflight[-run]`, `goal-completion-audit[-run]`, `current-evidence-status-matrix[-run]`, `open-source-release-readiness[-run]` |
| Network / UDP | `udp-pcm-send-once`, `udp-pcm-receive-once`, `udp-pcm-route-run`, `udp-pcm-loopback-run`, `direct-p2p-session-run`, `direct-p2p-two-peer-local-run`, `udp-pcm-route-certification-run` |
| Audio | `audio-loopback-run`, `madi-receive-run`, `madi-full-duplex-run`, `latency-profile-run` |
| Validation | `validate-*` (various report types), `validate-direct-p2p-session`, `validate-external-connector-session` |
| External connectors | `external-connector-session-run`, `external-connector-nmp-preflight-run`, `external-connector-nmp-workflow-run` |
| Benchmarks | `e2e-benchmark-run`, `performance-audit-run` |
| Devices | `device-inventory` |

### 2.2 macOS App — `open-lola-app`

**Files:** `Sources/open-lola-app-main/OpenLolaAppMain.swift` → `Sources/open-lola-app/OpenLolaApp.swift`

**Startup flow:**
1. `OpenLolaAppMain` sets `NSApplication.activationPolicy` to `.regular`, then activates the app.
2. `OpenLolaAppScene` creates three windows: "Open LoLa" (main), "Local Preview" (secondary), and a Settings sheet.
3. On `.task { }` launch:
   - `refreshSyntheticMetricsAsync()` runs `NativeAppShellSyntheticSmoke.run()` off-main-thread and stores result in `@State var report`.
   - `refreshInventory()` calls `AppLocalOperatorInventoryController.refresh()` to populate audio/video device inventory.
4. All state is held in `@State` and `@Observable` objects on the main actor:
   - `NativeAppShellOperatorPrototypeState` — user's session parameters.
   - `AppExecutionController` — manages the live process lifecycle and reports.
   - `AppPreviewReceiverState` — UDP video preview state.
   - `AppSettings` — persisted user prefs via `UserDefaults`.

**All settings are written to `UserDefaults`** using the `openLola.*` key namespace defined in `AppStorageKeys`. Reading on cold start hydrates state via `AppShellStoredDefaults`.

### 2.3 Python Connector — `linux_connector`

**Entry:** `python -m linux_connector.lola_connector.cli ...`

Provides a Python seed of the LoLa protocol. Not merged into SwiftPM. Tested separately via pytest. Provides `LolaPeerConnector`, `UDPPcmTransport`, codec, and process runtime abstractions. Acts as a compatibility reference and interoperability test harness.

---

## 3. Domain Primitives

### 3.1 `MeasurementVerdict` (`OpenLolaContracts`)

```
enum MeasurementVerdict: String { case pass, fail, partial }
```

The central verdict type. Every report, CLI command output, and validation path produces one of these three values. **`partial` is the expected steady-state for most runtime paths** — it means execution succeeded but evidence is incomplete for a field `pass`. A `pass` requires explicit human-reviewed evidence beyond synthetic or localhost tests.

### 3.2 `MeasurementMethodology` (`OpenLolaContracts`)

```
enum MeasurementMethodology: String { case synthetic, measured }
```

Distinguishes reports produced from code-path smoke (synthetic) from those produced from real hardware/network measurements. All current CI outputs are synthetic.

### 3.3 `RxBufferProfile` (`OpenLolaContracts`)

```
enum RxBufferProfile: String { case direct, small, stable, wan, adaptive }
```

Governs receive-buffer latency policy for the realtime audio path. Serialized in reports and persisted in `UserDefaults`. Protocol contract — do not rename values.

### 3.4 `UdpPcmPacket` / `UdpPcmPacketHeader`

The native Open LoLa audio wire format. Header: 48 bytes.

| Offset | Field | Type |
|--------|-------|------|
| 0-3 | Magic `OLPC` | `[UInt8]` |
| 4 | Version (currently 1) | `UInt8` |
| 5 | Sample format (`int16LE`=1, `float32LE`=2) | `UInt8` |
| 6-7 | Channel count | `UInt16 LE` |
| 8-11 | Frames per packet | `UInt32 LE` |
| 12-15 | Sample rate (Hz) | `UInt32 LE` |
| 16-23 | Sequence number | `UInt64 LE` |
| 24-31 | Sender frame index | `UInt64 LE` |
| 32-39 | Sender host time (ns) | `UInt64 LE` |
| 40-43 | Payload byte count | `UInt32 LE` |
| 44-47 | Header guard `0x3143504C` | `UInt32 LE` |
| 48+ | Interleaved PCM payload | raw bytes |

Payload size = `framesPerPacket × channelCount × bytesPerSample`. Any mismatch throws `UdpPcmPacketError.payloadLengthMismatch`. Max payload: 1 MiB.

This format is the **primary protocol contract**. Changes break interoperability with any endpoint using the existing format.

### 3.5 `UdpMediaPacket` / `UdpMediaPacketHeader`

A second native transport envelope (magic `OLMP`, header: 36 bytes) used by the `UdpMediaTransport` layer. Carries audio and video streams with a `payloadType` field (`SessionPayloadType`) and a `streamID`. Designed for the Direct P2P / multi-stream session path.

### 3.6 `ExternalConnectorSessionConfiguration`

A large struct (~50 fields) covering all parameters for a LoLa, JackTrip, or UltraGrid connector session. Serializable; written to `plan.json` by the app and read back by the CLI supervisor. **This is the plan/report serialization contract** — field renames or type changes break deserialization of existing plans.

### 3.7 Report types

All reports conform to `ReportValidatingArtifact: PrettyJSONCodable`. Every report has an `id`, `capturedAt` (ISO 8601), `verdict: MeasurementVerdict`, and `notes: String`. Validation is performed by calling `.validate()` before writing.

---

## 4. Major Flows

### 4.1 CLI Command Dispatch

```
Process.arguments
    → runOpenLolaCommand(arguments: [String])
    → [imperative handler chain] or [registry lookup]
    → domain function (synchronous, throws)
    → JSON printed to stdout + "VERDICT: PASS|FAIL|PARTIAL" footer
    → exit(0) on success, exit(1) on throw
```

**What starts it:** Process launch.

**Inputs:** `CommandLine.arguments`. No external config files are read at startup (except for `validate-*` commands which read from a user-supplied file path).

**Validation:** Argument count is checked before dispatch. File-path arguments are read with `BoundedFileReader` (enforces max byte limits). JSON deserialization is type-safe via `Codable`.

**State read:** None at the CLI level; each command is stateless on entry. Long-running commands (route-run, loopback-run, external-connector-session-run) create and run stateful objects internally for the duration.

**State written:** Output JSON is written atomically to user-supplied `--output` paths via `FileManager.createDirectory` + `Data.write(.atomic)`. No global state is mutated.

**What can fail:**
- Invalid arguments → `CommandError.invalidArgument` → stderr, exit 1
- File I/O → system errors → stderr, exit 1
- Network/socket errors → thrown errors with errno context
- External process launch failures → `ExternalConnectorSessionError.processLaunchFailed`

**How failures surface:** All errors propagate to the top-level `do/catch` in `main.swift`. `commandErrorDescription(_:)` formats known `CommandError` variants; unknown errors use `String(describing:)`. Written to stderr.

**Tests protecting this:** `CLICommandInventory` snapshot tests, `FixtureSmokeMatrixTests`, `ReleaseArtifactHygieneContractTests` (exercising the registry structure). Individual command logic is tested via domain unit tests.

**Where it can produce wrong results silently:** Synthesis-only commands (`goal-codewise-closure`, `session-capabilities`, etc.) always emit a report regardless of whether real hardware was available. A `VERDICT: PARTIAL` output will never indicate missing real-world evidence on stdout — only the report JSON body contains the evidence gap detail.

---

### 4.2 Direct P2P Audio Session (Native UDP PCM)

This is the primary native audio path.

```
Configuration (UdpPcmRouteRunConfiguration / DirectP2PSessionConfiguration)
    → PeerSessionRunner pair (TX + RX)
    → [negotiate] — exchange session parameters over in-process channel or UDP control
    → [startMedia] — open UDP socket, bind port
    → [TX loop] — RealtimeAudioEngine capture callback
                  → CoreAudio AudioDeviceIOProcID fires per hardware interrupt
                  → SPSCAtomicRing.push(captureBlock)       [audio thread → network thread]
                  → UdpPcmPacket.encoded()
                  → sendto(socket, packet)
    → [RX loop] — recvfrom(socket, buffer)
                  → UdpPcmPacket.decode(bytes)
                  → DirectPeerAudioPayloadRing.push(payload) [network thread → audio thread]
                  → RxBuffering: place into playout window
                  → AudioDeviceIOProcID RX callback → output to CoreAudio
    → [teardown] — AudioDeviceStop, AudioDeviceDestroyIOProcID
                 → restore original sample rate & buffer size
    → DirectPeerSessionReport (verdict: partial)
```

#### Realtime audio callback boundary

`DirectPeerRealtimeAudioGraph` owns two `DirectPeerAudioPayloadRing` objects:
- `captureRing` — populated by the CoreAudio input IOProc (audio thread), drained by the network TX thread.
- `playoutRing` — populated by the network RX thread, drained by the CoreAudio output IOProc (audio thread).

Both rings are lock-free SPSC (`SPSCAtomicRing` backed by `COpenLolaAtomics`). The correctness comment in `SPSCAtomicRing.swift` explicitly states: _"The producer cannot mutate readIndex and the consumer cannot mutate writeIndex."_ Any violation of SPSC ownership causes a data race.

**Ring overflow behavior:** If `captureRing.push` returns `.full`, the block is **dropped silently** and `droppedInputBlocks` is atomically incremented. There is no backpressure to the CoreAudio callback. If `playoutRing` is empty at output callback time, **silence is produced** and `outputUnderrunBlocks` is incremented.

**State read:** CoreAudio device IDs (from `inputDeviceUID` / `outputDeviceUID` config). Device sample rate and buffer size are read and then **modified** (saved and restored at teardown).

**State written:**
- CoreAudio device sample rate (set to `sampleRateHertz`).
- CoreAudio device buffer frame size (set to `framesPerBuffer`).
- Atomic counters: `capturedInputBlocks`, `droppedInputBlocks`, `outputBlocks`, etc.
- The graph holds `ioProcRunning` flag to prevent double-start.

**What can fail:**
- CoreAudio property set fails → thrown error with OSStatus.
- IOProc registration/start fails → thrown error.
- Teardown: IOProc destroy can fail; errors are collected but do not throw (only logged in `latestCleanupResult`).

**Where it can produce wrong results silently:**
- Dropped input blocks or output underruns increment counters but do **not** abort the session.
- RxBuffer adaptation (`adaptiveRxBufferController`) runs outside the audio callback, protected by `rxBufferAdaptationLock`. If the lock is contended at callback time, adaptation is skipped — **no failure is signaled**.
- The session reports `verdict: .partial` unconditionally; dropped packets are visible only by inspecting `DirectPeerSessionReportMetrics`.

**Tests protecting this:** `DirectPeerRealtimeAudioGraphTests` (synthetic), `RxBufferBenchmarkRunner` tests, `RealtimeAudioEngineReportValidation` tests. No hardware-backed tests are run in CI.

---

### 4.3 External Connector Session (LoLa / JackTrip / UltraGrid)

```
ExternalConnectorSessionConfiguration
    → ExternalConnectorSessionRunner.run(configuration:)
    → ExternalConnectorLaunchPlan.build(configuration:)  [plan construction, no side effects]
    → if dryRun → return ExternalConnectorSessionReport(verdict: .partial)
    → switch plan.launchKind:
        case .internalLoLaControl / .internalLoLaControlUdp:
            → runLoLaControlExchangeAttempt()
              → bind UDP/TCP socket
              → send /MESG_QUICKCONN (or CHECKLOLASTATUS)
              → receive ACK with timeout
              → LoLaCompatibilityControlMessage.parse(response)
            → if failure → report(verdict: .fail)
            → makeLoLaMediaSessionEvidence()  [may transmit/receive UDP media packets]
            → startLoLaControlRetryResponder() if applicable
            → assemble ExternalConnectorSessionReport
        case .externalProcess:
            → runExternalProcess(plan, durationSeconds)
              → Foundation.Process.launch()
              → wait durationSeconds
              → SIGKILL + waitUntilExit()
            → parse stdout for metrics
            → assemble report
```

#### LoLa control protocol

Control messages are text-encoded key-value strings:
```
/MESG_QUICKCONN SRCIP=x.x.x.x;DSTIP=y.y.y.y;SID=N;...
/MESG_QUICKCONN_ACK SRCIP=...
/MESG_CHECKLOLASTATUS ...
/MESG_CHECKLOLASTATUS_ACK ...
```

Sent and received over UDP (default) or TCP. Parsed by `LoLaCompatibilityControlMessage` and `LoLaCompatibilityControlSocket`. The session ID (`SID`) must be a numeric integer. Invalid IDs throw `ExternalConnectorSessionError.invalidLoLaSessionID`.

**What starts the flow:** CLI `external-connector-session-run` or app `AppExecutionController.startArmed(operatorSurface:)`.

**Inputs trusted/untrusted:** All configuration comes from `ExternalConnectorSessionConfiguration`, which is either parsed from CLI args or deserialized from `plan.json`. The `plan.json` path is user-supplied — no sandbox. Network responses (control ACK, media packets) are untrusted.

**Validation:**
- `ExternalConnectorSessionConfiguration.validate()` checks all required fields before launch.
- Control ACK is parsed and compared against the sent message.
- Media datagrams are decoded via `LoLaCompatibilityUdpMedia` — malformed packets are counted in `rejectedMediaCount` but do not abort the session.

**State read:** None beyond configuration and the network socket.

**State written:** Report JSON is written to `configuration.outputPath`.

**What can fail:**
- Socket creation/bind fails → `ExternalConnectorSessionError.socketFailed`.
- Control receive times out → `ExternalConnectorSessionError.receiveTimedOut`.
- Process launch fails → `ExternalConnectorSessionError.processLaunchFailed`.
- `runtimePassMissingEvidence` — thrown if a `pass` verdict is claimed but required evidence classes are absent.

**How failures surface:** Errors are either thrown (CLI exits 1) or embedded in the report as `runtimeError: String?` with `verdict: .fail`. A session can complete with a `.fail` report — the output file is still written.

**Where it can produce wrong results silently:**
- If the LoLa peer sends back a valid ACK but does not actually transmit media, the media evidence section will show zero packets but the control handshake will report success.
- `startLoLaControlRetryResponder()` runs on a background thread and may continue sending after the primary session has concluded — its result is captured in `retryResponder?.runtimeError` but not validated against any contract.
- UltraGrid/JackTrip process output is parsed from stdout; if the external process changes its output format, counts will silently be zero.

**Tests protecting this:** `ExternalConnectorSessionTests`, `ExternalConnectorAvMatrixTests`, `LoLaCompatibilityMediaSessionTests`, `JackTripCompatibilityTests`. All are synthetic or localhost. No field/hardware tests in CI.

---

### 4.4 App Execution Lifecycle

```
AppExecutionController (@MainActor, @Observable)
    state: AppExecutionPhase = .idle

    writePlanOrLogError(from: operatorSurface)
        → AppOperatorPrototypePlan.make(operatorSurface:)
        → serialize to plan.json (settings.planPath)
        → phase = .planWritten

    dryRun(operatorSurface:)
        → phase = .dryRunRunning
        → run open-lola CLI via ManagedProcess (dry-run flag)
        → capture stdout/stderr to logfiles
        → waitUntilExit()
        → phase = .runFinished or .runFailed

    startArmed(operatorSurface:)
        → pre-condition: armedForExecution == true
        → phase = .supervisorRunning
        → launch ManagedProcess (open-lola external-connector-session-run ...)
        → poll isRunning; tick elapsedSeconds via async Timer
        → on completion: parse report from supervisorReportPath
        → phase = .runFinished or .runFailed

    stop()
        → process.terminate() → (if still running) process.killImmediately()
        → phase = .stopRequested

    validateReport(operatorSurface:)
        → phase = .validationRunning
        → launch open-lola validate-external-connector-session <supervisorReportPath>
        → phase = .validationPassed or .validationFailed

    tearDown()  [called on scene backgrounding]
        → process.killImmediately()
        → phase = .idle
```

**State machine note:** `AppExecutionPhase` is not formally guarded — it is possible to call `startArmed` while `isRunning`, but UI buttons are disabled by convention. There is no enforcement at the model layer.

**Settings persistence:** `AppSettings` properties write to `UserDefaults` in their `didSet` observers. This means every UI interaction writes to disk synchronously on the main actor.

**What can fail:**
- Plan serialization fails → logged in `errorLog`, returns false, phase stays at `.idle`.
- Process launch fails → `ManagedProcess` init throws → caught in `startArmed`, phase = `.failedToStart`.
- Report file not found after run → `missingReport` validation readiness state → UI disables validate button.
- App backgrounded while running → `tearDown()` fires via `scenePhase` change observer, process is killed.

**Tests protecting this:** `NativeAppShellSurfaceContractTests`, `NativeAppShellSyntheticSmokeTests`, `AppExecutionControllerTests` (if present — UNCLEAR: no test file for `AppExecutionController` was identified in the test suite; verify by grepping `Tests/`).

---

### 4.5 MADI Full-Duplex Audio Session

```
MadiFullDuplexRunConfiguration
    → MadiFullDuplexRuntime.run(configuration:)
    → CoreAudioInventoryReader.capture()  [enumerate devices, find MADI device]
    → RmeFastestAudioPath.configure(device, mode)  [set sample rate + buffer size]
    → MadiFullDuplexSocketRunner.run(...)
      → TX: CoreAudio IOProc → UDP PCM packets → sendto(socket, madiPeer:port)
      → RX: recvfrom(socket) → decode UdpPcmPacket → write to output buffer
    → MadiFullDuplexReport (verdict: partial without real MADI hardware evidence)
```

Requires physical RME MADI hardware. Always emits `verdict: .partial` in synthetic mode; `PASS` requires measured hardware evidence.

---

### 4.6 Video Transport

```
VideoCaptureRunner.run(configuration:)
    → AVCaptureSession (AVFoundation)
    → VideoCaptureAVFoundation.startCapture()
    → frames → VideoMediaSocket.send(frame)
              → VideoTransportPacket.encode()  [fragmentation if needed]
              → UDP sendto

VideoTransportRunner.run(configuration:)
    → UDP recvfrom
    → VideoTransportReassembly.reassemble(fragment)
    → VideoOutputRenderer.render(frame)
    → AppKit/CoreGraphics display  [RawBGRAAppKitPreviewWindow or SwiftUI preview]
```

Video frames may span multiple UDP packets. `VideoTransportReassembly` tracks fragment reassembly by stream ID and sequence number. Incomplete frames are discarded.

**LoLa video path:** `LoLaAVFoundationLiveRaw8Source` captures via AVFoundation and produces raw 8-bit frames for the LoLa compatibility UDP stream. Video payload kind is controlled by `LoLaVideoPayloadKind` (raw, JPEG-XS, or JPEG).

---

### 4.7 Goal / Release Evidence Commands

These commands are pure analytics — they read source inventories, check for placeholder values, and produce structured JSON reports assessing readiness. They do **not** run any live hardware path.

```
GoalCodewiseClosureReport.codewiseClosure()
    → reads SourceOwnershipInventory (static table of source files + owners)
    → PlaceholderDetection.check(sourcePaths)
    → cross-reference with GOAL.md expected deliverables
    → emit GoalCodewiseClosureReport (verdict: partial)

GoalRuntimePreflightRunner.run()
    → CoreAudioInventoryReader.capture()  [enumerates real devices]
    → UdpPcmLocalhostSmoke.run()          [real socket I/O]
    → ExternalConnectorExecutablePreflight.run()  [checks executables in PATH]
    → emit GoalRuntimePreflightReport
```

`GoalRuntimePreflightRunner` is the only "goal" command that performs real I/O.

---

## 5. Module Dependency Boundaries

```
OpenLolaContracts (no dependencies)
    ↑
OpenLolaCore (depends on OpenLolaContracts, COpenLolaAtomics,
              Darwin/Foundation/CoreAudio/AVFoundation/AppKit/CoreGraphics/
              CoreImage/CoreMedia/ImageIO/UniformTypeIdentifiers)
    ↑
open-lola-app (depends on OpenLolaCore, SwiftUI)
    ↑
open-lola-app-main (depends on open-lola-app, AppKit, SwiftUI)

open-lola (depends on OpenLolaCore, Darwin/Foundation)
```

`OpenLolaContracts` is a stability island. It must not import `OpenLolaCore`. Any type that appears in serialized reports or CLI output format belongs here or in `OpenLolaCore`'s public API.

`OpenLolaCore` is macOS-only. It uses `CoreAudio`, `AVFoundation`, and `AppKit` directly. It cannot be built for Linux.

`COpenLolaAtomics` provides `memory_order_release` / `memory_order_acquire` atomics used by `SPSCUInt64Ring` and `DirectPeerAudioPayloadRing`. Any change to the C module breaks the lock-free audio path.

---

## 6. Storage and File-System Interactions

| Surface | Path / Key | Who writes | Who reads | Notes |
|---------|-----------|-----------|----------|-------|
| Plan JSON | `~/Library/Application Support/OpenLoLa/MacToMac/plan.json` (default) | `AppExecutionController.writePlanOrLogError` | `open-lola external-connector-session-run` (CLI) | User-configurable via `AppSettings.planPath` |
| Supervisor report JSON | `…/MacToMac/supervisor.json` (default) | `open-lola` CLI stdout redirect | `AppExecutionController.validateReport` | Written by CLI, read by app for validation |
| Connection preflight report | `…/MacToMac/connection-preflight.json` | CLI preflight command | App `requirePreflight` check | Optional; gated by `requirePreflight` flag |
| Logs (stdout/stderr) | Temp paths from `AppExecutionController.defaultLogURLs()` | `ManagedProcess` stdout/stderr redirection | UI console views | Not persisted across app launches |
| Evidence reports | CLI `--output` path | CLI | Validator commands | All written atomically via `Data.write(.atomic)` |
| UserDefaults | `openLola.*` key namespace | `AppSettings` didSet observers | `AppShellStoredDefaults` on cold start | Synchronous write per UI interaction; no batching |
| Fixture files | `Tests/OpenLolaCoreTests/Fixtures/` | Manually committed | Test suite | JSON and binary; tracked by `FixtureSmokeMatrix` |

---

## 7. External APIs and Third-Party Dependencies

| API / Library | Usage | Risk |
|--------------|-------|------|
| CoreAudio (`AudioDeviceIOProcID`, `AudioObjectSetPropertyData`) | Realtime audio I/O, device enumeration, sample-rate/buffer-size mutation | High — any CoreAudio API deprecation or macOS permission change breaks the primary audio path |
| AVFoundation (`AVCaptureSession`, `AVCaptureDeviceInput`) | Video capture, LoLa AV source | Medium — camera permission required; API has changed across macOS versions |
| Foundation (`Process`, `FileHandle`, `FileManager`) | Subprocess management, I/O | Low |
| AppKit (`NSApplication`, `RawBGRAAppKitPreviewWindow`) | App lifecycle, video preview window | Low |
| Darwin BSD sockets (`sendto`, `recvfrom`, `bind`, `inet_pton`) | UDP PCM transport, LoLa control socket | Low — POSIX stable |
| `mach_timebase_info` | Converting mach absolute time to nanoseconds for packet timestamps | Low — Apple-private but stable |
| Opus 1.5.2 (vendored C) | Audio codec (`OpusCELTLowDelayCodec`) | Medium — CELT low-delay mode; C library version frozen |
| JPEG-XS `xs_ref_sw_ed2` (vendored C) | Video codec reference | Medium — reference implementation, not production-grade speed |
| JackTrip (external binary) | JackTrip connector external process | External dependency; not installed in CI |
| UltraGrid `uv` (external binary) | UltraGrid connector external process | External dependency; not installed in CI; name collides with Python `uv` |

---

## 8. Configuration Sources

| Config type | Source | Precedence |
|-------------|--------|-----------|
| CLI arguments | `CommandLine.arguments` | Per-invocation |
| Session parameters (app) | `UserDefaults` via `AppSettings` / `AppShellStoredDefaults` | Persistent; loaded at app start |
| `ExternalConnectorSessionConfiguration` | Plan JSON or CLI flags | CLI flags override JSON fields |
| Audio device UIDs | `CoreAudioInventoryReader` at runtime | Runtime (device must be connected) |
| RxBuffer policy | `AppSettings.rxBufferProfile` → `RxBufferProfile` enum | Persisted in UserDefaults |
| UltraGrid executable | `ExternalConnectorSessionConfiguration.executable` | Default: `"uv"` (PATH lookup) |
| JackTrip executable | `ExternalConnectorSessionConfiguration.executable` | Default: `"jacktrip"` (PATH lookup) |

**No environment variables** are read by the Swift CLI or app (except standard `PATH` for executable lookups). The Python connector reads env vars via its `cli` module.

---

## 9. Error-Handling Strategy

The codebase uses **typed Swift errors** throughout. Key patterns:

1. **Throw → catch at CLI boundary.** CLI commands throw; `main.swift` catches everything and formats to stderr. This is consistent and correct for the CLI.

2. **Embed in report.** For session runners (`ExternalConnectorSessionRunner`, `MadiFullDuplexRuntime`, etc.), errors are often **caught and embedded as `runtimeError: String?`** in the report struct rather than thrown. This allows partial evidence collection but means callers cannot distinguish "ran and failed" from "failed to run" without inspecting the report.

3. **Atomic counters for realtime.** Audio callback errors (dropped blocks, underruns) are tracked via `OpenLolaAtomicUInt64` counters. These are never surfaced to the app in real time — only visible in the final `RealtimeAudioEngineReport`. There is no real-time failure signal to the UI.

4. **Cleanup warnings.** `ManagedProcess` teardown returns `[ManagedProcessCleanupWarning]` rather than throwing, so cleanup failure does not abort the caller.

5. **Validation errors.** `validate()` on reports throws typed validation errors (e.g., `ExternalConnectorSessionError`, `NativeAppShellExecutionValidationError`). These are checked before writing reports.

**Weak areas:**
- Subprocess stdout parsing uses string scanning; format changes in external tools produce silent zero-counts.
- `retryResponder?.runtimeError` is captured optionally — if the background responder thread fails after the main session completes, the failure is silently incorporated into the report without failing the verdict.
- `AppSettings` `didSet` observers do not handle `UserDefaults.set` failures (which are always silent on Apple platforms).

---

## 10. Realtime Boundary Rules

The codebase documents these rules in `NativeRealtimeBoundaryReport`:

| Property | Value |
|----------|-------|
| `uiOwnsAudioLane` | `false` — UI never mutates audio path while IOProc is running |
| `realtimeDependsOnSwiftUILifecycle` | `false` — audio graph is independent of scene phase (except `tearDown` on background) |
| `usesImmutableConfigSnapshots` | `true` — `RealtimeAudioEngineConfiguration` is frozen before IOProc start |
| `latencyChangeRequiresExplicitUserAction` | `true` — RxBuffer target change outside callback |
| `settingsPersistedOutsideCallback` | `true` |

**Implications:** The audio IOProc is safe from SwiftUI re-renders. The only coupling between UI and realtime audio is:
1. App backgrounding triggers `tearDown` (SIGKILL of subprocess; does not affect native IOProc).
2. Adaptive RxBuffer changes are applied via `rxBufferAdaptationLock` outside the callback.

---

## 11. State Transitions

### 11.1 AppExecutionPhase

```
.idle
  → writePlanOrLogError → .planWritten
  → startArmed (without prior plan write, if plan.json exists) → .supervisorRunning

.planWritten
  → dryRun → .dryRunRunning
  → startArmed → .supervisorRunning

.dryRunRunning / .supervisorRunning
  → process exits 0 → .runFinished
  → process exits nonzero → .runFailed
  → stop() called → .stopRequested

.runFinished / .runFailed
  → validateReport → .validationRunning

.validationRunning
  → exit 0 → .validationPassed
  → exit nonzero → .validationFailed

.stopRequested / .validationPassed / .validationFailed / .failedToStart
  → (reset not currently modeled — UNCLEAR: there is no explicit "reset to .idle" action)
```

**Risk:** There is no guarded reset. If the phase reaches `.validationFailed` the user must restart the app or the phase will not return to `.idle` without an explicit transition not shown in code.

### 11.2 ExternalConnectorSession lifecycle

```
[not started]
  → ExternalConnectorSessionRunner.run(configuration:)
    → plan = ExternalConnectorLaunchPlan.build(configuration:)
    → if dryRun → report(verdict: .partial)          [terminal]
    → else:
      .internalLoLaControl / .internalLoLaControlUdp:
        → control exchange:
          .sent
          .received_ack → [media session]
          .receive_timeout → report(verdict: .fail)  [terminal]
          .runtime_error → report(verdict: .fail)    [terminal]
        → [media session]:
          .success → report(verdict: .pass or .partial)
          .failure → report(verdict: .fail)
      .externalProcess:
        → process.launch → process.wait → report(verdict: .partial or .fail)
```

### 11.3 DirectPeerRealtimeAudioGraph lifecycle

```
[allocated]
  → startCapture(deviceID:) → [capturing]
  → startPlayback(deviceID:) → [capturing + playing]

[capturing + playing]
  → atomic counters update per callback
  → adaptiveRxBuffer may adjust targetFrames (outside callback)

[capturing + playing]
  → stopAndTearDown()
    → AudioDeviceStop (input)
    → AudioDeviceStop (output)
    → AudioDeviceDestroyIOProcID (input)
    → AudioDeviceDestroyIOProcID (output)
    → restore original sample rate and buffer size
    → [torn down]
```

Teardown failures are recorded in `latestCleanupResult` but do not throw.

---

## 12. Compatibility and Deprecation Layers

### 12.1 LoLa Protocol Compatibility

`Sources/OpenLolaCore/Connectors/LoLa/` implements clean-room reverse-engineered LoLa protocol compatibility:
- `LoLaCompatibilityControlMessage` — text-encoded control handshake.
- `LoLaCompatibilityUdpMedia` — source-level audio/video UDP envelope.
- `LoLaCompatibilityCaptureReport` — passive pcap decoder for packet capture analysis.

These are compatibility shims for LoLa interoperability. Their packet format is fixed by the LoLa protocol — changing them breaks compatibility with real LoLa endpoints.

`LoLaParityDeferredFeatures` in `Sources/OpenLolaCore/Release/` is a deferred-feature ledger (not runtime logic).

### 12.2 JackTrip Protocol Compatibility

`Sources/OpenLolaCore/Connectors/JackTrip/JackTripCompatibility.swift` (764 lines) is the primary JackTrip interop surface. It implements JackTrip packet format, TCP handshake, and audio payload codec. Tests in `JackTripCompatibilityTests.swift` (768 lines) both exceed the 720-line LOC budget — a signal that these files carry significant complexity and may need splitting.

### 12.3 UltraGrid Compatibility

`Sources/OpenLolaCore/Connectors/UltraGrid/` — UltraGrid RTP/JPEG/H.264 payload codecs, FEC, and encryption mode abstractions. `UltraGridCompatibility.swift` orchestrates the session. The launch plan argument construction has a known bug (F2 in the test failures: wrong RX argument order).

### 12.4 `OpenLolaContractsAliases.swift`

`Sources/OpenLolaCore/Core/OpenLolaContractsAliases.swift` re-exports `OpenLolaContracts` types via `typealias` for backwards compatibility within `OpenLolaCore`. This is a compatibility shim — it exists to avoid widespread import changes. **Do not remove without checking all callsites.**

### 12.5 `script/` vs `scripts/`

Two separate directories with a confusing naming convention:
- `scripts/` — release, verification, Docker, hygiene helpers. Included in release candidate export.
- `script/` — legacy app bundle helpers (`build_and_run.sh`, `build_cli_app_bundle.sh`). **Not included in the release candidate export.** Any docs referencing `script/` paths in backticks will fail the release hygiene gate.

---

## 13. Public Contracts That Must Not Break

These surfaces have downstream consumers (tests, validators, docs, plans, fixtures) that will silently or loudly break if changed:

| Contract | Location | What breaks if changed |
|----------|----------|----------------------|
| `MeasurementVerdict` raw values (`pass`, `fail`, `partial`) | `OpenLolaContracts/MeasurementVerdict.swift` | All serialized reports, CLI output parsers, Python connector tests |
| `RxBufferProfile` raw values | `OpenLolaContracts/RxBufferProfile.swift` | UserDefaults round-trips, serialized configurations, RxBuffer policy tests |
| `UdpPcmPacketHeader` byte layout and magic `OLPC` | `OpenLolaCore/Network/UDP/UdpPcmPacket.swift` | All packet-level interoperability; fixture hex files in `Tests/Fixtures/` |
| `UdpMediaPacketHeader` byte layout and magic `OLMP` | `OpenLolaCore/Network/UDP/UdpMediaTransport.swift` | Session-level multi-stream transport |
| `ExternalConnectorSessionConfiguration` fields | `OpenLolaCore/Connectors/Core/ExternalConnectorSession.swift` | `plan.json` deserialization; any stored plans break on field rename |
| CLI command names and argument counts | `open-lola/main.swift` `openLolaCommands()` | Shell scripts, app launch invocations, documentation, tests |
| Report JSON field names | All `ReportValidatingArtifact` conformers | `validate-*` CLI commands, fixture JSON files, Python connector schema tests |
| `LoLaCompatibilityControlMessage` message format | `OpenLolaCore/Connectors/LoLa/LoLaCompatibilityControlMessage.swift` | LoLa protocol interoperability with real LoLa endpoints |
| `JackTripAudioPacket` wire format | `OpenLolaCore/Connectors/JackTrip/JackTripProtocolModel.swift` | JackTrip interoperability |
| `AppStorageKeys` string values (`openLola.*`) | `open-lola-app/AppStorageKeys.swift` | UserDefaults persistence across app upgrades |
| Fixture file tree structure and counts | `Tests/OpenLolaCoreTests/Fixtures/` + `FixtureSmokeMatrixData.swift` | `fixtureSmokeMatrixMatchesFixtureTree` test |

---

## 14. Hidden Coupling

| Coupling | Files involved | Risk |
|----------|--------------|------|
| `docs/` backtick paths checked against release candidate tree | `scripts/verify_docs/markdown_checks.py` checks all docs; `scripts/export-release-candidate.sh` controls what is exported | Medium — adding `script/` backtick paths in any doc breaks the release gate (demonstrated by `docs/code-index.md` regression) |
| `FixtureSmokeMatrixData` hardcoded counts must match Fixtures/ tree | `FixtureSmokeMatrixData.swift`, `Tests/Fixtures/` | Low — adding a fixture directory without updating `FixtureSmokeMatrixData` silently drifts until the test catches it |
| `CLICommandInventory.entries` must stay in sync with `main.swift` command registry | `CLICommandInventory.swift`, `main.swift` | Medium — `command-inventory` reports a static list; actual commands dispatched differ if one is added to main.swift but not the inventory |
| `NativeAppShellSurfaceContract.releaseReadiness` actions list must match `AppMenuActionHandling.handledActionIDs` | `NativeAppShellSurfaceContract.swift`, `OpenLolaApp.swift` | Low — unmatched action IDs render as disabled "Unsupported" menu items |
| `ExternalConnectorReport.assumptions` strings must match test substring expectations | `ExternalConnectorReport.swift:315`, `SyntheticSmokeReportContractTests.swift:76` | Low — already broken (F7 in test failures) |
| `GoalCodewiseClosureReport` cross-references `GOAL.md` by parsing doc text | `GoalCodewiseClosure.swift`, `GOAL.md` | Medium — GOAL.md edits may silently change codewise closure verdict |
| `PlaceholderDetection` scans source files for known placeholder strings | `PlaceholderDetection.swift`, multiple source files | Low — adding a legitimate use of a placeholder keyword causes false positives |
| UserDefaults keys used both in `AppStorageKeys` (Swift) and `AppShellStoredDefaults` | `AppStorageKeys.swift`, `AppShellStoredDefaults.swift` | Medium — key rename breaks settings migration for existing users |
| `UltraGridCompatibility` launch plan argument order is wrong for RX role | `UltraGridCompatibility.swift` or `ExternalConnectorLaunchPlan` | High — known active bug (F2 in test failures); UltraGrid RX sessions produce wrong args silently |

---

## 15. Flow Analysis: What Can Run Without Crashing But Produce Wrong Results

| Flow | Wrong-result scenario |
|------|-----------------------|
| CLI inventory commands | Always return `verdict: .partial`. A consumer treating `.partial` as confirmation of readiness will be misled. |
| `goal-codewise-closure` | Reports readiness based on source file presence and GOAL.md text matching. A file can exist and be hollow; the report will still count it as present. |
| `external-connector-session-run` (dry run) | Returns `.partial` and includes a plan — but the plan may have argument-order bugs (UltraGrid RX). The dry run does not validate argument correctness. |
| `external-connector-session-run` (live LoLa) | Control handshake can succeed while media transport carries zero packets. Report verdict may be `.partial` with non-zero control and zero media. |
| `audio-loopback-run` | Runs against the built-in audio device. Will report round-trip latency and `verdict: .partial` but this is not MADI evidence. Misinterpreting the device UID as "real hardware" gives false confidence. |
| `goal-runtime-preflight-run` | Checks executables in PATH. If `uv` (Python tool) is in PATH, UltraGrid preflight reports a non-nil result that may or may not be accurate. |
| App `refreshSyntheticMetrics` | Runs `NativeAppShellSyntheticSmoke.run()` and updates the UI report. This is always synthetic — no hardware is queried. The UI will show populated fields based on code-path logic, not live device state. |
| `session-capabilities` | Emits `verdict: .pass`. This is the **only** command that emits `pass` without hardware evidence. It checks localhost UDP PCM smoke only. |
| DirectPeer audio session — drop counters | Dropped input/output blocks increment counters silently. A session with significant dropout still writes `verdict: .partial` and may be mistaken for a healthy session if metrics are not inspected. |

---

## 16. Not Fully Understood / UNCLEAR

| Area | What is UNCLEAR | What would prove it |
|------|----------------|-------------------|
| `AppExecutionController` test coverage | No test file matching `AppExecutionController` was found in `Tests/`. | `grep -r "AppExecutionController" Tests/` to confirm or deny. |
| `NativeAppShellSearchAndPacketMonitor` | File exists but its relationship to the live session (polling interval, thread ownership, whether it ever runs in production) is not verified from code alone. | Read `NativeAppShellSearchAndPacketMonitor.swift` fully; find all call sites. |
| `AppLocalOperatorInventoryController` | Manages the "operator prototype" inventory, but whether it polls or is event-driven is UNCLEAR. | Read `AppLocalOperatorInventory.swift` and `AppLocalOperatorSurfaceView.swift`. |
| `RecordingSessionLiveCapture` | Files exist under `Sources/OpenLolaCore/Release/` for live recording sessions — relationship to the app execution flow is UNCLEAR. | Check if `AppExecutionController` calls any `RecordingSession*` types. |
| `PackagingFieldTest` | Purpose and integration point is UNCLEAR. Whether it runs in CI or manually only is not confirmed. | Check `swift test --filter PackagingFieldTest` and callers in CLI command list. |
| `DriftPlc*` timing path | `DriftPlcRun`, `DriftPlcReport`, `DriftPlcHelpers` exist for drift/PLC timing. Whether this is wired into the live realtime audio graph or only as a standalone measurement is UNCLEAR. | Check callers of `DriftPlcRun.run()`. |
| `VideoTransportMultiStreamRuntime` vs `VideoTransportRunner` | Two video transport runners exist. Which is active in the production app path vs the CLI path is UNCLEAR. | Trace callers of both from `AppExecutionController` and `NetworkCommands.swift`. |
| `BlackmagicOutputBoundary` | Evidence boundary for Blackmagic video output. Whether this is ever called at runtime or only appears in inventory reports is UNCLEAR. | `grep -r "BlackmagicOutputBoundary" Sources/` for callers. |
| `OpenLolaCLI.localCapabilitySet()` | Called by `session-capabilities`. What hardware checks it performs beyond UDP PCM localhost smoke is UNCLEAR. | Read `OpenLolaCLI.swift` fully. |
| `NativeAppShellOperatorPrototypeState+RunPlan.swift` | The `+RunPlan` extension likely contains the plan-to-CLI-args translation. Whether it handles all session modes (`windowsLoLa`, `jackTrip`, `ultraGrid`) correctly is UNCLEAR. | Read the file; check `prepareExecution()` in `OpenLolaApp.swift`. |

---

## 17. Highest-Risk Coupling Points

1. **`DirectPeerRealtimeAudioGraph` CoreAudio IOProc** — Any CoreAudio API change, permission denial, or device removal while running will cause silent failures (underrun/overrun counters increment; no throw; no UI alert).

2. **`UdpPcmPacket` wire format** — The 48-byte header is the network protocol. Any change breaks all in-flight packets and stored fixture files.

3. **Plan JSON (`ExternalConnectorSessionConfiguration`)** — The app writes a JSON plan; the CLI reads it. Any field addition with no default or any field rename is a breaking serialization change.

4. **`SPSCUInt64Ring` thread ownership** — The SPSC contract requires single-producer / single-consumer ownership. A refactor that inadvertently adds a second producer/consumer thread causes a data race in the audio callback without any compile-time warning (the `@unchecked Sendable` conformance bypasses Swift concurrency checking).

5. **UserDefaults key namespace** — `AppStorageKeys` string literals are the persistence contract. Any rename silently loses existing settings on upgrade.

6. **`GoalCodewiseClosure` / `GOAL.md` text coupling** — Release readiness reports depend on GOAL.md text parsing. Reformatting GOAL.md without updating the parser changes the closure verdict without any test failure.

---

## 18. Coverage Gaps in This Map

- **`linux_connector/` internals** — The Python connector's internal class structure, its error handling, and the full set of protocol scenarios it covers are not mapped here. See `linux_connector/docs/protocol-reference.md`.
- **SwiftUI view layer** — View bindings, animation, and state observation paths are not mapped. UI behavior is tested via `NativeAppShellSurfaceContractTests` but not rendered-view tests.
- **`xs_ref_sw_ed2` / `opus-1.5.2` internals** — Vendored C libraries are treated as black boxes. Their error handling and API surface are not mapped.
- **`scripts/` shell scripts** — Internal logic of Docker parity scripts, stress scripts, and export scripts is not mapped beyond their command signatures.
- **Multi-machine SSH execution path** — `AppSettings.executionMode == .ssh` triggers an SSH-based two-machine run via `scp`/`ssh`. This path is present in `NativeAppShellExecution.swift` but not traced end-to-end here.
