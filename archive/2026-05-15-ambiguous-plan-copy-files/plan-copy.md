# open-lola2 Full Audit and Remediation Plan

Status: ACTIVE
Date: 2026-05-14
Scope: read-only audit of first-party Swift, Python, shell, PowerShell, app UI, runtime media paths, connector paths, release tooling, and related tests/docs contracts.
Repository note: this checkout is not a Git worktree, so evidence is filesystem-based, not Git-diff-based.
Artifact note: this root `plan.md` is intentionally present because it was requested. Earlier docs conventions preferred archiving root plan files after closure; this file should be archived after remediation is complete.

## Audit Method

- Local inventory covered 733 Swift/Python/shell first-party source and test files.
- Owned-code line inventory, excluding large vendored/reference drops, found about 136k lines across `Sources/OpenLolaCore`, `Sources/open-lola`, `Sources/open-lola-app`, `Tests/OpenLolaCoreTests`, `linux_connector/lola_connector`, `linux_connector/tests`, `scripts`, and `script`.
- Six read-only subsystem audits were run in parallel:
  - realtime audio, CoreAudio, MADI, codec, and local RX
  - UDP, P2P, NAT, control, and direct-peer CLI
  - video, AV sync, connectors, release media artifacts, and packaging
  - macOS SwiftUI app, NativeAppShell, menus, state, and operator UX
  - Python connector, shell, PowerShell, Docker, and release helpers
  - cross-cutting structure, release boundaries, docs contracts, dead code, and source ownership
- Local static scans searched for sleeps, busy polling, detached/global concurrency, `Data(contentsOf:)`, forced casts, process handling, source-text tests, generated residue, and oversized files.
- No source code was changed. No full build/test/user-surface matrix was run because this was requested as a no-code audit.

## Three-Pass Lens Coverage

The enrichment pass on 2026-05-14 reran the audit with at least three passes for every requested lens. The pass model was deliberately redundant: local static scans, delegated subsystem reading, and synthesis against the existing plan had to agree before a finding was added.

| Lens | Pass 1 | Pass 2 | Pass 3 |
| --- | --- | --- | --- |
| Slop | Local generated-residue/TODO/cache scan across first-party surfaces | Slop/dead-code subagent review of source, tests, docs, release hygiene | Synthesis against docs gate, release hygiene, source-string coverage |
| Boilerplate | Largest-file and repeated helper scan | Refactor/dedup subagent review of module boundaries and repeated process/report helpers | Synthesis into line-budget, source-text, and shared-helper remediation |
| Dead code | TODO/human, unused state, generated residue, missing-test scan | UI/tooling/test subagents searched dormant controls and non-executed tests | Synthesis into pinned TODO, missing `@Test`, dead UI state, and cache findings |
| Refactor | File responsibility and line-budget inventory | Structure subagent reviewed target boundaries, ownership, and app/CLI testing shape | Synthesis into target split, source ownership, line-budget, and process runner findings |
| Dedup | Repeated `Data(contentsOf:)`, process runner, source-read helper, and action-menu scans | Refactor and UI subagents reviewed duplicated app/CLI/menu/report patterns | Synthesis into bounded reads, process-runner, menu inventory, and source-test findings |
| Structure | Package target, release manifest, ownership inventory, docs authority scans | Structure and verification subagents reviewed root plan/docs contract and target coverage | Synthesis into active-plan gate, release boundary, executable/app behavior coverage |
| Code quality | Error handling, `try?`, catch, forced/trapping, process, and dependency scans | Code-quality subagent reviewed bounds, parsing, lifecycle, and invariant handling | Synthesis into Python parsing, unbounded settings, clamping, payload validation |
| Logic | Runtime scheduling, sequencing, state derivation, verdict, PASS/PARTIAL scans | Runtime and UI subagents reviewed realtime, UDP/P2P, video, control, TX/RX, state | Synthesis into stale evidence, unauthenticated control, RX aborts, metrics gaps |

Additional read-only checks observed during the enrichment:

- `bash scripts/verify-docs.sh`: FAIL because active root `plan.md` lacks the companion root ledger/status files required by the docs verifier.
- `bash scripts/verify-release-readiness.sh`: FAIL at the docs gate for the same reason.
- `bash scripts/verify-release-hygiene.sh`: PASS despite live forbidden residue, proving a false-green no-candidate mode.
- `ruff check --no-cache linux_connector scripts`: PASS in the delegated tooling lane.
- `python -m mypy --strict linux_connector/lola_connector`: PASS in the delegated tooling lane.
- `python3 -B -m pytest -p no:cacheprovider linux_connector/tests`: PASS, 58 passed and 2 skipped in the delegated tooling lane.
- `shellcheck` over audited shell helpers: PASS in the delegated tooling lane.

## Priority Semantics

- P0: immediate blocker, data corruption, unsafe runtime behavior that must stop release work. No P0 was found in this static pass.
- P1: high-risk runtime correctness, hang, leak, broken operator behavior, release-truthfulness, or source boundary issue.
- P2: correctness edge case, maintainability, test quality, performance, UI polish, slop, deduplication, or architecture improvement.

## P0 Findings

No P0 findings were confirmed in this read-only audit.

## P1 Findings

F-001 P1 Realtime audio graph double-start can leak live CoreAudio IOProcs.
Evidence: `DirectPeerRealtimeAudioGraph.start()` starts unconditionally at `Sources/OpenLolaCore/Audio/Realtime/DirectPeerRealtimeAudioGraph.swift:143`, passes `self` unretained to callbacks at line 201, callbacks recover it unretained in `DirectPeerRealtimeAudioGraphCallbacks.swift:84`, and `stop` destroys only currently stored IDs at `DirectPeerRealtimeAudioGraph.swift:228`.
Remediation: make `start()` idempotence explicit by rejecting start when IOProc IDs or `ioProcRunning` are already set; preserve original device state only once.
Verification: fake CoreAudio ops test proving a second start throws and only one IOProc exists.

F-002 P1 Realtime playout scheduling can wrap far-future packets into immediate playout.
Evidence: `queuePlayoutPayload` computes due frames using wrapping addition in `DirectPeerRealtimeAudioGraph.swift:306`.
Remediation: replace wrapping arithmetic with checked addition and a typed overflow/drop outcome.
Verification: queue a payload near `UInt64.max` and assert it is rejected or counted, not scheduled immediately.

F-003 P1 Realtime payload shape byte-count multiplication is unchecked.
Evidence: `RealtimeAudioPayloadShape.byteCount` multiplies frame count, channel count, and sample bytes in `RealtimeAudioBuffers.swift:36`.
Remediation: centralize checked byte-count helpers for all audio/video payload sizing.
Verification: invalid huge frame/channel combinations return typed validation errors, not traps.

F-004 P1 MADI ready-block ring accepts a far-future first packet.
Evidence: `MadiReceiveBuffers.swift:281` computes a future horizon, but line 286 bypasses it when the ring is empty.
Remediation: apply the future-window check before inserting the first block.
Verification: first packet at sequence 99 with expected sequence 0 is reported as future-dropped.

F-005 P1 Direct audio routing copies receiver state per packet under lock.
Evidence: `DirectAudioMediaRouter.swift:21` pulls a value `MadiReceiveEngine` from a dictionary, mutates it, then stores it back; the engine owns array-backed realtime state in `MadiReceive.swift:12`.
Remediation: use reference boxes or an in-place mutation API for per-receiver state.
Verification: allocation benchmark around repeated `route(_:)` calls.

