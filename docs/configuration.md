# Configuration

The two runtimes have independent configuration systems. There is no shared
repository-wide runtime configuration file and no `.env` contract. This document
records where each runtime reads its inputs, how those inputs are ordered, and
which values cross a trust boundary.

## macOS app and CLI

The SwiftUI app persists operator choices in `UserDefaults`. Stable keys are
centralized in
`runtimes/macos/Sources/OpenLolaAppSupport/AppStorageKeys.swift` and cover execution
mode, peer addresses and ports, device and media choices, output and report
paths, SSH/SCP settings, and connector-specific settings. The app hydrates those
values at launch, and an applied settings draft replaces the corresponding
in-memory values.
A stored value that fails validation resets only that field to its default, and
the main window shows a "Stored settings were reset" banner naming each reset
field; the whole group resets only when the offending field cannot be isolated.
The local audio and video device selections and the operator-imported remote
inventory are persisted too. A stored device identifier that the refreshed local
inventory (or the stored remote inventory) no longer contains is dropped, and
the inventory warning or settings banner names it.

**Options → Appearance** selects System, Light, or Dark for the macOS application
windows. This presentation preference uses the additive `openLola.appearance`
key; it does not change a session configuration or authorize execution.

The `open-lola` CLI is configured by its command arguments. Output and report
paths are trusted operator inputs: the CLI can create parent directories and
atomically replace the selected output. Plans, reports, packet captures, logs,
and proof bundles may contain operational data, so store them outside the
repository unless they are sanitized fixtures intended for version control.

Remote execution mode accepts SSH/SCP executables, host names, working
directories, and artifact paths. It runs commands on the selected hosts and
retrieves selected files. Review every value and use dedicated, least-privilege
accounts on trusted hosts.

Setting `OPEN_LOLA_DISABLE_APPKIT_PREVIEW=1` in the environment of a direct-peer
session run replaces the AppKit preview window with a headless sink for received
video (also used automatically for synthetic-fixture runs). The sink validates and
counts every frame but keeps only the newest four, so memory stays bounded on long
runs; there is no on-screen preview. The variable is read at session start and has
no effect on audio or on what is sent.

Debug builds (`swift build`, `.build/debug/open-lola`, which the app resolves by
default) route the Core Audio IO-proc calls through test hooks. Those hooks default
to the real `AudioDevice*` and property calls and are replaced only by unit tests,
so a debug binary behaves like a release binary on the wire; it is only slower
because it is unoptimized. Use a release build for latency or CPU measurements.

## Rust station

The Rust station applies values in this order, from lowest to highest
precedence:

1. built-in defaults;
2. `--settings` file;
3. `--session` profile;
4. explicit CLI arguments.

`station --settings <path>` creates a default settings file when the path does
not exist, while `connect` and `listen` reject a missing `--settings` file.
Session input is selected by extension: JSON uses the Open LoLa profile format,
and `.ssn` accepts tagged Open LoLa JSON or the documented subset of Windows
LastSsn INI fields. `session-profile --out <path>.ssn` writes tagged Open LoLa
JSON, not a proprietary Windows session file.

Tracked camera-mode catalogs live in `runtimes/rust-station/data/camera_modes/`
and apply to XIMEA only. Linux device names and FOURCC values are explicit
settings (`audio.input_device`, `audio.output_device`, `video.device`, and
`video.pixel_format`) with ALSA/V4L2 defaults. See
[Linux migration](linux-migration.md). On Windows, XIMEA is not the only camera:
`video.backend: "mediafoundation"` (CLI `--camera-backend mediafoundation` or
`mf`) captures from USB/UVC webcams, with `video.device` naming the camera and
`video.width`, `video.height`, and `video.fps` matching one of its modes exactly.
See the [Rust station README](../runtimes/rust-station/README.md).

Windows native libraries load only from canonical direct children of fixed trusted
installation directories: `C:\Windows\System32`, its `Npcap` subdirectory,
`C:\Program Files\XIMEA\API\xiAPI`, and `C:\Program Files\Open LoLa\portaudio`,
then, searched last, the running executable's own directory (known library file
names only; refused on a UNC or network path). Media Foundation loads from
System32 only. The allowlist applies to the top-level DLL only; its imports resolve
from that DLL's directory (`LOAD_LIBRARY_SEARCH_DLL_LOAD_DIR`) and System32. No bare-name, PATH, other executable-adjacent,
build, or archive discovery occurs. Diagnostic copying applies the same source
policy and does not make its destination a runtime search path. The loader does
not establish signature or digest trust.

Settings and profile reads are limited to 1 MiB through one opened regular file.
Writes use a same-directory temporary file and atomic replacement, with a Unix
creation mode of 0600. On Windows, directory ACLs govern file privacy.

For controlled Npcap diagnostics, `RUSTY_LOLA_LOCAL_MAC` and
`RUSTY_LOLA_PEER_MAC` can override MAC-address resolution. These variables affect
only the process in which they are set and must contain explicit MAC addresses.
Prefer normal UDP for routed peers.

Full CLI details are in the
[Rust station README](../runtimes/rust-station/README.md).

## Build and gate variables

Repository scripts use a small set of documented environment variables:

| Variable | Purpose |
|---|---|
| `DEVELOPER_DIR` | Select the Xcode installation used by Swift commands. |
| `OPEN_LOLA_SWIFT_BUILD_PATH` | External Swift scratch path for the Makefile Swift targets, `make verify`/`make verify-full` (passed through to the release-readiness script) and the macOS bundle helper. Defaults to the shared `/private/tmp/open-lola-swiftpm-build`; set it per checkout when several checkouts build at once. |
| `SWIFT_BUILD_PATH` | Deprecated alias of `OPEN_LOLA_SWIFT_BUILD_PATH`, honored only when the canonical name is unset; the Makefile and scripts print a deprecation warning. |
| `OPEN_LOLA_APP_DIST_DIR` | Select an external output directory for the local ad-hoc app bundle. |
| `OPEN_LOLA_RELEASE_CANDIDATE` | Ask release hygiene to verify a specific exported source candidate. |
| `OPEN_LOLA_ALLOW_DIRTY_INSPECTION` | Permit a nonpublishable inspection export from a dirty tree. |
| `OPEN_LOLA_SKIP_INTERACTIVE_APP` | Set to `1` to skip the graphical launch probe in a declared headless environment. `make verify` sets it; `make verify-full` clears it. Every active skip prints a `SKIPPED:` line. |
| `OPEN_LOLA_SKIP_LIVE_RESIDUE` | Set to `1` to skip raw-checkout residue inspection. `make verify` sets it because the raw checkout is not a release candidate; `make verify-full` clears it. Prints a `SKIPPED:` line. |
| `OPEN_LOLA_TEST_OPEN_LOLA_CLI` | Redirect the release-readiness CLI probes to a caller-supplied `open-lola` binary instead of the freshly built one. Prints a warning when set; results then describe that binary, not this checkout. |
| `OPEN_LOLA_RELEASE_HYGIENE_LIVE_ROOT` | Redirect the live generated-residue scan to another directory instead of the checkout. Prints a warning when set; a pass then says nothing about this checkout. |

The last two are debugging redirects, not supported operator configuration, and
a run that sets them is not release evidence.
