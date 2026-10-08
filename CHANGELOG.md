# Changelog

Notable repository changes are recorded here, newest first. Open LoLa does not
publish releases; these entries describe repository state and preparation only.

## Unreleased

- Rust station scheduling: the interleaved loop sends up to 16 video fragments
  per quantum and stops 150 µs before the audio deadline (previously one
  fragment per pass, with a control-socket poll and two blocking-mode toggles
  on every pass); the control socket is serviced at most every 2 ms unless
  audio is due; the idle sleep ends 200 µs early and spins to the deadline;
  the media thread asks for elevated priority (Windows `TIME_CRITICAL`, Linux
  `SCHED_FIFO` with a nice fallback, macOS user-interactive QoS) and the
  outcome is reported as `realtime_priority`; a PortAudio capture block that
  is ready paces the audio deadline ahead of the wall clock
  (`audio_device_paced_services`), a capture backlog above two blocks is
  trimmed to one (`audio_capture_backlog_drops`), and a capture wait that
  expires skips the block instead of ending the session
  (`audio_capture_timeouts`); the PortAudio callback ring never spins or
  discards more than one block when the session thread holds a slot.
- Rust station resilience: transient socket faults (`ENOBUFS`, unreachable
  host or network, refused or reset connection, `EINTR`, and the Winsock
  equivalents) are counted drops (`audio_send_drops`,
  `transient_receive_errors`) instead of session failures, and only a fault
  that persists for two seconds without one successful send ends the session; a rejected
  wrong-peer or wrong-port datagram no longer ends an audio or video receive
  drain early; the audio receive queue resynchronises after 16 consecutive
  stale sequences (`audio_sequence_resyncs`); the video reassembler evicts
  incomplete frames that are serial-older than a newer frame instead of
  refusing new frames once 32 incomplete ones accumulate (video froze for up
  to 2 s under moderate loss; `video_superseded_incomplete_frames`), while
  the newest superseded partial frame stays available to the diagnostic
  incomplete-frame threshold; received video is sequence-gated
  (`video_out_of_order_drops`).
- Rust station video and UI: JPEG decoding of received frames moved off the
  session thread to a newest-wins decode worker (a 720p decode took several
  audio periods inline); local capture and received video are published to
  separate preview slots, the GUI shows "Received (RX)" when peer video is
  present and labels local capture as not received video, the preview keeps
  its aspect ratio, the idle placeholder is rendered once, and both previews
  are cleared when a session ends instead of showing the last frame as live.
- Interop corpus: `cargo test --test lola2_compatibility` now exists and
  replays all 25 manifest cases and all 110 migration-oracle observations
  against the Rust codec (the README had claimed this test since the corpus
  was added); `.gitignore` re-includes that one file under
  `runtimes/rust-station/tests/`.
- macOS LoLa connector interop with the Rust station: the initiator accepts
  the peer's `/MESG_REJECT` as a terminal answer and reports its reason
  (`peer rejected QUICKCONN: …`) instead of re-sending `QUICKCONN` until the
  deadline; audio-only sessions advertise the corpus placeholder video fields
  (`FPS:25;BPP:8;X:640;Y:480;COMP:0;BAYER:0`) instead of zeros, which the
  Rust responder rejected; `SEND_AUDIO_SIGNAL`/`STOP_AUDIO_SIGNAL` end with
  the trailing `;` like every other field-less message; responder REJECT
  reasons are short (`audio settings mismatch`, `invalid media settings`);
  a validated `/MESG_DISCONNECT` from the pinned peer's address and control
  port ends the live RX media loop within 50 ms and is recorded in the report; the responder's terminal
  `STOP_AUDIO_SIGNAL`/`DISCONNECT` carry the negotiated SID.