F-006 P1 Audio preview meter assumes CoreAudio buffers are Float32.
Evidence: `AppReceiverPreviewServices.swift:315` uses `assumingMemoryBound(to: Float32.self)` for audio level extraction.
Remediation: read the device stream format and convert supported formats, or request a known float format.
Verification: meter tests for Float32 and Int16 buffers plus one real-device smoke probe.

F-007 P1 Control UDP accepts arbitrary parseable datagrams without source filtering.
Evidence: `DirectPeerSessionSocketRunner.swift:573` receives control datagrams without source endpoint data; sends use the expected remote endpoint at line 554, and decoded messages mutate state in `PeerSessionRunner.swift:665`.
Remediation: use connected UDP or `recvfrom` source checks, then validate expected peer/session IDs before state mutation.
Verification: forged `sessionAccept` and `shutdown` from a third socket are ignored.

F-008 P1 Control socket factory leaks descriptors on partial initialization failure.
Evidence: `DirectPeerSessionSocketRunner.swift:522` and line 536 create descriptors before bind/nonblocking calls without the cleanup guard used in `UdpMediaTransport.swift:303`.
Remediation: mirror the `succeeded` cleanup guard pattern for all control socket factories.
Verification: occupied-port or injected-nonblocking-failure tests assert descriptors are closed.

F-009 P1 Unbounded positive CLI integers can trap in runtime arithmetic.
Evidence: `DirectP2PSessionRunCommandSupport.swift:411` accepts any positive `Int`; video budget multiplication happens in `DirectPeerSessionAVRunTypes.swift:140`; timeout conversion multiplies in `DirectPeerSessionSocketRunner.swift:515`; NAT duration multiplies in `NatFriendlyRouteRunner.swift:58`.
Remediation: add bounded parsers and overflow-reporting arithmetic with typed invalid-argument errors.
Verification: `Int.max` dimensions, frame rates, timeouts, and durations fail cleanly.

F-010 P1 Two-peer local supervisor can hang forever after children launch.
Evidence: readiness is bounded in `DirectP2PTwoPeerLocalRunCommandSupport.swift:67`, then both children are waited with unbounded `waitUntilExit` at line 81.
Remediation: add a run timeout derived from child duration plus slack, terminate/kill on expiry, and still emit partial process results.
Verification: fake child sleeps past timeout; supervisor exits with a failed report.

F-011 P1 UDP probes rely on fixed sleeps instead of readiness handshakes.
Evidence: `UdpPcmContinuousRouteRunner.swift:88` launches a receiver queue and line 103 uses `Thread.sleep(0.05)`; related loopback/NAT smokes repeat this pattern.
Remediation: signal readiness after bind/nonblocking setup and wait on a semaphore or socket readiness primitive.
Verification: stress test under CPU load has deterministic startup and no arbitrary sleep.

F-012 P1 UDP receive loops busy-poll with `usleep`.
Evidence: `UdpPcmContinuousRouteRunner.swift:276`, `UdpPcmLoopbackSocketRunners.swift:73`, `NatFriendlyRouteRunner.swift:127`, and `DirectPeerSessionAVSocketRunner.swift:454` use micro-sleeps in receive/scheduling loops.
Remediation: replace polling sleeps with `poll`, `select`, `kevent`, or a bounded wait abstraction that wakes on socket readiness or deadline.
Verification: local route tests pass with lower CPU and without timing flakes.

F-013 P1 UDP loss metrics can undercount real loss when duplicates are present.
Evidence: `collectReceiverMetrics` increments received packets before duplicate handling and computes loss from total packet count minus received count in `UdpPcmContinuousRouteRunner.swift:297`.
Remediation: count unique accepted sequence numbers separately from duplicates, late packets, and reordered packets.
Verification: packet stream with skipped and duplicated sequences reports loss, duplicates, and reorders independently.

F-014 P1 Fastest production AV sync can drop or defer nearly all real video.
Evidence: `MediaClock.swift:311` gives `directAudioFirst` zero tolerance/defer/drop thresholds; synthetic widening happens in `DirectPeerSessionAVSocketRunner.swift:340`; RX compares raw video timestamps in `DirectPeerSessionAVVideoLoops.swift:36`; AVFoundation frames are presentation-time timestamps in `VideoCaptureAVFoundation.swift:407`.
Remediation: convert video timestamps to the same host-time basis as audio and give production fastest a bounded latest-frame tolerance.
Verification: production-like AVFoundation timestamp tests for `directAudioFirst` with plus/minus one frame offset.

F-015 P1 Deferred video RX silently overwrites older deferred frames.
Evidence: one deferred slot is retried in `DirectPeerSessionAVVideoLoops.swift:60`, then each new deferred frame overwrites it at line 106 without a replaced/drop metric.
Remediation: use a bounded latest-only queue with explicit replaced-frame accounting.
Verification: two early video frames before audio anchor retain one and count one as replaced.

F-016 P1 Raw video recording retention trims indexes but not backing memory.
Evidence: raw frame bytes append to one `Data` in `VideoCaptureAVFoundation.swift:535`; trim advances `rawFrameDataBaseOffset` at line 554 but does not compact backing storage; recording enables raw capture in `RecordingSessionLiveCapture.swift:365`.
Remediation: compact after a threshold or switch artifacts to chunked/file-backed storage.
Verification: after more than `maxRetainedRawFrameCount` BGRA frames, backing byte count remains bounded.

F-017 P1 External connector subprocesses can block on full stdout/stderr pipes.
Evidence: pipes are attached in `ExternalConnectorProcessRunner.swift:106`, but output prefixes are read only after process exit at line 132 and in `ExternalConnectorSessionRuntime.swift:111`.
Remediation: drain stdout/stderr asynchronously into bounded ring buffers or temp logs while the process runs.
Verification: fake connector writes more than pipe capacity and sleeps; runner does not hang.

F-018 P1 Python connector runtime startup can leak sockets if setup fails midway.
Evidence: `linux_connector/lola_connector/runtime.py:96` allocates audio/video/control sockets and tasks without a setup cleanup guard; cleanup only exists in `stop()` at line 113.
Remediation: wrap startup in `try/except`, cancel created tasks, close opened sockets, and close backends on failure.
Verification: fake `make_udp_socket()` failing on second or third socket leaves no open earlier sockets and no tasks.

F-019 P1 Python video subprocess capture lacks audio-equivalent cleanup.
Evidence: audio capture cleans failed start/read paths in `backends.py:317` and line 344; raw/JPEG video reads at lines 414 and 450 do not close/reset on EOF, `IncompleteReadError`, cancellation, or stdoutless failure.
Remediation: share the audio lifecycle helper or add equivalent cleanup paths to raw/JPEG video capture.
Verification: subprocess exits early; `process is None` and no child remains.

F-020 P1 Native app stop state can be overwritten after termination.
Evidence: `AppExecutionController.swift:229` writes a stop-requested report, but the termination handler at line 332 later sets `Run finished` or `Run failed` and calls `finishReport()` without preserving stop state.
Remediation: track a stop-requested flag through termination and preserve it in final report construction.
Verification: controller test with injectable process runner proves final report keeps `stopRequested == true`.

