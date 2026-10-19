# Benchmark methodology

A benchmark result counts only if it names the revision, system under test,
configuration, route, collection method, thresholds and result. A report model
is not a measurement.

The first half of this page is the method. The second half records two
optimization rounds from 2026-09-06; those numbers describe the named runs only.
Unless stated otherwise, the recorded runs exclude physical capture, network
transit and rendering, kept raw data outside the checkout, and say nothing about
hardware or field latency.

## Evidence Labels

| Evidence | Label |
|---|---|
| Report schema and verdict vocabulary | `original open-lola design` |
| Named hardware/route acceptance thresholds | `experimentally derived requirement` |
| Synthetic report or fixture | `original open-lola design` and `synthetic` evidence only |

## Required identity

Record the source revision, timestamp, host, platform and toolchain, hardware
and driver/firmware, peer identity or class, route and capture points, sample
rate, frames, channels, media/codec format, MTU, latency/RX profile, run
duration and any fallback. Keep raw evidence outside the repository if it
contains sensitive or unclear material.

## Required measurements

Audio and network paths: one-way estimate and/or round trip, jitter
p50/p95/p99/max, packet age, loss and lateness, underruns and overruns, missed
deadlines, PLC or concealment, drift, queue and buffer occupancy, callback
timing, CPU, resident memory and realtime warnings.

Video adds capture interval and age, encode/decode time where it applies,
fragment reassembly completeness, presentation age, frame drops, stream
selection, CPU/memory and a comparison with audio running. OSC, sACN, Art-Net
and fixture control add cue-to-output timing, destination or universe identity,
capture evidence and a comparison with audio running.

## Test matrices

Use only the rows the claim needs:

- local device or socket loopback, to diagnose code paths;
- two machines as direct peers, for physical route evidence;
- audio only as a baseline;
- audio plus video;
- audio plus control/lighting;
- the full integrated stream set;
- the relevant channel counts, codecs, RX modes and sustained durations;
- before/after rows on identical hardware and route, for tuning claims.

Exclude rows that are not comparable; do not average them together. DSCP, PTP,
AVB, switch features and clock sources count only if observed on the tested
route.

## Verdicts

- `PASS`: every required observation and threshold for the stated scope is
  present and passes.
- `FAIL`: the required evidence exists and violates a threshold or invariant.
- `PARTIAL`: the code or report shape exists, but a required measurement,
  identity or external result is missing.

Synthetic fixtures can validate report shape and validators. Localhost runs can
validate process and socket behavior. Neither settles device, route or
reference-peer claims.

See [latency-budget.md](latency-budget.md) for the budget model,
[latency-profiles.md](latency-profiles.md) for profiles, and
[testing.md](testing.md) for test commands.

## E2E aggregate measurement sources

`e2e-benchmark-run` copies each field from a measured input or leaves it nil
("not measured"). A nil gating field blocks PASS and is named in the notes.

`direct-p2p-session-run` (audio-only and audio-video) records these optional
report blocks:

- `resources`: CPU p50/p99/max and peak resident memory of the peer process.
  A utility-QoS timer samples every 250 ms, never on an audio thread. CPU is
  the `getrusage` user+system delta over the wall delta times active cores
  (0–100 % of the machine). Memory is `MACH_TASK_BASIC_INFO` resident size,
  in MiB. Up to 4,096 samples are kept for percentiles; max and peak cover the
  whole run. The newest sample also fills the CPU and memory fields of the
  peer metrics messages, so the remote values in the report are real.
- `host`: machine model (`sysctl hw.model`), chip (`machdep.cpu.brand_string`)
  and macOS version of the peer. It carries no host name, user name, serial
  number or address.
- `mediaTraffic`: UDP payload bytes sent and received on the audio and video
  transports, the wall duration, and reordered and duplicate packets. A packet
  is reordered when its sequence number is below the highest seen on its
  stream and it is not a duplicate. It is a duplicate when that number already
  arrived within a 256-packet bitmap window. AES67 RTP audio carries no
  transport sequence number, so with `--audio-transport aes67-st2110-l24` both
  order counters stay nil.

