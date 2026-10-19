# Changelog

Notable changes, newest first. Open LoLa does not publish releases; these
entries describe the state of the repository.

## Unreleased

- Core Audio: each IOProc registration owns its own callback storage. A failed
  stop, unregister, or callback drain can no longer leave callbacks pointing at
  a freed graph or scratch buffers. Startup failures keep their registration
  handles so cleanup can retry, and stopped output callbacks emit silence. If
  the HAL still refuses teardown when the graph is released, the callback
  storage is kept for the life of the process.
- Rust A/V timing: received audio is re-blocked to the local device's sample
  quantum, combining or splitting peer packets without changing the playback
  rate. Invalid PCM no longer advances sequence state, and duplicate bursts no
  longer trigger a false sender restart. The PortAudio ring keeps producer and
  consumer ownership separate even at capacity one.
- Rust video: invalid frames no longer advance receive freshness; JPEG recording
  gets decoded pixels; network video counters count completed frames, not UDP
  fragments.
- macOS scheduling: media waits wake on control messages. Video transmit and
  receive bursts yield between packets after a quarter of an audio period
  (at most 250 µs). Synthetic capture follows the negotiated audio cadence.
  Transport jitter works across hosts with different uptimes and starts at the
  second observation. Decoded media drains consume and count empty datagrams
  instead of stopping early; the shared and raw receive APIs keep their
  existing empty-payload behavior.
- macOS LoLa lifecycle: a peer disconnect reaches TX, RX, and TX-RX media
  workers, including capture waits and fragment bursts. Outgoing sessions keep
  a control socket for retries and disconnects, and retries stay pinned to the
  accepted session. Bidirectional cleanup joins workers before stopping their
  shared audio bridge. Video settings must match in both directions; audio-only
  negotiation accepts legacy video placeholders.
- macOS media: small downsampling chunks and large mach timestamps no longer
  overflow or trap; rejected playout blocks no longer reserve future playback
  time. Adaptive buffering uses a bounded jitter p99 instead of a smoothed mean.
  Matching interleaved audio layouts use a bounds-checked block copy. Video
  rendering keeps the latest frame per stream, rejects stale sequences,
  re-checks deadlines at delivery against local receive time, and keeps
  continuity across queued frames. Raw preview rejects invalid dimensions.
- Test sources are no longer published. The Swift and Rust integration test
  trees stay local, `Package.swift` declares a test target only if its source
  directory exists, and `make swift-test` falls back to a build when it does
  not. Removed obsolete duplication-baseline entries without raising the
  duplication budget. Hardware latency and reference-peer behavior still need
  separate testing.
- Rust station scheduling:
  - The interleaved loop sends up to 16 video fragments per quantum and stops
    150 µs before the audio deadline. Previously it sent one fragment per pass,
    with a control-socket poll and two blocking-mode toggles on every pass.
  - The control socket is serviced at most every 2 ms unless audio is due.
  - The idle sleep ends 200 µs early and spins to the deadline.
  - The media thread requests elevated priority (Windows `TIME_CRITICAL`, Linux
    `SCHED_FIFO` with a nice fallback, macOS user-interactive QoS) and reports
    the outcome as `realtime_priority`.
  - A ready PortAudio capture block paces the audio deadline ahead of the wall
    clock (`audio_device_paced_services`). A capture backlog above two blocks
    is trimmed to one (`audio_capture_backlog_drops`). A capture wait that
    expires skips the block instead of ending the session
    (`audio_capture_timeouts`).
  - The PortAudio callback ring never spins, and never discards more than one
    block, when the session thread holds a slot.
- Rust station resilience:
  - Transient socket faults (`ENOBUFS`, unreachable host or network, refused or
    reset connection, `EINTR`, and the Winsock equivalents) are counted as
    drops (`audio_send_drops`, `transient_receive_errors`) instead of failing
    the session. Only a fault that lasts two seconds without one successful
    send ends the session.
  - A rejected wrong-peer or wrong-port datagram no longer ends an audio or
    video receive drain early.
  - The audio receive queue resynchronises after 16 consecutive stale
    sequences (`audio_sequence_resyncs`).
  - The video reassembler evicts incomplete frames that are serial-older than a
    newer frame, instead of refusing new frames once 32 incomplete ones pile up.
    Under moderate loss, video used to freeze for up to 2 s
    (`video_superseded_incomplete_frames`). The newest superseded partial frame
    stays visible to the diagnostic incomplete-frame threshold.
  - Received video is sequence-gated (`video_out_of_order_drops`).
- Rust station video and UI: JPEG decoding of received frames moved off the
  session thread to a newest-wins decode worker (an inline 720p decode took
  several audio periods). Local capture and received video go to separate
  preview slots. The GUI shows "Received (RX)" when peer video is present and
  labels local capture as not received video. The preview keeps its aspect
  ratio, the idle placeholder is drawn once, and both previews clear when a
  session ends instead of showing the last frame as live.