F-021 P1 Native app process termination race can lose final report state.
Evidence: `AppExecutionController.launchProcess` assigns the process after `run()` at lines 343-344, but the termination handler can fire first and return because `self.process` is still nil or stale.
Remediation: assign process before `run()` and clear it on run failure, matching the safer one-shot pattern.
Verification: immediate-exit process test still produces a final report.

F-022 P1 Native app process file handles are not explicitly closed.
Evidence: `AppExecutionController.swift:330` and line 357 create output/error `FileHandle`s for child processes without retaining and closing them on termination.
Remediation: retain handles for the active process and close them in termination and failure paths.
Verification: repeated runs do not increase open file descriptor count.

F-023 P1 SSH execution mode is exposed but not configurable in the app.
Evidence: `NativeAppShellExecution.swift:43` requires SSH targets/executables; `AppShellSettingsView.swift:436` exposes only execution mode, executable, plan/report paths, and preflight; `AppShellStoredDefaults.swift:203` hydrates only mode/preflight/paths.
Remediation: expose and persist SSH target/workdir/executable fields or remove SSH mode from the GUI.
Verification: settings test asserts generated supervisor args contain configured SSH values.

F-024 P1 Remote inventory import mutates state before validation.
Evidence: `NativeAppShellArtifacts.swift:77` assigns `remoteInventory` before validation; UI catches the failure in `AppOperatorArtifactViews.swift:102`, but state can already be changed.
Remediation: decode and validate into a candidate value, commit only after validation succeeds.
Verification: failing import leaves operator state unchanged.

F-025 P1 Release hygiene reports PASS while forbidden generated artifacts are present.
Evidence: `.gitignore:23` and `linux_connector/.gitignore:1` forbid Python caches and `.DS_Store`; live scope contains `__pycache__/*.pyc` and `linux_connector/.DS_Store`; `scripts/verify-release-readiness.sh:171` calls hygiene without a candidate, and `scripts/verify-release-hygiene.sh:189` only prints a notice in no-candidate mode.
Remediation: scan the live checkout for forbidden generated artifacts or make release-readiness stage and scan a candidate.
Verification: temp `.pyc` and `.DS_Store` fixtures make the hygiene gate fail.

F-026 P1 UltraGrid Docker image policy is bypassed by parity/run helpers.
Evidence: `scripts/open-lola-ultragrid-docker-policy.sh:4` rejects `latest`; docs claim helpers reject mutable `latest`; `compare-local-ultragrid-parity-docker.sh:11` and `run-local-ultragrid-rxtx-docker.sh:14` read `OPEN_LOLA_ULTRAGRID_DOCKER_IMAGE` directly.
Remediation: source the policy helper in both scripts and resolve the image through `open_lola_required_ultragrid_docker_image`.
Verification: `OPEN_LOLA_ULTRAGRID_DOCKER_IMAGE=latest` exits before Docker runs.

F-027 P1 WSL networking helper is destructive without strict/dry-run controls.
Evidence: `linux_connector/env/enable_wsl_lola_network.ps1:1` uses `Continue`, overwrites `.wslconfig` at line 14, opens broad firewall rules at lines 16 and 27, and shuts down WSL at line 53.
Remediation: add `Set-StrictMode -Version Latest`, `$ErrorActionPreference = 'Stop'`, `SupportsShouldProcess`, backup/merge `.wslconfig`, and narrow firewall scope.
Verification: Pester `-WhatIf` proves no write/firewall/shutdown calls execute.

F-028 P1 Release/source boundary includes large uncompiled vendor trees.
Evidence: `Package.swift:61` defines vendored C targets and manually lists selected Opus sources starting at line 73; `docs/compliance/release-manifest.md:18` allowlists `Sources/**`; `Sources/opus-1.5.2` includes large upstream extras such as `.github`, tests, training, and DNN folders.
Remediation: move raw upstream drops outside release-included `Sources/` or make the exporter include only compiled subsets plus notices.
Verification: release candidate contains no vendored `.github`, tests, training, or unused build-system files.

F-029 P1 `OpenLolaCore` is platform/runtime-heavy instead of a clean core boundary.
Evidence: `Package.swift:28` publishes `OpenLolaCore` with codec targets and line 43 links AppKit, AVFoundation, CoreAudio, CoreGraphics, CoreImage, ImageIO, CoreMedia, and UniformTypeIdentifiers.
Remediation: split pure protocol/report/validation contracts from macOS runtime adapters.
Verification: pure contracts target builds without Apple framework linkage; app/CLI targets still pass.

F-030 P1 Source-text tests encode implementation shape instead of behavior.
Evidence: `AppShellSourceContractTests.swift:7` reads source files and asserts substrings across a large test; `ReleaseArtifactHygieneContractTests.swift:5` follows the same pattern.
Remediation: keep source-text tests only for script/release policy; replace UI/runtime assertions with API-level, model, controller, and report behavior tests.
Verification: behavior-neutral rename/split does not fail tests.

F-031 P1 Source ownership inventory can produce false coverage.
Evidence: `SourceOwnershipInventoryTests.swift:41` only checks that every source path maps to some entry; `SourceOwnershipInventory.swift:131` falls back from exact paths to broad prefixes, including roots at line 423.
Remediation: distinguish exact ownership from fallback-only ownership and fail when new files rely only on coarse prefixes unless explicitly allowed.
Verification: inventory test reports unmatched and fallback-only files separately.

F-032 P1 Architecture docs contain stale code-path contracts.
Evidence: `docs/architecture/blackmagic-video-rx-tx.md:91`, `multichannel-audio-routing.md:85`, and `madi-full-rx-tx.md:83` list planned or missing files as if they were current source contracts.
Remediation: mark planned paths explicitly or update them to current source paths; add a docs verifier for backticked source/test paths.
Verification: docs verifier plus markdown path-existence check.

F-075 P1 Active root `plan.md` currently breaks the docs and release-readiness gates.
Evidence: this file is active at `plan.md:3`; `scripts/verify_docs/markdown_checks.py:169` requires active root `plan.md` to have root `plan-findings-ledger.md` and `plan-status.md`; `scripts/verify-release-readiness.sh:166` runs the docs gate first; `README.md:39` and `docs/current-state.md:77` still describe the previous plan closure as archived.
Remediation: while this audit is active, either add the required root companion artifacts and update docs routing, or archive/remove root `plan.md` after audit closure.
Verification: `bash scripts/verify-docs.sh` and `bash scripts/verify-release-readiness.sh` pass.

F-076 P1 Release hygiene false-greens in no-candidate mode while forbidden residue exists.
Evidence: `.gitignore:23` and `docs/compliance/release-manifest.md:52` forbid Python caches and `.DS_Store`; live inventory found `.DS_Store`, `__pycache__`, and `.pyc` files under root, `Sources`, `docs`, `linux_connector`, and `scripts/verify_docs`; `scripts/verify-release-hygiene.sh:189` only scans a candidate when supplied and still prints `VERDICT: PASS` at line 196.
Remediation: make no-candidate mode scan the live checkout, or require a staged candidate before any PASS verdict; include `.pytest_cache`, `.ruff_cache`, and `.mypy_cache`.
Verification: live and candidate fixtures containing `.DS_Store`, `__pycache__`, `.pyc`, `.pytest_cache`, `.ruff_cache`, and `.mypy_cache` fail.

