# Contributing to Open LoLa

Open LoLa is an experimental source alpha. Contributions must remain
clean-room: use public standards, public APIs, original experiments, and
material you are entitled to share. Do not submit proprietary binaries,
decompiled material, confidential captures, credentials, or personal data.

## Choose the owning boundary

- macOS session policy, evidence models, transport, media/platform, and
  application code belongs in the matching SwiftPM target under
  `runtimes/macos/Sources/`; `OpenLolaCore` is facade-only;
- framework-free shared report contracts belong in `OpenLolaContracts`;
- Rust station behavior belongs in `runtimes/rust-station/`;
- Linux compatibility behavior belongs in
  `runtimes/linux-compat-connector/`;
- cross-runtime LoLa protocol evidence belongs in `interop/lola2/`;
- vendored upstream code belongs only in `third_party/`.

Avoid generic utility modules. Put side effects in platform, transport,
integration, process, or device boundaries; keep session-domain policy
independent of UI and concrete media frameworks. The architecture verifier
enforces target dependencies, import allowlists, facade shape, and semantic
placement rules.

## Evidence and compatibility

Label evidence accurately as source, synthetic, localhost, measured hardware,
or reference-peer evidence. A local test does not establish field readiness.
Preserve documented CLI, report, persistence, package, and wire contracts. An
internal module path or private type is not a compatibility requirement.

## Verification

Run the narrow lane while developing and `make verify` before submitting a
cross-cutting change. At minimum:

```bash
make architecture
make lint
make test-swift
make test-python
make test-rust
git diff --check
```

Use `/private/tmp` for build and tool caches. Report checks that could not run,
especially hardware, peer, signing, and graphical-session gates. See
[docs/testing.md](docs/testing.md) for exact commands and
[docs/architecture.md](docs/architecture.md) for dependency rules.