- macOS direct-peer runtime: the A/V session runs on a dedicated
  user-interactive thread and, when the preview is on, the main thread pumps
  the run loop so the AppKit preview window actually renders (it never did
  from the CLI); the newest-frame video workers always publish a finished
  result (under load every result was superseded and no frame was ever
  delivered); a failed video encode drops the frame instead of ending the
  session; `ENOBUFS` is backpressure and unreachable/refused/interrupted sends
  are counted drops rather than session failures; receive treats refused,
  reset, interrupted and zero-length datagrams as "no datagram"; the
  redundant `MSG_PEEK` before every receive is gone; the control-socket poll
  reuses one 16 KiB buffer, is bounded to 64 datagrams and counts undecodable
  ones; the discarded second audio engine run per PCM packet is gone; video
  reassembly mutates its bucket in place instead of copying the fragment
  table per fragment; playout re-anchors only when a payload is late beyond
  the target buffer and trims sustained excess latency
  (`audioPlayoutReanchors`); the adaptive RX controller uses RFC 3550
  interarrival jitter instead of comparing two hosts' clocks; capture blocks
  are stamped with the input sample time.
- Rust station media plane: every readable audio datagram is now admitted into
  the bounded receive queue and exactly one block is presented per audio
  deadline, so arrival clustering is absorbed instead of dropped (the transport
  no longer discards older audio blocks); the audio queue defaults to depth 4
  with prefill 0 (settings, session profiles, and tabs) and returns latency it
  borrowed after a late burst; remote
  audio is re-blocked to the local device block instead of failing the session
  when a peer uses a different frames-per-packet; a full playout ring displaces
  the oldest block as a counted drop instead of ending the session; video
  receive drains a bounded burst per scheduler quantum (previously one
  datagram, which capped receive throughput near 1,000 datagrams per second);
  a video frame blocked by socket backpressure is retried until a frame
  interval has passed instead of being dropped on the first `EWOULDBLOCK`;
  media sockets request larger kernel buffers with a descending fallback.
- Rust station control plane: unanswered `CHECKLOLASTATUS` and `QUICKCONN`
  datagrams are re-sent every 500 ms until the negotiation deadline and no
  datagram leaves after the deadline; the responder acknowledges every
  repeated status check while waiting for `QUICKCONN` and re-sends its cached
  `QUICKCONN_ACK` (at most once per 100 ms) when the initiator repeats
  `QUICKCONN` during media, so a lost acknowledgement no longer strands the
  session; a `QUICKCONN` with unusable media fields is answered with
  `/MESG_REJECT` (`invalid media settings: …`) instead of ending the listener,
  and audio-only sessions accept zeroed video fields; REJECT reasons and chat
  text are shown with their TXT escapes decoded; a persistent (GUI) listener
  waits for its peer until the operator stops it instead of timing out after
  the finite session timeout.
- macOS LoLa connector: live RX and TX-RX sessions receive until the session
  deadline and retain a bounded evidence sample instead of stopping, and
  growing memory, at an expected datagram count; the live RX window is the
  session duration rather than a fixed one second; one malformed playout
  payload is counted instead of ending the receive loop; audio datagrams carry
  any whole number of 16-bit frames that fit the padded 1066-byte datagram
  (32- and 64-frame peers interoperate); live frame validation reports
  incomplete video frames and orphan fragments instead of failing the report;
  unanswered status and quick-connect requests are re-sent at 500 ms intervals
  (up to five times, then the final attempt waits out the deadline); live
  receive admits every clustered audio block into a four-block playout ring
  instead of keeping only the newest.
- macOS direct-peer AV loop: video fragments leave in bounded bursts (16 per
  turn, more when the next frame is far) instead of one per audio poll, the
  loop returns immediately while fragments remain, backpressured frames are
  retried for up to a frame interval before being dropped (a refused fragment
  is re-sent rather than skipped), and the video socket requests a 2 MiB
  kernel buffer with descending fallback.
- Redesigned the static `web/demo` walkthrough ("Patch sheet"): token-based
  styles aligned with the native porcelain, graphite, and yellow-marker
  palette, pencil-versus-ink evidence styling, a phone index strip instead of a
  drawer, and re-rendered tour images. Behavior, ids, and fixture data are
  unchanged.