F-077 P1 Source-string tests are broad enough to create fake coverage.
Evidence: local and delegated scans found hundreds of `source.contains` / `readText` assertions across many test files; examples include `AppShellSourceContractTests.swift:8`, `AudioLoopbackRunTests.swift:198`, `DirectAudioMediaRouterTests.swift:6`, `MediaClockTests.swift:40`, and `ReleaseArtifactHygieneContractTests.swift:153`.
Remediation: keep source-string checks only for explicit policy and forbidden-token contracts; replace runtime, UI, and release behavior assertions with typed behavior tests, fakes, or script execution.
Verification: behavior-neutral refactors pass, while actual behavior regressions fail.

F-078 P1 Executable and app behavior coverage is structurally weak.
Evidence: `Package.swift:224` defines executable targets separately, while the only test target depends on `OpenLolaCore` at `Package.swift:236`; CLI and app coverage then falls back to source-text checks in `CLICommandInventoryTests.swift:60` and `AppShellSourceContractTests.swift:7`.
Remediation: extract testable app/CLI support targets or add integration tests that execute real binaries and the app surface.
Verification: focused app/CLI behavior tests and a native app launch/screenshot probe fail on real behavior regressions.

F-079 P1 Current UI/runtime probes do not prove launched app behavior.
Evidence: `scripts/verify-release-readiness.sh:190` runs `native-app-shell-surface-probe`, but `MilestoneCommands.swift:300` constructs it from synthetic contract data and `NativeAppShellSurfaceContract.swift:361` still records that launched-window evidence is missing.
Remediation: add a real app surface probe that builds/launches the app, captures screenshot or log evidence, and validates expected sections/controls.
Verification: release readiness fails when the app cannot launch or required UI evidence is missing.

F-080 P1 Windows LoLa mode can surface stale Direct-P2P evidence as current live status.
Evidence: `AppExecutionController.swift:416` always loads latency from `settings.supervisorReportPath`, even after Windows LoLa execution starts at line 292; `AppShellRootView.swift:250` treats any `lastLatencyMetrics` as runtime evidence, and `AppSessionStateBanner.swift:137` can show live state from that evidence.
Remediation: scope latency/report loading by execution kind; Windows LoLa must use only external connector reports and must not reuse Direct-P2P supervisor artifacts.
Verification: Windows LoLa run with stale supervisor report present shows no stale latency hero, no packet monitor capture, and no `.live` state.

F-081 P1 Manual handoff intent can show CONNECTING before a configured or running session exists.
Evidence: `OpenLolaApp.swift:75` enables Set Handoff Intent whenever not running; `AppLocalOperatorSurfaceView.swift:326` mutates intent directly; `AppSessionStateBanner.swift:153` derives `.connecting` before checking whether the surface is configured.
Remediation: gate handoff intent mutation behind configured session state or make command intent execution-derived only.
Verification: unconfigured state plus `handoffRequested` remains `.unconfigured`, and menu/debug controls are disabled until configured.

F-082 P1 Linux LoLa control loop lets non-session control packets toggle TX.
Evidence: `linux_connector/lola_connector/runtime.py:256` accepts control datagrams and calls `handle_control_message` at line 304; `linux_connector/lola_connector/connector.py:316` session-checks disconnect only, while send/stop audio actions at lines 328-331 can mutate TX state without sender/SID validation.
Remediation: require source address, message source IP, and SID to match the active session before any state-changing action.
Verification: forged `MESG_SEND_AUDIO_SIGNAL` and `MESG_STOP_AUDIO_SIGNAL` from a third address do not alter TX state.

F-083 P1 AES67 and Opus RX errors can abort the AV run instead of becoming drop metrics.
Evidence: `AES67ST2110L24Transport.swift:188` throws on payload, sequence, timestamp, and SSRC issues; `DirectPeerSessionAVAudioLoops.swift:217` and line 225 call throwing decoders/validators without the per-packet catch used for raw audio at lines 189-195.
Remediation: catch decode and validation failures per packet, increment typed RX drop/loss counters, and continue draining.
Verification: corrupt Opus and RTP packets complete the AV loop and report drops rather than aborting.

F-084 P1 Metrics UDP is connected but not exercised by the AV loop.
Evidence: `PeerSessionRunner.swift:307` connects `metricsTransport`; `PeerSessionRunnerMetrics.swift:23` defines publish/receive methods; `DirectPeerSessionAVSocketRunner.swift:363` runs media without calling them; `DirectPeerSessionReportTypes.swift:3` lacks remote metrics fields.
Remediation: publish and receive metrics on a bounded cadence during media loops and persist remote counters in reports.
Verification: two-peer local run reports nonzero metrics messages and peer-side loss/jitter fields.

F-085 P1 LoLa UDP RX can throw before emitting a failure report.
Evidence: `LoLaCompatibilityUdpMedia.swift:315` catches only timeout; `LoLaCompatibilityMediaSession.swift:292` validates received frames before report construction; `LoLaCompatibilityMediaEnvelopeValidation.swift:27` throws on duplicate/missing video prelude/fragments.
Remediation: convert validation errors into `.fail` reports with `runtimeError`, best-effort decoded counts, and malformed-frame counts.
Verification: malformed or partial captures return a failure report rather than an uncaught command failure.

F-086 P1 Python LoLa control/media parsing can terminate accept/RX loops on malformed peer input.
Evidence: `linux_connector/lola_connector/protocol.py:67` catches `ValueError` but not `OverflowError`; OSC15 QuickConn parsing around line 249 is unguarded; `runtime.py:222`, line 235, and lines 239-244 call parsing/reassembly paths that raise.
Remediation: catch `ValueError` and `OverflowError` at UDP/control trust boundaries, reject or count malformed packets, and keep runtime tasks alive.
Verification: malformed ASCII, OSC QuickConn, media prelude, and fragment cases increment malformed/drop metrics without task death.

F-087 P1 Python connector CLI accepts unbounded media and timing values before allocation and pacing.
Evidence: `linux_connector/lola_connector/cli.py:33` through line 50 use raw `type=int` and `type=float`; values flow into `MediaSettings` at lines 92-105; synthetic capture and fragmentation allocate from those values in `backends.py:92`, line 169, line 202, `media.py:91`, and line 168.
Remediation: add bounded argparse validators or one runtime `MediaSettings` validation gate before connector startup.
Verification: negative, zero, infinite, and huge dimensions/durations fail with typed errors; defaults still pass self-test.

F-088 P1 App latency hero silently computes partial metrics from missing or unreadable peer reports.
Evidence: `AppLatencyHeroMetrics.swift:11` reads the supervisor report with `try?`; line 16 uses `compactMap(loadSessionReport)`; line 37 silently drops unreadable child reports and still returns metrics if any report remains.
Remediation: track expected process result count, report read/decode failures explicitly, and suppress or mark partial metrics when any peer report is missing.
Verification: one valid and one missing child report yields a visible partial/error state, not clean latency metrics.

## P2 Findings

F-033 P2 MADI render recovery allocates inside callback-facing logic.
Evidence: `MadiReceive.swift:199` is the render callback path; line 214 reads missing fragment indices built with `filter` in `MadiReceiveBuffers.swift:110`.
Remediation: replace with fixed-size bitset or preallocated small vector.
Verification: recovery-path allocation test.

