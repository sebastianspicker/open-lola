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
[Linux migration](linux-migration.md).

Windows native libraries load only from canonical direct children of fixed
trusted installation directories: `C:\Windows\System32`, its `Npcap`
subdirectory, `C:\Program Files\XIMEA\API\xiAPI`, and
`C:\Program Files\Open LoLa\portaudio`. Dependent DLL lookup is restricted to the
selected DLL's directory and System32. No bare-name, PATH, executable-adjacent,
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

## Build and packaging variables

Repository scripts use a small set of documented environment variables:

| Variable | Purpose |
|---|---|
| `DEVELOPER_DIR` | Select the Xcode installation used by Swift commands. |
| `SWIFT_BUILD_PATH` | Override the Makefile's external Swift scratch path. |
| `OPEN_LOLA_SWIFT_BUILD_PATH` | Select an external scratch path for the macOS bundle helper. |
| `OPEN_LOLA_APP_DIST_DIR` | Select an external output directory for the local ad-hoc app bundle. |
| `OPEN_LOLA_RELEASE_CANDIDATE` | Ask release hygiene to verify a specific exported source candidate. |
| `OPEN_LOLA_ALLOW_DIRTY_INSPECTION` | Permit a nonpublishable inspection export from a dirty tree. |