Pass the session reports to `e2e-benchmark-run` with `--source-session <path>`
and `--receiver-session <path>`, both optional. With them, the direct profile
rows get:

- throughput: the busiest one-way rate, bytes × 8 ÷ duration, in Mbit/s;
- reordered and duplicate packets: summed over the sessions, and nil unless
  every session counted them;
- CPU p99 and resident memory: the maximum across the sessions and the other
  inputs.

The WAN row keeps throughput and packet order nil. The receiver session's
`host` block fills the receiver-peer model, chip and OS version. The source
session's `host` replaces the source-peer values from the other inputs.
Receiver-peer fields stay `unknown` without a receiver session report, or with
one written before `host` existed. Without session reports the output is
unchanged.

Nothing yet measures GPU load, impairment (no link injector; dummynet needs
root), reconnect timing (no reconnect drill), receive-to-render latency, cue
timing or WAN. Those fields stay nil, so an aggregate run cannot reach PASS.

## Reproducible optimization comparisons

Before editing a measured path, snapshot the working tree, including untracked
first-party files and uncommitted changes. Record the commit and a SHA-256
manifest of those files; a commit alone does not identify a dirty checkout.
Keep snapshots, raw samples, profiles and build products outside the checkout.
Use the same generated inputs, toolchain, optimization level, warmup,
repetition count and seed for both revisions.

Report median, nearest-rank p95, standard deviation, minimum and maximum. Where
the method allows, add allocation counts, bytes copied, work counts and peak
resident memory, and say which were not measured. Process peak memory includes
the harness and runtime, so it is not a per-operation figure. Treat timings
from a host with overlapping builds or other load as diagnostic only.

Cover audio at 2, 8, 32 and 64 channels where the runtime supports them, small
and 1920-by-1080 video frames, and ordered and reordered fragments up to the
fragment limit. Do not raise a runtime's negotiated channel or packet limits
for a benchmark. Include empty and rejected receive polls.

Correctness suites check packet bytes, numerical parity, bounded work, queue
capacity, buffer ownership and cancellation. Wall-clock thresholds do not gate
shared CI. Keep an optimization when comparable measurements or a
deterministic reduction in work support it; record rejected approaches with the
reason.

To measure build caching, use a new external scratch directory for the cold
build, then repeat the same command against it for warm builds:

```bash
export DEVELOPER_DIR=/Applications/Xcode-26.6.0.app/Contents/Developer
export CARGO_TARGET_DIR="$(mktemp -d /private/tmp/open-lola-cargo-bench.XXXXXX)"
export SWIFT_BUILD_PATH="$(mktemp -d /private/tmp/open-lola-swift-bench.XXXXXX)"
/usr/bin/time -lp cargo build --workspace --release
/usr/bin/time -lp cargo build --workspace --release
/usr/bin/time -lp make swift-build
/usr/bin/time -lp make swift-build
```

These `time` flags are for macOS; on Linux use `/usr/bin/time -v`. A warm build
measures local incremental compilation, not GitHub cache transfer cost or hit
rate. The routine Python jobs use setup-uv dependency caching. Any further Rust
or Swift CI cache needs its own restore/save size and timing measurements first.

## Optimization audit, 2026-09-06

The baseline was a dirty working-tree snapshot of 1,728 files, SHA-256 manifest
fingerprint
`1d1a674764368d80acfee5d1d490bf0b8ae1c0e1f3e5ea75b27f56cb8a9a80af`,
parent commit `4add2df44cfd8cade3106e3a8f734a105059f288`.
Runs used Darwin arm64, Xcode 26.6, Swift 6.3.3, Rust/Cargo 1.96.0,
uv 0.10.7 and Python 3.14.7 (the pinned 3.14.6 was unavailable); Python
correctness was also checked on 3.11.14.

### Candidates