F-034 P2 Receiver pan gains are computed and validated but ignored by runtime mixing.
Evidence: `ReceiverMixSnapshot.swift:134` computes left/right gains; `MadiReceive.swift:350` mixes only `linearGain`.
Remediation: implement stereo pan semantics or reject/remove pan from runtime-facing config.
Verification: nonzero-pan MADI mix test.

F-035 P2 Direct peer graph duplicates and weakens AudioBufferList channel mapping.
Evidence: `DirectPeerRealtimeAudioGraph.swift:455` treats multi-buffer input channel selection as buffer index; `RealtimeAudioPayloadCaptureRing.swift:332` already has a fuller stable-channel mapping.
Remediation: share one buffer-list mapper or explicitly reject unsupported layouts.
Verification: multi-buffer, multi-channel layout tests.

F-036 P2 Audio loopback metrics ignore handoff underrun/overrun results.
Evidence: counters exist in `AudioLoopbackRun.swift:347`; line 401 ignores capture/render return values before reporting metrics at line 432.
Remediation: map `.droppedFull` and `.silence` to explicit callback metrics.
Verification: forced full/empty handoff tests.

F-037 P2 Opus low-delay codec allocates per encode/decode packet on the hot AV loop.
Evidence: `OpusCELTLowDelayCodec.swift:93` and line 145 allocate `Data`; AV loops call this per packet.
Remediation: add scratch-buffer encode/decode overloads and keep allocating wrappers for tests.
Verification: allocation-budget benchmark.

F-038 P2 Realtime report PASS validation allows zero target frames while direct RX policy requires one packet.
Evidence: `RealtimeAudioEngineReportValidation.swift:190` allows `playoutTargetFrames == 0`; `RxBuffering.swift:75` requires direct target of one.
Remediation: choose zero-buffer direct explicitly or reject zero-target PASS.
Verification: targeted PASS/fail report tests.

F-039 P2 MADI full-duplex render can run before `start()`.
Evidence: send/receive paths call `requireRunning()` in `MadiFullDuplexRuntime.swift:361`; `renderRemoteAudioCallback` at line 395 does not.
Remediation: enforce `.notStarted` in render or hide the primitive behind a started wrapper.
Verification: render-before-start unit test.

F-040 P2 Realtime ring single-owner enforcement is debug-only.
Evidence: direct peer audio payload ring ownership checks are guarded by `#if DEBUG` while production uses non-atomic metadata.
Remediation: expose typed producer/consumer handles or add a cheap release counter for misuse reporting.
Verification: misuse test fails deterministically in debug and cannot compile through the safe public API.

F-041 P2 AV audio drop metrics are accumulated, then overwritten.
Evidence: `DirectPeerSessionAVAudioLoops.swift:184` counts RX drops, `DirectPeerSessionAVSocketRunner.swift:390` accumulates them, then line 456 replaces them with audio-graph output drops.
Remediation: split counters or add instead of overwrite.
Verification: corrupt audio packets with zero graph drops preserve RX drop count.

F-042 P2 UDP media sequence metrics can regress on stale packets.
Evidence: `UdpMediaTransport.swift:477` overwrites `nextSequenceByStream` unconditionally; stale packets return zero loss at line 508; `latePackets` at line 239 is not updated.
Remediation: do not move expected sequence backwards; track late, duplicate, and reordered packets explicitly.
Verification: sequence `10, 9, 11` produces no false loss and increments late/reordered metrics.

F-043 P2 Hot receive path decodes nested media payloads repeatedly.
Evidence: envelope validation decodes audio/video payloads in `UdpMediaTransport.swift:168` and line 198; P2P decodes again in `PeerSessionRunner.swift:623` and line 634; AV video decodes again in `DirectPeerSessionAVVideoLoops.swift:81`.
Remediation: return typed decoded payloads from envelope decode.
Verification: one decode per packet plus depacketization benchmark.

F-044 P2 NAT rendezvous/relay registrations accept invalid or squatted peer IDs.
Evidence: `NatRendezvousRelayRunners.swift:26` and line 196 store `request.peerID` directly; helpers only reject duplicates at line 242; report validation catches empty IDs later in `NatFriendlyRouteReports.swift:24`.
Remediation: validate safe non-empty peer IDs at registration and optionally enforce expected-peer allowlists.
Verification: empty ID and spoofed duplicate endpoint tests.

F-045 P2 Raw audio reassembly trusts declared fragment counts too far into the hot path.
Evidence: `UdpPcmV2Packet.swift:567` checks only positive/index bounds; reassembly scans declared range at line 421; AV audio receive calls it in `DirectPeerSessionAVAudioLoops.swift:112`.
Remediation: cap fragment count to negotiated mode/max fragments before reassembly.
Verification: forged `fragmentCount = 65535` returns bounded error without large missing-list work.

F-046 P2 `SessionStateMachine` exists but runtime bypasses it.
Evidence: transition policy exists in `SessionControlMessage.swift:226`; runtime uses ad hoc handling in `PeerSessionRunner.swift:665`.
Remediation: apply the state machine with explicit expected message types per phase.
Verification: out-of-order capabilities, accept, mediaStart, and shutdown messages do not mutate state unexpectedly.

F-047 P2 AV loop uses fixed sleep scheduling instead of socket/media deadlines.
Evidence: `DirectPeerSessionAVSocketRunner.swift:454` sleeps fixed audio poll intervals while also scheduling video by next frame time.
Remediation: wait on the earliest of socket readiness, audio due time, and video due time.
Verification: AV socket runner timing test shows no avoidable late video/audio iterations.

F-048 P2 Media geometry byte-count calculations can overflow before typed validation.
Evidence: `DirectPeerSessionAVRunTypes.swift:138`, `LoLaCompatibilityMediaCodec.swift:106`, and `LoLaVideoPayloadProvider.swift:55` use unchecked products; validation in `DirectPeerSessionAVSocketRunner.swift:78` happens too late for some budget math.
Remediation: centralize checked multiply/sizing helpers and validate geometry before budget estimation.
Verification: `Int.max` dimensions return typed validation errors.

F-049 P2 Video reassembly has wrap-aware helpers but active-frame eviction uses plain integer ordering.
Evidence: `VideoTransportReassembly.swift:223` and line 335 use `>`/`<=`; wrap-aware helpers exist around line 410.
Remediation: use wrap-aware ordering for all sequence comparisons.
Verification: `UInt64.max -> 0` reassembly with active incomplete frames.

F-050 P2 Final incomplete raw-audio reassembly is not flushed at AV loop shutdown.
Evidence: flush support exists in `DirectPeerSessionAVAudioLoops.swift:104`; `DirectPeerSessionAVSocketRunner.swift:456` returns metrics without an end-of-run flush.
Remediation: flush incomplete audio reassembly before report construction.
Verification: stopping after one partial raw audio block records incomplete/drop metrics.

F-051 P2 Packaging report construction can emit an invalid PASS before validation catches it.
Evidence: `PackagingFieldTestRun.swift:119` uses ad-hoc/unsigned/unclean packaging state, while verdict at line 158 depends on input reports; `PackagingFieldTestValidation.swift:79` later rejects invalid PASS.
Remediation: never construct PASS unless local packaging/signing/clean-Mac predicates also pass.
Verification: all input reports PASS still produce packaging PARTIAL without packaging proof.

