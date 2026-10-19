# rusty-lola

`rusty-lola` is the Windows and native Linux station in the Open LoLa workspace.
It implements LoLa 2.0 independently from the macOS Swift runtime. Windows
defaults request XIMEA and PortAudio/ASIO, and ordinary USB/UVC webcams work
through the Media Foundation camera backend; Linux defaults request V4L2 and ALSA.
UDP and Windows Npcap provide media transport, and diagnostic media is always an
explicit choice.

## Requirements

- stable Rust, edition 2021;
- Windows for XIMEA or Media Foundation cameras, PortAudio/ASIO, and Npcap, or
  Ubuntu 24.04 x86_64 for ALSA and V4L2; and
- locally licensed native libraries and connected devices for hardware paths.

Cross-platform tests use explicit diagnostic adapters and UDP loopback. They do
not prove native drivers or physical hardware. See
[Linux migration](../../docs/linux-migration.md) for device configuration and
every retired Python option.

## Windows/Linux checks

The `make` targets in the repository root assume a macOS developer machine (bash,
GNU make, Xcode, `uv`), so Windows and Linux testers run the Rust lane with plain
`cargo` from `runtimes/rust-station` (the same commands work in PowerShell):

```text
cargo fmt --all -- --check
cargo clippy --workspace --all-targets --all-features -- -D warnings -D clippy::undocumented_unsafe_blocks -D clippy::missing_safety_doc
cargo test --workspace --all-targets --all-features
cargo test --workspace --all-targets --no-default-features
cargo run --no-default-features -- selftest
```

On Windows install the MSVC toolchain first: Visual Studio Build Tools with the
"Desktop development with C++" workload, then `rustup default stable` (the
`x86_64-pc-windows-msvc` host). On Linux install a C toolchain and, for the native
paths, `libasound2` and V4L2 headers/utilities (`v4l-utils`).

## Build and test

Run from this directory:

```bash
cargo test
cargo build --release
```

From the repository root, use the full Rust lane:

```bash
make test-rust
```

The corpus compatibility test (its source is not published) replays every case of
`../../interop/lola2/manifest.json` (control and media encode/parse, reject
categories, 1024-byte NUL padding) and the 110 ASCII/OSC15 observations of
`migration-control-oracle.json` against the public `rusty_lola::protocol` API.
The corpus is synthetic regression evidence, not original Windows capture.

The default `gui` feature includes the interactive egui application. For a
CLI-only build without `eframe`, use:

```bash
cargo build --release --no-default-features
cargo run --no-default-features -- ui --headless
```

The `ui` command and headless controller remain available in this build.
Interactive `ui` requires rebuilding with `--features gui` or the default
features; command names, settings, and media defaults are unchanged.

## Run

A LAN session uses `listen` on one host and `connect` on the other (add
`--duration`, or `--continuous --duration`, to bound a run):

```bash
cargo run -- listen --remote-ip 192.0.2.10
cargo run -- connect 192.0.2.20 --duration 30
```

`station` is a loopback demo, not a LAN session: it talks to a synthetic peer on
the same host, caps the stream at 160x120, and prints a notice saying so. Its
`--timeout` bounds negotiation only. `emulate`/`tester` run synthetic software
emulation modes, and a `diagnostic` (or settings alias `software`) backend
produces synthetic media; each prints a stderr notice.

```bash
cargo run -- identity
cargo run -- station --timeout 5 --frames 3 --no-extras \
  --camera-backend diagnostic --audio-backend diagnostic
cargo run -- ui --headless --run-connect --frames 2
```

Use `cargo run -- --help` and the relevant subcommand help for the current
arguments. Available command families include `identity`, `station`, `connect`,
`listen`, `emulate`, `tester`, `convert`, `wavsplit`, `ui`, `check-remote`,
`session-profile`, `multi-sid`, `status`, `selftest`, `devices`, and
`decode-pcap`.

