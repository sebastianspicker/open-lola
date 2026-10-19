# Known issues in the Open LoLa alpha

This is a source alpha: you build it from a checkout (see the README) and run it
on a trusted local network. Below is what does not work yet, how to work around
it, and what to send us when something goes wrong.

## Before you start

- **This revision has not been tested on real hardware.** The build and the
  automated tests pass, but nobody has run these exact steps on two physical
  Macs, a Windows ASIO setup, or a Linux camera and sound card. Expect rough
  edges, and tell us about every step that does not work as written.
- **Results say PARTIAL, not PASS.** Every session report ends with the verdict
  PARTIAL, even when audio and video flowed correctly. PASS needs measured
  reference evidence, which the alpha does not collect yet. A PARTIAL result
  with a written report is a completed run; read its numbers and notes.

## macOS app and command line

- **Your camera may not offer the default video size.** The app defaults to
  160×90 so the picture fits the network budget of the fastest profile. If your
  camera lacks that size, the run stops and lists the sizes it does offer. Pick
  one of those in Settings. The fastest profile fits up to about 34,000 pixels
  (for example 192×144 or 240×135), the "balanced" profile up to about 400×300.
  Larger pictures need JPEG XS.
- **JPEG XS is not in the default build.** Its code is licensed for evaluation
  and testing only, so it is included only when you build with
  `OPEN_LOLA_ENABLE_JPEG_XS=1` (see the README). Otherwise
  `--video-compression jpeg-xs` and the app's JPEG XS setting are refused with
  a message saying so. Workaround: use a picture size that fits uncompressed.
- **The app's default run puts both peers on this Mac.** It only checks that
  everything starts and stops. Workaround: for a session between two Macs, use
  the command-line recipe in "Running a session" (in the docs folder), which
  runs one command on each Mac.
- **A two-Mac run supervised from one Mac needs a direct local network.** Before
  starting, the app checks that the other Mac is on the same subnet and answers
  pings without loss. If it is behind a router or a VPN, the app does not start
  and lists the reasons. Workaround: use the one-command-per-Mac recipe.
- **Stop may not restore audio settings if a peer is slow.** Stop asks both
  peers, including peers started over SSH, to end their media, restore their
  audio device settings, and write a report marked "stopped by signal" (verdict
  PARTIAL). A peer that has not finished within about two seconds is killed and
  cannot restore its settings. Workaround: if an interface sounds wrong
  afterwards, check its sample rate and buffer size in Audio MIDI Setup. A peer
  still waiting for the other Mac writes no report, but it has not changed any
  audio settings yet.
- **External connector sessions default to a dry run.** Without
  `--dry-run false`, the connector command only shows what it would do. It says
  so on screen.
- **External connectors can fall back to test signals.** If you do not name a
  real capture device, UltraGrid and JackTrip sessions send generated test audio
  or video, and the command prints a warning. Workaround: name the capture
  device.
- **Some benchmark commands are incomplete.** Benchmark reports leave values
  they could not measure empty, so they will not reach PASS. Two synthetic
  benchmark commands (video transport and performance audit) can crash on
  start. You do not need them for sessions.

## Rust station (Windows and Linux)

- **Windows needs an ASIO driver and the PortAudio library.** Without an ASIO
  driver the station cannot open audio. Run `rusty-lola devices` to list
  devices; ASIO devices are marked. The station README says where to put the
  PortAudio DLL.
- **Linux devices must match the settings exactly.** The camera and sound card
  must support the configured size, frame rate, and audio format. If not, the
  error lists what the device offers and which option to change.
- **`listen` ignores other computers unless you name the caller.** On a LAN,
  start the listener with `--remote-ip <the other computer's address>`. Without
  it, the listener accepts only the same computer and stops with a message
  naming the address it ignored.
- **Pressing Ctrl-C twice can cut off a recording.** Press it once to stop
  cleanly: the result is printed and any recording is finished. A second press
  exits at once. After an interruption the result may say "peer disconnected:
  session cancelled"; that wording is wrong and you can ignore it.

## macOS together with the Rust station

- **They cannot run on the same computer.** Both use the same fixed network
  ports. Workaround: run them on two machines.
- **Video between macOS and the Rust station is limited.** The Mac does not yet
  show video received from the station, and the two sides have different video
  defaults. Workaround: start with audio-only sessions.

## How to report a bug

1. Open a new issue with the **Bug report** template.
2. Fill in:
   - which part you ran (app, macOS command line, Rust station on Windows or
     Linux, or the station GUI);
   - the source revision: run `git rev-parse --short HEAD` in your checkout;
   - your OS version and tool versions (`swift --version`, `cargo --version`,
     `uv --version`, Xcode version) and the audio or video devices involved;
   - the exact commands or app steps, what you expected, and what happened.
3. Attach logs and reports from the failing run. SUPPORT.md lists where each
   part writes them. In short:
   - macOS app: the run logs in your Library caches folder for Open LoLa, and
     the plan, preflight, and supervisor reports in Application Support
     → OpenLoLa → MacToMac;
   - macOS command line: the file you passed to `--output`, plus the terminal
     output;
   - Rust station: run with `--report result.json` and attach that file, the
     terminal error output, and the output of `rusty-lola devices`.
4. Before attaching anything, remove hostnames, IP addresses, and device
   identifiers you do not want to publish.

Report suspected security problems privately as described in SECURITY.md,
never in a public issue.
