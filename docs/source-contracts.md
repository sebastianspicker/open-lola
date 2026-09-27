# Source contracts

Status: active source-alpha contract index
Verdict: PARTIAL

Open LoLa separates externally meaningful contracts from internal structure. The
stable surfaces below stay compatible while internal module ownership and file
layout evolve.

## Stable surfaces

- SwiftPM products and modules: `OpenLolaContracts`, `OpenLolaCore`,
  `OpenLolaAppSupport`, `open-lola`, and `open-lola-app`. The architecture
  verifier enforces internal target boundaries.
- Swift CLI command names, argument semantics, final `VERDICT:` lines, report
  JSON property names and types, and persisted preference keys.
- Rust `status`, `listen`, `connect`, `selftest`, `devices`, and `decode-pcap`,
  which replace the retired Python connector. Every command and option
  replacement is documented in [Linux migration](linux-migration.md).
- The Rust package and executable name `rusty-lola`, bundled resources,
  configuration files, and user settings formats.
- LoLa control and media ports, defaults, packet semantics, and the corpus under
  `interop/lola2`.

## Compatibility horizons

`audioTransport` is the canonical direct-peer audio field. Hidden legacy
`audioCompression` decoding remains for existing reports, defaults, and callers,
but new output writes only the canonical field.

Split `inputDeviceUID` and `outputDeviceUID` fields are canonical. The
single-device `audioDeviceUID` accessor remains only for decoding or adapting
existing callers; new encodings use split identifiers.

`direct-p2p-two-peer-report` and its validator are canonical. Prototype-named
report decoding remains where current fixtures and external callers require it,
but new commands and documentation use the canonical name.

## Non-contracts

Internal Swift folders, private symbol names, Python helper modules, test file
layout, and implementation-specific abstractions are not compatibility surfaces.
Python is repository tooling and has no runtime distribution contract.

Connector families and show-control bridges live in `OpenLolaIntegrations`;
direct-peer orchestration, CLI command bodies, and cross-domain evidence flows
live in `OpenLolaApplication`; transport mechanics live in `OpenLolaTransport`,
media adapters in `OpenLolaMediaPlatform`, and reusable reports and validators in
`OpenLolaEvidenceModels`. These module names are not products. `OpenLolaCore`
re-exports all of them, so moving a type between internal modules does not
change the public product surface.

Configuration sources and precedence are compatibility surfaces only where
explicitly documented in [configuration.md](configuration.md). Test-only
environment injection and internal helper-module paths are not operator APIs.

## Rust station media admission

The syntax parser preserves corpus protocol values independently of native
session capabilities. Station raw presentation accepts 8-bit grayscale and 24-bit
RGB. Auto-Bayer advertises the transformed RGB24 output with `BAYER=0`; JPEG
output is negotiated as decoded RGB24. Camera capture geometry remains local,
while transmitted scaling and receive validation follow the accepted wire
geometry, and unsupported output tuples are rejected during negotiation. Decoded
JPEG dimensions and channels must match the negotiated tuple; invalid frames are
counted drops, and subsequent valid frames remain admissible.

Reports keep existing keys and add native xrun, skipped-clock-slot, queue-age,
and lateness observations. Missing optional measurements remain absent or null,
and software scheduler observations are not hardware latency evidence. Recording
and preview paths identify successfully written files in private session
subdirectories of their independently configured output roots.

## Evidence limits

Implemented source and passing tests may earn a source-level PASS. Physical
hardware, field latency, original Windows peer interoperability, signing, and
distribution claims remain PARTIAL until their own evidence gates succeed.

VERDICT: PARTIAL
