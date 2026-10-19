# Linux ALSA validation

The Rust station drives ALSA PCM directly through the system `libasound.so.2`.
It loads the library only from fixed system library directories, and only if
the file is a regular, root-owned library without group or world write
permission (checked after resolving its canonical path). It does not search
`LD_LIBRARY_PATH`, build directories, or the working directory.

Only direct `hw` devices are accepted. ALSA `default` and `plughw` can route
through the plug layer and convert formats, so they cannot guarantee the exact
native format. See the
[ALSA PCM interface](https://www.alsa-project.org/alsa-doc/alsa-lib/pcm.html).

## Choosing the ALSA device

With no device configured, the station opens `hw:0` at exactly 44.1 kHz, 2
channels, 16-bit and 64-frame periods. It does not negotiate another format.
List the direct devices with `rusty-lola devices` (`audio.devices`) or
`arecord -l` / `aplay -l`. Select one with `--input-device` / `--output-device`
on `connect`/`listen`, or with the settings keys `audio.input_device` /
`audio.output_device`, for example `hw:CARD=USB,DEV=0`. Set `sample_rate`,
`channels`, `bits_per_sample` and `buffer_samples` to values the hardware
supports natively. If opening fails, the error lists the `hw:` devices found.

## Tests without hardware

Run on any test host:

```bash
cargo test -p rusty-lola --no-default-features audio::alsa
```

These tests use a substitute ALSA API. They cover rejection of format
coercion, partial I/O, EAGAIN, xrun recovery, finite wait budgets,
cancellation, and which direction owns input and output. Capture uses
preallocated storage, and a read with no data ready publishes no PCM.

Xrun counts are kept apart from successful media counts. Session reports
include `audio_device_xruns`, which is null for backends that do not count
xruns. Inventory reads at most 4,096 device hints within two seconds and reads
at most 4 KiB of each metadata string. ALSA owns and frees its hint list.

## Virtual-device check on Ubuntu 24.04

On a disposable Linux test machine, load the `snd-aloop` module following that
machine's usual admin rules. The inventory then lists direct loopback PCM
identifiers. Use a paired set of subdevices as reported by ALSA (one playback
side feeds the opposite capture side), pick a common rate, channel count,
sample format, and period, and run:

```bash
cargo run -p rusty-lola --no-default-features -- devices
```

The repository has no automated native-ALSA integration test (no
`linux_native` test target and no `OPEN_LOLA_ALSA_CAPTURE` or
`OPEN_LOLA_ALSA_PLAYBACK` variables). Check by hand: set `audio.input_device`
and `audio.output_device` to the paired `hw` identifiers from the `devices`
output, start a short local session, and confirm that audio opens, runs, and
stops cleanly. A loopback run shows that the ALSA code works, not what latency
real hardware has.

## Physical hardware

Record the kernel, ALSA version, firmware, device identity, and selected mode
outside the repository. Confirm the exact parameters with an independent ALSA
inventory. Then:

1. Run duplex capture and playback and compare an injected signal at the
   physical output.
2. Test unplugging, unavailable or busy devices, unsupported rates and periods,
   underrun recovery, repeated start/stop, and stopping during capture.
3. Record xrun and drop counters and how long cancellation takes.

Before making any latency claim, compare a hardware loopback against an
external reference clock.
