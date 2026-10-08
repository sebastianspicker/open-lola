# rusty-lola

`rusty-lola` is the Windows and native Linux station in the Open LoLa workspace.
It implements LoLa 2.0 independently from the macOS Swift runtime. Windows
defaults request XIMEA and PortAudio/ASIO; Linux defaults request V4L2 and ALSA.
UDP and Windows Npcap provide media transport, and diagnostic media is always an
explicit choice.

## Requirements

- stable Rust, edition 2021;
- Windows for XIMEA, PortAudio/ASIO, and Npcap, or Ubuntu 24.04 x86_64 for ALSA
  and V4L2; and
- locally licensed native libraries and connected devices for hardware paths.

Cross-platform tests use explicit diagnostic adapters and UDP loopback. They do
not prove native drivers or physical hardware. See
[Linux migration](../../docs/linux-migration.md) for device configuration and
every retired Python option.

## Build and test

Run from this directory:

```bash
cargo test
cargo build --release
cargo test --test lola2_compatibility
```

From the repository root, use the full Rust lane:

```bash
make test-rust
```

`tests/lola2_compatibility.rs` replays every case of
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

## Configuration

Values are applied in this order: defaults, `--settings`, `--session`, then
explicit CLI overrides. `station --settings <missing-path>` creates a default
file, while `connect` and `listen` reject a missing settings file.

JSON session profiles use the Open LoLa format. `.ssn` input accepts tagged Open
LoLa JSON or the documented subset of Windows LastSsn INI fields.
`session-profile --out name.ssn` writes tagged Open LoLa JSON and never writes a
proprietary Windows session file.

`network.audio_receive_queue_depth` (default 4) bounds how many remote audio
blocks the receiver may hold; every readable block is admitted and one block
is presented per audio deadline, so the bound is the most latency a jitter
burst can add. `network.audio_receive_prefill` (default 0) withholds playout
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

## Trust and evidence boundary

Windows loads XIMEA, PortAudio, and Npcap only from canonical direct children of
fixed trusted installation directories: `C:\Windows\System32`, its `Npcap`
subdirectory, `C:\Program Files\XIMEA\API\xiAPI`, and
`C:\Program Files\Open LoLa\portaudio`. Dependent DLL lookup is limited to the
selected DLL's directory and System32; PATH, current-directory,
executable-adjacent, build, and archive searches are excluded. The loader does
not establish signature or digest trust, so keep installation directories
controlled and use only licensed libraries from known sources. See
[ship/README.md](ship/README.md) and the repository
[security policy](../../SECURITY.md).

LoLa-compatible traffic is not authenticated or encrypted. Source and port
filtering reduces accidental cross-talk but is not peer identity. Operate on a
trusted isolated network or a separately secured tunnel.

## License

The crate is MIT OR Apache-2.0; see `LICENSE-MIT` and `LICENSE-APACHE`.