| Candidate | Outcome and evidence |
|---|---|
| 1. Rust reassembly | Retained offset-ordered interval lookup and fragment-index membership. At most two neighboring intervals are examined per insertion; assembly no longer sorts fragment payloads. Membership uses a bounded bitset, at most 2,048 bytes per maximum-size fragment set. |
| 2. Rust UDP receive | Retained one 65,535-byte receive scratch buffer under the receive lock. Empty and rejected media polls do not allocate receive storage or copy rejected payloads. Media sockets become nonblocking once; control timeout behavior is preserved. |
| 3. Rust video transmit | Retained separate validation and one serialized frame with metadata, cursor, and datagram scratch. Session transmission avoids eager per-fragment payload copies and discarded validation serialization. Public eager helpers remain compatible. |
| 4. Swift audio fragment plans | Retained immutable plans for raw PCM session modes. Plan validation runs once per session mode, preserving supplied fragment order. Public arbitrary-mode calls keep their validation contract; Opus and RTP retain their own paths. |
| 5. Swift preview | Retained one source slot, one prepared-image slot, and at most one scheduled delivery. Congestion replaces superseded images and records each drop once. Closure clears both slots and prevents subsequent presentation. |
| 6. Swift MADI mixing | Retained route offsets and format execution metadata prepared with the immutable mix snapshot. Route order, Double arithmetic, per-route rounding/clipping, pan, mute, and revisions are covered by numerical regression tests. Returned Data remains independently owned. |
| 7. Python audio draining | Retained batches of at most 64 datagrams and the newest validated candidate across yields. Publication still occurs at WouldBlock. The winning decoded audio is reused without another parse/reassembly pass. |
| 8. CI and local build work | Retained one shared quality job instead of three matrix copies, interpreter-specific tests/type checks, cancellation of superseded routine runs, pinned setup-uv caching, and shared Swift prerequisites. Required job identities and native Windows coverage remain; CodeQL keeps its extraction build. |
| Additional: Npcap | Retained borrowed capture parsing and accepted-payload copying. UDP checksum validation uses stack metadata and borrowed bytes. The snapshot-only statistics cadence previously stated for this row was inaccurate; the follow-up below separates receive polling from explicit refreshes. |
| Additional: optional Rust GUI | Retained default-enabled gui feature. CLI-only builds keep the ui command and headless controller; interactive invocation explains how to rebuild with gui. |
| Additional: Swift video receive | Retained receive/peek scratch buffers through the existing buffered socket API. Real-loopback tests cover truncation recovery, malformed packets, ownership, and repeated buffer identity/capacity. |
| Additional: duplicate history | Retained a 256-slot circular history with set membership and in-place dictionary mutation. Eviction no longer shifts 255 entries; wraparound and duplicate behavior remain covered. |
| Python dead helpers | Removed only message_ip and loopback_alias_capability after checking imports, exports, registration, tests, docs, and invocation contracts. The separate Rust symbol remains. |

Rejected:

- pooling MADI output Data that callers may retain;
- replacing the Swift receive API beyond scratch reuse;
- applying raw PCM fragment validation to unrelated codecs or to MADI receive
  admission;
- adding Rust or Swift CI caches without restore/save measurements.

Performance regression tests check bytes, buffer ownership and reuse, fragment
limits, duplicate/overlap precedence, congestion counters, cancellation and
bounded cooperative work, but not timing.

### Audio measurements

Python (retired connector): the harness ran the real coordinator against a
finite socket double at 16 bits with 1, 2 and 8 channels and 1, 64 and 257
datagrams; the callback-size limit ruled out larger blocks. Timings include
event-loop and harness setup. Seed 20260906, five warmups, 31 measured
repetitions. The rows are 257-datagram bursts. Times are microseconds; SD is
population standard deviation. All nine workloads had equal input hashes, PCM
hashes, final sequences and complete receive counters.

