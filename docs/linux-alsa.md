# Linux ALSA validation

The Rust adapter uses ALSA PCM directly through a system `libasound.so.2`. It
accepts canonical regular libraries owned by root without group or world write
permission from fixed system library directories, and it does not search
`LD_LIBRARY_PATH`, build directories, or the working directory.

Only direct `hw` devices are accepted. ALSA `default` and `plughw` can invoke the
plug layer and transform formats, so they cannot satisfy exact native
negotiation. See the
[ALSA PCM interface](https://www.alsa-project.org/alsa-doc/alsa-lib/pcm.html).

## Deterministic checks

Run on any software test host:

```bash
cargo test -p rusty-lola --no-default-features audio::alsa
```

The substitute API exercises format coercion rejection, partial I/O, EAGAIN, xrun
recovery, finite wait budgets, cancellation, and input/output direction
ownership. Capture uses preallocated storage, and no-ready reads publish no PCM.
The API exposes xrun counts separately from successful media observations.
Session reports include `audio_device_xruns`; uninstrumented backends report
null. Inventory visits at most 4,096 hints over two seconds and bounds each
native metadata string read to 4 KiB. ALSA itself owns and frees its hint list.

## Virtual-device case on Ubuntu 24.04

On a disposable Linux test machine with `snd-aloop` available, load that module
under the machine's normal administration policy. Inventory then includes direct
loopback PCM identifiers. Use the paired subdevices reported by ALSA (one
playback side feeds the opposite capture side), choose a common rate, channels,
sample format, and exact period, and run:

```bash
cargo run -p rusty-lola --no-default-features -- devices
cargo test -p rusty-lola --no-default-features --test linux_native -- --ignored --nocapture
```

The integration test reads `OPEN_LOLA_ALSA_CAPTURE` and `OPEN_LOLA_ALSA_PLAYBACK`
for these explicitly selected `hw` identifiers. It opens the native adapter,
writes and captures bounded quanta, cancels, and stops. Missing variables are a
test failure when explicitly invoked. The virtual loopback demonstrates ALSA
software integration, not physical latency.

## Physical follow-up

Record kernel, ALSA, firmware, device identity, and selected mode outside the
repository. Confirm exact parameters with an independent ALSA inventory, then run
duplex capture/playback and compare an injected signal at the physical output.
Exercise unplug, unavailable or busy devices, unsupported rates and periods,
underrun recovery, repeated start/stop, and stop during capture. Record xrun and
drop counters and elapsed cancellation time. Compare a hardware loopback with an
external reference clock before making any latency claim.
