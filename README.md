# Open LoLa

Open LoLa is an independent source-alpha project for configuring, running, and
verifying low-latency audiovisual sessions. It is audio-first: an operator
selects devices, peers, routes, and a latency profile; the runtime negotiates a
bounded session, moves media, and records evidence about what actually ran.

The repository contains three deliberately separate runtime implementations:

- a macOS Swift package, CLI, and SwiftUI operator application;
- a Windows-first, cross-platform Rust station; and
- a Python Linux compatibility connector for LoLa control and media research.

The runtimes share interoperability contracts and evidence conventions, not
implementation modules. Open LoLa is not affiliated with or endorsed by the
LoLa project, Conservatorio di Musica Giuseppe Tartini, or GARR.

## Capabilities

The macOS runtime provides direct-peer session negotiation, UDP audio and video
transport, Core Audio and AVFoundation integration, receive buffering and drift
handling, Opus and JPEG XS codec paths, external LoLa/UltraGrid/JackTrip
adapters, and machine-readable run reports with validators. Its public SwiftPM
products remain `OpenLolaCore`, `OpenLolaContracts`, `OpenLolaAppSupport`,
`open-lola`, and `open-lola-app`.

The Rust station provides connect/listen lifecycle, bounded control handling,
audio and video device adapters, persisted operator settings, and protocol
oracle checks. The Python connector provides `status`, `listen`, `connect`,
and `selftest` commands plus synthetic and subprocess-backed media adapters. It
is not a native low-latency Linux capture/playback stack.

Source tests, synthetic reports, localhost traffic, and screenshots are useful
evidence, but do not prove physical latency, hardware compatibility, peer
interoperability, security, signing, or distribution readiness.

## Repository map

| Path | Responsibility |
|---|---|
| `runtimes/macos/` | Swift app, CLI, session orchestration, media, transport, integrations, evidence, and platform adapters. |
| `runtimes/rust-station/` | Rust station implementation. The crate remains named `rusty-lola`. |
| `runtimes/linux-compat-connector/` | Python package, tests, deployment material, and connector documentation. |
| `interop/lola2/` | Shared LoLa 2.0 corpus, protocol constants, captures, and conformance evidence. |
| `third_party/` | Vendored Opus and JPEG XS source. |
| `Tests/` | SwiftPM behavioral and contract tests. |
| `tools/` | Verification, packaging, documentation, macOS, and interoperability tooling. |
| `web/demo/` | Static, fixture-backed Signal Desk demonstration. |
| `docs/` | Current architecture, operation, evidence, and release guidance. |

See [docs/architecture.md](docs/architecture.md) for ownership and dependency
rules. SwiftPM targets now enforce the runtime boundaries: `OpenLolaCore` is a
single facade, while session policy, evidence models, transport,
media/platform services, and application composition are separate targets.

## Build and run

The supported macOS build uses Xcode 26.6 and Swift 6.3.3:

```bash
export DEVELOPER_DIR=/Applications/Xcode-26.6.0.app/Contents/Developer
swift build --disable-sandbox \
  --scratch-path /private/tmp/open-lola-swiftpm-build
```

Inspect the CLI:

```bash
export OPEN_LOLA_TEST_OPEN_LOLA_CLI="$(swift build --disable-sandbox \
  --scratch-path /private/tmp/open-lola-swiftpm-build \
  --show-bin-path)/open-lola"
"$OPEN_LOLA_TEST_OPEN_LOLA_CLI" --help
"$OPEN_LOLA_TEST_OPEN_LOLA_CLI" session-capabilities
```

Create the locked Python environment and run its self-test:

```bash
uv sync --locked --extra dev
uv run --locked python -m linux_connector.lola_connector.cli \
  --local-ip 127.0.0.1 selftest --duration 0.25
```

Run the Rust station from the workspace root:

```bash
cargo run -p rusty-lola -- --help
```

Serve the static demo locally:

```bash
python3 -m http.server 4173 --bind 127.0.0.1 --directory web/demo
```

The demo cannot discover devices, launch the native application, open media
streams, or contact peers.

## Verification

The root acceptance command runs architecture, documentation, Swift, Python,
Rust, shell, and release checks:

```bash
make verify
```

Focused lanes are available as `make test-swift`, `make test-python`,
`make test-rust`, `make lint`, and `make architecture`. See
[docs/testing.md](docs/testing.md).

## External contracts

The repository preserves these intentional compatibility surfaces:

- SwiftPM product and module names;
- `open-lola` commands, terminal verdict lines, report JSON formats, and
  persisted preference keys;
- the Python module CLI and its console behavior;
- the Rust crate and executable name, settings formats, and bundled resources;
- LoLa wire ports, protocol defaults, and the shared interoperability corpus.

Internal paths and private helpers are not compatibility contracts. The Python
connector facade delegates to explicit lifecycle, control-exchange, receive,
socket-I/O, and media-receiver services. Its wheel contract includes only the
runtime package and is tested by installing it into a clean environment.

## Status and licensing

This remains an experimental, unpublished source alpha. Physical two-Mac and
Windows peer evidence, RME/Blackmagic device proof, authentication and media
integrity, signing, notarization, clean-machine installation, and final legal
review remain outside local software verification.

First-party source and documentation are licensed under
[Apache-2.0](LICENSE). Vendored components retain their own terms; see
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md). Compatibility and clean-room
boundaries are described in [LEGAL.md](LEGAL.md) and
[docs/compatibility-scope.md](docs/compatibility-scope.md).