| Channels | Median before / after | p95 before / after | SD before / after | Tracemalloc peak bytes before / after |
|---|---|---|---|---|
| 1 | 1740.208 / 621.959 | 2398.958 / 656.459 | 237.061 / 18.210 | 17327 / 17189 |
| 2 | 1809.250 / 643.584 | 3585.625 / 664.583 | 1501.962 / 21.988 | 17711 / 17487 |
| 8 | 2044.542 / 674.458 | 5226.584 / 715.250 | 1161.382 / 13.916 | 20015 / 19791 |

For a 257-datagram burst, uninterrupted reads fell from 257 to 64, heartbeat
opportunities rose from zero to four, and media/audio/reassembly call counts
went from 258/258/1 to 257/257/0. Process peak RSS was 37,076,992 versus
36,798,464 bytes. Baseline timings varied widely, so the bounded work and
identical outputs are the stronger evidence.

Swift packetization: seed 14921, 50 warmup iterations, 11 samples, and 1,000
iterations per sample at two channels or 400 at 64, all float32, 32 frames and
MTU 1200, in Swift's debug configuration. Prepared and public APIs ran in the
same binary. The benchmark (`packetizationOptimizationBenchmark`,
`OPEN_LOLA_PACKETIZATION_BENCHMARK_OUTPUT`) is not in this repository; a rerun
needs the harness restored from the original snapshot.

| Channels and API | Median us | p95 us | SD us |
|---|---|---|---|
| 2, baseline public | 7.959 | 8.353 | 0.422 |
| 2, final public | 4.307 | 4.762 | 0.189 |
| 2, final prepared | 4.188 | 4.306 | 0.060 |
| 64, baseline public | 54.336 | 60.840 | 2.154 |
| 64, final public | 30.971 | 31.441 | 0.167 |
| 64, final prepared | 30.659 | 30.891 | 0.191 |

The shift between baseline and final public timings shows that run conditions
matter. The change was kept because it removes repeated planning and keeps
packets identical; the prepared API's advantage is small.

MADI: run `open-lola madi-rx-synthetic-smoke` once for warmup and 11 more
times, using the built CLI at `$SWIFT_BUILD_PATH/debug/open-lola`. It covers all
five channel counts with float32, 32 frames and 48 kHz. The timing includes
receive and depacketization, not just the mix kernel.

| Channels | Median us before / after | p95 us before / after | SD us before / after |
|---|---|---|---|
| 2 | 93.750 / 82.334 | 119.500 / 87.500 | 9.052 / 4.189 |
| 8 | 61.125 / 40.458 | 70.958 / 42.917 | 3.121 / 0.948 |
| 16 | 112.208 / 74.958 | 127.208 / 80.292 | 4.671 / 2.174 |
| 32 | 206.834 / 129.291 | 234.416 / 132.667 | 9.656 / 3.178 |
| 64 | 393.333 / 231.250 | 501.375 / 242.500 | 31.803 / 6.348 |

Each report had matching input/output byte counts and zero allocation warnings,
which is neither proof of identical payloads nor an allocator profile. Separate
int16/float32 tests check numerical bytes, routing, clipping, pan, mute and
revisions. Swift allocator counts and per-operation peak memory were not
measured.

### Rust measurements

The release-mode reassembly and eager-packetization harness used seed
`0x4c4f4c4132303236`, 15 measured repetitions, three warmups for ordinary
reassembly and video, and two for maximum-fragment reassembly. The harness
(`tests/optimization_benchmark.rs`, test `rust_hot_path_benchmarks`) is not in
this repository.

Each ordinary reassembly sample processes three 1-MiB frames with 768
fragments; each maximum-fragment sample one frame of 16,384 one-byte fragments.
Times are milliseconds per sample. Allocations are totals across all measured
samples, including reassembler setup and parsed-fragment ownership.