- Extracted the external connector families, show-control bridges, and the
  managed process runner from `OpenLolaApplication` into a new
  `OpenLolaIntegrations` SwiftPM target. `OpenLolaCore` re-exports it, so the
  public product surface is unchanged.
- Renamed macOS source folders to match their targets and responsibilities
  (`OpenLolaAppSupport`, `open-lola-app`, `AppShell`, `IntegratedAV`,
  `Evidence/Certification`).
- Made `station::profile` the owner of Rust `.ssn` session files, which removes
  the `config` and `station` module cycle; the `.ssn` format is unchanged and
  now pinned by a characterization test.
- The E2E benchmark PASS gate accepts the current
  `docs/benchmark-methodology.md` reference as well as the retired
  `benchmark-e2e-av.md` name.
- Organized the repository around explicit macOS, Rust station, and Linux
  compatibility runtime boundaries.
- Reorganized the Swift implementation by application, session, media,
  transport, integration, evidence, and platform ownership, while preserving
  public SwiftPM products and CLI and report contracts.
- Moved vendored codecs to `third_party`, shared protocol evidence to
  `interop/lola2`, development tooling to `tools`, and the static demo to
  `web/demo`.
- Replaced the Python connector catch-all implementation modules with explicit
  lifecycle, receive, and support responsibilities and removed the obsolete
  root compatibility wrapper surface.
- Removed internal source-ownership, command, route, runtime-path, report
  schema, goal-closure, and evidence-task catalogs from the production CLI.
- Added Swift behavioral tests, a root Cargo workspace, cross-runtime CI lanes,
  and mechanical architecture-boundary verification.

### Proposed `v0.1.0-alpha.1` source alpha

#### Added

- Add the Open LoLa signal-path identity, adaptive SVG marks, reproducible
  social-preview and macOS icon assets, and a compact native Signal Desk
  signature.
- Establish public contribution, security, conduct, issue-reporting, and pull
  request evidence boundaries, plus an explicit support scope, for the
  experimental source alpha.
- Add a public release-status snapshot, a source-only release procedure, and
  reproducible light/dark documentation renders of the real SwiftUI hierarchy.
- Add a deterministic source-documentation gate covering every active
  first-party Swift, Python, shell, PowerShell, C, C-header, and Dockerfile
  source, plus public API and command-entry contracts.

#### Changed

- Standardize public naming on Open LoLa, rename the unpublished Python
  distribution to `open-lola-linux-connector`, and document independent LoLa
  interoperability positioning and attribution.
- Establish a curated public documentation and release-candidate boundary.
- Rework the native Signal Desk around configuration, measured evidence, and a
  persistent guarded transport.
- Harden candidate export against unapproved screenshots and Opus C sources not
  selected by `Package.swift`; reject dirty source state unless an explicit
  inspection-only override is set; make forbidden-path-only changes run CI.
- Make tracked-boundary verification fail closed outside Git, force the
  lower-bound CI lane to execute Python 3.11, and pin third-party checkout
  steps by commit.
- Document the unauthenticated control/media boundary, process-adapter trust
  model, and UltraGrid passphrase limitations.
- Make the Linux synthetic self-test use paired localhost ports instead of
  requiring a nonportable `127.0.0.2` loopback alias.
- Coordinate direct-peer audio/video stop boundaries with a bounded
  `mediaPause` exchange before connected UDP transports close, and distinguish
  peer pause from fatal shutdown in the control loop.
- Refresh the README, platform matrix, Linux onboarding, testing evidence,
  release manifest, third-party inventory, and current-state documentation.
- Replace low-information source comments with concise
  responsibility, invariant, fallback, protocol, and evidence-boundary
  explanations for technical readers.

#### Release posture

- Record that the public product and release verdict remains `PARTIAL`.
- Restrict source-candidate Opus content to selected C files, headers, and the
  four required upstream notice files.

This is preparation for source-alpha collaboration only. It does not announce
or imply that `v0.1.0-alpha.1` has been tagged, pushed, published, supported, or
validated for field deployment.
