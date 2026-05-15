# open-lola2 Runtime, UI, and Code-Quality Audit Plan

Date: 2026-05-12
Mode: read-only audit artifact with remediation plan
Scope: active source, tests, scripts, CLI, macOS app, Linux connector
Verdict: PARTIAL

## Assumptions And Boundaries

- This checkout is not a Git worktree. `git status --short --branch` fails with `fatal: not a git repository`, so evidence is file/line based.
- This file is the only intended change in this pass. No source, test, script, or documentation remediation is included here.
- Active audit scope:
  - `Sources/OpenLolaCore/**`
  - `Sources/open-lola/**`
  - `Sources/open-lola-app/**`
  - `Tests/OpenLolaCoreTests/**`
  - `linux_connector/**`
  - `scripts/**`
  - `script/**`
  - `Package.swift`, `pyproject.toml`, release/compliance entrypoints
- Historical/generated/vendor scope is excluded from active-runtime findings except for build warnings, dependency boundary, and release hygiene notes:
  - `archive/**`
  - `dist/**`
  - `private/**`
  - `Sources/opus-1.5.2/**`
  - `Sources/xs_ref_sw_ed2/**`
- Severity policy:
  - `P0`: possible crash, use-after-free, realtime audio data loss, race/deadlock, or user-visible false safety state.
  - `P1`: runtime correctness, validation, packetization, AV sync, UX readability, or coverage gaps that can hide field failures.
  - `P2`: slop, boilerplate, dead code, structure, duplication, source-string tests, warning cleanup, or deferred feature boundary.

## Verification Snapshot

Commands already run during this audit/planning pass:

```sh
git status --short --branch
swift test --build-path /private/tmp/open-lola2-audit-plan-build --no-parallel
ruff check linux_connector
python -m pytest linux_connector/tests
python -m mypy --strict linux_connector/lola_connector
bash scripts/verify-docs.sh
shellcheck scripts/*.sh scripts/lib/*.sh script/*.sh linux_connector/env/*.sh
bash scripts/verify-release-hygiene.sh
/private/tmp/open-lola2-audit-plan-build/debug/open-lola session-capabilities
/private/tmp/open-lola2-audit-plan-build/debug/open-lola native-app-shell-surface-probe
```

Observed results:

- Git status: not available because the checkout has no `.git`.
- SwiftPM: `1400` tests passed in `95.262` seconds from isolated build path.
- `ruff check linux_connector`: pass.
- `python -m pytest linux_connector/tests`: `44 passed, 2 skipped`.
- `python -m mypy --strict linux_connector/lola_connector`: pass.
- `shellcheck`: pass over active project shell scripts.
- `bash scripts/verify-docs.sh`: passed before root `plan.md` existed; after this requested root artifact was added, the docs verifier fails because active root `plan.md` is explicitly banned by `scripts/verify_docs/markdown_checks.py`.
- `bash scripts/verify-release-hygiene.sh`: `VERDICT: PASS`.
- `open-lola session-capabilities`: `VERDICT: PASS`.
- `open-lola native-app-shell-surface-probe`: `VERDICT: PARTIAL`; it is source-level and records no screenshot/log.

Residual verification gaps:

- No live macOS screenshot or window hierarchy was captured.
- No physical RME/CoreAudio, Blackmagic/DeckLink, ATEM, OSC, lighting, two-Mac, WAN, or signing evidence was produced in this pass.
- No remediation tests were added because this pass writes only the audit plan.
- Current artifact caveat: root `plan.md` is explicitly requested here, but it conflicts with the current documentation contract. Until that contract is changed or this file is archived, the repo-wide release-readiness gate is expected to fail at `bash scripts/verify-docs.sh`.

## Coverage Ledger

Current coverage is sufficient for a remediation plan, but not field-ready product certification.

- Runtime audio/local RX/TX: inspected by targeted source pass and realtime-audio subagent.
- UDP/P2P/control: inspected by targeted source pass and network/control subagent.
- Video/AV: inspected by targeted source pass and video/AV subagent.
- macOS app/UI: inspected by targeted source pass and UI subagent.
- Python Linux connector: static and test gates passed.
- Shell scripts: active project scripts passed `shellcheck`.
- Release/docs gates: docs and release hygiene passed.
- Vendor C code: not line-audited as owned application code; warnings noted as hygiene inputs.

Before closing any remediation branch, add a final file-coverage table that marks every active source/test/script file as one of:

- `finding-attached`
- `reviewed-no-finding`
- `third-party-boundary`
- `generated-or-archive-excluded`

## Findings

### P0 - Realtime Audio And Local RX/TX

#### AUD-P0-AUDIO-001 - CoreAudio callback lifetime can outlive `DirectPeerRealtimeAudioGraph`

Evidence:

- `Sources/OpenLolaCore/Audio/Realtime/DirectPeerRealtimeAudioGraph.swift:72` deinitializes only scratch buffers.
- `Sources/OpenLolaCore/Audio/Realtime/DirectPeerRealtimeAudioGraph.swift:183` passes `self` with `Unmanaged.passUnretained`.
- `Sources/OpenLolaCore/Audio/Realtime/DirectPeerRealtimeAudioGraph.swift:204` has explicit `stop()`, but `deinit` does not call it.

Risk:

- If a started graph is released without `stop()`, CoreAudio can call an IOProc with a dangling `self` pointer.
- This is a use-after-free class issue in the highest-risk realtime path.

Remediation:

- Make started graph lifetime explicit and non-leaky: `deinit` must stop IOProcs before deallocating scratch buffers, or the API must make started graphs non-releasable through an owning runtime object.
- Add a contract test for `deinit`/`stop()` behavior using a fake CoreAudio backend or seam.
- Keep callback hot path allocation-free and lock-free after the lifetime fix.

Acceptance:

- A started graph cannot be deallocated while `ioProcRunning == 1`.
- Tests cover start failure rollback, normal stop, repeated stop, and deinit-with-started-graph.

#### AUD-P0-AUDIO-002 - AV raw PCM RX appears to queue fragments before reassembly

Evidence:

- `Sources/OpenLolaCore/Network/P2P/DirectPeerSessionAVAudioLoops.swift:82` receives an audio media packet.
- `Sources/OpenLolaCore/Network/P2P/DirectPeerSessionAVAudioLoops.swift:89` decodes one `UdpPcmV2Packet`.
- `Sources/OpenLolaCore/Network/P2P/DirectPeerSessionAVAudioLoops.swift:118` queues `decodedPayload` directly to `audioGraph.queuePlayoutPayload`.
- `Sources/OpenLolaCore/Audio/Realtime/DirectPeerRealtimeAudioGraph.swift:280` queues the supplied payload directly into the playout ring.

Risk:

- TX packetization can split larger audio blocks, especially 64-channel/MADI-sized payloads.
- RX can hand one fragment to the playout ring instead of a full audio block.
- Invalid/short payloads can be dropped without truthful output-drop accounting.

Remediation:

- Add a reassembly stage for OpenLoLa raw audio before playout.
- Make invalid payload drops visible in runtime counters and reports.
- Cover 2-channel, 64-channel, fragmented, duplicate, missing-fragment, and out-of-order cases.