`connect <remote-ip>` is the initiator and `listen` the fixed-port responder.
Both support bounded durations, explicit RX and TX stream directions, settings
and session input, and native or diagnostic backend selection. Default ports are
7000 control, 19788 audio, and 19798 video.

Ctrl-C (SIGINT) and SIGTERM stop a `connect` or `listen` run cleanly: the session
sends DISCONNECT, the result JSON is still printed with `ok: true`,
`stopped_by` and a "stopped by operator" note, and the exit status is 130 for
SIGINT or 143 for SIGTERM (130 for Windows console events). A run that had
already failed keeps its failure and exits 1; a second signal exits immediately.
A session the peer ends with DISCONNECT is a normal end as well: `ok: true`, a
"peer disconnected" note, exit status 0. Every failed result carries a non-empty
`error`.

For a LAN peer, `listen --remote-ip <ip>` names the expected peer (`connect`
takes it positionally). While `--local-ip` is unset and the remote is not
loopback, the local IP is chosen from the OS route to the remote and printed on
stderr; pass `--local-ip` to override. Listeners ignore datagrams from any other
IP and name the last unexpected sender when they time out.
`--record <dir>` records the session's audio and video (or follows
`recording.enabled` in `--settings`), `--report <path>` also writes the result
JSON atomically, failures print `connect failed: ...` / `listen failed: ...` on
stderr, and `--continuous` prints a progress line about every 5 seconds.

## Configuration

Values are applied in this order: defaults, `--settings`, `--session`, then
explicit CLI overrides. `station --settings <missing-path>` creates a default
file, while `connect` and `listen` reject a missing settings file.

JSON session profiles use the Open LoLa format. `.ssn` input accepts tagged Open
LoLa JSON or the documented subset of Windows LastSsn INI fields.
`session-profile --out name.ssn` writes tagged Open LoLa JSON and never writes a
proprietary Windows session file.

`network.audio_receive_queue_depth` (default 4) bounds how many remote audio
local-device blocks the receiver may hold. Valid peer packets are combined or
split into one local block per audio deadline, so differing packet sizes preserve
the sample rate. The queue retains at least one complete peer packet when its
packetization interval exceeds the configured local-block depth. `network.audio_receive_prefill` (default 0) withholds playout
until that many blocks are queued. A queue that stays above its prefill target
for about 0.7 s discards one block and reports it as a realigned buffer. Remote
blocks whose frames-per-packet differ from the local device are re-blocked
before playout. `network.video_receive_queue_depth` defaults to 1 (newest
frame).

`RUSTY_LOLA_LOCAL_MAC` and `RUSTY_LOLA_PEER_MAC` provide explicit MAC addresses
for controlled Npcap diagnostics when automatic resolution is unsuitable. Use
ordinary UDP for routed peers.

Npcap receive counters track accepted and rejected packets as they are read.
Kernel drop statistics refresh at the terminal session report snapshot and once
more during finalization before capture closes. Individual receive polls and
ordinary status copies use cached kernel counters, so there is no periodic
kernel-statistics query. A failed refresh follows the existing session error path
while the partial report retains all transport fields and the last observed
software counters. Finalization still closes capture on refresh failure.

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

## Windows audio (PortAudio/ASIO)

Native vendor DLLs (xiAPI, PortAudio, wpcap/Packet) are loaded only from absolute
paths in these locations, searched in this order:

1. `C:\Windows\System32` (and `C:\Windows\System32\Npcap` for Npcap);
2. the vendor directory: `C:\Program Files\XIMEA\API\xiAPI` or
   `C:\Program Files\Open LoLa\portaudio`;
3. the directory of the running executable, last (an app-local copy used only as a
   fallback when no installed library exists; only the known file names
   `xiapi64.dll`/`xiapi.dll`/`xiapi32.dll`, `portaudio_x64.dll`/`portaudio.dll`/
   `portaudio_x86.dll` and `wpcap.dll`/`Packet.dll` are accepted there, and an
   executable directory on a UNC or network path is refused).