F-052 P2 External connector argv validation is inconsistent.
Evidence: `JackTripLaunchPlan.swift:83` sanitizes primary args; `UltraGridLaunchPlan.swift:25` and `JackTripAuxiliaryVideoPlan.swift:7` append capture/display/peer values raw.
Remediation: reuse one argv-value validator per connector option class.
Verification: `--video-capture --help` and whitespace/device-name tests.

F-053 P2 Docker helpers are not fully reproducible or non-root.
Evidence: `scripts/ultragrid-docker/Dockerfile:17` downloads a GitHub tarball without checksum and final image has no `USER`; `linux_connector/env/Dockerfile:1` uses `python:3.12-slim`; compose uses host networking at `linux_connector/env/compose.yaml:6`.
Remediation: pin by digest/checksum and add non-root users where feasible.
Verification: bad checksum fails; `docker run ... id -u` is nonzero for production images.

F-054 P2 Type/test gates omit Python helper surfaces.
Evidence: `scripts/verify-release-readiness.sh:168` runs mypy only on `linux_connector/lola_connector`; `scripts/verify_docs` and `scripts/lib/*.py` are outside strict typing.
Remediation: add helper surfaces to strict typing or document exclusions.
Verification: `mypy --strict linux_connector scripts/verify_docs scripts/lib/*.py`.

F-055 P2 Python UDP socket lock registries never shrink.
Evidence: global lock dictionaries live in `connector.py:45`, are keyed by fd around line 120, and close paths at line 419 do not unregister.
Remediation: key locks by weak socket object or unregister by fd on close.
Verification: repeated socket open/close cycles keep lock dict sizes bounded.

F-056 P2 App bundle helper kills matching user processes before validating mode/build.
Evidence: `script/build_and_run.sh:23` runs `pkill` for `OpenLoLa` and `open-lola-app` unconditionally.
Remediation: kill only the staged bundle process or require explicit restart mode.
Verification: dummy same-name process outside `dist/OpenLoLa.app` is not killed.

F-057 P2 JackTrip Docker RX startup knob is ignored.
Evidence: `run-local-jacktrip-rxtx-docker.sh:8` defines `startup_seconds`; line 47 sleeps hard-coded `4`.
Remediation: use `sleep "$startup_seconds"`.
Verification: run with `OPEN_LOLA_JACKTRIP_STARTUP_SECONDS=1` under trace.

F-058 P2 Transport action buttons can have poor text contrast.
Evidence: `AppTransportView.swift:45` and line 83 use `.foregroundStyle(.primary)` over armed/live colored capsule backgrounds.
Remediation: use semantic on-state foreground colors, outline style, or contrast-tested fills.
Verification: screenshot/contrast pass for light, dark, and increased contrast.

F-059 P2 Command examples can be clipped and unreadable.
Evidence: `AppExecutionView.swift:89` renders joined command text without the multiline handling used elsewhere.
Remediation: use a scrollable/monospaced multiline command block with copy action.
Verification: long supervisor command remains readable at minimum window width.

F-060 P2 Packet monitor truncates critical packet fields.
Evidence: `AppPacketMonitorView.swift:8` defines fixed widths and row cells at lines 196-206 use single-line text; long endpoints and candidate fields are clipped.
Remediation: use resizable table columns, tooltips/full-text help, and row copy actions.
Verification: long IPv6/hostname row is inspectable at minimum width.

F-061 P2 Packet monitor silently converts row errors into an empty table.
Evidence: `AppPacketMonitorView.swift:211` catches all row-building errors and returns `[]`.
Remediation: surface an error banner distinct from "no packets match".
Verification: injected row error displays an error state.

F-062 P2 Stop controls are active while nothing is running.
Evidence: `AppConsoleChromeView.swift:110` and `AppTransportView.swift:100` expose stop controls; `AppExecutionController.swift:229` then reports "No active process".
Remediation: disable stop unless `isRunning`.
Verification: idle UI state test.

F-063 P2 Forced dark mode constrains accessibility and appearance.
Evidence: `AppShellRootView.swift:92` forces `.preferredColorScheme(.dark)` while `AppDesignSystem.swift:51` defaults to dark/standard contrast.
Remediation: honor system appearance/increased contrast unless fixed-theme operator mode is explicit and tested.
Verification: screenshot pass in light, dark, and increased-contrast modes.

F-064 P2 Fixed-height session banner can clip long status strings.
Evidence: `AppSessionStateBanner.swift:56` fixes height at 44 while labels include full peer/host strings at line 73.
Remediation: truncate with full tooltip/accessibility text or let height grow.
Verification: long-hostname screenshot at minimum width.

F-065 P2 Menu actions duplicate the action inventory and can drift.
Evidence: `OpenLolaApp.swift:47` hard-codes command menu actions; `NativeAppShellSurfaceContract.swift:149` defines the action inventory.
Remediation: render menus from `NativeAppShellActionInventory.menuActions` or add a parity test.
Verification: inventory/menu parity test fails if a menu action is missing.

F-066 P2 Action contract says arm execution does not arm control output.
Evidence: `NativeAppShellSurfaceContract.swift:167` sets `armsControlOutput: false` for `arm-execution`; `OpenLolaApp.swift:57` toggles execution arming and `AppTransportView.swift:151` gates start on it.
Remediation: split execution arming from control-output arming or rename the contract field.
Verification: contract test for explicit execution-arm semantics.

F-067 P2 App logs view has dead search state.
Evidence: `AppLogsView` declares `searchText` but no search control uses it.
Remediation: implement log search or remove the unused state.
Verification: Swift compile/test after deletion or UI search behavior test.

F-068 P2 App settings view is oversized and repeats form patterns.
Evidence: `AppShellSettingsView.swift` is about 674 lines and owns many tabs/field binding patterns.
Remediation: split by tab/section and reuse typed setting rows after behavior tests exist.
Verification: source line budget plus settings hydration tests.

F-069 P2 Oversized mixed-responsibility files remain under an over-generous line budget.
Evidence: `CodeLineBudgetTests.swift:4` permits 720 lines; large first-party files include `PeerSessionRunner.swift`, `MilestoneCommands.swift`, `AppShellSettingsView.swift`, `VideoTransportPacket.swift`, `UdpPcmV2Packet.swift`, and `DirectPeerSessionReport.swift`.
Remediation: split by runtime concern, then lower the first-party Swift budget.
Verification: focused file-owner tests plus full SwiftPM tests.

F-070 P2 Source ownership inventory has duplicate related paths.
Evidence: `SourceOwnershipInventory.swift:369` and line 382 repeat `docs/mac-port/README.md`.
Remediation: dedupe path arrays and add a uniqueness assertion.
Verification: `SourceOwnershipInventoryTests`.

F-071 P2 Generated residue is present in the working tree.
Evidence: live inventory found `__pycache__/*.pyc` and `linux_connector/.DS_Store`.
Remediation: delete generated residue and make hygiene fail on live forbidden artifacts.
Verification: `find`/release hygiene gate reports zero forbidden generated files.

F-072 P2 CLI/report code uses repeated unbounded file reads.
Evidence: `AppExecutionController.swift:455` and line 489 use `Data(contentsOf:)`; CLI command files also use direct file reads for reports and probes.
Remediation: centralize bounded report read helpers with file-size limits and typed errors.
Verification: oversized report fixture fails before loading into memory.