Acceptance:

- Fragmented raw PCM only reaches `queuePlayoutPayload` after full validated reassembly.
- Invalid fragments increment explicit RX/drop counters and never masquerade as successful playout.

### P1 - Realtime Audio, Buffering, And Timing

#### AUD-P1-AUDIO-003 - Socket receive helpers allocate per packet in hot paths

Evidence:

- `Sources/OpenLolaCore/Network/UDP/UdpPcmSocketOperations.swift:229` allocates `[UInt8](repeating: 0, count: byteCount)` for every receive attempt.
- `Sources/OpenLolaCore/Audio/MADI/MadiFullDuplexSocketRunner.swift:152` drains in a tight loop around that helper.

Risk:

- Per-packet allocation and copy can increase jitter under load.
- This is especially risky for realtime audio and MADI full-duplex loops.

Remediation:

- Introduce reusable receive buffers or a caller-owned scratch buffer.
- Keep packet parsing separate from allocation.
- Measure allocation count and p99 loop latency before/after.

Acceptance:

- Hot receive loops do not allocate a fresh Swift array per poll.
- Tests or benchmarks assert bounded allocation behavior for receive drains.

#### AUD-P1-AUDIO-004 - MADI full-duplex loop uses tight sleep polling

Evidence:

- `Sources/OpenLolaCore/Audio/MADI/MadiFullDuplexSocketRunner.swift:158` loops until deadline.
- The same drain path depends on nonblocking packet checks rather than event-driven readiness.

Risk:

- Tight polling competes with audio scheduling and wastes CPU.
- Under load, this can either miss deadlines or steal time from audio render/capture work.

Remediation:

- Replace deadline busy-drain with `poll`/`select`/dispatch source where possible.
- If polling remains, isolate it from callback-critical scheduling and make interval policy explicit.
- Add stress tests around deadline miss metrics.

Acceptance:

- MADI drain loop reports deadline misses and avoids unbounded CPU spin.
- Realtime tests cover no-packet, burst-packet, and deadline-overrun cases.

#### AUD-P1-AUDIO-005 - MADI ready-block storage can collide with far-future blocks

Evidence:

- `Sources/OpenLolaCore/Audio/MADI/MadiReceiveBuffers.swift:248` stores by modulo index.
- `Sources/OpenLolaCore/Audio/MADI/MadiReceiveBuffers.swift:252` computes the storage index directly from `block.startFrame`.
- The realtime buffer path has stronger stale/future playout semantics elsewhere.

Risk:

- A far-future complete block can occupy a modulo slot and force nearer blocks into overrun/drop behavior.
- This can surface as intermittent RX loss that looks like network jitter.

Remediation:

- Add an explicit "too far ahead" guard before ready-block storage.
- Track future-drop and overrun-drop separately.
- Add tests for far-future, stale, wraparound, and near-deadline blocks.

Acceptance:

- MADI receive buffer cannot evict a nearer valid block because of a far-future block.
- Reports distinguish stale, future, duplicate, and overrun outcomes.

#### AUD-P1-AUDIO-006 - AV audio RX decodes the same packet more than once

Evidence:

- `DirectPeerSessionAVAudioLoops.swift` decodes received packets for playout.
- `PeerSessionRunner` also records/routes media packets in the receive path before playout handling.

Risk:

- Duplicate decode increases CPU pressure and allocation in local RX.
- Under AV load this competes with video reassembly and audio callback deadlines.

Remediation:

- Return a typed decoded packet from the receive helper once.
- Feed the same decoded object into metrics, routing, and playout.
- Add a test that validates only one decode path per received audio packet.

Acceptance:

- One packet receive produces one decode and one metrics update.
- No behavior regression for raw, Opus, and AES67 paths.

### P1 - UDP, P2P, And Control

#### AUD-P1-NET-001 - `0.0.0.0` can be advertised as a peer endpoint

Evidence:

- `Sources/open-lola/Commands/Network/DirectP2PSessionRunCommandSupport.swift:355` accepts `--local-host` as a required string.
- `Sources/OpenLolaCore/Network/P2P/PeerSessionRunner.swift:79` binds media transports to `localHost`.
- `Sources/OpenLolaCore/Network/P2P/PeerSessionRunner.swift:90` builds advertised media endpoints from bound local endpoints.

Risk:

- Binding to `0.0.0.0` is valid locally but not a remote-connectable advertised address.
- A remote peer can be told to connect to `0.0.0.0`, causing route failure that looks like P2P negotiation failure.

Remediation:

- Split bind host from advertised host.
- Reject wildcard addresses for advertised endpoints unless an explicit `--advertise-host` is supplied.
- Add CLI tests for wildcard bind, loopback bind, and explicit advertise host.

Acceptance:

- `--local-host 0.0.0.0` either fails with a clear error or requires a non-wildcard advertised endpoint.

#### AUD-P1-NET-002 - P2P port uniqueness is not consistently validated

Evidence:

- `Sources/open-lola/Commands/Network/DirectP2PSessionRunCommandSupport.swift:357` parses control/audio/video/metrics ports independently.
- `Sources/OpenLolaCore/Network/P2P/PeerSessionRunner.swift:79` binds audio, video, and metrics ports independently.
- Two-peer planning validation has distinct-port checks but omits some metrics coverage in preflight paths.

Risk:

- Duplicate media/control ports can bind fail late or cross-route traffic.
- Metrics collisions can hide packet loss or report-path failures.

Remediation:

- Centralize a `DirectPeerPortSet` validator.
- Enforce uniqueness across control, remote control, audio, video, and metrics where applicable.
- Reuse the validator in manual run, two-peer plan, local supervisor, and report validation.

Acceptance:

- All direct/two-peer entrypoints reject duplicate active ports before bind/start.

#### AUD-P2-NET-003 - Audio-only CLI accepts flags that runtime ignores

Evidence:

- Audio-only `direct-p2p-session-run` accepts sample shape flags.
- The audio-only session helper still uses default stream shape in the runtime path.

Risk:

- Operator thinks a sample rate/frame/sample-format setting is active when it is not.
- This creates false confidence in test runs and reports.

Remediation:

- Either wire the flags through audio-only runtime or reject them outside AV mode.
- Update help text and tests to make behavior explicit.

Acceptance:

- Every accepted audio flag either changes runtime behavior or is rejected with a clear error.

#### AUD-P2-NET-004 - Two-peer planner accepts arbitrary format strings too late

Evidence:

- Two-peer plan accepts sample/pixel format strings and forwards them into generated commands.
- Rejection happens later in direct runtime parsing.

Risk:

- Generated plans can look valid but fail only after handoff/start.
- This weakens preflight as an operator safety gate.

Remediation:

- Reuse direct runtime parsers in the planner.
- Validate sample format, pixel format, compression, profile, and buffer profile at plan creation.

Acceptance:

- Two-peer plan generation cannot emit a command that direct runtime immediately rejects for static argument validity.

#### AUD-P2-NET-005 - ATEM host contract is narrower than the CLI name implies

Evidence:

- `AtemReadOnlyControl` accepts `--host` wording.
- Implementation uses numeric IPv4 parsing through `inet_pton`-style handling.

