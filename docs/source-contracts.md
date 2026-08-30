# Source contracts

Status: active source-alpha contract index
Verdict: PARTIAL

Open LoLa distinguishes externally meaningful contracts from internal
structure. The stable surfaces below remain compatible while internal module
ownership and file layout may evolve.

## Stable surfaces

- SwiftPM products/modules: `OpenLolaContracts`, `OpenLolaCore`,
  `OpenLolaAppSupport`, `open-lola`, and `open-lola-app`; internal target
  boundaries are enforced by the architecture verifier.
- Swift CLI command names, argument semantics, final `VERDICT:` lines, report
  JSON property names/types, and persisted preference keys.
- Python invocation through `python -m linux_connector.lola_connector.cli` and
  its `status`, `listen`, `connect`, and `selftest` commands.
- Rust package/executable name `rusty-lola`, bundled resources,
  configuration files, and user settings formats.
- LoLa control/media ports, defaults, packet semantics, and the corpus under
  `interop/lola2`.

## Compatibility horizons

`audioTransport` is the canonical direct-peer audio field. Hidden legacy
`audioCompression` decoding remains for existing reports, defaults, and
callers. New output writes only the canonical field.

Split `inputDeviceUID` and `outputDeviceUID` fields are canonical. The
single-device `audioDeviceUID` accessor remains only for decoding or adapting
existing callers; new encodings use split identifiers.

`direct-p2p-two-peer-report` and its validator are canonical.
Prototype-named report decoding remains where current fixtures and external
callers require it, but new commands and documentation use the canonical name.

## Non-contracts

Internal Swift folders, private symbol names, Python helper modules, test file
layout, and implementation-specific abstractions are not compatibility
surfaces. The connector facade is composed from explicit lifecycle,
control-exchange, receive, socket-I/O, and media-receiver services; retired
helper module names are not import contracts. Its wheel is the distribution
contract: only the `linux_connector` runtime package is installed, while tests,
deployment material, and tooling stay out of the wheel.

Connector families and direct-peer orchestration live under
`runtimes/macos/Sources/OpenLolaApplication`; transport mechanics live under
`OpenLolaTransport`, media adapters under `OpenLolaMediaPlatform`, and reports
and validators under `OpenLolaEvidenceModels`, even when they describe another
domain.

## Evidence limits

Implemented source and passing tests may earn a source-level PASS. Physical
hardware, field latency, original Windows peer interoperability, signing, and
distribution claims remain PARTIAL until their own evidence gates succeed.

VERDICT: PARTIAL
