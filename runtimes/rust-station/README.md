# rusty-lola

`rusty-lola` is the Windows and native Linux station in the Open LoLa workspace.
It implements LoLa 2.0 independently of the macOS Swift runtime.

- Windows defaults to XIMEA cameras and PortAudio/ASIO audio. Ordinary USB/UVC
  webcams work through the Media Foundation camera backend.
- Linux defaults to V4L2 and ALSA.
- Media travels over UDP, or over Npcap on Windows.
- Diagnostic (synthetic) media is used only when you select it.

## Requirements

- Stable Rust, edition 2021.
- Windows for XIMEA or Media Foundation cameras, PortAudio/ASIO, and Npcap; or
  Ubuntu 24.04 x86_64 for ALSA and V4L2.
- Locally licensed native libraries and connected devices for the hardware
  paths.

Cross-platform tests use the diagnostic adapters and UDP loopback, so they say
nothing about native drivers or physical hardware. See
[Linux migration](../../docs/linux-migration.md) for device configuration and
the replacement for every retired Python option.

## Windows/Linux checks

The `make` targets in the repository root assume a macOS developer machine
(bash, GNU make, Xcode, `uv`). On Windows and Linux, run plain `cargo` from
`runtimes/rust-station` (the same commands work in PowerShell):

```text
cargo fmt --all -- --check
cargo clippy --workspace --all-targets --all-features -- -D warnings -D clippy::undocumented_unsafe_blocks -D clippy::missing_safety_doc
cargo test --workspace --all-targets --all-features
cargo test --workspace --all-targets --no-default-features
cargo run --no-default-features -- selftest
```

On Windows, first install Visual Studio Build Tools with the "Desktop
development with C++" workload, then run `rustup default stable` (the
`x86_64-pc-windows-msvc` host). On Linux, install a C toolchain and, for the
native paths, `libasound2` and the V4L2 headers and utilities (`v4l-utils`).

## Build and test

From this directory:

```bash
cargo test
cargo build --release
```

From the repository root, run the full Rust checks:

```bash
make test-rust
```

The corpus compatibility test (its source is not published) replays every case
of `../../interop/lola2/manifest.json` and the 110 ASCII/OSC15 observations of
`migration-control-oracle.json` against the public `rusty_lola::protocol` API.
The manifest cases cover control and media encode/parse, reject categories, and
1024-byte NUL padding. The corpus is synthetic regression data, not a capture
from Windows.

The default `gui` feature includes the interactive egui application. For a
CLI-only build without `eframe`:

```bash
cargo build --release --no-default-features
cargo run --no-default-features -- ui --headless
```

This build keeps the `ui` command and the headless controller. Interactive `ui`
needs `--features gui` or the default features. Command names, settings, and
media defaults are the same in both builds.

## Run

For a LAN session, run `listen` on one host and `connect` on the other. Add
`--duration`, or `--continuous --duration`, to bound a run:

```bash
cargo run -- listen --remote-ip 192.0.2.10
cargo run -- connect 192.0.2.20 --duration 30
```

`station` is a loopback demo. It talks to a synthetic peer on the same host,
caps the stream at 160x120, and prints a notice saying so. Its `--timeout`
bounds negotiation only. `emulate` and `tester` run synthetic emulation modes,
and the `diagnostic` backend (settings alias `software`) produces synthetic
media. Each prints a notice on stderr.

```bash
cargo run -- identity
cargo run -- station --timeout 5 --frames 3 --no-extras \
  --camera-backend diagnostic --audio-backend diagnostic
cargo run -- ui --headless --run-connect --frames 2
```

`cargo run -- --help` and each subcommand's `--help` list the current
arguments. The commands are `identity`, `station`, `connect`, `listen`,
`emulate`, `tester`, `convert`, `wavsplit`, `ui`, `check-remote`,
`session-profile`, `multi-sid`, `status`, `selftest`, `devices`, and
`decode-pcap`.

### `connect` and `listen`

`connect <remote-ip>` is the initiator and `listen` the fixed-port responder.
Both accept a bounded duration, separate RX and TX stream directions, settings
and session files, and native or diagnostic backends. Default ports are 7000
(control), 19788 (audio), and 19798 (video).

`listen --remote-ip <ip>` names the expected LAN peer; `connect` takes it as a
positional argument. If `--local-ip` is unset and the remote is not loopback,
the station picks the local IP from the OS route to the remote and prints it on
stderr; pass `--local-ip` to override. Listeners ignore datagrams from any other
IP and name the last unexpected sender when they time out.

Other options:

- `--record <dir>` records the session's audio and video (or set
  `recording.enabled` in `--settings`).
- `--report <path>` also writes the result JSON atomically.
- `--continuous` prints a progress line about every 5 seconds.

Failures print `connect failed: ...` or `listen failed: ...` on stderr, and
every failed result has a non-empty `error`.

### Stopping a run

Ctrl-C (SIGINT) or SIGTERM stops a `connect` or `listen` run cleanly. The
session sends DISCONNECT and still prints the result JSON with `ok: true`,
`stopped_by`, and a "stopped by operator" note. The exit status is 130 for
SIGINT and 143 for SIGTERM (130 for Windows console events). A run that had
already failed keeps its failure and exits 1. A second signal exits
immediately.

When the peer ends the session with DISCONNECT, that is a normal end too:
`ok: true`, a "peer disconnected" note, and exit status 0.

## Configuration

Values apply in this order: defaults, `--settings`, `--session`, then CLI
flags. `station --settings <missing-path>` creates a default file; `connect`
and `listen` reject a missing settings file.

JSON session profiles use the Open LoLa format. `.ssn` input accepts tagged Open
LoLa JSON or the documented subset of Windows LastSsn INI fields.
`session-profile --out name.ssn` writes tagged Open LoLa JSON; it never writes a
proprietary Windows session file.