- Interop corpus: a Rust compatibility test (source not published) replays all
  25 manifest cases and all 110 migration-oracle observations against the Rust
  codec.
- macOS LoLa connector interop with the Rust station:
  - The initiator treats the peer's `/MESG_REJECT` as a final answer and reports
    its reason (`peer rejected QUICKCONN: …`) instead of re-sending `QUICKCONN`
    until the deadline.
  - Audio-only sessions advertise the corpus placeholder video fields
    (`FPS:25;BPP:8;X:640;Y:480;COMP:0;BAYER:0`) instead of zeros, which the
    Rust responder rejected.
  - `SEND_AUDIO_SIGNAL` and `STOP_AUDIO_SIGNAL` end with a trailing `;` like
    every other message without fields.
  - Responder REJECT reasons are short (`audio settings mismatch`,
    `invalid media settings`).
  - A validated `/MESG_DISCONNECT` from the pinned peer's address and control
    port ends the live RX media loop within 50 ms and is recorded in the report.
  - The responder's final `STOP_AUDIO_SIGNAL` and `DISCONNECT` carry the
    negotiated SID.
- macOS direct-peer runtime:
  - The A/V session runs on a dedicated user-interactive thread. With preview
    on, the main thread pumps the run loop so the AppKit preview window
    renders; from the CLI it never did.
  - The newest-frame video workers always publish a finished result. Under load
    every result used to be superseded and no frame was delivered.
  - A failed video encode drops the frame instead of ending the session.
  - `ENOBUFS` is treated as backpressure; unreachable, refused, and interrupted
    sends are counted drops instead of session failures. Receive treats
    refused, reset, interrupted, and zero-length datagrams as "no datagram".
  - Removed the redundant `MSG_PEEK` before every receive and the discarded
    second audio-engine run per PCM packet.
  - The control-socket poll reuses one 16 KiB buffer, reads at most 64
    datagrams, and counts undecodable ones.
  - Video reassembly updates its bucket in place instead of copying the
    fragment table for each fragment.
  - Playout re-anchors only when a payload is later than the target buffer, and
    trims sustained excess latency (`audioPlayoutReanchors`).
  - The adaptive RX controller uses RFC 3550 interarrival jitter instead of
    comparing two hosts' clocks.
  - Capture blocks are stamped with the input sample time.
- Rust station media plane:
  - Every readable audio datagram enters the bounded receive queue, and exactly
    one block is played per audio deadline, so clustered arrivals are absorbed
    instead of dropped. The transport no longer discards older audio blocks.
  - The audio queue defaults to depth 4 with prefill 0 (settings, session
    profiles, and tabs) and gives back latency it borrowed after a late burst.
  - Remote audio is re-blocked to the local device block size when a peer uses
    a different frames-per-packet, instead of failing the session.
  - A full playout ring drops the oldest block as a counted drop instead of
    ending the session.
  - Video receive drains a bounded burst per scheduler quantum. It used to read
    one datagram, which capped throughput near 1,000 datagrams per second.
  - A video frame blocked by socket backpressure is retried for up to one frame
    interval instead of being dropped on the first `EWOULDBLOCK`.
  - Media sockets request larger kernel buffers, falling back to smaller sizes.
- Rust station control plane:
  - Unanswered `CHECKLOLASTATUS` and `QUICKCONN` datagrams are re-sent every
    500 ms until the negotiation deadline, and nothing is sent after it.
  - While waiting for `QUICKCONN`, the responder answers every repeated status
    check. If the initiator repeats `QUICKCONN` during media, the responder
    re-sends its cached `QUICKCONN_ACK` (at most once per 100 ms), so a lost
    acknowledgement no longer strands the session.
  - A `QUICKCONN` with unusable media fields gets a `/MESG_REJECT`
    (`invalid media settings: …`) instead of ending the listener. Audio-only
    sessions accept zeroed video fields.
  - REJECT reasons and chat text are shown with their TXT escapes decoded.
  - A persistent (GUI) listener waits for its peer until the operator stops it,
    instead of timing out after the session timeout.
- macOS LoLa connector:
  - Live RX and TX-RX sessions receive until the session deadline and keep a
    bounded evidence sample. They used to stop, with growing memory, at an
    expected datagram count.
  - The live RX window is the session duration instead of a fixed second.
  - A malformed playout payload is counted instead of ending the receive loop.
  - Audio datagrams carry any whole number of 16-bit frames that fits the
    padded 1066-byte datagram, so 32- and 64-frame peers interoperate.
  - Live frame validation reports incomplete video frames and orphan fragments
    instead of failing the report.
  - Unanswered status and quick-connect requests are re-sent every 500 ms, up
    to five times; the final attempt waits out the deadline.
  - Live receive puts every clustered audio block into a four-block playout
    ring instead of keeping only the newest.