| Workload | Median before / after | p95 before / after | SD before / after | Allocation calls before / after | Allocated bytes before / after |
|---|---|---|---|---|---|
| 768, ordered | 1.901 / 0.818 | 2.971 / 0.954 | 0.314 / 0.152 | 40500 / 40455 | 101166120 / 98141040 |
| 768, shuffled | 2.889 / 0.672 | 3.899 / 0.762 | 0.566 / 0.045 | 39195 / 39150 | 100373760 / 97286040 |
| 16384, ordered | 315.887 / 2.609 | 360.154 / 3.126 | 14.319 / 0.216 | 286741 / 286726 | 48551952 / 26957832 |
| 16384, shuffled | 312.669 / 3.147 | 338.768 / 3.642 | 8.383 / 0.224 | 278536 / 278521 | 43570152 / 21582192 |

The eager helper was also measured at 64-by-64 BGRA and full-HD Mono8/BGRA; its
allocation counts and bytes were unchanged, as expected. Whole-harness peak RSS
was 45,596,672 bytes before and 43,483,136 after. The host was not isolated
from background load, so the change rests on the deterministic neighbor bounds
and copy reductions.

The session cursor was compared against the eager helper in the same binary,
with constant 0x5a full-HD BGRA input, three warmups and 15 samples of one
frame each:

```bash
cargo test --release \
  streaming_cursor_reuses_storage_against_previous_eager_path \
  -- --ignored --nocapture --test-threads=1 \
  > /private/tmp/open-lola-streaming-benchmark.log
```

| Path | Median ms | p95 ms | SD ms | Allocation calls | Allocated bytes |
|---|---|---|---|---|---|
| Eager helper | 0.786 | 0.982 | 0.065 | 91081 | 256206300 |
| Streaming cursor | 0.413 | 0.465 | 0.023 | 31 | 124437240 |

Both paths emitted 8,494,716 wire bytes per frame. Allocation totals cover 15
frames plus harness overhead. Codec and socket time are excluded.

### Build measurements

For `make -n test-swift lint`, Swift test invocations fell from two to one and
build invocations stayed at one. Each of the six interpreter-independent CI
quality steps now runs once instead of three times.

The Swift baseline cold build was contaminated by ModuleCache and concurrent
load, and the warm baseline rebuilt, so neither is comparable. The final
cold/warm builds took 53.42/1.45 seconds. Rust cold builds also overlapped other
work, so no cache saving is claimed.

The final headless `make verify` passed the source gate with product runtime
verdict partial. Windows/Npcap, physical devices, reference peers, signing and
distribution were not covered.

## Follow-up optimization matrix, 2026-09-06

The follow-up started from the tree the first audit left: 1,734 files, parent
commit `4add2df44cfd8cade3106e3a8f734a105059f288`, SHA-256 manifest fingerprint
`78739cf802099c349345769db2a495fd185d3be5b27ae17e32ee27fa183c3c0b`, same
toolchains. Harness overlays added parity tests and identical measurement
settings to both versions without changing baseline runtime sources.

Timing workloads use five warmup samples and 31 measured samples. Percentiles
are nearest-rank, so p99 is the maximum and says little about the tail. Memory
runs are separate from timing runs. Traced peaks and process RSS measure
different things, and neither counts copied bytes.

### Reproduction

The Swift benchmark tests and the `optimization_benchmark`,
`audio_optimization_benchmark` and `jpeg_optimization_benchmark` Rust
integration tests that produced the figures below are not in this repository.
Their `--filter` names and the `OPEN_LOLA_*_BENCHMARK_OUTPUT`,
`RUSTY_LOLA_AUDIO_BENCHMARK_OUTPUT` and `RUSTY_LOLA_JPEG_BENCHMARK_OUTPUT`
variables do nothing here.

The opt-in Rust benchmarks that are in the repository are ignored library
tests. The output variables name external files. Run them by hand, away from
other load:

```bash
RUSTY_LOLA_INTERNAL_AUDIO_BENCHMARK_OUTPUT="$EVIDENCE_DIR/audio-writer.json" \
  cargo test --release --lib reusable_audio_writer_has_zero_steady_state_allocations \
  -- --ignored --nocapture --test-threads=1
RUSTY_LOLA_CALLBACK_BENCHMARK_OUTPUT="$EVIDENCE_DIR/callback.json" \
  cargo test --release --lib callback_ring_has_zero_steady_state_allocations \
  -- --ignored --nocapture --test-threads=1
RUSTY_LOLA_PREVIEW_BENCHMARK_OUTPUT="$EVIDENCE_DIR/preview.json" \
  cargo test --release --lib preview_generation_benchmark \
  -- --ignored --nocapture --test-threads=1
```

The resampling fixtures compare exact Float bit patterns across 192 irregular
chunks, retained outputs, partial input frames and reset, at 2/8/64 channels,
with equal rates and both 44.1/48 kHz directions. The playout workload splits
4,096-frame input bursts into 32-frame output blocks. It measures accumulation
and conversion against an in-process target, not a physical callback.

### Npcap statistics

`receive_kind` used to query kernel statistics after every poll. Receive
polling now updates only software counters. A fallible terminal report snapshot
and finalization refresh the kernel counters, and the last cached result goes
into the report before the transport is released. Refresh failures stay visible
and do not remove transport fields from a partial report. Fake-capture tests
check query counts and lifecycle; real Npcap cost needs native Windows
measurements.

### CI cache decision

No CI cache was added. The latest completed routine run checked was GitHub
Actions run `33325140399`, at the parent commit on 2026-08-30. Its Windows Rust
steps took 78 seconds for Clippy, 74 seconds for tests and 185 seconds for the
release build. Linux Rust Clippy/tests took 57/62 seconds. The Swift test step
took 90 seconds, 80.32 of them in the build. That run has no cache restore/save
timings or sizes, so the cache stays blocked until CI numbers exist.

### FIFO candidates

The head-index change to the standalone linear resampler was rejected. In the
reverse-order confirmation run, two-channel 44.1-to-48 kHz conversion rose from
31.334 to 35.167 microseconds per 48-block sample, and 48-to-44.1 kHz rose from
28.166 to 31.291 microseconds; the first comparison showed the same. The
original resampler stays, with the new exact-bit-pattern fixtures and release
benchmark.

The decoded playout accumulator change was kept. It consumes complete blocks by
advancing a head index, clears fully consumed storage, and compacts an
incomplete tail only after at least 4,096 consumed samples and when the
consumed prefix is at least half the storage. In the 4,096-frame burst
workload, the old accumulator shifted `32 * channels * (127 * 128 / 2)` Float
elements per burst; the new one shifts none when the burst is fully consumed.
That count comes from the code, not an allocator.

### Follow-up outcomes

| Item | Outcome and local evidence |
|---|---|
| 1. Python diagnostic video | Retained. Exact pixels, alpha, precedence, frame sequence, cache invalidation, concurrent reads, and cancellation agree with the baseline; generation yields in bounded row batches. |
| 2. Swift receive parsing | Retained. Borrowed Data parsing removes two temporary UInt8 arrays and one validation serialization in the measured nested PCM path. Public results remain owned; sliced and noncontiguous inputs and error ordering are tested. |
| 3. Swift raw-audio reassembly | Retained. One destination per deadline with bounded descriptor membership and eight pending deadlines; ordered/reordered 2/8/64-channel results agree with the public stateless oracle. |
| 4. Swift video transmission | Retained. Immutable prepared frames and lazy cursors replace session packet arrays. Byte parity, complete admission validation, cancellation, latest-frame replacement, backpressure, and drop counts are tested. |
| 5. Rust preview | Retained. Shared immutable pixels and process-unique generations avoid routine owned copies and unchanged-frame conversion. Cross-session invalidation and owned public preview boundaries are tested; actual texture upload remains a native GUI check. |
| 6. Rust Npcap statistics | Retained locally. Fake capture checks prove no per-poll kernel query, fallible terminal refreshes, final counter publication, and visible cleanup failures. Native Windows performance remains unverified. |
| 7. Audio allocation and waiting | Retained reusable Rust audio/capture buffers and Swift contiguous datagrams. The 50-microsecond wait experiment was rejected for production: fewer polls but later completion, without hardware deadline evidence. |
| 8. Remaining copies | Retained Python immutable fragment assembly, Swift playout accumulator indexing, and borrowed Rust JPEG views. The separate Swift resampler indexing candidate was rejected for two-channel regressions. |
| 9. Evidence and CI | Retained opt-in release benchmarks and parity checks. Additional CI caching remains blocked by missing restore/save measurements; existing jobs and platform coverage remain. |