Risk:

- Hostnames are a reasonable operator expectation but fail as invalid host strings.

Remediation:

- Either rename/help-text the argument as IPv4 address or add DNS resolution.
- Add tests for hostname rejection or hostname resolution, depending on chosen contract.

Acceptance:

- CLI help and runtime behavior agree.

### P1 - Video, AV Sync, And Packetization

#### AUD-P1-VIDEO-001 - Default raw video packetization is too heavy for audio-first realtime behavior

Evidence:

- `Sources/OpenLolaCore/Network/P2P/PeerSessionRunner.swift:208` describes bidirectional AVFoundation video.
- `Sources/OpenLolaCore/Network/P2P/PeerSessionRunner.swift:491` packetizes frames against `mtuBytes`, defaulting to `1200`.
- `Sources/OpenLolaCore/Video/VideoTransportPacket.swift:510` fragments raw captured frames.
- CLI defaults currently include raw `1280x720@30` style AV operation.

Risk:

- Raw BGRA at 1280x720x30 can create thousands of fragments per second.
- Video can starve audio, inflate packet loss, and make "balanced" AV unsafe by default.

Remediation:

- Add an explicit packet-budget estimator before AV start.
- Refuse or degrade raw video when estimated fragments exceed the active profile budget.
- Prefer lower raw defaults or require explicit override for high raw frame sizes.

Acceptance:

- CLI reports estimated video bandwidth/fragments before run.
- Audio-first profiles cannot start an unsafe raw video shape silently.

#### AUD-P1-VIDEO-002 - Live AV sync bypasses `AVTimestampAligner`

Evidence:

- `Sources/OpenLolaCore/Timing/MediaClock.swift:309` defines `AVSyncPolicy`.
- `Sources/OpenLolaCore/Timing/MediaClock.swift:351` defines `AVTimestampAligner`.
- `Sources/OpenLolaCore/Network/P2P/DirectPeerSessionAVSocketRunner.swift:325` computes local tolerance directly.
- `Sources/OpenLolaCore/Network/P2P/DirectPeerSessionAVSocketRunner.swift:539` accepts video through a boolean tolerance window.

Risk:

- The explicit policy model is not the live runtime behavior.
- Defer/drop/render decisions cannot be trusted to match `directAudioFirst`, `balancedAV`, or WAN profiles.

Remediation:

- Use `AVTimestampAligner.decision` in the live video RX path.
- Record render/defer/drop counts by decision type.
- Add tests for zero-tolerance `directAudioFirst`, balanced defer, stale drop, and WAN tolerance.

Acceptance:

- Runtime AV sync decisions are policy-driven and reportable.

#### AUD-P1-VIDEO-003 - AES67 AV sync mixes local and remote time domains

Evidence:

- `Sources/OpenLolaCore/Network/P2P/DirectPeerSessionAVAudioLoops.swift:115` sets AES67 sender frame from RTP timestamp.
- `Sources/OpenLolaCore/Network/P2P/DirectPeerSessionAVAudioLoops.swift:116` sets audio host time to local `DispatchTime.now()`.
- `Sources/OpenLolaCore/Network/P2P/DirectPeerSessionAVSocketRunner.swift:539` compares video timestamp against latest audio host time.

Risk:

- Audio and video timestamps may not share a clock origin.
- Valid video can be dropped, or invalid video can be accepted, depending on local receive timing.

Remediation:

- Normalize AES67 RTP timestamp into the same media clock domain used by video.
- Store clock-domain metadata in reports.
- Add tests for AES67 plus raw video with controlled offsets.

Acceptance:

- AV sync never compares local receive time to remote media timestamp without explicit conversion.

#### AUD-P2-VIDEO-004 - Corrupt video fragments can abort the AV run

Evidence:

- `Sources/OpenLolaCore/Network/P2P/DirectPeerSessionAVSocketRunner.swift:567` throws on `VideoTransportFragment.decode`.
- Reassembly and report tests already model malformed fragments, but live AV loop still throws through the run path.

Risk:

- One corrupt UDP fragment can terminate a live AV run instead of being counted and dropped.

Remediation:

- Convert fragment decode/reassembly failures into recoverable drop counters in live AV RX.
- Keep fatal errors only for local programming/configuration failures.

Acceptance:

- Malformed video packet increments a corrupt/drop counter and the AV loop continues.

#### AUD-P2-VIDEO-005 - Preview errors and drops are not surfaced into AV runtime reports

Evidence:

- `DirectPeerSessionAVSocketRunner` submits preview frames directly and can throw from `previewSink.submit`.
- `RawBGRAAppKitPreviewWindow` has queue/drop behavior that is not reflected in AV reports.

Risk:

- Preview backpressure can abort the runtime or hide dropped preview frames.
- Operators cannot distinguish media RX success from preview UI failure.

Remediation:

- Make preview sink errors nonfatal by default.
- Count preview submitted, dropped, and failed frames in the runtime report.

Acceptance:

- A preview-window failure cannot stop audio/video transport unless explicitly configured as fatal.

#### AUD-P2-VIDEO-006 - Blackmagic output boundary is an explicit stub

Evidence:

- `Sources/OpenLolaCore/Video/BlackmagicOutputBoundary.swift:54` says hardware enumeration is not implemented.

Risk:

- Product can appear to have linked DeckLink output support while runtime output is only preview/report-level.

Remediation:

- Keep this as an explicit `PARTIAL` blocker until enumeration and output are implemented.
- Surface the limitation in CLI/app reports.

Acceptance:

- No report or UI surface implies DeckLink output works without actual hardware enumeration evidence.

### P1 - macOS App, UI, And Operator Truthfulness

#### AUD-P1-UI-001 - Preview reports active before device/permission success

Evidence:

- `Sources/open-lola-app/AppPreviewReceiverView.swift:48` sets `previewIsActive = true`.
- `Sources/open-lola-app/AppPreviewReceiverView.swift:49` starts video preview after the active flag.
- `Sources/open-lola-app/AppPreviewReceiverView.swift:50` starts audio meter after the active flag.
- `Sources/open-lola-app/AppPreviewReceiverView.swift:51` reports `Local device preview active.`

Risk:

- UI can show a live/active preview state even when camera, audio device, or permission startup fails.

Remediation:

- Add explicit preview state: idle, starting, active, degraded, failed.
- Set active only after controllers confirm availability.
- Surface permission/device errors in routing/status panels.

Acceptance:

- UI cannot display "active" without a verified audio/video controller state.

#### AUD-P1-UI-002 - Local preview scaling can overlap adjacent UI

Evidence:

- `Sources/open-lola-app/AppPreviewReceiverView.swift:177` sets layout frame.
- `Sources/open-lola-app/AppPreviewReceiverView.swift:178` applies `.scaleEffect(previewState.videoScale)`.
- Scale can reach `2.0`, which does not reserve layout space.

Risk:

- At high scale or small window sizes, the preview can visually overdraw adjacent audio/status controls.

Remediation:

- Replace layout-external scale transform with size-aware layout, zoomed viewport, or clipped scroll/fit behavior.
- Add minimum-window and max-scale visual probes.

Acceptance:

