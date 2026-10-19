# Contributing to Open LoLa

Thanks for taking a look. Open LoLa is an experimental source alpha, and all
work must be clean-room: use public standards and APIs, your own experiments,
and material you are allowed to share. Do not submit proprietary binaries or
source, decompiler output, confidential captures, credentials, or personal data.

## Where your change goes

Each concept has one owner:

- macOS code goes in the matching SwiftPM target under `runtimes/macos/Sources/`.
  `OpenLolaCore` only re-exports the other modules and holds no code of its own.
- Shared values that need no framework go in `OpenLolaContracts`.
- Rust station and Linux behavior goes in `runtimes/rust-station/`.
- Synthetic wire cases shared by both runtimes go in `interop/lola2/`.
- Upstream code goes in `third_party/`. Our own Opus bridge code lives only in
  `third_party/opus/openlola_bridge/`.

Keep side effects in device, media, transport, process, filesystem, or
presentation adapters. Session logic must not depend on the UI or on a specific
media framework. [Architecture](docs/architecture.md) is the reference for who
owns what.

## Compatibility and claims

Read [source contracts](docs/source-contracts.md) before you change package,
CLI, wire, report, preference, or settings behavior. Internal paths and private
helpers can change freely; stable interfaces need a planned migration.

State what kind of evidence you have: source only, synthetic, localhost,
measured hardware, reference peer, or not measured. Do not present a local or
generated result as a field, security, signing, or distribution result.
[Clean-room design rules](docs/clean-room-design-rules.md) covers
interoperability work you want to publish.

## Check your change

Run the quick checks while you work:

```bash
make architecture
make code-quality
make lint
make test-python
make test-rust
git diff --check
```

Run `make verify` before changing both runtimes, a stable interface, or the
release export. For documentation-only changes, run the documentation checks in
[docs/testing.md](docs/testing.md). In your pull request, list every check you
could not run, especially hardware, reference-peer, graphical-session, signing,
and notarization checks.

When you change behavior, commands, configuration, or a stable interface,
update the one document that covers it. Do not add plans, work logs, or
duplicate status pages.
