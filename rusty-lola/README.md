# rusty-lola

Windows-first Rust implementation of the recovered LoLa 2.0 protocol.

Lives next to the Python tree (`../../open-lola/`), which stays the behavior
oracle. Production sessions use strict XIMEA, PortAudio/ASIO, and UDP or Npcap
backends. Deterministic synthetic media is available only through the explicit
diagnostic backends and is labelled synthetic in reports.

## Requirements

- Rust 2021 (stable)
- Windows is the primary target. Cross-platform tests use explicit diagnostic
  backends and UDP loopback.

## Build & test

Parity is checked **in-process** (`cargo test` + `cli::run(argv)`). You do not
need to launch the binary for the suite.

```text
cargo test
cargo build --release   # optional
```

```text
cargo run -- identity
cargo run -- station --timeout 5 --frames 3 --no-extras
cargo run -- ui --headless --run-connect --frames 2
```

The production defaults request XIMEA and PortAudio/ASIO and fail if they are
unavailable. For a deterministic software diagnostic, select both diagnostic
backends explicitly with `--camera-backend diagnostic --audio-backend
diagnostic`.

To consume the versioned implementation-neutral corpus in
`../interop/lola2/manifest.json`, then compare its vectors with the live
sibling Python codec:

```text
TUX_LOLA_ROOT=.. cargo test --test protocol_conformance \
  live_python_wire_output_matches_rust -- --ignored --nocapture
```

The corpus records recovered synthetic wire behavior and explicitly does not
claim original Windows capture provenance. The cross-process lanes are also
explicit because they require a distinct local address. They default to
`127.0.0.2`; set `RUSTY_LOLA_TEST_PEER_IP` to another configured local IPv4
address when that loopback alias is unavailable:

```text
TUX_LOLA_ROOT=../../open-lola RUSTY_LOLA_TEST_PEER_IP=127.0.0.2 \
  cargo test --test python_connector_conformance \
  -- --ignored --nocapture
```

## CLI

```text
identity | station | connect | listen | emulate | tester | convert | wavsplit
ui | check-remote | session-profile | multi-sid
```

Useful `station` flags: `--settings`, `--session`, `--timeout`, `--compress`,
`--record`, `--preview`, `--no-extras`, `--reject`, `--frames`, `--peer-mode`,
`--duration`, `--interleaved`, `--pcap` / `--pcap-raw`, `--camera-backend`,
`--audio-backend`, `--catalog`, `--camera-mode-id`, `--precheck-reachable`.

Session input is fallible and selected by extension: JSON profiles are the
Open-Lola format, while `.ssn` accepts either tagged Open-Lola JSON or only the
documented recoverable Windows LastSsn INI fields (`RemoteIpAddr`,
`RemoteAudioBuffers`, and `RemoteVideoBuffers`). Unknown, malformed, and
out-of-range `.ssn` input is rejected. `session-profile --out name.ssn` writes
tagged Open-Lola JSON; it never writes a proprietary Windows session file.
Settings are applied first, imported session fields next, then explicit CLI
overrides. In particular, `connect <remote-ip>` overrides the imported peer.

Default ports: **7000** (control), **19788** (audio), **19798** (video).

`connect <remote-ip>` is the explicit initiator command and `listen` is the
fixed-port responder command. Both accept `--settings`, `--session`, backend selections,
`--duration`, `--continuous`, `--receive-only` (or `--rx`), `--audio-only`,
and explicit stream flags: `--tx-audio`, `--rx-audio`, `--tx-video`,
`--rx-video`. Supplying any explicit stream flag enables only those named
directions. `--continuous` requires `--duration`; that bounded operator seam
owns one `SessionRuntime` lifecycle and stops it through its handle when the
duration elapses.

```text
cargo run -- connect 192.0.2.44 --receive-only --audio-only --duration 30
cargo run -- listen --continuous --duration 300 --rx-audio --tx-video
```

`station` remains compatible; its `--peer-mode` accepts only `loopback`,
`remote`, or `listen`. Invalid roles are errors and never fall back to
loopback.

## Layout

```text
rusty-lola/
├── Cargo.toml
├── data/camera_modes/   # Ximea.ini, XimeaColors.ini, PtGrey.ini
├── ship/                # optional vendor DLLs for probe paths (gitignored)
├── src/
│   ├── protocol/        # LoLa 2.0 control and media framing
│   ├── config/          # catalogs, colors, settings, ssn
│   ├── net/             # fixed-port UDP, Npcap, reachability
│   ├── audio/ video/    # strict native and diagnostic backends
│   ├── station/         # session, multi-sid, monitor, dual record, emulate
│   ├── ui/              # egui + headless controller
│   └── cli.rs
└── tests/
```

## Optional hardware DLLs

Drop locally licensed vendor DLLs into `ship/` if you want the native probes to
find them (see `ship/README.md`). A requested native backend fails when its DLL,
device, or stream cannot be initialized; it never switches to diagnostics.

## Network trust boundary

LoLa 2.0 is intentionally wire-compatible and therefore adds no authentication
or encryption. The implementation pins accepted control and media packets to
the negotiated IPv4 peer and fixed source ports, but production use still
requires a trusted network or a separately secured tunnel.

## License

MIT OR Apache-2.0 (see `LICENSE-MIT` and `LICENSE-APACHE`).