- Text and controls remain readable at minimum supported window size and every supported preview scale.

#### AUD-P1-UI-003 - Command preview mutates execution settings during view rendering

Evidence:

- `Sources/open-lola-app/AppExecutionView.swift:56` renders a command preview.
- `Sources/open-lola-app/AppExecutionView.swift:60` passes `dryRun: true`.
- `Sources/open-lola-app/AppExecutionController.swift:95` sets `settings.execute = !dryRun`.

Risk:

- A SwiftUI body render can mutate execution settings.
- Previewing a command can silently flip the execution mode back to dry-run.

Remediation:

- Split pure command rendering from state mutation.
- Make `executionCommand(... dryRun:)` pure.
- Mutate `settings.execute` only in explicit start/write actions.

Acceptance:

- Rendering `AppExecutionView` has no side effects on execution settings.

#### AUD-P1-UI-004 - Latency hero appears unreachable

Evidence:

- `Sources/open-lola-app/AppExecutionController.swift:420` loads latency metrics after successful report/validation.
- `Sources/open-lola-app/AppShellRootView.swift:286` displays the latency hero only when `sessionState == .live`.
- `Sources/open-lola-app/AppSessionStateBanner.swift:121` derives states but never returns `.live`.

Risk:

- Important runtime latency data can be loaded but never shown.

Remediation:

- Define the exact evidence required for `.live`.
- Either derive `.live` when report-backed evidence exists or render latency metrics in `awaitingEvidence` with truthful labeling.

Acceptance:

- Latency metrics are visible in the correct truthful state, or the dead `.live` branch is removed.

#### AUD-P1-UI-005 - Current app surface probe cannot catch unreadable text or missing windows

Evidence:

- `native-app-shell-surface-probe` returns `VERDICT: PARTIAL`.
- Its launch plan records `recordsScreenshotOrLog: false`.
- `script/build_and_run.sh --verify` checks process/window existence rather than visual readability.

Risk:

- UI regressions such as unreadable text, overlap, missing menu items, and invisible windows can pass.

Remediation:

- Add a macOS surface probe that launches the app, captures a screenshot or accessibility/window hierarchy, and verifies key menus/views.
- Include minimum-size and high-contrast visual checks.

Acceptance:

- UI verification includes rendered evidence, not only source-contract assertions.

#### AUD-P2-UI-006 - Sidebar avoids native desktop navigation semantics

Evidence:

- App shell uses custom chrome/sidebar rather than native `NavigationSplitView`/`List` semantics.
- Tests explicitly preserve the custom surface shape.

Risk:

- Keyboard navigation, accessibility, focus, and system behaviors can lag behind macOS expectations.

Remediation:

- Keep custom console style only where it carries real operator value.
- Add accessibility labels, focus order, keyboard navigation, and VoiceOver checks.

Acceptance:

- Sidebar is keyboard-usable and screen-reader coherent.

### P2 - Tests, Slop, Dead Code, And Structure

#### AUD-P2-TEST-001 - Source-string tests hide behavioral regressions

Evidence:

- App shell and video tests include many `source.contains(...)` assertions.
- Subagents found source-string checks in UI, AV support, and video transport suites.

Risk:

- Tests can pass while runtime behavior is broken.
- Tests can fail on harmless refactors, creating noisy maintenance.

Remediation:

- Replace source-string assertions with behavior tests where practical.
- Keep source-string tests only for narrow policy constraints that cannot be behaviorally probed.

Acceptance:

- Critical UI/runtime contracts are tested through functions, reports, CLI probes, or rendered app probes.

#### AUD-P2-TEST-002 - Production AV coverage is mostly synthetic or fixture-level

Evidence:

- Swift suite passes, but production AV regression paths build reports/fixtures more than they exercise live AVFoundation/audio/video loops.

Risk:

- Real device graph issues can remain invisible until field testing.

Remediation:

- Add local bounded production-mode smoke tests with injectable audio/video seams.
- Keep hardware-required tests opt-in and report `PARTIAL` when hardware is absent.

Acceptance:

- CI has deterministic source-level production-mode tests; hardware gates remain explicit manual/field evidence.

#### AUD-P2-SLOP-001 - Synthetic smoke uses `try!`

Evidence:

- `Sources/OpenLolaCore/Control/LightingFixtureGateRun.swift:258` uses `try!`.

Risk:

- A future config or validator change turns a smoke helper into a hard crash.

Remediation:

- Replace `try!` with a throwing smoke method or a nonthrowing fixture builder that cannot fail by construction.

Acceptance:

- Smoke helpers do not trap on recoverable validation changes.

#### AUD-P2-SLOP-002 - Compile warnings remain in tests/vendor boundary

Evidence:

- Swift test run emitted `var` never mutated warnings in `RecordingSessionLiveCaptureTests.swift`.
- Third-party C compilation emitted warnings from vendored Opus/JPEG XS code.

Risk:

- Warnings reduce signal in future verification logs.

Remediation:

- Change unmutated test locals to `let`.
- Track third-party warnings in a dependency-boundary note; do not patch vendored code unless needed for release.

Acceptance:

- Owned Swift test warnings are removed.
- Vendor warnings are either suppressed at boundary or documented as accepted.

#### AUD-P2-STRUCT-001 - Oversized files concentrate runtime logic

Evidence:

- Several source/test files are near the repo line-budget ceiling, including runtime runners, app settings, recording artifacts, and command matrices.

Risk:

- Large files hide duplicated validation and make focused review harder.

Remediation:

- Split only when it reduces actual cognitive load:
  - P2P validation helpers
  - AV audio/video loop helpers
  - UI command preview/state derivation
  - report fixture builders

Acceptance:

- No file split changes behavior.
- Existing line-budget tests pass without weakening the threshold.

#### AUD-P2-STRUCT-002 - Validation logic is duplicated across CLI, planner, and app

Evidence:

- Direct CLI, two-peer planner, and app operator surfaces each shape command arguments.
- Findings above show inconsistent validation for ports, host format, and media shape.

Risk:

- One surface accepts combinations that another rejects later.

Remediation:

- Create shared value objects for direct peer endpoint, media shape, port set, and advertised host.
- Keep parsing thin and route all surfaces through the same validators.

Acceptance:

- CLI, app, and planner reject the same invalid configurations with consistent messages.

## Deep Audit Enrichment - 2026-05-12

This section adds findings from the second, deeper pass over the live tree. It keeps the first finding set intact and records only additional or materially sharpened findings.

Additional read-only checks run for this enrichment:

```sh
PYTHONDONTWRITEBYTECODE=1 python3 -m scripts.verify_docs
find Sources Tests scripts script linux_connector -path 'Sources/opus-1.5.2' -prune -o -path 'Sources/xs_ref_sw_ed2' -prune -o -type f
find linux_connector scripts -name '*.pyc' -print
rg -n "source\.contains|contents\(ofFile|try!|as!|fatalError|preconditionFailure|Thread\.sleep|usleep|Task\.detached|createFile|TODO|FIXME|HACK" Sources Tests scripts script linux_connector --glob '!Sources/opus-1.5.2/**' --glob '!Sources/xs_ref_sw_ed2/**'
```