F-073 P2 Process-running logic is duplicated across app, direct-peer supervisor, and connector runtime.
Evidence: `AppExecutionController`, `DirectP2PTwoPeerLocalRunCommandSupport`, and `ExternalConnectorProcessRunner` each own process setup, stdout/stderr handling, timeout, and termination logic.
Remediation: after P1 process bugs are fixed, extract a narrow tested process runner for shared non-UI behavior.
Verification: existing app, CLI, and connector process tests share the same fake process scenarios.

F-074 P2 Vendored third-party trees need an explicit fence and patch policy.
Evidence: large upstream drops under `Sources/opus-1.5.2` and `Sources/xs_ref_sw_ed2` dominate inventories but are not first-party refactor targets.
Remediation: document vendor origin, exact compiled subset, notices, and local patch rules; exclude raw vendor extras from release candidates.
Verification: SBOM/release manifest check and vendor path allowlist.

F-089 P2 Active source TODO is pinned by a passing test.
Evidence: `Sources/open-lola/Commands/Network/DirectP2PTwoPeerPrototypeCommandSupport.swift:4` contains an unresolved `TODO(human)` about public "Prototype" naming; `SourceNamingConventionTests.swift:40` through line 49 asserts that TODO text remains.
Remediation: decide the naming, add compatibility aliases if needed, and test public command/schema behavior instead of preserving the note.
Verification: source `TODO(human)` scan is limited to intentional evidence templates.

F-090 P2 Line-budget enforcement is too permissive and misses audited first-party surfaces.
Evidence: `CodeLineBudgetTests.swift:4` allows 720 physical lines; line 21 only includes `swift`, `py`, and `sh`; current high-signal files sit near the cap, and first-party C/H plus PowerShell helpers such as `linux_connector/env/enable_wsl_lola_network.ps1` are not counted.
Remediation: lower budgets by file class and include first-party `.c`, `.h`, `.ps1`, Docker/YAML release helpers, or explicitly exempt them with rationale.
Verification: line-budget tests fail on current oversized/missed surfaces, then pass after targeted splits or documented exemptions.

F-091 P2 Python tool dependency contracts are inconsistent and under-pinned.
Evidence: `pyproject.toml:11` through line 16 uses unbounded tool dependencies, `.github/workflows/release-readiness.yml:39` uses different upper bounds, and `ReleaseArtifactHygieneContractTests.swift:184` through line 194 asserts divergent strings instead of one parsed policy.
Remediation: define one constraints source or bounded dependency policy shared by local and CI workflows.
Verification: CI and local installs use the same constraints; tests parse TOML/YAML rather than substring-matching versions.

F-092 P2 Source ownership coverage can pass through broad fallback ownership.
Evidence: `SourceOwnershipInventory.swift:131` falls back from exact paths to broad roots; `SourceOwnershipInventoryTests.swift:41` only requires a non-nil owner; delegated inventory found many first-party source files not explicitly listed before fallback ownership.
Remediation: report exact, fallback-only, and unowned files separately; fail new fallback-only files unless allowlisted.
Verification: focused source ownership tests expose fallback-only coverage.

F-093 P2 One intended Swift Testing guard is silently not executed.
Evidence: `NativeAppShellPolicyTests.swift:6` defines `nativeAppShellRejectsPassWhenUIOwnsRealtimeAudio()` without `@Test`; the guarded validator branch is in `NativeAppShell.swift:267`.
Remediation: add `@Test` and a meta-check for public top-level test-like functions lacking `@Test`.
Verification: focused NativeAppShell policy filter executes the missing guard.

F-094 P2 Docs and CI wrapper disagree on Python/helper verification scope.
Evidence: `docs/testing/README.md:28` says `ruff check .`; `scripts/verify-release-readiness.sh:168` runs only `ruff check linux_connector`; mypy is limited to `linux_connector/lola_connector` at line 170; CI delegates to the wrapper at `.github/workflows/release-readiness.yml:42`.
Remediation: align the wrapper with the documented matrix or narrow the docs to the actual CI contract.
Verification: release-readiness output lists and runs the intended Python/script scope.

F-095 P2 App persisted UInt16 ports are silently clamped into different valid ports.
Evidence: `AppSettings.swift:21` through line 24 persist ports as `Int`; `AppShellStoredDefaults.swift:65`, line 140, and line 298 use `UInt16(clamping:)`; `AppShellSettingsView.swift:412` through line 421 clamps UI bindings.
Remediation: use exact UInt16 conversion; invalid persisted values should fall back or surface validation instead of becoming 0 or 65535.
Verification: seeded UserDefaults with `70000` and `-1` produce validation/fallback, not silent clamping.

F-096 P2 Raw IPv4/UDP packet builder misses payload length validation.
Evidence: `linux_connector/lola_connector/ethernet.py:51` through line 65 computes UDP/IP lengths and packs them into 16-bit fields without checking payload size.
Remediation: reject payloads larger than 65,507 bytes with a deterministic `ValueError`.
Verification: 65,508-byte payload fails cleanly; 65,507 bytes succeeds.

F-097 P2 ASCII TXT escaping has no decode path.
Evidence: `linux_connector/lola_connector/protocol.py:164` through line 166 escapes builder TXT fields; parser stores raw values at lines 153-161; `ControlMessage.txt` returns raw TXT at lines 130-132; `linux_connector/tests/test_codec.py:161` locks in percent-encoded round trips.
Remediation: add decoded display text or explicitly split `raw_txt` from user-facing text.
Verification: `a:b;c%` round-trips to original display text while parser injection remains blocked.

F-098 P2 Raw-audio reassembly loses incomplete deadlines during normal traffic, not only shutdown.
Evidence: `DirectPeerSessionAVAudioLoops.swift:105` stores pending fragments in an array; line 110 drops the previous deadline without a metric; line 112 appends every fragment.
Remediation: key pending fragments by index, cap pending count to negotiated fragment count, and expose duplicate/incomplete-deadline counters.
Verification: duplicate-fragment flood stays bounded and deadline switch increments incomplete-drop count.

F-099 P2 AV video reassembler has a flush path that reports never use.
Evidence: `VideoTransportReassembly.swift:183` can flush incomplete frames and count missing fragments; `DirectPeerSessionAVSocketRunner.swift:456` returns runtime metrics without flushing or merging reassembler metrics.
Remediation: flush at AV loop shutdown and merge reassembler metrics into runtime/report counters.
Verification: stop after one partial video frame reports incomplete frame and missing fragments.

F-100 P2 Search and disabled sidebar state can leave hidden or unavailable sections active.
Evidence: `AppShellRootView.swift:14` persists selected section with `@SceneStorage`; search filters visible rows at line 51; `AppConsoleChromeView.swift:29` disables packet monitor when unconfigured; detail rendering still switches on stored selection in `AppShellRootView.swift:277`.
Remediation: clamp selection when search/session state hides the current section, or render a blocked-state detail.
Verification: unconfigured packet-monitor selection plus search filter cannot show an unavailable detail as active.

F-101 P2 Log/error surface hides accumulated controller errors and opens log paths blindly.
Evidence: `AppExecutionController.swift:43` stores `errorLog` and appends at line 493, but `AppExecutionView.swift:171` shows only file paths/last command; `AppExecutionView.swift:197` calls `NSWorkspace.shared.open` without existence/error handling.
Remediation: render accumulated errors, disable missing log buttons, and surface open failures.
Verification: injected report-load errors and missing log files are visible and cannot fail silently.

