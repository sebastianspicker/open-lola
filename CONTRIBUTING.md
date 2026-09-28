# Contributing to Open LoLa

Thanks for taking a look. Open LoLa is an experimental source alpha, and every
contribution has to stay clean-room: use public standards and APIs, original
experiments, and material you are entitled to share. Do not submit proprietary
binaries or source, decompiler output, confidential captures, credentials, or
personal data.

## Find the right home for your change

Each concept has one owner. Put your change where it belongs:

- macOS code goes in the matching SwiftPM target under `runtimes/macos/Sources/`.
  `OpenLolaCore` is a facade over the other modules and holds no implementation.
- Framework-free shared values go in `OpenLolaContracts`.
- Rust station behavior goes in `runtimes/rust-station/`.
- Linux compatibility behavior also lives in `runtimes/rust-station/`.
- Codec-backed modes remain unavailable until an authorized implementation and
  its notices are reviewed.

Keep side effects in explicit device, media, transport, process, filesystem, or
presentation adapters. Session policy stays independent of UI and concrete media
frameworks. [Architecture](docs/architecture.md) is the ownership source of truth.

## Keep contracts and evidence honest

Read [source contracts](docs/source-contracts.md) before changing package, CLI,
wire, report, preference, or settings behavior. Internal paths and private
helpers can change freely; public compatibility surfaces need an intentional
migration.

Say what your evidence actually is: source, synthetic, localhost, measured
hardware, reference peer, or not measured. Never promote a local or generated
result into field, security, signing, or distribution proof. The rules for
publishable interoperability work are in
[clean-room design rules](docs/clean-room-design-rules.md).

## Verify your change

Run the build and lint checks while developing:

```bash
make lint
make swift-build
make rust-build
git diff --check
```

Run `make verify` before a cross-runtime, public-contract, or release-boundary
change. Report every check you could not run,
especially hardware, reference-peer, graphical-session, signing, and
notarization checks.

When behavior, commands, configuration, or a compatibility contract changes,
update the single document that owns it. Please do not add plans, audit ledgers,
implementation diaries, or duplicate status pages.