Observed enrichment results:

- Active-scope inventory excluding vendor trees found `615` files.
- Active owned Swift line inventory is `118535` total physical lines.
- Root `plan.md` makes `PYTHONDONTWRITEBYTECODE=1 python3 -m scripts.verify_docs` fail with `plan.md must stay archived, not active`.
- Live Python bytecode residue exists under `linux_connector/**/__pycache__` and `scripts/verify_docs/__pycache__`.

### Additional P0 Findings

#### AUD-P0-PLAN-001 - Requested root `plan.md` breaks the active docs contract

Evidence:

- `plan.md:1` is active at the repository root.
- `scripts/verify_docs/markdown_checks.py:169` includes `ROOT / "plan.md"` in the stale active-path denylist.
- `scripts/verify-release-readiness.sh:162` runs `bash scripts/verify-docs.sh` as the first release-readiness step.
- `PYTHONDONTWRITEBYTECODE=1 python3 -m scripts.verify_docs` currently fails with `plan.md must stay archived, not active`.

Risk:

- The requested audit artifact blocks the docs and release-readiness gates.
- A stale verification snapshot can claim docs passed even though the current tree now fails.

Remediation:

- Make an explicit product decision:
  - Option A: root `plan.md` is now an active authority surface; update `scripts.verify_docs`, README/docs routing, and release/compliance docs accordingly.
  - Option B: root `plan.md` is a temporary audit artifact; archive it after use and keep active docs clean.
- Until that decision is made, report the repo verdict as `FAIL` for docs verification.

Suggested test:

- `PYTHONDONTWRITEBYTECODE=1 python3 -m scripts.verify_docs`
- `bash scripts/verify-docs.sh`
- `bash scripts/verify-release-readiness.sh`

Acceptance:

- Either root `plan.md` is accepted by the docs contract, or no active root `plan.md` remains.
- Verification text never claims docs pass while the active tree fails.

#### AUD-P0-AUDIO-003 - `DirectPeerAudioPayloadRing` mixes atomics with non-atomic Swift array metadata

Evidence:

- `Sources/OpenLolaCore/Audio/Realtime/DirectPeerAudioPayloadRing.swift:10` stores `startFrames` in a Swift array.
- `Sources/OpenLolaCore/Audio/Realtime/DirectPeerAudioPayloadRing.swift:11` stores `hostTimes` in a Swift array.
- `Sources/OpenLolaCore/Audio/Realtime/DirectPeerAudioPayloadRing.swift:12` stores `occupied` in a Swift array.
- `Sources/OpenLolaCore/Audio/Realtime/DirectPeerAudioPayloadRing.swift:61` writes `startFrames` from the producer path.
- `Sources/OpenLolaCore/Audio/Realtime/DirectPeerAudioPayloadRing.swift:66` writes `occupied` before publishing `writeIndex`.
- `Sources/OpenLolaCore/Audio/Realtime/DirectPeerAudioPayloadRing.swift:84` reads `occupied` from the consumer path.
- `Sources/OpenLolaCore/Audio/Realtime/DirectPeerAudioPayloadRing.swift:96` writes `occupied` from the consumer path.
- `Sources/OpenLolaCore/Audio/Realtime/DirectPeerAudioPayloadRing.swift:148` scans slots between `read` and `write`.
- `Sources/COpenLolaAtomics/OpenLolaAtomics.c:9` and `Sources/COpenLolaAtomics/OpenLolaAtomics.c:13` provide acquire/release index atomics, but those atomics do not make Swift array element access itself formally synchronized.

Risk:

- The IOProc and network thread can concurrently touch Swift array storage and Bool metadata.
- The ring may work empirically but still be a data-race risk under TSAN and a rare realtime corruption/crash risk.

Remediation:

- Move slot metadata into fixed raw buffers or a C slot struct with explicit atomic slot state.
- Define a single ownership transition per slot: producer writes payload and metadata, then publishes the slot; consumer claims and clears it after copy.
- Keep Swift `Array` out of cross-thread realtime slot metadata.

Suggested test:

- Add a TSAN-targeted producer/consumer stress test for `DirectPeerAudioPayloadRing`, separate from `SPSCUInt64Ring`.
- Add deterministic tests for producer wrap, consumer skip, late playout lookup, and slot reuse.

Acceptance:

- The payload ring has no unsynchronized Swift array element mutation across producer/consumer threads.
- TSAN stress does not report slot metadata races.

### Additional P1 Findings

#### AUD-P1-AUDIO-007 - MADI receive omits metadata revision and packing mode from fragment-plan matching

Evidence:

- `Sources/OpenLolaCore/Audio/MADI/MadiReceive.swift:255` validates incoming `UdpPcmV2Packet` fields against the MADI mode.
- `Sources/OpenLolaCore/Audio/MADI/MadiReceive.swift:274` matches the packet against `mode.fragments`.
- `Sources/OpenLolaCore/Audio/MADI/MadiReceive.swift:275` through `Sources/OpenLolaCore/Audio/MADI/MadiReceive.swift:278` check fragment index, channel offset, channel count, and payload byte count, but not `metadataRevision` or `packingMode`.
- Generic reassembly checks metadata consistency among packets, but this MADI mode check does not prove the packet matches the expected mode metadata.

Risk:

- A full deadline with stale MADI matrix metadata can be accepted if its fragments are internally consistent.
- Receiver mix/routing evidence can look valid while using the wrong metadata revision or packing mode.

Remediation:

- Include `fragment.metadataRevision == packet.header.metadataRevision` and `fragment.packingMode == packet.header.packingMode` in the mode/fragment match.
- Report metadata mismatch separately from packet corruption.

Suggested test:

- Mutate the first MADI packet's `metadataRevision` and `packingMode` before `receive`.
- Expect `MadiReceiveError.transportModeMismatch`, not queued/rendered audio.

Acceptance:

- MADI receive rejects internally consistent fragments that do not match the configured MADI metadata revision and packing mode.

#### AUD-P1-AUDIO-008 - Generic UDP PCM v2 reassembly can complete overlapping channel fragments

Evidence:

- `Sources/OpenLolaCore/Network/UDP/UdpPcmV2Packet.swift:408` groups fragments only by `fragmentIndex`.
- `Sources/OpenLolaCore/Network/UDP/UdpPcmV2Packet.swift:442` validates shared deadline fields.
- `Sources/OpenLolaCore/Network/UDP/UdpPcmV2Packet.swift:464` checks total channel count consistency.
- `Sources/OpenLolaCore/Network/UDP/UdpPcmV2Packet.swift:467` checks fragment count consistency.
- `Sources/OpenLolaCore/Network/UDP/UdpPcmV2Packet.swift:473` and `Sources/OpenLolaCore/Network/UDP/UdpPcmV2Packet.swift:476` check metadata revision and packing mode consistency.
- `Sources/OpenLolaCore/Network/UDP/UdpPcmV2Packet.swift:493` reassembles by iterating fragment indices.
- `Sources/OpenLolaCore/Network/UDP/UdpPcmV2Packet.swift:497` uses each packet's `channelsInFragment`.
- The aggregate path does not prove channel ranges are non-overlapping and gap-free before returning a complete payload.

