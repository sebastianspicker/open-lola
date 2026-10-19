# Known issues in the Open LoLa alpha

This is a source alpha. You build it from a checkout (see the README) and run
it on a trusted local network. This page lists what does not work yet, how to
work around it, and what to send us when something goes wrong.

## Before you start

- **This revision has not been tested on real hardware yet.** The build and
  the automated tests pass, but no one has yet run these exact steps on two
  physical Macs, on a Windows ASIO setup, or on a Linux camera and sound card.
  Expect rough edges, and please tell us about every step that does not work
  as written.
- **Results say "PARTIAL", not "PASS".** Every session report currently ends
  with the verdict PARTIAL, even when audio and video flowed correctly. That
  is expected: PASS is reserved for runs with measured reference evidence,
  which the alpha does not collect yet. Treat PARTIAL with a written report as
  a completed run, and look at the report's numbers and notes.

## macOS app and command line

- **The default video size may not exist on your camera.** The app now
  defaults to a small 160×90 picture so that it fits the network budget of the
  fastest profile. If your camera does not offer that size, the run stops with
  a message that lists the sizes your camera does offer. Pick one of those in
  Settings. The fastest profile fits pictures up to about 34,000 pixels (for
  example 192×144 or 240×135); the "balanced" profile fits up to about
  400×300; larger pictures need JPEG XS compression.
- **JPEG XS is not in the default build.** The JPEG XS code that Open LoLa
  uses is licensed for evaluation and testing only, so it is left out unless
  you build with `OPEN_LOLA_ENABLE_JPEG_XS=1` (see the README). In the default
  build, `--video-compression jpeg-xs` is refused with a message that says so,
  and the app rejects the JPEG XS setting. Use a picture size that fits the raw
  budget instead.
- **The app's default run uses both peers on this Mac.** It is meant as a first
  check that everything starts and stops. For a session between two Macs, use
  the command-line recipe in the guide "Running a session" (in the docs
  folder), where you run one command on each Mac.
- **Two-Mac runs supervised from one Mac only start on a directly connected
  network.** Before it starts, the app checks the connection to the other Mac.
  The check passes when the other Mac is on the same local network as this Mac
  (same subnet, answering pings without loss). If it is not, for example when it
  is behind a router or a VPN, the app does not start and lists the reasons.
  Connecting across the internet still needs network-route evidence that is
  difficult to produce; use the one-command-per-Mac recipe there.
- **Stop ends the run and restores audio device settings.** When you press
  Stop, the app asks both peers to stop. Each peer ends its media, puts the
  audio device settings back the way it found them, and writes its report with
  the note "stopped by signal" and the verdict PARTIAL. Peers started on
  another Mac over SSH are stopped the same way. A peer that has not finished
  within about two seconds is ended at once and then cannot undo its changes;
  if an audio interface sounds wrong afterwards, check its sample rate and
  buffer size in Audio MIDI Setup. A peer that is still waiting for the other
  Mac to connect writes no report when stopped; it has not changed any audio
  settings yet.
- **"Dry run" is the default for external connector sessions.** Unless you add
  `--dry-run false`, the connector command only shows what it would do and
  launches nothing. It now says so on screen.
- **External connectors can fall back to test signals.** If you do not name a
  real capture device, UltraGrid and JackTrip sessions send generated test
  audio or video. The command now prints a warning when this happens.
- **Some benchmark commands are incomplete.** Benchmark reports now leave
  values they could not measure empty instead of showing made-up numbers, so
  they will not reach PASS. Two synthetic benchmark commands (video transport
  and performance audit) can crash on start; they are not needed for sessions.

## Rust station (Windows and Linux)

- **Windows needs an ASIO driver and the PortAudio library.** Without an ASIO
  driver the station cannot open audio. Run `rusty-lola devices` to list
  devices; ASIO devices are marked. The station README says where to put the
  PortAudio DLL.
- **Linux devices must match exactly.** The camera and sound card must support
  the exact size, frame rate, and audio format that are configured. If they do
  not, the error message lists what the device offers and which option to
  change.
- **Tell `listen` who is calling.** On a LAN, start the listener with
  `--remote-ip <the other computer's address>`. Without it, the listener only
  accepts the same computer and gives up with a message saying which address
  it ignored.
- **Ctrl-C:** press it once to stop cleanly (the run's result is printed and a
  recording is finished). Pressing it twice exits immediately and can leave a
  recording incomplete. After an interruption the result may say "peer
  disconnected: session cancelled"; that wording is wrong and can be ignored.

## macOS together with the Rust station

- **They cannot run on the same computer.** Both use the same fixed network
  ports, so put the Mac and the station on two different machines.
- **Video between macOS and the Rust station is limited.** The Mac does not
  display received video from the station yet, and the two sides have
  different default video settings, so start with audio-only sessions.

## How to report a bug

1. Open a new issue with the **Bug report** template.
2. Fill in:
   - which part you ran (app, macOS command line, Rust station on Windows or
     Linux, or the station GUI);
   - the source revision: run `git rev-parse --short HEAD` in your checkout;
   - your OS version and tool versions (`swift --version`, `cargo --version`,
     `uv --version`, Xcode version) and the audio or video devices involved;
   - the exact commands or app steps, what you expected, and what happened.
3. Attach logs and reports from the failing run. The support guide (SUPPORT.md)
   lists where each part writes them. In short:
   - macOS app: the run logs in your Library caches folder for Open LoLa, and
     the plan, preflight, and supervisor reports in Application Support
     → OpenLoLa → MacToMac;
   - macOS command line: the file you passed to `--output`, plus the terminal
     output;
   - Rust station: run with `--report result.json` and attach that file and the
     terminal error output, plus the output of `rusty-lola devices`.
4. Remove host names, IP addresses, and device identifiers you do not want to
   publish before attaching anything.

Report suspected security problems privately as described in SECURITY.md,
never in a public issue.