### Python measurements

All six diagnostic frame and fragment-assembly hashes matched. Warm generation
times are milliseconds per frame, baseline / candidate. The baseline overlapped
compilation and its late RGB/RGBA runs were heavily contended, so the ratios are
not stable speedup estimates.

| Geometry / format | Median | p95 | p99 | SD |
|---|---|---|---|---|
| 640x480 Mono8 | 50.300 / 0.752 | 52.349 / 0.794 | 52.671 / 0.800 | 0.740 / 0.036 |
| 640x480 RGB | 372.035 / 0.522 | 473.591 / 0.579 | 494.789 / 0.605 | 46.528 / 0.032 |
| 640x480 RGBA | 288.261 / 0.737 | 310.516 / 8.483 | 354.472 / 8.748 | 13.064 / 2.738 |
| 1920x1080 Mono8 | 344.208 / 2.770 | 353.336 / 3.045 | 431.095 / 3.049 | 15.883 / 0.336 |
| 1920x1080 RGB | 1936.463 / 1.319 | 3051.488 / 1.348 | 5170.130 / 1.367 | 608.399 / 0.020 |
| 1920x1080 RGBA | 1962.678 / 1.255 | 2531.817 / 1.333 | 3288.232 / 1.387 | 272.239 / 0.037 |

The cache holds one static frame per capture, at most 8,294,400 pixel bytes for
the tested RGBA geometry. Warm heartbeat maximum-gap medians were 1.09–1.67
milliseconds in the candidate (an event-loop probe with a 1-millisecond
heartbeat).

In the first whole-harness run, assembly looked slower for smaller frames.
Rerunning assembly alone with baseline and candidate interleaved showed all six
workloads improving in both orders, with median reductions of 21.4–29.6% and
traced transient peaks about 7.2–8 times lower.

### Swift release measurements

Times are microseconds per operation. Receive rows compare source snapshots;
send rows compare the eager and prepared paths in the same candidate binary.

| Workload | Median before / after | p95 before / after | p99 before / after | SD before / after |
|---|---|---|---|---|
| Nested PCM parser | 2.221 / 0.611 | 2.441 / 0.807 | 2.495 / 1.009 | 0.108 / 0.103 |
| Reassembly 2ch ordered | 0.802 / 0.347 | 0.828 / 0.358 | 0.829 / 0.360 | 0.022 / 0.011 |
| Reassembly 2ch reordered | 0.756 / 0.316 | 0.757 / 0.359 | 0.766 / 0.444 | 0.005 / 0.029 |
| Audio datagrams 2ch | 3.315 / 2.801 | 3.695 / 3.123 | 3.699 / 3.125 | 0.197 / 0.139 |
| Reassembly 8ch ordered | 0.836 / 0.381 | 0.896 / 0.434 | 0.898 / 0.436 | 0.030 / 0.022 |
| Reassembly 8ch reordered | 0.831 / 0.453 | 0.854 / 0.633 | 0.858 / 0.713 | 0.007 / 0.086 |
| Audio datagrams 8ch | 3.308 / 2.671 | 3.755 / 2.962 | 3.759 / 2.971 | 0.218 / 0.113 |
| Reassembly 64ch ordered | 10.761 / 1.878 | 11.072 / 1.986 | 12.017 / 2.057 | 0.415 / 0.093 |
| Reassembly 64ch reordered | 10.757 / 1.786 | 11.206 / 1.922 | 11.219 / 1.922 | 0.229 / 0.098 |
| Audio datagrams 64ch | 24.845 / 20.848 | 28.247 / 24.488 | 28.423 / 24.541 | 1.274 / 2.051 |
| Video datagrams 320x180 | 766.333 / 543.639 | 907.805 / 588.139 | 927.653 / 588.153 | 76.487 / 21.219 |
| Video datagrams 1920x1080 | 26220.875 / 19661.209 | 28642.792 / 20772.375 | 28663.709 / 21069.458 | 1069.937 / 741.992 |