Risk:

- Two decoded-valid fragments with different `fragmentIndex` but overlapping `channelOffset` can overwrite channels and leave holes zero-filled.
- The reusable reassembler can report a complete payload that is not a complete channel map.

Remediation:

- Validate aggregate channel coverage before `payload` is returned:
  - no overlapping `[channelOffset, channelOffset + channelsInFragment)` ranges;
  - no gaps;
  - final coverage equals `totalChannelCount`;
  - fragment order matches the deterministic fragment planner for the declared packing mode.

Suggested test:

- Build two decoded-valid fragments with indices `0` and `1` but the same `channelOffset`.
- Expect reassembly failure rather than `payload != nil`.

Acceptance:

- `UdpPcmV2FragmentReassembler.reassemble` only returns complete payloads for a full, non-overlapping channel coverage plan.

#### AUD-P1-NET-006 - Two-peer supervisor can report `PASS` without aggregate or RX-proof evidence

Evidence:

- `Sources/open-lola/Commands/Network/DirectP2PTwoPeerLocalRunCommandSupport.swift:16` builds `aggregateReportPath` with `try?`, suppressing aggregate generation errors.
- `Sources/OpenLolaCore/Network/P2P/DirectPeerTwoPeerLocalRunReport.swift:166` validates `PASS` by checking execution and process exit status only.
- `Sources/OpenLolaCore/Network/P2P/DirectPeerTwoPeerLocalRunReport.swift:170` accepts `PASS` when process results all have exit code `0`.
- `Sources/OpenLolaCore/Network/P2P/DirectPeerTwoPeerLocalRunReport.swift:210` sets verdict to `.pass` when executed and all process exits are zero.
- The validation path does not require `aggregateExecuted`, `aggregateReportPath`, collected direct reports, or RX proof artifacts.

Risk:

- The supervisor can overstate two-peer evidence if both child commands exit zero but aggregate proof assembly fails or RX proof is absent.
- This is especially dangerous because the project distinguishes source-level completion from field evidence.

Remediation:

- Require aggregate generation and both peer reports/RX proofs before supervisor `PASS`.
- If aggregate or RX proof is unavailable, downgrade to `PARTIAL` with explicit blockers.
- Preserve nonzero exit code as `FAIL` or `PARTIAL` according to the existing measurement model.

Suggested test:

- Build process results with two zero exit codes and `aggregateReportPath == nil`.
- Assert report verdict is `PARTIAL` and validation rejects `PASS`.

Acceptance:

- Two-peer supervisor `PASS` cannot be produced without aggregate report evidence and RX proof evidence.

#### AUD-P1-NET-007 - Metrics transport is wired but peer metrics are not exchanged

Evidence:

- `Sources/OpenLolaCore/Network/P2P/PeerSessionRunner.swift:79` binds the metrics UDP transport.
- `Sources/OpenLolaCore/Network/P2P/PeerSessionRunner.swift:277` requires a metrics transport before media starts.
- `Sources/OpenLolaCore/Network/P2P/PeerSessionRunner.swift:282` connects the metrics transport to the remote metrics endpoint.
- `Sources/OpenLolaCore/Network/UDP/UdpMediaTransport.swift:242` can convert local `UdpMediaMetrics` into a control message.
- `Sources/OpenLolaCore/Network/P2P/PeerSessionRunner.swift:669` ignores incoming `.metrics` messages.

Risk:

- `--metrics-port` appears operational but peer metrics are local-only.
- Loss, jitter, late packet, CPU, memory, and queue telemetry cannot be correlated across peers.

Remediation:

- Either implement periodic local metrics publication and remote metrics storage, or mark the metrics port as reserved/nonfunctional in CLI help, reports, and app UI.
- Add remote metrics to report validation only after exchange exists.

Suggested test:

- Loopback pair sends metrics from peer A to peer B.
- Assert peer B records remote `packetsLost`, `jitterMicroseconds`, and `latePackets`.

Acceptance:

- A connected metrics port either exchanges peer metrics or is no longer presented as active telemetry.

#### AUD-P1-VIDEO-007 - AVFoundation capture timestamps callback-arrival time, not sample presentation time

Evidence:

- `Sources/OpenLolaCore/Video/VideoCaptureAVFoundation.swift:395` receives sample buffers.
- `Sources/OpenLolaCore/Video/VideoCaptureAVFoundation.swift:411` timestamps frames with `DispatchTime.now().uptimeNanoseconds`.
- `Sources/OpenLolaCore/Video/VideoCaptureAVFoundation.swift:426` records frame metadata as `.hostUptimeNanoseconds`.

Risk:

- Capture queue jitter becomes media timestamp jitter.
- AV sync and frame interval metrics can look better or worse than actual camera timing.

Remediation:

- Derive media timestamps from `CMSampleBufferGetPresentationTimeStamp`.
- If callback arrival time is still useful, store it as separate diagnostic metadata.
- Make the timestamp domain explicit in video reports.

Suggested test:

- Add an injectable sample-buffer timestamp conversion test where callback execution is delayed but PTS is stable.
- Assert frame metadata follows PTS, not callback arrival.

Acceptance:

- Video media timestamps represent presentation time, and callback-arrival latency is measured separately.

#### AUD-P1-UI-007 - App menu action contract drifts from the reported surface contract

Evidence:

- `Sources/open-lola-app/OpenLolaApp.swift:47` defines the actual `CommandMenu("Open LoLa")`.
- `Sources/open-lola-app/OpenLolaApp.swift:57` includes `Arm Execution`.
- `Sources/open-lola-app/OpenLolaApp.swift:62` includes `Write Two-Peer Plan`.
- `Sources/open-lola-app/OpenLolaApp.swift:67` includes `Dry Run Supervisor`.
- `Sources/open-lola-app/OpenLolaApp.swift:93` includes `Clear Command Intent`.
- `Sources/OpenLolaCore/Platform/NativeAppShellSurfaceContract.swift:134` defines a separate action list with different ids/titles such as `run-supervisor-preflight`, `request-start-intent`, and `request-run-intent`.
- Existing source-contract tests assert selected strings rather than an exact parity model.

Risk:

- The source-level surface probe can claim action coverage that does not match the real menu surface.
- Missing menu items or stale action ids can survive verification.

Remediation:

- Define one typed action inventory shared by the menu, app transport controls, and `NativeAppShellSurfaceContract`.
- Alternatively add an exact parity test that compares ids, titles, shortcuts, disabled policy, and execution flags.

Suggested test:

- Assert `NativeAppShellSurfaceContract.releaseReadiness.actions` equals the actual menu/action inventory.
- Include keyboard shortcuts and realtime-safety flags.

Acceptance:

- The reported app action contract cannot drift from the actual operator menu.

#### AUD-P1-UI-008 - Settings and main console have split sources of truth

Evidence:

- `Sources/open-lola-app/AppShellSettingsView.swift:325` starts settings bindings that write both `AppSettings` storage and `operatorSurface`.
- `Sources/open-lola-app/AppShellSettingsView.swift:338` has peer bindings that write storage plus command fields.
- `Sources/open-lola-app/AppShellSettingsView.swift:378` has app preview bindings that write storage plus preview state.
- `Sources/open-lola-app/AppLocalOperatorSurfaceView.swift:214` and `Sources/open-lola-app/AppLocalOperatorSurfaceView.swift:222` mutate console/operator-surface selections directly.

