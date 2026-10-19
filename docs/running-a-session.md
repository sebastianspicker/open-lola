# Running a session

How to run real sessions with the macOS `open-lola` CLI and, for LoLa
interoperability, the Rust station. Commands appear in the order you use them.
Every flag below exists in the CLI source, and each command lists its flags with
`--help`.

> **Not yet verified on hardware.** These recipes were derived from the command
> parsers and help text. None has been run on physical Macs, a physical
> network, or a real LoLa station in this revision. A `PASS` report covers that
> run only; see [current state](current-state.md). Report any flag or step that
> does not behave as written.

## Build and list the commands

Build the CLI as described in the README [quick start](../README.md#quick-start)
and set `OPEN_LOLA_CLI` to the built executable. The examples call it
`open-lola`; substitute `"$OPEN_LOLA_CLI"`.

```bash
open-lola --help
```

The help lists the session commands first, then every other command grouped by
area (network, NAT, MADI, benchmarks, video, control, field and release,
connectors, LoLa compatibility, report validators). Run
`open-lola <command> --help` for a command's flags.

| Command | Purpose |
|---|---|
| `direct-p2p-session-run` | Run one peer of a direct Mac-to-Mac session |
| `direct-p2p-two-peer-plan-run` | Write a two-peer run plan |
| `mac-to-mac-connection-preflight-run` | Check connectivity to the remote peer and write the preflight report the supervisor requires |
| `direct-p2p-two-peer-local-run` | Supervise both peers from a plan; dry run unless `--execute true` |
| `validate-direct-p2p-two-peer-local-run-report` | Validate a supervisor report |
| `external-connector-session-run` | Run a LoLa, UltraGrid, or JackTrip connector session; dry run unless `--dry-run false` |
| `session-capabilities` | Print the local session capability set |

## Find device identifiers

Audio devices are selected by Core Audio UID:

```bash
open-lola device-inventory
```

Pass the `uid` of a device from the JSON `devices` array to `--input-uid` and
`--output-uid`. For video, `--video-device-id` takes either `auto` or the
`uniqueId` of a device from `open-lola video-capture-inventory`. The terminal
application needs macOS camera permission; without it the inventory is empty.

## Choose a video size that fits

Raw video (`bgra8`, 4 bytes per pixel) is sent in fragments of about 1,063
bytes. Each A/V profile caps the fragments per frame:

| Profile | Fragments per frame |
|---|---|
| `fastest`/`direct` | 128 (about 136 KB per frame) |
| `balanced`/`small` | 512 |
| `balanced`/`adaptive` | 768 |

The app's default, 160×90 at 30 fps with `fastest`/`direct`, fits the tightest
budget. The camera must offer the requested size at exactly the requested frame
rate. If it does not, the peer stops with
`requested video format WxH@fps unavailable; this camera offers …` and lists the
sizes it offers. Pick one that fits the budget, for example 320×180 or 320×240
with `balanced`/`small`.

Alternatively use `--video-compression jpeg-xs`. It exists only in builds with
JPEG XS enabled (`OPEN_LOLA_ENABLE_JPEG_XS=1`, evaluation-only licence; see the
README build section). The default build rejects it.

## Two Macs on a LAN with `direct-p2p-session-run`

Run one command on each Mac. Both Macs need the CLI, a reachable LAN address,
and the UDP ports below open between them. In the example, Mac A
`192.168.10.11` is the initiator and Mac B `192.168.10.12` the responder.
Replace the addresses, peer ids, UIDs, and ports with your own.

One Mac's local ports are the other's remote ports: Mac A's
`--remote-control-port` is Mac B's `--control-port`, and the reverse. Each Mac
also needs its own audio, video, and metrics ports.

Start the responder (Mac B) first:

```bash
open-lola direct-p2p-session-run \
  --media audio-video --role responder \
  --local-peer mac-b --remote-peer mac-a \
  --local-host 192.168.10.12 --remote-host 192.168.10.11 \
  --control-port 41100 --remote-control-port 41000 \
  --audio-port 41101 --video-port 41102 --metrics-port 41103 \
  --duration-seconds 30 \
  --input-uid "<Mac B input UID>" --output-uid "<Mac B output UID>" \
  --video-device-id auto \
  --output ~/open-lola-runs/mac-b-session.json
```

Then start the initiator (Mac A):

```bash
open-lola direct-p2p-session-run \
  --media audio-video --role initiator \
  --local-peer mac-a --remote-peer mac-b \
  --local-host 192.168.10.11 --remote-host 192.168.10.12 \
  --control-port 41000 --remote-control-port 41100 \
  --audio-port 41001 --video-port 41002 --metrics-port 41003 \
  --duration-seconds 30 \
  --input-uid "<Mac A input UID>" --output-uid "<Mac A output UID>" \
  --video-device-id auto \
  --output ~/open-lola-runs/mac-a-session.json
```

With `--media audio-video` these flags are required: `--role`, `--local-peer`,
`--remote-peer`, `--local-host`, `--remote-host`, the five ports,
`--duration-seconds`, `--input-uid` and `--output-uid` (or one
`--audio-device-uid` for both), `--video-device-id`, and `--output`.

Optional flags shape the media: `--channels`, `--sample-rate`, `--frames`,
`--av-profile balanced|fastest`, `--rx-buffer-profile`, `--audio-transport`,
`--video-compression raw|jpeg-xs` (`jpeg-xs` only in builds with JPEG XS
enabled), `--preview on|off`, and
`--quality-policy structural|require-useful-media`. The help text lists the rest.

Without `--media audio-video` the command runs audio-only with manual addresses.
It takes the same peer, host, and port flags plus `--packets` (default 3). With
no `--role` it runs a localhost loopback. Both modes reject the
audio/video-only flags.

Each Mac prints a summary and a verdict and writes its report to `--output`.
Validate each report as described in [Reports and validation](#reports-and-validation).

### Stopping a peer early

Press Ctrl-C once or send `SIGTERM`. The peer then:

1. ends its media loop and tells the other peer to pause, which ends that
   peer's run too;
2. stops audio and video capture and restores the audio device settings;
3. writes its report with the note `stopped by signal (SIGTERM)` (or `SIGINT`)
   and verdict `PARTIAL`, and exits 0.

A second Ctrl-C or `SIGTERM`, at least half a second after the first, exits at
once with status 128 plus the signal number and skips that cleanup. A peer
still waiting for the other peer to connect keeps waiting until
`--timeout-seconds` ends.

## Supervised two-peer flow

The supervisor starts both peers from one plan, responder first, and collects
their reports. It takes three commands.

### 1. Write the plan

The plan holds both peers' addresses, devices, and ports. Mac A is the
initiator and Mac B the responder. Each `--mac-*-port-base` is the control
port; the audio, video, and metrics ports are the base plus 1, 2, and 3.

```bash
open-lola direct-p2p-two-peer-plan-run \
  --output ~/open-lola-runs/plan.json \
  --run-dir ~/open-lola-runs/run-001 \
  --duration-seconds 30 \
  --mac-a-peer mac-a --mac-a-host 192.168.10.11 --mac-a-port-base 41000 \
  --mac-a-input-uid "<Mac A input UID>" --mac-a-output-uid "<Mac A output UID>" \
  --mac-a-video-device-id auto \
  --mac-b-peer mac-b --mac-b-host 192.168.10.12 --mac-b-port-base 41100 \
  --mac-b-input-uid "<Mac B input UID>" --mac-b-output-uid "<Mac B output UID>" \
  --mac-b-video-device-id auto
```

### 2. Write the connection preflight

Bind the preflight to the plan with `--plan`. The supervisor rejects a report
created from a different plan. On a LAN you do not need a NAT route report, so
leave out `--nat-route-report`.

```bash
open-lola mac-to-mac-connection-preflight-run \
  --plan ~/open-lola-runs/plan.json \
  --output ~/open-lola-runs/preflight.json
```

The preflight reaches the remote host with ping and traceroute. Without a NAT
route report, the verdict is `PASS` when the peer is directly on-link and all
of these hold:

- The peer address is IPv4, is not loopback or an address of this Mac, and lies
  inside the subnet of one of this Mac's up and running interfaces. Loopback
  and point-to-point (utun/VPN) interfaces never count, and neither does a
  `/32`.
- Ping succeeded with 0 % loss.
- Traceroute reached the peer in exactly one hop. If traceroute was blocked or
  unavailable, the two checks above must hold and the subnet must be `/24` or
  narrower; on a wider subnet a missing traceroute gives `PARTIAL`.

The report notes name the rule that applied and record the interface, subnet,
and traceroute basis (`directLANBasis`). An off-link peer, packet loss, or a
multi-hop path gives `PARTIAL` with the reasons listed as blockers, and the
supervisor refuses to execute. The app runs the same preflight before an
executed two-Mac start.

If the peer is not on the same LAN, add `--nat-route-report` with a `PASS`
report that selects a direct UDP/IP route. That report keeps the stricter
rules: a relay fallback is never a direct route. Create it with
`nat-friendly-route-run` against a rendezvous (`nat-rendezvous-run`). Its flags
are `--role sender|looper`, `--bind-host`, `--peer-id`, `--rendezvous-host`,
`--rendezvous-port`, `--session-id`, `--port`, `--duration-seconds`, and
`--output`. The multi-host sequence that produces a passing NAT route report
has not been exercised; it is the least certain step of this flow.

Two-Mac runs always need the preflight. When both peers run on this Mac
(`--execution-mode local`), you can skip it with `--require-preflight false` in
step 3, at the cost described there.

### 3. Run the supervisor

Without `--execute true` the supervisor does a dry run: it launches nothing and
writes a `PARTIAL` report. Check the plan with a dry run, then execute.

```bash
# dry run: writes a report, launches nothing
open-lola direct-p2p-two-peer-local-run \
  --plan ~/open-lola-runs/plan.json \
  --output ~/open-lola-runs/supervisor-dry.json

# launches the responder, then the initiator
open-lola direct-p2p-two-peer-local-run \
  --plan ~/open-lola-runs/plan.json \
  --execute true \
  --connection-preflight-report ~/open-lola-runs/preflight.json \
  --output ~/open-lola-runs/supervisor.json
```

`--require-preflight` defaults to `true`, so `--execute true` needs
`--connection-preflight-report`. With `--require-preflight false` and
`--execution-mode local` you can omit the preflight report, but the run can
never be `PASS`: the report notes that the preflight was not required and the
verdict stays `PARTIAL`. The supervisor rejects `--require-preflight false`
with `--execution-mode ssh`.

In the default `--execution-mode local`, the supervisor starts both peers as
child processes on its own machine, so the plan's hosts must be addresses that
machine can bind. To run a peer on another Mac, use `--execution-mode ssh` with
`--mac-a-ssh`, `--mac-b-ssh`, `--ssh-fallback-explicit true`, and
`--ssh-fallback-reason`. The report records SSH as a fallback.

Two more flags:

- `--executable` overrides the `open-lola` binary path written in the plan.
- `--readiness-delay-ms` (default 300) bounds the wait for the responder's
  ready file.

Stopping the supervisor (Ctrl-C, `SIGTERM`, or Stop in the app) sends `SIGTERM`
to both peers and ends any peer still running two seconds later. Each peer
stops as described in [Stopping a peer early](#stopping-a-peer-early), so it
restores the audio device settings and writes its report. In SSH mode the
remote command watches its standard input, which the supervisor holds open.
When ssh ends, the remote peer gets `SIGTERM` too and writes its report on the
remote Mac. When a remote peer ends on its own, ssh exits with the peer's exit
status.

## macOS and the Rust station

`external-connector-session-run --connector lola` runs the macOS LoLa
connector, which sends the control handshake to `--peer`. The Rust station's
`listen` command is the fixed-port responder. Both sides default to ports 7000
(control), 19788 (audio), and 19798 (video).

On the Rust station host, start the responder. `--remote-ip` names the Mac; the
listener ignores datagrams from any other address. For device and settings
options see the [Rust station README](../runtimes/rust-station/README.md) and
[Linux migration](linux-migration.md). The diagnostic backends need no
hardware:

```bash
cargo run -p rusty-lola --no-default-features -- listen \
  --remote-ip <mac-ip> --local-ip <rust-host-ip> --bind-ip <rust-host-ip> \
  --audio-backend diagnostic --camera-backend diagnostic \
  --audio-only --continuous --duration 30 --report lola-listen.json
```

Then start the live connector session on the Mac. The default is a dry run, so
pass `--dry-run false`:

```bash
open-lola external-connector-session-run \
  --connector lola --role tx-rx \
  --peer <rust-host-ip> --local-host <mac-ip> \
  --media audio --channels 2 \
  --duration-seconds 30 --dry-run false \
  --output ~/open-lola-runs/lola-connector.json
```

Audio settings must agree on both sides. Match the Mac's `--sample-rate`,
`--frames`, and `--channels` with the Rust station's `--sr`,
`--audio-frames-per-callback`, and `--channels`, or the responder rejects the
session with `audio settings mismatch`. To see the plan the connector would
execute, run it once without `--dry-run false`; that report is always
`PARTIAL`.

### Video settings

For `--media video` or `audio-video`, both runtimes default to 1280x720 at
60 fps, 8 bpp, uncompressed, Mono8 (`BAYER:0`). 8 bpp needs about a third of
the bandwidth of 24 bpp, and the Mac decodes it as GREY. The LoLa connector
used to default to 1920x1080 at 30 fps and 24 bpp; to keep that, pass
`--video-width 1920 --video-height 1080 --video-fps 30 --video-bpp 24`. Other
connectors keep their own defaults.

On Linux the Rust station sends the default tuple. On Windows and macOS its
default camera is a raw-Bayer sensor (`bayer` 1), which it converts to 24 bpp
RGB. There, either pass `--video-bpp 24` to the Mac, or start the Rust station
with `--bayer 0` when its camera is not a Bayer sensor (for example
`--camera-backend diagnostic`).

To watch received LoLa video, add `--video-display appkit` to an `rx` or
`tx-rx` session with `--media video` or `audio-video`. The connector
reassembles each frame, decodes it according to the negotiated settings, and
shows it in a preview window:

- `--video-compression 1`: JPEG;
- `--video-bpp 8`: GREY, or the raw Bayer mosaic shown as grey when
  `--video-bayer` is not 0;
- `--video-bpp 24`: RGB.

Frames with other `--video-bpp` values are reassembled and counted but not
shown. The report's `lolaMedia.videoDisplay` counts reassembled, decoded,
displayed and dropped frames.

### Reading the outcome

A live LoLa connector report stays `PARTIAL` even when the session works,
because `PASS` needs measured evidence. To see whether the run worked, read the
report's `outcome` field, which the command also prints as an `outcome:` line:

| `outcome.kind` | Meaning |
|---|---|
| `completed` | The session ran for its whole duration without a runtime error |
| `stopped` | The session ended early without an error; `outcome.reason` says why, for example `peer disconnected` |
| `failed` | The session hit a runtime error; `outcome.reason` repeats `runtimeError` and the verdict is `FAIL` |

Dry-run reports have no `outcome`.

`external-connector-session-run` also drives the UltraGrid
(`--connector ultragrid`) and JackTrip (`--connector jacktrip`) connectors. It
rejects flags meant for a different connector.

### Control side

The LoLa control side is independent of the media role. By default `tx` and
`tx-rx` initiate and `rx` responds; `--lola-control-side initiator|responder`
overrides that:

| Rust station | macOS connector |
|---|---|
| `listen` | `--role tx`, `tx-rx` or `rx` with `--lola-control-side initiator` (the default for `tx` and `tx-rx`) |
| `connect <mac-ip>` | `--role tx`, `tx-rx` or `rx` with `--lola-control-side responder` (the default for `rx`) |

A responder waits up to `--duration-seconds` for the status check and
QUICKCONN, validates them against `--peer` and the media settings, sends the
ACK, and then streams for `--duration-seconds`.

### Same host

Both runtimes use the fixed LoLa ports. The Rust listener only accepts control
datagrams sent from its own control port (7000), as LoLa peers do on a LAN. Two
processes cannot both bind 127.0.0.1:7000, so on one host each side gets its
own local IPv4 address on the standard ports: the Mac uses 127.0.0.1 and the
Rust station the Mac's LAN address (or 127.0.0.2 on Linux). No check is relaxed
for this, and `--local-host` equal to `--peer` is still not supported.

`tools/run-local-lola-interop.sh [run-dir]` runs that session. It starts the
Rust `listen` with the diagnostic audio and camera backends and runs the LoLa
connector as `tx-rx` against it. It writes `rust-listen.json`,
`rust-listen.log`, `mac-connector.json` and `mac-connector.log` to the run
directory (default: a new directory under `$TMPDIR`), prints the Rust handshake
and media counters, and validates the Mac report:

```bash
OPEN_LOLA_BIN=<path-to>/open-lola bash tools/run-local-lola-interop.sh
```

Environment variables:

- `OPEN_LOLA_RUSTY_LOLA_BIN` uses an existing Rust station binary instead of
  building one.
- `OPEN_LOLA_LOLA_RUST_IP` and `OPEN_LOLA_LOLA_MAC_IP` override the two
  addresses.
- `OPEN_LOLA_LOLA_MEDIA` (default `audio-video`) and
  `OPEN_LOLA_CONNECTOR_DURATION_SECONDS` (default 5) set the session.

The listener ends the session, so expect the Mac report's outcome to be
`stopped` with `peer disconnected`. Like every live LoLa connector report, the
verdict is `PARTIAL`.

### Where the runtimes differ

Both runtimes refuse a QUICKCONN whose media they cannot carry, using the same
rule:

- Audio (`SR`, `BPS`, `CHNLS`) must equal the responder's settings.
- For video sessions, `FPS`, `BPP` and `BAYER` must equal what the responder
  will send. They are checked first, in that order.
- `COMP`, `X` and `Y` must match only when the responder cannot adapt. The Rust
  station re-encodes and scales to the requested compression and geometry. The
  macOS connector sends its configured payload unchanged, so it requires them
  to match.
- Audio-only sessions ignore the video fields on both sides.

A refused QUICKCONN gets a `MESG_REJECT` whose text is a lower-case reason,
optionally followed by `: <detail>`:

| REJECT text | Sent by | Cause |
|---|---|---|
| `audio settings mismatch` | both | `SR`, `BPS` or `CHNLS` differs |
| `unsupported audio bit depth: <bps>` | macOS | `BPS` is 8, 24 or 32; the connector carries 16-bit PCM only |
| `video frame rate mismatch` | both | `FPS` differs |
| `video pixel format mismatch` | both | `BPP` differs |
| `video Bayer format mismatch` | both | `BAYER` differs |
| `video compression mismatch` | macOS | `COMP` differs |
| `video geometry mismatch` | macOS | `X` or `Y` differs |
| `invalid media settings[: <detail>]` | both | Missing or malformed media fields |
| `device unavailable: <detail>` | Rust | An audio or video device failed to open |
| `busy` | Rust | The scripted rejection used by `run_reject_session` diagnostics |

The Rust station supports 8, 16, 24 and 32 `BPS`. The macOS connector always
announces 16, so run the Rust station with its default `--bps 16`.

After `MESG_QUICKCONN_ACK`, the Rust `connect` side sends `MESG_SWITCH_ON_BB`,
`MESG_CHAT` and `MESG_SEND_AUDIO_SIGNAL` unless `--no-extras` is set. The macOS
connector ignores them: it lists each under
`lolaControlRetryResponder.ignoredControlMessages` in its report and does not
treat them as errors.

Two control features exist on one side only:

- TCP control (`--control-transport tcp`) is macOS only. Sessions with the Rust
  station use UDP control, the default.
- The OSC15 control dialect (`--control-dialect osc15`) is Rust only. Sessions
  with the macOS connector use the ASCII dialect, the Rust default.

## Reports and validation

Every command writes its report to the `--output` path and creates parent
directories as needed. The supervised flow also writes into the plan's
`--run-dir`, created with owner-only permissions:

| File | Written by |
|---|---|
| `m06-direct-p2p-av-<peer>.json` | Each peer's session report |
| `m06-direct-p2p-av-<peer>-rx-proof.json` | Each peer's receive proof |
| `<peer>-stdout.log`, `<peer>-stderr.log` | Child process output |
| `<peer>-ready` | Responder ready marker |
| `m06-direct-p2p-two-peer-prototype.json` | Aggregate report across both peers |

Validate each report with its validator. Each prints a verdict and exits
nonzero on an invalid report:

```bash
open-lola validate-direct-p2p-session-report ~/open-lola-runs/mac-a-session.json
open-lola validate-direct-p2p-two-peer-plan-report ~/open-lola-runs/plan.json
open-lola validate-direct-p2p-two-peer-local-run-report ~/open-lola-runs/supervisor.json
open-lola validate-external-connector-session-report ~/open-lola-runs/lola-connector.json
```

Reports may contain host names, addresses, and device identifiers. Store them
outside the repository unless they are sanitized fixtures; see
[configuration](configuration.md).