F-102 P2 Preview disabled states are treated as active.
Evidence: `AppPreviewReceiverView.swift:107` treats disabled audio/video statuses as live inputs; `isLiveOrDisabledStatus` returns true for `"disabled"` at line 129; `previewIsActive` at line 29 can enable controls from that state.
Remediation: add a distinct disabled phase and gate controls by active service state.
Verification: both preview toggles off yields disabled/idle, not active controls.

F-103 P2 Long paths and status values remain non-readable outside command and packet views.
Evidence: `MetricsGrid` caps content at `AppShellSupportViews.swift:110`; executable/report/stdout/stderr paths render as plain `LabeledContent` in `AppExecutionView.swift:31` and line 115; topology peer/host labels truncate at fixed width in `AppConnectionTopologyView.swift:71` and line 77.
Remediation: introduce a reusable path/status value component with selection, tooltip, wrapping or horizontal scroll, and copy action.
Verification: minimum-width screenshot/accessibility pass with long Application Support paths and host names.

F-104 P2 Diagnostics/preflight process wrappers can block on full pipes.
Evidence: `NetworkDiagnostics.swift:416` attaches stdout/stderr to a pipe but waits for process exit before reading at line 434; `GoalRuntimePreflight.swift:113` attaches pipes and reads only after `waitUntilExit()` at line 120.
Remediation: drain pipes asynchronously or redirect to bounded temp files for any helper process that may emit unbounded output.
Verification: verbose fake helper writes more than pipe capacity and exits under timeout without deadlock.

## Remediation Sequence

1. Establish failing tests before code changes.
   - Add targeted unit tests for F-001, F-002, F-004, F-007, F-008, F-009, F-010, F-014, F-015, F-017, F-018, F-020, F-021, F-023, F-024, F-025, and F-026.
   - Add UI screenshot/contrast probes for F-058, F-059, F-060, F-063, and F-064.
   - Add source/release hygiene tests for F-028, F-031, F-032, F-071, and F-074.

2. Close P1 runtime correctness first.
   - Realtime audio lifecycle and arithmetic: F-001 through F-005.
   - UDP/P2P/control identity and bounded execution: F-007 through F-013.
   - AV/video scheduling and retention correctness: F-014 through F-016.
   - Connector/process lifecycle: F-017 through F-024.

3. Close P1 release truthfulness and source boundaries.
   - Live hygiene and Docker policy: F-025 through F-027.
   - Release/source boundary and target split plan: F-028 and F-029.
   - Replace brittle source-text tests with behavior tests where runtime behavior is asserted: F-030.
   - Tighten ownership and stale-doc checks: F-031 and F-032.

4. Fix UI readability and missing/fragile operator controls.
   - Contrast and command text readability: F-058 and F-059.
   - Packet monitor readability and error state: F-060 and F-061.
   - Idle stop controls, appearance, banner sizing, menu/action parity, arm semantics: F-062 through F-066.

5. Reduce realtime and media hot-path slop.
   - Audio callback allocation/mapping/metrics: F-033 through F-040.
   - AV/UDP metrics, repeated decoding, sequence ordering, fragment bounds, and shutdown flushing: F-041 through F-050.
   - External connector argv consistency and Docker reproducibility: F-052 and F-053.

6. Reduce structure, dead code, and duplicated plumbing.
   - Strictly expand Python/helper verification: F-054.
   - Bound lock registries and shell helper behavior: F-055 through F-057.
   - Remove dead state and split oversized UI/source files: F-067 through F-070.
   - Centralize bounded report reads and process running after behavior tests exist: F-072 and F-073.
   - Fence vendor code and release inclusion: F-074.

7. Close the enrichment-pass release and verification false-greens.
   - Resolve the active root plan/docs contract before any release-readiness claim: F-075.
   - Make release hygiene fail on live forbidden residue and missing candidate scans: F-076.
   - Replace broad source-string coverage with behavior tests and real executable/app probes: F-077 through F-079.
   - Align Python/helper verification scope and dependency policy: F-091 and F-094.

8. Close the enrichment-pass high-risk runtime logic.
   - Prevent stale or partial evidence from changing operator truth: F-080, F-081, and F-088.
   - Harden Linux LoLa control/media trust boundaries and CLI bounds: F-082, F-086, and F-087.
   - Make AV RX decode failures and LoLa RX validation produce metrics/reports rather than aborts: F-083 and F-085.
   - Wire peer metrics UDP into runtime reports: F-084.
   - Bound and flush audio/video reassembly state: F-098 and F-099.

9. Close the enrichment-pass UI, structure, and slop items.
   - Decide or remove pinned TODO naming: F-089.
   - Tighten line budgets and ownership inventories: F-090 and F-092.
   - Execute the missing Swift test guard: F-093.
   - Fix silent clamping, payload bounds, TXT decoding, and process pipe behavior: F-095 through F-097 and F-104.
   - Fix hidden/disabled sections, log errors, preview disabled state, and long text readability: F-100 through F-103.

## Verification Matrix For Closure

Swift focused tests:
- `swift test --filter DirectPeerRealtimeAudioGraph`
- `swift test --filter MadiReceive`
- `swift test --filter UdpMediaTransport`
- `swift test --filter UdpPcmV2Packet`
- `swift test --filter PeerSessionRunner`
- `swift test --filter PeerSessionAV`
- `swift test --filter DirectPeerSessionCLI`
- `swift test --filter DirectPeerTwoPeer`
- `swift test --filter NativeAppShell`
- `swift test --filter AppShell`
- `swift test --filter SourceOwnershipInventory`
- `swift test --filter ReleaseArtifactHygiene`

Swift broad gate:
- `swift test`

Python/tooling gates:
- `ruff check --no-cache linux_connector scripts`
- `pytest linux_connector/tests`
- `mypy --strict linux_connector scripts/verify_docs scripts/lib/*.py`

Shell/PowerShell gates:
- `shellcheck scripts/*.sh script/*.sh linux_connector/env/*.sh`
- `bash -n scripts/*.sh script/*.sh`
- `Invoke-Pester` for WSL helper once tests exist

Docs/release gates:
- `bash scripts/verify-docs.sh`
- `bash scripts/verify-release-readiness.sh`
- release candidate export plus hygiene scan of the candidate and live checkout

Surface probes:
- `open-lola session-capabilities`
- direct P2P manual validation command with bounded timeout
- direct P2P two-peer local dry run with forced child timeout
- native app launch/screenshot probe for menus, transport controls, packet monitor, and long text

Closure criteria:
- All P1 findings have failing tests first, then passing fixes.
- All runtime counters distinguish loss, duplicate, late, reordered, deferred, overwritten, underrun, overrun, and output-drop classes where relevant.
- No generated residue is present in live checkout or release candidate.
- `plan.md` is archived after completion and current docs point to the archived closure artifact.
- The docs/release-readiness gate no longer fails because of active root plan authority ambiguity.
- At least one real app/executable surface probe supplements source-text contract tests.

VERDICT: FAIL

Reason: the requested read-only audit artifact is enriched, but the live repo currently has high-risk P1 findings and the docs/release-readiness gate fails while this root plan is active without its required companion artifacts.