Risk:

- Operators can edit routing/device fields in the console, see previews or command text change, then lose or contradict those values in Settings/relaunch.

Remediation:

- Choose one authoritative edit model:
  - `operatorSurface` persisted on change, or
  - all console controls routed through `AppSettings` bindings.
- Add a synchronization boundary for imported remote inventory and local inventory refreshes.

Suggested test:

- With test `UserDefaults`, mutate console-equivalent fields and assert persisted defaults plus command preview remain in sync after rehydration.

Acceptance:

- The same field cannot have different values in console state, settings storage, and generated command preview.

#### AUD-P1-UI-009 - App execution log preparation fails on repeated runs with existing log files

Evidence:

- `Sources/open-lola-app/AppExecutionController.swift:384` prepares log files.
- `Sources/open-lola-app/AppExecutionController.swift:387` requires `FileManager.default.createFile(atPath: stdoutPath, contents: nil)` to return true.
- `Sources/open-lola-app/AppExecutionController.swift:390` applies the same guard to stderr.
- `Sources/open-lola-app/AppExecutionController.swift:496` uses stable default log paths under the app cache directory.

Risk:

- `createFile` returns false when the file already exists, so a second run can fail before starting.
- The app can appear broken after the first execution unless logs are manually removed.

Remediation:

- Create the directory, then open/truncate existing log files intentionally.
- Include failure context with the exact log path.

Suggested test:

- Pre-create stdout/stderr log files, then call the run/validation preparation path.
- Assert the files are truncated/opened and execution can start.

Acceptance:

- Repeated app runs and validations do not fail solely because previous log files exist.

#### AUD-P1-RELEASE-001 - Release export can carry Python bytecode/cache residue

Evidence:

- `.gitignore:24` ignores `__pycache__/`.
- `.gitignore:25` ignores `*.py[cod]`.
- `docs/compliance/release-manifest.md:51` says caches are excluded from release.
- `scripts/export-release-candidate.sh:21` removes only `.DS_Store`.
- `scripts/export-release-candidate.sh:60` starts an allowlist that copies whole trees.
- `scripts/export-release-candidate.sh:71` copies `linux_connector`.
- `scripts/export-release-candidate.sh:72` copies `scripts`.
- `scripts/verify-release-hygiene.sh:100` scans for many forbidden candidate items but not `__pycache__` or `*.pyc`.
- Live residue exists under `linux_connector/**/__pycache__` and `scripts/verify_docs/__pycache__`.

Risk:

- Source release candidates can pass hygiene while shipping local Python bytecode.
- This contradicts the release manifest and weakens reproducibility.

Remediation:

- Strip `__pycache__` and `*.pyc` in `export-release-candidate.sh`.
- Reject `__pycache__` and `*.pyc` in `find_forbidden_candidate_item`.
- Run Python tools with `PYTHONDONTWRITEBYTECODE=1` in verification wrappers when possible.

Suggested test:

- Extend `ReleaseArtifactHygieneContractTests.swift` to require `__pycache__` and `*.pyc` rejection.
- Stage a candidate containing a `.pyc` and assert `verify-release-hygiene.sh` fails.

Acceptance:

- Release export and release hygiene both reject Python bytecode/cache residue.

### Additional P2 Findings

#### AUD-P2-NET-008 - Manual network host and port validation remains late and incomplete

Evidence:

- `Sources/open-lola/Commands/Network/DirectP2PSessionRunCommandSupport.swift:351` builds manual configuration from strings and UInt16 ports.
- `Sources/open-lola/Commands/Network/DirectP2PSessionRunCommandSupport.swift:355` accepts `--local-host` as a required string.
- `Sources/open-lola/Commands/Network/DirectP2PSessionRunCommandSupport.swift:357` through `Sources/open-lola/Commands/Network/DirectP2PSessionRunCommandSupport.swift:361` parse ports independently.
- `Sources/OpenLolaCore/Protocol/SessionProtocol.swift` only enforces non-empty endpoints.
- `Sources/OpenLolaCore/Network/P2P/DirectPeerTwoPeerLocalRunReport.swift:318` checks distinct ports for control/audio/video only.
- `Sources/OpenLolaCore/Network/P2P/DirectPeerTwoPeerLocalRunReport.swift:319` omits metrics and remote-control ports from the distinct-port check.

Risk:

- Invalid hostnames and duplicate metrics/control ports fail at bind/connect time instead of plan/CLI validation.
- Operator feedback is later and less actionable.

Remediation:

- Add shared endpoint validation for supported host forms and advertised/bind host semantics.
- Require distinct active control/audio/video/metrics ports per peer.
- Include remote-control consistency checks in two-peer preflight.

Suggested test:

- Duplicate `--metrics-port`/`--audio-port` rejects before bind.
- Unsupported host strings reject before socket creation.

Acceptance:

- Manual direct and two-peer commands fail invalid host/port combinations before runtime sockets are opened.

#### AUD-P2-UI-010 - Windows LoLa non-negative fields use a positive-only integer control

Evidence:

- `Sources/open-lola-app/AppShellSettingsView.swift:405` uses non-negative bindings for Windows LoLa fields such as compression and Bayer values.
- `Sources/open-lola-app/AppShellSupportViews.swift:60` accepts only parsed values greater than zero in the generic integer field.
- `Sources/open-lola-app/AppShellSettingsView.swift:514` wires these controls into the settings UI.

Risk:

- Valid zero values become hard or impossible to re-enter through Settings.
- The UI can produce a different shape than the underlying command contract permits.

Remediation:

- Add a `NonNegativeIntField` or parameterize `IntField` with a minimum value.
- Use positive-only controls only for fields that truly reject zero.

Suggested test:

- Unit or source-contract binding test proving `0` is accepted for compression/Bayer fields and rejected for positive-only fields.

Acceptance:

- UI numeric controls match each command field's actual validation range.

#### AUD-P2-UI-011 - Settings window uses horizontal scrolling around a tab view

Evidence:

- `Sources/open-lola-app/AppShellSettingsView.swift:12` wraps the entire settings `TabView` in `ScrollView(.horizontal)`.
- `Sources/open-lola-app/AppShellSettingsView.swift:177` constrains the `TabView` only with min/ideal width.

Risk:

- Smaller windows can hide fields laterally.
- Keyboard and VoiceOver navigation through forms becomes less predictable than a native macOS settings scene.

Remediation:

- Use a standard settings `TabView` with stable width and per-tab vertical form scrolling.
- Avoid horizontal scroll around the tab container.

Suggested test:

- Source-contract test forbidding `ScrollView(.horizontal)` around the settings `TabView`.
- Rendered app probe at minimum settings window width.

Acceptance:

- Settings fields remain discoverable and readable without horizontal panning.

#### AUD-P2-STRUCT-003 - CLI argument parsing is duplicated despite a shared parser

Evidence:

- `Sources/OpenLolaCore/Core/KeyValueArgumentParser.swift:1` provides the shared parser.
- `Sources/open-lola/Commands/Network/DirectP2PSessionRunCommandSupport.swift:19` contains a manual parser loop.
- `Sources/open-lola/Commands/Network/DirectP2PMeshArgumentSupport.swift:3` contains another manual parser path.

Risk:

- Missing-value, duplicate-key, and unknown-argument behavior can drift across commands.

Remediation:

- Route manual key/value command parsers through `KeyValueArgumentParser.parseValues`.
- Keep command-specific validation after shared parsing.

Suggested test:

- Add duplicate, missing-value, and unknown-argument parity tests for affected commands.

Acceptance:

- Key/value CLI surfaces share the same parse error semantics.

#### AUD-P2-STRUCT-004 - Legacy `script/` generator sits outside the canonical script surface

Evidence:

- `scripts/README.md` documents canonical `scripts/**` workflows.
- `script/build_and_run.sh:12` writes generated app bundles into `dist`.
- `.gitignore:38` ignores `/dist/`.
- `NativeAppShellSurfaceContract` points to `./script/build_and_run.sh --verify`, so this legacy path is still active.

Risk:

- A live artifact generator is easy to miss in docs, shellcheck scope, release hygiene, and cleanup.

Remediation:

- Either move `script/*.sh` under `scripts/` and document it, or document `script/` explicitly as the app-bundle helper lane.
- Keep shellcheck and verification contract tests covering it.

Suggested test:

- Verification tooling contract asserts every active shell helper directory is documented and shellchecked.

Acceptance:

- No active shell helper lane exists outside the documented verification surface.

#### AUD-P2-STRUCT-005 - Line-budget guard omits active Python and legacy shell lanes

Evidence:

- `Tests/OpenLolaCoreTests/CodeLineBudgetTests.swift:12` defines scoped paths for the line-budget test.
- `Tests/OpenLolaCoreTests/CodeLineBudgetTests.swift:13` through `Tests/OpenLolaCoreTests/CodeLineBudgetTests.swift:17` include `Package.swift`, `Sources`, `Tests`, `scripts`, and `private`.
- The current active audit scope includes `linux_connector` and `script`, but those paths are not covered by the line-budget guard.

Risk:

- Python and legacy shell files can grow past the repo's own readability budget.

Remediation:

- Add `linux_connector` and `script` to the line-budget scope.
- Exclude `__pycache__`, vendor paths, and generated artifacts.

Suggested test:

- `swift test --filter CodeLineBudgetTests`

Acceptance:

- All active owned Swift, Python, and shell files are subject to the same line-budget policy.

#### AUD-P2-STRUCT-006 - Generated Python bytecode exists in the active checkout

Evidence:

- `linux_connector/lola_connector/__pycache__/runtime.cpython-313.pyc` exists.
- `linux_connector/tests/__pycache__/test_codec.cpython-313-pytest-8.3.4.pyc` exists.
- `scripts/verify_docs/__pycache__/main.cpython-313.pyc` exists.
- `.gitignore:24` and `.gitignore:25` ignore those files, but they remain in the raw filesystem checkout.

Risk:

- Local generated residue pollutes audit inventories and can be copied by coarse release/export scripts.

Remediation:

- Add dry-run-first cleanup for generated Python bytecode.
- Prefer `PYTHONDONTWRITEBYTECODE=1` for audit/verification commands that do not need bytecode caches.

Suggested test:

- Release hygiene check rejects a staged candidate containing `__pycache__` or `*.pyc`.

Acceptance:

- Active source inventories can exclude generated Python bytecode reliably, and release candidates cannot include it.

## Remediation Roadmap

### Phase 0 - Prove And Patch P0 Audio Safety

1. Add failing tests for started graph deinit/lifetime.
2. Add failing tests for fragmented 64-channel raw PCM RX.
3. Fix graph ownership/stop semantics.
4. Add raw PCM audio reassembly before playout.
5. Add invalid payload accounting.
6. Run focused audio tests, then full `swift test --no-parallel`.

### Phase 1 - Stabilize Network, AV Sync, And Video Budgeting

1. Add shared bind/advertise host validation and port-set validation.
2. Add AV packet-budget estimator and safe raw-video defaults.
3. Route live AV sync through `AVTimestampAligner`.
4. Normalize AES67 clock domain before AV comparison.
5. Make malformed video packets recoverable drops.
6. Run network, AV, and video test slices plus CLI probes.

### Phase 2 - Fix UI Truthfulness And Rendered Verification

1. Make command preview pure.
2. Replace preview boolean with explicit preview states.
3. Fix preview scaling/layout overflow.
4. Define or remove `.live` app state.
5. Add real macOS surface probe with screenshot or accessibility/window evidence.
6. Verify menus, settings, preview, and minimum window layout.

### Phase 3 - Remove Slop And Tighten Structure

1. Replace source-string tests with behavior tests for critical contracts.
2. Remove `try!` smoke trap.
3. Clean owned warnings.
4. Deduplicate validation helpers.
5. Split oversized files only where a test-backed seam already exists.
6. Re-run broad verification and update docs only where behavior changes.

## Required Verification Matrix After Remediation

Run from the repository root:

```sh
ruff check linux_connector
python -m pytest linux_connector/tests
python -m mypy --strict linux_connector/lola_connector
bash scripts/verify-docs.sh
shellcheck scripts/*.sh scripts/lib/*.sh script/*.sh linux_connector/env/*.sh
bash scripts/verify-release-hygiene.sh
swift test --build-path /private/tmp/open-lola2-remediation-build --no-parallel
/private/tmp/open-lola2-remediation-build/debug/open-lola session-capabilities
/private/tmp/open-lola2-remediation-build/debug/open-lola direct-p2p-session-run --help
/private/tmp/open-lola2-remediation-build/debug/open-lola native-app-shell-surface-probe
```

Add remediation-specific probes:

```sh
/private/tmp/open-lola2-remediation-build/debug/open-lola network-route-command-matrix
/private/tmp/open-lola2-remediation-build/debug/open-lola realtime-audio-path-inventory
/private/tmp/open-lola2-remediation-build/debug/open-lola video-control-degrade-matrix
/private/tmp/open-lola2-remediation-build/debug/open-lola goal-runtime-preflight
```

Required live/manual evidence before field-ready claims:

- CoreAudio/RME local full-duplex run.
- Two-Mac direct P2P run.
- Packet capture with advertised host and distinct media/control ports.
- Raw/Opus/AES67 AV receive proof.
- Rendered macOS app screenshot or accessibility/window hierarchy.
- Signing, notarization, Gatekeeper, clean-Mac launch.

## Acceptance Criteria For This Audit Artifact

- Findings are enumerated and tiered as `P0`, `P1`, and `P2`.
- Runtime areas are grouped by realtime audio/local RX/TX, UDP/P2P/control, video/AV, UI/app, and structure/tests.
- Each finding includes evidence, risk, remediation, and acceptance criteria.
- The plan does not claim field readiness without live hardware/window/signing evidence.
- The final verdict remains `PARTIAL` until remediation and field evidence are complete.

VERDICT: PARTIAL
