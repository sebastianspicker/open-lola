# Source contracts

These are the parts of Open LoLa that outside users and tools depend on. They
stay compatible while internal modules and file layout change.

## Stable interfaces

- SwiftPM products and modules: `OpenLolaContracts`, `OpenLolaCore`,
  `OpenLolaAppSupport`, `open-lola` and `open-lola-app`. The architecture
  verifier enforces the internal target boundaries.
- Swift CLI command names, argument meaning, final `VERDICT:` lines, report JSON
  property names and types, and persisted preference keys.
- The Rust commands `status`, `listen`, `connect`, `selftest`, `devices` and
  `decode-pcap`, which replace the retired Python connector. Each command and
  option mapping is listed in [Linux migration](linux-migration.md).
- The Rust package and executable name `rusty-lola`, its bundled resources,
  configuration files and user settings formats.
- LoLa control and media ports, defaults, packet semantics, and the corpus under
  `interop/lola2`.

## Legacy fields still accepted

- `audioTransport` is the direct-peer audio field. The hidden legacy
  `audioCompression` field is still decoded for existing reports, defaults and
  callers, but new output writes only `audioTransport`.
- `inputDeviceUID` and `outputDeviceUID` are the device fields. The single
  `audioDeviceUID` accessor remains only to decode or adapt existing callers;
  new encodings use the split fields.
- `direct-p2p-two-peer-report` and its validator are the current report name.
  Prototype-named reports are still decoded where current fixtures and external
  callers need them, but new commands and docs use the current name.

## Not stable

Internal Swift folders, private symbol names, Python helper modules, test file
layout and implementation-specific abstractions can change at any time. Python
is repository tooling and is not distributed as a runtime.

Internal modules are not products:

| Module | Contents |
|---|---|
| `OpenLolaIntegrations` | Connector families and show-control bridges |
| `OpenLolaApplication` | Direct-peer orchestration, CLI command bodies, cross-domain report flows |
| `OpenLolaTransport` | Transport mechanics |
| `OpenLolaMediaPlatform` | Media adapters |
| `OpenLolaEvidenceModels` | Reusable reports and validators |

`OpenLolaCore` re-exports all of them, so moving a type between internal
modules does not change the public product.

Configuration sources and precedence are stable only where
[configuration.md](configuration.md) documents them. Test-only environment
injection and internal helper-module paths are not operator APIs.

## Rust station media admission

The parser keeps corpus protocol values as received, independent of what the
native session supports.

- Raw presentation accepts 8-bit grayscale and 24-bit RGB.
- Auto-Bayer advertises its RGB24 output with `BAYER=0`.
- JPEG output is negotiated as decoded RGB24.
- Camera capture geometry stays local. Transmitted scaling and receive
  validation follow the negotiated wire geometry, and unsupported output
  combinations are rejected during negotiation.
- Decoded JPEG dimensions and channels must match the negotiated format. An
  invalid frame is counted as a drop, and later valid frames are still accepted.

Reports keep their existing keys and add native xrun, skipped-clock-slot,
queue-age and lateness fields. Missing optional measurements are absent or
null. Software scheduler figures are not hardware latency measurements.
Recording and preview report the files they wrote, in private per-session
subdirectories of their separately configured output roots.

## What a PASS covers

Implemented code with passing tests can earn a PASS for source behavior only.
Physical hardware, field latency, interoperability with the original Windows
peer, signing and distribution stay PARTIAL until each has its own measured
result.

VERDICT: PARTIAL