### Receive queues

- `network.audio_receive_queue_depth` (default 4) bounds how many audio blocks,
  sized to the local device, the receiver may hold. Peer packets are combined
  or split into one local block per audio deadline, so peers with different
  packet sizes keep the sample rate. When a peer's packet interval is longer
  than the configured depth, the queue still holds at least one whole peer
  packet.
- `network.audio_receive_prefill` (default 0) holds back playout until that
  many blocks are queued. If the queue stays above its prefill target for about
  0.7 s, it discards one block and reports a realigned buffer.
- `network.video_receive_queue_depth` defaults to 1 (newest frame only).

### Npcap

`RUSTY_LOLA_LOCAL_MAC` and `RUSTY_LOLA_PEER_MAC` set MAC addresses for
controlled Npcap diagnostics when automatic resolution does not work. Use
ordinary UDP for routed peers.

Npcap receive counters count accepted and rejected packets as they are read.
Kernel drop statistics are refreshed only for the final session report and once
more before capture closes; receive polls and ordinary status copies use the
cached values. If a refresh fails, the session reports the error as usual, the
partial report keeps all transport fields and the last software counters, and
capture still closes.

See the repository [configuration reference](../../docs/configuration.md) for
precedence and trust details.

## Layout

| Path | Responsibility |
|---|---|
| `src/protocol/` | LoLa control and media framing |
| `src/config/` | Settings, session import, catalogs, and bundled resources |
| `src/net/` | Fixed-port UDP, Npcap, and reachability |
| `src/audio/`, `src/video/` | Native and diagnostic media adapters |
| `src/station/` | Session lifecycle, monitor, recording, emulation, and multi-SID behavior |
| `src/ui/` | egui and headless UI controller |
| `data/camera_modes/` | Tracked camera-mode resources |
| `ship/` | Ignored local native libraries for optional probes |

## Windows native libraries

The station loads vendor DLLs (xiAPI, PortAudio, wpcap/Packet) only by absolute
path, from these locations in this order:

1. `C:\Windows\System32` (and `C:\Windows\System32\Npcap` for Npcap);
2. the vendor directory: `C:\Program Files\XIMEA\API\xiAPI` or
   `C:\Program Files\Open LoLa\portaudio`;
3. the directory of the running executable, as a fallback when no installed
   library exists. Only the known file names are accepted there
   (`xiapi64.dll`/`xiapi.dll`/`xiapi32.dll`,
   `portaudio_x64.dll`/`portaudio.dll`/`portaudio_x86.dll`,
   `wpcap.dll`/`Packet.dll`), and an executable directory on a UNC or network
   path is refused.

Nothing else is searched: not `PATH`, the working directory, or the `ship/`
staging folder. This list applies to the top-level DLL only. Its imports
resolve from that DLL's directory (`LOAD_LIBRARY_SEARCH_DLL_LOAD_DIR`) and
System32. Media Foundation DLLs load from System32 only.

The loader does not check signatures or digests, so keep the installation
directories under your control and use only licensed libraries from known
sources. See [ship/README.md](ship/README.md) and the repository
[security policy](../../SECURITY.md).

## Windows audio (PortAudio/ASIO)

The audio backend accepts only ASIO devices. It looks for `portaudio_x64.dll`,
`portaudio.dll`, or `portaudio_x86.dll` (in that order) in the locations above.
Install a PortAudio build with the ASIO host API enabled next to
`rusty-lola.exe` or into `C:\Program Files\Open LoLa\portaudio`.

With no `input_device`/`output_device` configured, the station uses the ASIO
host API's default devices; if no ASIO driver is installed, the error says so.
`rusty-lola devices` lists every PortAudio device under `portaudio.devices`
with its index, name, host API, channel counts and default sample rate, and
marks ASIO devices with `"asio": true`. Pass one of those names to
`--input-device` / `--output-device` (or the settings keys) to choose a device.

## Windows video (XIMEA or Media Foundation)

`--camera-backend mediafoundation` (alias `mf`, settings
`video.backend: "mediafoundation"`) captures from any camera Media Foundation
lists as a video capture device, which covers ordinary USB/UVC webcams. XIMEA
stays the Windows default so existing XIMEA stations and their camera-mode
catalogs behave as before; select Media Foundation by name.

- `video.device` selects a camera by friendly name or symbolic link. When it is
  empty, `video.local_camera_index` picks the n-th camera.
- `video.width`, `video.height`, and `video.fps` must match a mode the camera
  offers exactly; a frame-rate range that contains the requested rate also
  matches. There is no scaling or automatic negotiation. A mismatch fails with
  the list of offered modes.
- The camera's NV12, YUY2, or RGB32 output is converted to the session format:
  `video.bpp` 8 gives Mono8 (luma) and 24 gives RGB24. Mono8 requires
  `video.bayer` 0, because webcam luma is not a Bayer mosaic.
  `video.pixel_format` may name `NV12`, `YUY2`, or `RGB32` to force one; empty
  picks the cheapest. MJPEG-only modes are listed but not used.
- `rusty-lola devices` lists each camera under `mediafoundation.devices` with
  its native modes.

Media Foundation DLLs (`mfplat.dll`, `mf.dll`, `mfreadwrite.dll`, `ole32.dll`)
load at runtime from `C:\Windows\System32`. Windows N editions need the Media
Feature Pack. On other systems the backend reports that it is unsupported.

## Network security

LoLa-compatible traffic is neither authenticated nor encrypted. Source and port
filtering reduces accidental cross-talk but does not identify the peer. Run on a
trusted isolated network or a separately secured tunnel.

## License

The crate is Apache-2.0, like the rest of Open LoLa; see `LICENSE-APACHE`.