Per-operation allocator counts were not instrumented for Swift; the work
reductions come from the code: the parser drops its temporary arrays and
serialization, reassembly owns one destination per deadline, and senders reuse
datagram storage.

### Rust release measurements

Audio rows process 8,192 operations; JPEG rows process 16 frames. Times are
microseconds per sample. Allocations were measured in separate passes. Baseline
and candidate packet and JPEG byte lengths and checksums match.

| Workload | Median before / after | p95 before / after | p99 before / after | Allocated bytes before / after |
|---|---|---|---|---|
| Public audio builder | 1056.208 / 295.209 | 1380.583 / 306.792 | 1381.833 / 314.291 | 13524992 / 8732672 |
| Caller-buffered synthetic capture | 1445.083 / 1358.750 | 1551.375 / 1373.584 | 1589.959 / 1376.667 | 2097152 / 256 |
| RGB JPEG | 41239.000 / 37658.208 | 41613.375 / 38325.084 | 41614.708 / 38767.375 | 21555504 / 10496304 |
| Grayscale frame JPEG | 35906.958 / 32438.417 | 36472.750 / 32954.958 | 38347.750 / 33182.250 | 27371904 / 16312704 |

The public owned capture wrapper still allocates one block; its repeated median
was 1,492.083 microseconds against 1,445.083 in the baseline, within baseline
variability. The caller-buffered production path avoids those allocations.
Internal audio writing and callback-ring transfer each ran 8,192 operations with
zero steady-state allocations.

Preview polling of a pre-published 96x96 RGB frame allocated zero bytes for both
changed and unchanged tokens. The old two-copy path allocated 452,984,832 bytes
in 16,384 allocations over 8,192 reads. GPU upload is not included.

The bounded 50-microsecond wait cut the median poll count from 4,968 to 7 for a
synthetic 500-microsecond deadline, but moved median completion from 500.083 to
559.375 microseconds, so production yield polling is unchanged. Changing it
needs physical PortAudio/ASIO measurements first.

### Playout and verification

These runs use the original resampler and the new head-index accumulator. Each
sample is eight 4,096-frame inputs split into 32-frame output blocks. Times are
microseconds per sample.

| Channels | Median before / after | p95 before / after | p99 before / after | SD before / after |
|---|---|---|---|---|
| 2 | 296.625 / 154.583 | 316.459 / 169.167 | 322.292 / 169.583 | 7.370 / 6.144 |
| 8 | 833.209 / 220.000 | 840.833 / 228.375 | 851.792 / 241.375 | 4.493 / 4.113 |
| 64 | 8544.625 / 920.750 | 8649.084 / 945.083 | 8871.042 / 969.583 | 79.062 / 13.630 |

Process peak RSS for these harnesses was 77,578,240 bytes before and 77,529,088
after, including SwiftPM and the test runner.

The complete `make verify` exited zero with `source-gate-verdict: pass` and
`product-runtime-verdict: partial`. The final Swift suite had 54 tests and the
Python suite 81. Separate review found and fixed bugs in cross-session preview
generations, send error precedence, lock-wait time counted in packetization
metrics, and final cleanup error reporting. Windows/Npcap, ASIO, physical
devices, reference peers and GPU rendering remain unverified.

## Native Linux migration measurements

The [2026-09-08 verification record](linux-migration-verification.md) holds the
sustained session, allocation and timing measurements taken after the Linux
migration, including the shared-host contention that limits timing acceptance.

VERDICT: PARTIAL
