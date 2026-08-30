# Architecture

Open LoLa configures, runs, and verifies bounded low-latency audiovisual
sessions. The stable product loop is:

1. an operator selects local devices, peers, routes, and a latency profile;
2. the runtime validates capabilities and negotiates a session;
3. media adapters capture and encode frames;
4. transports packetize, send, receive, and reassemble them;
5. output adapters play or display accepted frames; and
6. evidence components report observed behavior without promoting it beyond
   its source, synthetic, localhost, hardware, or peer evidence class.

## Runtime boundaries

The repository is one product with three runtime implementations. They do not
import each other:

- `runtimes/macos` is the primary operator runtime, implemented as a SwiftPM
  modular application;
- `runtimes/rust-station` is a Windows-first station with cross-platform
  software fallbacks;
- `runtimes/linux-compat-connector` is a Python LoLa compatibility and
  research connector, not a complete native Linux media engine.

`interop/lola2` is the cross-runtime protocol authority. It contains evidence
and fixtures rather than a hidden fourth runtime. `third_party` is an upstream
vendor boundary. Product logic must not be placed there.

## macOS ownership

SwiftPM targets are real boundaries. `OpenLolaCore` contains exactly one
`Facade.swift` re-exporting lower targets; implementation directories do not
remain under that target. The target dependencies are:

```text
SessionDomain       -> Contracts
EvidenceModels      -> Contracts
Transport           -> Contracts, SessionDomain, EvidenceModels
MediaPlatform       -> Contracts, SessionDomain, EvidenceModels, Transport, C bridges
Application         -> Contracts, SessionDomain, EvidenceModels, Transport, MediaPlatform, C bridges
Core (facade)       -> Application and all lower Swift targets
AppSupport          -> Core, COpenLolaAtomics
```

`OpenLolaSessionDomain` owns framework-free session policy and depends only on
`OpenLolaContracts`. `OpenLolaEvidenceModels` owns reports and validators and
also depends only on contracts. `OpenLolaTransport` owns sockets, packet
movement, process/network diagnostics, and transport policy. `OpenLolaMediaPlatform`
owns audio/video devices, codecs, and platform media adapters. `OpenLolaApplication`
composes all lower targets and C bridges; it never imports `OpenLolaCore`.
`OpenLolaAppSupport` owns SwiftUI presentation and depends on the facade plus
atomics. Executable targets compose these boundaries.

The intended direction is application/UI -> orchestration -> session and media
policy -> transport/integration/platform side effects. Session-domain code is
framework- and side-effect-free; transport may use Darwin and process/socket
APIs but may not import UI or media frameworks. The boundary checker enforces
the target DAG, import allowlists, facade shape, parser placement, and these
semantic placement rules without coupling architecture to a file count.

## Linux ownership

The package separates protocol/media values, orchestration, backend ports,
socket/process adapters, receive coordination, and CLI composition. The public
`connector.py` facade delegates to explicit lifecycle, control-exchange,
receive, socket-I/O, and media-receiver services. Retired helper names are not
import contracts. The wheel contract test builds and installs a clean wheel,
includes only runtime packages, excludes tests/deployment/tools, and runs the
installed CLI self-test without source-tree imports.

WSL deployment helpers live under
`runtimes/linux-compat-connector/linux_connector/deployment/wsl`.

## External interfaces

Intentional contracts are SwiftPM product/module names, executable and Python
CLI behavior, terminal verdict lines, report/persistence formats, Rust package
and settings formats, and documented LoLa wire constants and corpus. Internal
files, private symbols, and helper module paths may change freely.

Side effects happen at explicit device, socket, process, filesystem, UI, and
codec adapters. Validators consume captured facts; they do not manufacture
field claims. Any migration adapter must live at an external boundary, name its
removal horizon, and never become the new internal dependency direction.

## Adding code

Put each concept in its owning runtime and domain. Add shared code only for a
shared concept, not similar syntax. Prefer concrete types until a second real
implementation needs a boundary. Keep public APIs small, test stable behavior,
and extend `tools/verify_architecture.py` only for rules important enough to
fail CI.