- macOS direct-peer AV loop: video fragments leave in bounded bursts (16 per
  turn, more when the next frame is far off) instead of one per audio poll. The
  loop returns at once while fragments remain. Backpressured frames are retried
  for up to a frame interval before being dropped, and a refused fragment is
  re-sent, not skipped. The video socket requests a 2 MiB kernel buffer,
  falling back to smaller sizes.
- Redesigned the static `web/demo` walkthrough ("Patch sheet"): token-based
  styles matching the native porcelain, graphite, and yellow-marker palette,
  pencil-versus-ink styling for evidence, a phone index strip instead of a
  drawer, and new tour images. Behavior, ids, and fixture data are unchanged.
- Moved the external connector families, show-control bridges, and the managed
  process runner from `OpenLolaApplication` into a new `OpenLolaIntegrations`
  SwiftPM target. `OpenLolaCore` re-exports it, so the public products are
  unchanged.
- Renamed macOS source folders to match their targets (`OpenLolaAppSupport`,
  `open-lola-app`, `AppShell`, `IntegratedAV`, `Evidence/Certification`).
- `station::profile` now owns Rust `.ssn` session files, removing the `config`
  and `station` module cycle. The `.ssn` format is unchanged and now covered by
  a characterization test.
- The E2E benchmark PASS gate accepts the current
  `docs/benchmark-methodology.md` reference as well as the retired
  `benchmark-e2e-av.md` name.
- Split the repository into macOS, Rust station, and Linux compatibility
  runtimes.
- Reorganized the Swift code into application, session, media, transport,
  integration, evidence, and platform modules. Public SwiftPM products, CLI,
  and report formats are unchanged.
- Moved vendored codecs to `third_party`, shared protocol fixtures to
  `interop/lola2`, development tooling to `tools`, and the static demo to
  `web/demo`.
- Split the catch-all Python connector modules into lifecycle, receive, and
  support modules, and removed the obsolete root compatibility wrappers.
- Removed internal catalogs (source ownership, commands, routes, runtime paths,
  report schemas, goal closure, evidence tasks) from the production CLI.
- Added Swift behavioral tests, a root Cargo workspace, CI jobs for both
  runtimes, and automated architecture checks.

### Proposed `v0.1.0-alpha.1` source alpha

#### Added

- Open LoLa signal-path identity: adaptive SVG marks, reproducible
  social-preview and macOS icon assets, and a compact native Signal Desk
  signature.
- Contribution, security, conduct, issue, and pull request guidelines, and a
  support policy for the source alpha.
- A public status snapshot, a source-only release procedure, and reproducible
  light and dark renders of the real SwiftUI views for the documentation.
- A deterministic check that every first-party Swift, Python, shell,
  PowerShell, C, C-header, and Dockerfile source, and every public API and
  command entry point, is documented.

#### Changed

- Standardized the name Open LoLa, renamed the unpublished Python distribution
  to `open-lola-linux-connector`, and documented how Open LoLa relates to and
  credits LoLa.
- Defined which documents are public and what a release candidate contains.
- Reworked the native Signal Desk around configuration, measured results, and a
  persistent guarded transport.
- Candidate export now rejects unapproved screenshots and Opus C sources not
  selected by `Package.swift`, and refuses a dirty checkout unless an
  inspection-only override is set. Changes that touch only forbidden paths now
  run CI.
- The tracked-file check fails when run outside Git, the minimum-version CI job
  really runs Python 3.11, and third-party checkout steps are pinned by commit.
- Documented that control and media traffic is unauthenticated, the trust model
  for process adapters, and the limits of the UltraGrid passphrase.
- The Linux synthetic self-test uses paired localhost ports instead of needing
  a `127.0.0.2` loopback alias, which not every system has.
- Direct-peer audio and video stop with a bounded `mediaPause` exchange before
  the connected UDP transports close, and the control loop tells a peer pause
  apart from a fatal shutdown.
- Refreshed the README, platform matrix, Linux onboarding, testing notes,
  release manifest, third-party inventory, and current-state documentation.
- Replaced low-value source comments with short notes on responsibilities,
  invariants, fallbacks, protocol details, and evidence limits.

#### Release status

- The product and release verdict stays `PARTIAL`.
- Source-candidate Opus content is limited to the selected C files, headers,
  and the four required upstream notice files.

This prepares for collaboration on the source alpha. `v0.1.0-alpha.1` has not
been tagged, pushed, published, supported, or validated for field use.