Nothing else is searched: not `PATH`, the working directory, or the `ship/` staging
folder. The allowlist applies to the top-level DLL only; its imports resolve from that
DLL's directory (`LOAD_LIBRARY_SEARCH_DLL_LOAD_DIR`) and System32.

The strict audio backend accepts only ASIO devices. It looks for a PortAudio
DLL named `portaudio_x64.dll`, `portaudio.dll`, or `portaudio_x86.dll` (in that
order) in the three locations listed above, and nowhere else. Install a PortAudio
build with the ASIO host API enabled next to `rusty-lola.exe` or into
`C:\Program Files\Open LoLa\portaudio`.

With no `input_device`/`output_device` configured, the ASIO host API's own
default devices are used; if no ASIO driver is installed the error says so.
`rusty-lola devices` lists every PortAudio device under `portaudio.devices`
with its index, name, host API, channel counts and default sample rate, and
marks ASIO devices (`"asio": true`). Pass one of those names with
`--input-device` / `--output-device` (or the settings keys) to choose a device.

## Windows video (XIMEA or Media Foundation)

XIMEA is no longer the only Windows camera. `--camera-backend mediafoundation`
(alias `mf`, settings `video.backend: "mediafoundation"`) captures from any
camera Media Foundation lists as a video capture device, which covers ordinary
USB/UVC webcams. XIMEA stays the Windows default so existing XIMEA stations and
their camera-mode catalogs behave as before; choose Media Foundation explicitly.

- `video.device` selects a camera by friendly name or symbolic link; when empty,
  `video.local_camera_index` picks the n-th camera.
- `video.width`, `video.height`, and `video.fps` must match a mode the camera
  offers exactly. A frame-rate range that contains the requested rate also
  matches. There is no scaling or automatic negotiation; a mismatch fails with
  the list of offered modes.
- The camera's NV12, YUY2, or RGB32 output is converted to the session format:
  `video.bpp` 8 delivers Mono8 (luma) and 24 delivers RGB24. Mono8 requires
  `video.bayer` 0, because webcam luma is not a Bayer mosaic. `video.pixel_format`
  may name `NV12`, `YUY2`, or `RGB32` to insist on one; empty picks the cheapest.
  MJPEG-only modes are listed but not used.
- `rusty-lola devices` reports each camera under `mediafoundation.devices` with
  its native modes.

Media Foundation DLLs (`mfplat.dll`, `mf.dll`, `mfreadwrite.dll`, `ole32.dll`)
load at runtime from `C:\Windows\System32`. Windows N editions need the Media
Feature Pack. Off Windows the backend reports that it is unsupported.

## Trust and evidence boundary

Windows loads XIMEA, PortAudio, Npcap, and Media Foundation only from canonical
direct children of fixed trusted directories: `C:\Windows\System32`, its `Npcap`
subdirectory, `C:\Program Files\XIMEA\API\xiAPI`,
and `C:\Program Files\Open LoLa\portaudio`, then, last, the running executable's
own directory (known XIMEA, PortAudio, and Npcap library file names only; not on a
UNC or network path). Media Foundation DLLs are accepted
from System32 only. The allowlist applies to the top-level DLL only; its imports
resolve from that DLL's directory (`LOAD_LIBRARY_SEARCH_DLL_LOAD_DIR`) and System32, so
dependent DLL lookup is limited to the selected DLL's
directory and System32; PATH, current-directory, other executable-adjacent
(including `ship/`), build, and archive searches are excluded. The loader does
not establish signature or digest trust, so keep installation directories
controlled and use only licensed libraries from known sources. See
[ship/README.md](ship/README.md) and the repository
[security policy](../../SECURITY.md).

LoLa-compatible traffic is not authenticated or encrypted. Source and port
filtering reduces accidental cross-talk but is not peer identity. Operate on a
trusted isolated network or a separately secured tunnel.

## License

The crate is Apache-2.0, like the rest of Open LoLa; see `LICENSE-APACHE`.
