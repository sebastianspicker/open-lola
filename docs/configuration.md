# Configuration

The two runtimes are configured separately. There is no shared runtime
configuration file and no `.env` file.

## macOS app and CLI

The SwiftUI app stores operator choices in `UserDefaults`. The keys are defined
in `runtimes/macos/Sources/OpenLolaAppSupport/AppStorageKeys.swift`. They cover
execution mode, peer addresses and ports, device and media choices, output and
report paths, SSH/SCP settings, and connector settings. The app loads them at
launch, and applying a settings draft replaces the in-memory values.

If a stored value fails validation, only that field resets to its default. The
main window shows a "Stored settings were reset" banner naming each reset
field. The whole group resets only when the bad field cannot be isolated.

The app also stores the local audio and video device selections and the
imported remote inventory. If a stored device identifier is missing from the
refreshed local inventory (or the stored remote inventory), the app drops it
and names it in the inventory warning or settings banner.

**Options → Appearance** selects System, Light, or Dark for the app windows. It
is stored under `openLola.appearance` and does not affect session settings.

The `open-lola` CLI takes its configuration from command arguments. It treats
output and report paths as trusted: it creates parent directories and
atomically replaces the output file. Plans, reports, packet captures, logs, and
proof bundles may contain operational data, so store them outside the
repository unless they are sanitized fixtures meant for version control.

Remote execution mode accepts SSH/SCP executables, host names, working
directories, and artifact paths. It runs commands on the selected hosts and
copies selected files back. Check every value, and use dedicated low-privilege
accounts on trusted hosts.

Set `OPEN_LOLA_DISABLE_APPKIT_PREVIEW=1` for a direct-peer session run to
replace the AppKit preview window with a headless sink for received video.
Synthetic-fixture runs use the sink automatically. It validates and counts every
frame but keeps only the newest four, so memory stays bounded on long runs.
There is no on-screen preview. The variable is read at session start and does
not affect audio or what is sent.

Debug builds (`swift build`, `.build/debug/open-lola`, which the app uses by
default) route the Core Audio IO-proc calls through test hooks. The hooks call
the real `AudioDevice*` and property functions unless a unit test replaces
them, so a debug binary behaves like a release binary on the wire. It is only
slower because it is unoptimized. Use a release build for latency or CPU
measurements.

## Rust station

The Rust station applies values in this order, lowest precedence first:

1. built-in defaults;
2. `--settings` file;
3. `--session` profile;
4. CLI arguments.

`station --settings <path>` creates a default settings file if the path does not
exist; `connect` and `listen` reject a missing `--settings` file. The session
file extension selects its format: JSON uses the Open LoLa profile format, and
`.ssn` accepts tagged Open LoLa JSON or the documented subset of Windows LastSsn
INI fields. `session-profile --out <path>.ssn` writes tagged Open LoLa JSON,
never a proprietary Windows session file.

Camera-mode catalogs live in `runtimes/rust-station/data/camera_modes/` and
apply to XIMEA only. On Linux, device names and FOURCC values are settings
(`audio.input_device`, `audio.output_device`, `video.device`, and
`video.pixel_format`) with ALSA/V4L2 defaults; see
[Linux migration](linux-migration.md). On Windows,
`video.backend: "mediafoundation"` (CLI `--camera-backend mediafoundation` or
`mf`) captures from USB/UVC webcams. `video.device` names the camera, and
`video.width`, `video.height`, and `video.fps` must match one of its modes
exactly. See the [Rust station README](../runtimes/rust-station/README.md).

On Windows, native libraries load only from direct children of fixed
installation directories, after resolving the canonical path:
`C:\Windows\System32`, its `Npcap` subdirectory,
`C:\Program Files\XIMEA\API\xiAPI`, and `C:\Program Files\Open LoLa\portaudio`.
The running executable's own directory is searched last, for known library file
names only, and is refused on a UNC or network path. Media Foundation loads from
System32 only. These rules apply to the top-level DLL; its imports resolve from
that DLL's directory (`LOAD_LIBRARY_SEARCH_DLL_LOAD_DIR`) and System32. There is
no lookup by bare name, `PATH`, other folders next to the executable, build
directories, or archives. Diagnostic copying uses the same source rules and does
not add its destination to the search path. The loader does not check
signatures or digests.

Settings and profile reads are capped at 1 MiB and read from one opened regular
file. Writes go to a temporary file in the same directory, which then atomically
replaces the target; on Unix the file is created with mode 0600. On Windows,
directory ACLs control file privacy.

For controlled Npcap diagnostics, `RUSTY_LOLA_LOCAL_MAC` and
`RUSTY_LOLA_PEER_MAC` override MAC-address resolution. They affect only the
process they are set in and must contain literal MAC addresses. Use normal UDP
for routed peers.

## Build and gate variables

Repository scripts read these environment variables:

| Variable | Purpose |
|---|---|
| `DEVELOPER_DIR` | Select the Xcode installation used by Swift commands. |
| `OPEN_LOLA_SWIFT_BUILD_PATH` | External Swift scratch path for the Makefile Swift targets, `make verify`/`make verify-full` (passed through to the release-readiness script) and the macOS bundle helper. Defaults to the shared `/private/tmp/open-lola-swiftpm-build`; set it per checkout when several checkouts build at once. |
| `SWIFT_BUILD_PATH` | Deprecated alias of `OPEN_LOLA_SWIFT_BUILD_PATH`, used only when the canonical name is unset; the Makefile and scripts print a deprecation warning. |
| `OPEN_LOLA_APP_DIST_DIR` | External output directory for the local ad-hoc app bundle. |
| `OPEN_LOLA_RELEASE_CANDIDATE` | Make release hygiene verify a specific exported source candidate. |
| `OPEN_LOLA_ALLOW_DIRTY_INSPECTION` | Allow an inspection export from a dirty tree; the export cannot be published. |
| `OPEN_LOLA_SKIP_INTERACTIVE_APP` | Set to `1` to skip the graphical launch probe on a headless machine. `make verify` sets it; `make verify-full` clears it. Every active skip prints a `SKIPPED:` line. |
| `OPEN_LOLA_SKIP_LIVE_RESIDUE` | Set to `1` to skip the raw-checkout residue inspection. `make verify` sets it because the raw checkout is not a release candidate; `make verify-full` clears it. Prints a `SKIPPED:` line. |
| `OPEN_LOLA_TEST_OPEN_LOLA_CLI` | Point the release-readiness CLI probes at another `open-lola` binary instead of the freshly built one. Prints a warning when set; results then describe that binary, not this checkout. |
| `OPEN_LOLA_RELEASE_HYGIENE_LIVE_ROOT` | Scan another directory for generated residue instead of the checkout. Prints a warning when set; a pass then says nothing about this checkout. |

The last two are for debugging only. A run that sets them does not count as
release evidence.
