# Benchmark methodology

Status: active measurement and verdict contract
Verdict: PARTIAL

A benchmark is evidence only when it identifies the revision, system under
test, configuration, route, collection method, thresholds, and result. Report
models do not substitute for measurements.

This document states the measurement contract first, then records two
2026-09-06 optimization audits and the native Linux migration measurements.
Treat it as a historical record: the values describe the named runs and are not
current product claims.

## Evidence Labels

| Evidence | Label |
|---|---|
| Report schema and verdict vocabulary | `original open-lola design` |
| Named hardware/route acceptance thresholds | `experimentally derived requirement` |
| Synthetic report or fixture | `original open-lola design` and `synthetic` evidence only |

## Required identity

Record the source revision, timestamp, host/platform/toolchain, hardware and
driver/firmware identity, peer identity/class, route and capture points, sample
rate, frames, channels, media/codec format, MTU, latency/RX profile, run
duration, and any fallback. Preserve raw evidence outside the repository when
it contains sensitive or unclear material.

## Required measurements

For audio and network paths, record one-way estimate and/or round trip, jitter
p50/p95/p99/max, packet age/loss/late behavior, underruns/overruns, missed
deadlines, PLC or concealment, drift, queue/buffer occupancy, callback timing,
CPU, resident memory, and realtime warnings.

For video, add capture interval/age, encode/decode time where applicable,
fragment/reassembly completeness, presentation age, frame drops, stream
selection, CPU/memory, and an audio-active comparison. For OSC, sACN, Art-Net,
or fixture control, add cue-to-output timing, destination/universe identity,
capture evidence, and an audio-active comparison.

## Test matrices

Use only rows needed for the claim:

- local device or socket loopback for code-path diagnosis;
- two-machine direct peer for physical route evidence;
- audio-only baseline;
- audio plus video;
- audio plus control/lighting;
- full integrated stream set;
- relevant channel counts, codecs, RX modes, and sustained durations; and
- before/after rows on identical hardware and route for tuning claims.

Non-comparable rows must be excluded explicitly rather than averaged together.
DSCP, PTP, AVB, switch features, or clock sources are evidence only when
observed on the tested route.

## Verdicts

- `PASS`: every required observation and threshold for the stated scope is
  present and passes.
- `FAIL`: required evidence exists and violates the stated threshold or
  invariant.
- `PARTIAL`: source/report shape exists but required measurement, identity, or
  external evidence is missing.

Synthetic fixtures can validate report shape and validators. Localhost can
validate process and socket behavior. Neither closes physical device, route,
reference-peer, security, signing, or distribution claims.

The budget model is in [latency-budget.md](latency-budget.md), and profile
policy is in [latency-profiles.md](latency-profiles.md).


## Reproducible optimization comparisons

Capture the working tree before editing a measured path, including untracked
first-party files and existing changes. Record the commit and a SHA-256
manifest of those source bytes; a commit alone does not identify a dirty
checkout. Keep snapshots, raw samples, profiles, and build products outside
the checkout. Use the same generated inputs, toolchain, optimization level,
warmup, repetition count, and deterministic seed for both revisions.

Report median, nearest-rank p95, standard deviation, minimum and maximum,
plus allocation counts, bytes copied, work counts, and peak resident memory
where the measurement method supports them. State unavailable measurements
explicitly. Process peak memory includes the test harness and runtime; it is
not a per-operation allocation measurement. Record overlapping builds or
other competing load, and treat contaminated timing comparisons as diagnostic.

The optimization matrix includes audio channel counts 2, 8, 32, and 64 where
supported by the runtime, small and 1920-by-1080 video frames, and ordered and
reordered fragments through the supported fragment limit. Do not extend a
runtime's negotiated channel or packet limits to satisfy a benchmark. Include
empty and rejected receive polls as well as successful traffic.

Correctness suites enforce packet bytes, numerical parity, bounded work,
queue capacity, buffer ownership, and cancellation. Wall-clock thresholds do
not gate shared CI. Retain an optimization when comparable measurements or a
deterministic reduction in work supports it; record a rejected approach and
its reason. Synthetic timings do not establish field or hardware latency.

Historical measurement: the retired Python audio-drain harness ran the real
coordinator against a finite socket double. It recorded payload hashes, final
sequence and counters, observed yields, maximum reads between yields, timings, a
separate tracemalloc peak, and separately profiled decode, parse, and reassembly
call counts. It covered 1, 2, and 8 channels at 16 bits with 1, 64, and 257
datagrams; the negotiated callback-size limit excluded larger 16-bit blocks.

The benchmark command retired with the Python connector, so the measurements
below describe the historical implementation. They include event-loop and
harness setup and are a fairness and allocation comparison, not an estimate of
physical audio latency. `PYTHONPATH` could select an external before-edit
snapshot's connector tree for the baseline. Compare input and output hashes
before interpreting the timing samples.

For build-cache evaluation, use a new external scratch directory for the cold
build and repeat the identical command against that directory for warm builds:

```bash
export DEVELOPER_DIR=/Applications/Xcode-26.6.0.app/Contents/Developer
export CARGO_TARGET_DIR="$(mktemp -d /private/tmp/open-lola-cargo-bench.XXXXXX)"
export SWIFT_BUILD_PATH="$(mktemp -d /private/tmp/open-lola-swift-bench.XXXXXX)"
/usr/bin/time -lp cargo build --workspace --release
/usr/bin/time -lp cargo build --workspace --release
/usr/bin/time -lp make swift-build
/usr/bin/time -lp make swift-build
```

These `time` flags are for macOS; on Linux use `/usr/bin/time -v`. Warm build
reuse measures local incremental compilation, not GitHub cache transfer cost
or hit rate. The routine Python jobs reuse setup-uv dependency caching. Any
additional Rust or Swift CI cache needs its own restore/save-size and timing
evidence before adoption.

## Optimization audit, 2026-09-06

The baseline was a dirty working-tree snapshot of 1,728 source and supporting
files, not just its parent commit. Its SHA-256 manifest fingerprint was
`1d1a674764368d80acfee5d1d490bf0b8ae1c0e1f3e5ea75b27f56cb8a9a80af`,
with the nearest retained source state at public-history milestone
`1f5c9f304e4446805bdeecae7ea503489ce368db`.
Runs used Darwin arm64, Xcode 26.6, Swift 6.3.3, Rust/Cargo 1.96.0,
uv 0.10.7, and Python 3.14.7. Python correctness was also checked on 3.11.14.
The pinned Python 3.14.6 was unavailable to the installed uv catalog and
could not be provisioned for this run. No pin was changed.
Raw samples, source manifests, harness copies, and logs remain external to the
checkout. The smoke reports' fixed fixture timestamp is not the execution date.

### Candidate dispositions

| Candidate | Disposition and deterministic evidence |
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

Rejected approaches include:

- pooling MADI output Data that callers may retain;
- replacing the Swift receive API beyond scratch reuse;
- imposing raw PCM fragment validation on unrelated codecs or MADI receive
  admission; and
- adding Rust or Swift CI caches without restore/save measurements.

A HashSet for Rust fragment membership was replaced by the bounded bitset
because its metadata cost was unnecessary. Repeating prepared-plan validation on
every Swift fragment was also removed from the prepared session path.

Performance regression tests assert bytes, buffer ownership and reuse,
fragment limits, duplicate/overlap precedence, congestion counters, cancellation,
and bounded cooperative work. They do not assert timing thresholds. The
reviewed duplication inventory was reconciled for maximal-clone regrouping in
unchanged files and normalized standard-library imports in the benchmark tool;
line, complexity, and duplication detector settings were preserved.

### Audio measurements

Python uses seed 20260906, five warmups and 31 measured repetitions. These rows
are 257-datagram bursts. Times are microseconds; SD is population standard
deviation. All nine workloads, including 1- and 64-datagram bursts, had equal
input hashes, PCM hashes, final sequences, and complete receive counters.

| Channels | Median before / after | p95 before / after | SD before / after | Tracemalloc peak bytes before / after |
|---|---|---|---|---|
| 1 | 1740.208 / 621.959 | 2398.958 / 656.459 | 237.061 / 18.210 | 17327 / 17189 |
| 2 | 1809.250 / 643.584 | 3585.625 / 664.583 | 1501.962 / 21.988 | 17711 / 17487 |
| 8 | 2044.542 / 674.458 | 5226.584 / 715.250 | 1161.382 / 13.916 | 20015 / 19791 |

For a 257-datagram burst, uninterrupted reads fell from 257 to 64, heartbeat
opportunities rose from zero to four, and media/audio/reassembly call counts
changed from 258/258/1 to 257/257/0. Process peak RSS was 37,076,992 versus
36,798,464 bytes. Baseline timing variance was substantial; bounded work and
identical outputs are the stronger evidence.

The Swift packetization benchmark uses seed 14921, 50 warmup iterations,
11 samples, and 1,000 iterations per sample at two channels or 400 at 64.
Both use float32, 32 frames, and MTU 1200. The prepared and public APIs ran in the same final binary to reduce cross-build timing confounds.



| Channels and API | Median us | p95 us | SD us |
|---|---|---|---|
| 2, baseline public | 7.959 | 8.353 | 0.422 |
| 2, final public | 4.307 | 4.762 | 0.189 |
| 2, final prepared | 4.188 | 4.306 | 0.060 |
| 64, baseline public | 54.336 | 60.840 | 2.154 |
| 64, final public | 30.971 | 31.441 | 0.167 |
| 64, final prepared | 30.659 | 30.891 | 0.191 |

The baseline/final public timing shift indicates that cross-run conditions
matter. Retention rests on eliminated repeated planning and exact packet
parity; the same-binary prepared advantage is small. The baseline snapshot's
harness calls only the public API. Timing runs use Swift's debug configuration.

MADI measurements run `open-lola madi-rx-synthetic-smoke` once for warmup and
11 more times. It produces all five channel counts with float32, 32 frames,
and 48 kHz. Run the built CLI at `$SWIFT_BUILD_PATH/debug/open-lola` and keep
each stdout report outside the checkout. The measured field includes receive
and depacketization as well as mixing; it does not isolate the mix kernel.

| Channels | Median us before / after | p95 us before / after | SD us before / after |
|---|---|---|---|
| 2 | 93.750 / 82.334 | 119.500 / 87.500 | 9.052 / 4.189 |
| 8 | 61.125 / 40.458 | 70.958 / 42.917 | 3.121 / 0.948 |
| 16 | 112.208 / 74.958 | 127.208 / 80.292 | 4.671 / 2.174 |
| 32 | 206.834 / 129.291 | 234.416 / 132.667 | 9.656 / 3.178 |
| 64 | 393.333 / 231.250 | 501.375 / 242.500 | 31.803 / 6.348 |

Each report has matching input/output byte counts and zero allocation warnings.
Those fields are neither byte-for-byte payload proof nor a complete allocator
profile. Independent int16/float32 tests check numerical bytes, routing,
clipping, pan, mute, revisions, and retention of prior output. Swift allocator
counts and per-operation peak memory were not measured.

### Rust measurements

The release-mode reassembly/eager-packetization harness uses seed
`0x4c4f4c4132303236`, 15 measured repetitions, three warmups for ordinary
reassembly/video, and two for maximum-fragment reassembly. The same harness
source runs against both source snapshots. The same harness source ran against both source snapshots.



Each ordinary reassembly sample processes three 1-MiB frames with 768 fragments;
each maximum-fragment sample processes one frame of 16,384 one-byte fragments.
Times below are milliseconds per sample. Allocations are totals across all
measured samples, including reassembler setup and parsed-fragment ownership.

| Workload | Median before / after | p95 before / after | SD before / after | Allocation calls before / after | Allocated bytes before / after |
|---|---|---|---|---|---|
| 768, ordered | 1.901 / 0.818 | 2.971 / 0.954 | 0.314 / 0.152 | 40500 / 40455 | 101166120 / 98141040 |
| 768, shuffled | 2.889 / 0.672 | 3.899 / 0.762 | 0.566 / 0.045 | 39195 / 39150 | 100373760 / 97286040 |
| 16384, ordered | 315.887 / 2.609 | 360.154 / 3.126 | 14.319 / 0.216 | 286741 / 286726 | 48551952 / 26957832 |
| 16384, shuffled | 312.669 / 3.147 | 338.768 / 3.642 | 8.383 / 0.224 | 278536 / 278521 | 43570152 / 21582192 |

The compatibility eager helper was also measured at 64-by-64 BGRA and full-HD
Mono8/BGRA. Its allocation counts and bytes were exactly unchanged, as expected.
Its timing changes do not demonstrate session streaming savings. Whole-harness
peak RSS was 45,596,672 before and 43,483,136 bytes after. Raw samples retain
minimum, maximum, standard deviation, coefficient of variation, allocation and
deallocation counts; the host was not reserved against unrelated background
load. Deterministic neighbor bounds and copy reductions support retention.

The session cursor has a separate same-binary comparison against the retained
eager helper. It uses constant 0x5a full-HD BGRA input, three warmups, and
15 samples of one frame each.



| Path | Median ms | p95 ms | SD ms | Allocation calls | Allocated bytes |
|---|---|---|---|---|---|
| Eager helper | 0.786 | 0.982 | 0.065 | 91081 | 256206300 |
| Streaming cursor | 0.413 | 0.465 | 0.023 | 31 | 124437240 |

Both paths emitted 8,494,716 wire bytes per frame. Allocation totals cover
15 frames and harness overhead; independent packet tests compare actual bytes,
including packet-size clamping and the shared compatibility corpus. This
comparison excludes capture, codec, socket, and presentation time. The
separate removal of validation-only serialization is an additional deterministic
copy reduction, not included in these cursor timings.

### Build measurements and scope

For `make -n test-swift lint`, Swift test invocations fell from two to one and
build invocations remained one. Each of the six interpreter-independent CI
quality steps now runs once instead of three times. Release-readiness remains
independently complete, and `make verify` includes both Rust feature variants.

The Swift baseline cold run had ModuleCache/concurrent-load contamination;
the purported warm baseline rebuilt and cannot be compared as a no-op build.
The final cold/warm observations were 53.42/1.45 seconds. Rust's baseline and
final cold builds also overlapped other work; no cross-version cache saving is
claimed. Local incremental reuse alone does not justify further CI caches.

The final `make verify` completed with source-gate verdict pass and product
runtime verdict partial. Architecture fixtures, documentation checks, quality
fixtures, Ruff, strict mypy, workflow/web/shell/PowerShell checks, Python tests
and loopback self-test, both Rust feature variants, strict Clippy, and Swift
build/tests passed. Default and CLI-only Rust help output matched; headless UI
succeeded in both variants and disabled interactive UI returned the rebuild
instruction. Opt-in timing benchmarks were run separately from correctness
gates.

Windows/Npcap execution, physical media devices, reference peers, field latency,
signing, notarization, and distribution remain outside this local proof.
Interactive native-app launch and exported-candidate residue checks were not
run by the headless local gate.

VERDICT: PARTIAL

## Follow-up optimization matrix, 2026-09-06

This follow-up starts from the actual dirty tree left by the preceding audit:
1,734 tracked or untracked files, nearest retained public-history milestone
`1f5c9f304e4446805bdeecae7ea503489ce368db`, and SHA-256 manifest fingerprint
`78739cf802099c349345769db2a495fd185d3be5b27ae17e32ee27fa183c3c0b`.
The snapshot, original harness bytes, harness overlays, raw samples, source
hashes, toolchain records, and verification logs are held outside the checkout.
Harness overlays add parity tests and the same measurement configuration to
both versions; runtime sources in the baseline remain unchanged.

The available toolchains were Xcode 26.6 / Swift 6.3.3, stable Rust/Cargo
1.96.0, uv 0.10.7, and Python 3.14.7 on Darwin arm64. Python 3.14.6 was not
available; its pin was preserved. Baseline architecture, Python, Swift, both
Rust feature configurations, and lint passed. A preview test using a debug-only
injection hook is now compiled under the same condition as that hook; the
normal debug gate continues to run it.

New timing workloads use five complete warmup samples and 31 measured samples.
Percentiles use nearest rank; with 31 samples p99 is the maximum and has little
tail resolution. Raw samples accompany median, p95, p99, population standard
deviation, and range. Memory runs are separate from timing. Traced peaks and
process RSS are different quantities; neither is a literal byte-copy counter.
Static copy counts describe identified operations and are labeled separately.
Concurrent compilation and other host load are recorded with affected runs;
those timings cannot establish a hardware or scheduling guarantee.

### Historical measurement setup

Use external directories for the Python environment, caches, Swift scratch
space, Cargo target directory, and all outputs. The opt-in benchmarks do not
participate in correctness timing gates. The historical Python media benchmark
selected the captured baseline with `--source-root` and repeated against the
candidate tree with the same interpreter. That command retired with the
connector, so its recorded results remain historical comparisons.

The historical measurements used isolated Swift and Rust workloads with external output files.



The resampling fixtures compare exact Float bit patterns across 192 irregular
chunks, retained outputs, partial input frames, and reset at 2/8/64 channels,
with equal rates and both 44.1/48 kHz directions. The playout workload splits
4,096-frame input bursts into 32-frame output blocks; it isolates accumulation
and conversion using an in-process target, not a physical callback.

### Npcap reporting cadence

The prior snapshot-only description did not match the implementation:
`receive_kind` also queried kernel statistics after each poll. Receive polling
now updates software counters only. A fallible terminal report snapshot and
finalization refresh the kernel counters, with the final cached result copied
into the report before the transport is released. Refresh failures remain
visible and do not remove transport fields from the partial report. Fake
capture tests establish query counts and lifecycle behavior; actual Npcap call
cost and Windows driver behavior require native measurements.

### CI cache decision

No additional CI cache is enabled by this follow-up. The latest completed
routine run inspected was GitHub Actions run `33325140399`, at the parent
commit on 2026-08-30. Its Windows Rust steps took 78 seconds for Clippy,
74 seconds for tests, and 185 seconds for release compilation. Linux Rust
Clippy/tests took 57/62 seconds; the Swift test step took 90 seconds, including
80.32 seconds reported for its build. These are step observations from one
older workflow run, not distributions for the dirty-tree workflow.

That run has no comparable Rust/Swift cache restore/save transfer timings or
sizes. It also predates the existing local workflow changes. Local incremental
reuse cannot supply the missing network-cache evidence, so the additional
cache candidate remains blocked by unavailable CI measurements. All existing
required jobs and platform coverage are preserved.

### FIFO candidate decision

The standalone linear resampler's head-index candidate was rejected. In the
reverse-order confirmation, two-channel 44.1-to-48 kHz conversion rose from
31.334 to 35.167 microseconds per 48-block sample, and 48-to-44.1 kHz rose from
28.166 to 31.291 microseconds. The first comparison also regressed those
workloads. Higher-channel results varied by run and did not justify accepting
a regression in the common two-channel path. The original resampler remains,
with the new exact-bit-pattern fixtures and release benchmark retained. The
rejected implementation and both raw comparisons are preserved externally.

The decoded playout accumulator is a separate retained candidate. It consumes
complete blocks by advancing a head index, clears fully consumed storage, and
compacts an incomplete tail only after at least 4,096 consumed samples and a
consumed prefix at least half the storage. Output arrays and Data remain
independently owned. In the 4,096-frame burst workload, the old accumulator
shifted `32 * channels * (127 * 128 / 2)` Float elements per burst; the new
accumulator shifts none when the burst is completely consumed. This is a
source-derived work count, not an allocator observation. Output block creation
and conversion still occur and are included in the measurements.

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
times below are milliseconds per frame. Columns show baseline / candidate; SD
is population standard deviation. The formal baseline overlapped compilation
and its late RGB/RGBA runs were heavily contended. These distributions describe
the observed run; their ratios are not stable speedup estimates.

| Geometry / format | Median | p95 | p99 | SD |
|---|---|---|---|---|
| 640x480 Mono8 | 50.300 / 0.752 | 52.349 / 0.794 | 52.671 / 0.800 | 0.740 / 0.036 |
| 640x480 RGB | 372.035 / 0.522 | 473.591 / 0.579 | 494.789 / 0.605 | 46.528 / 0.032 |
| 640x480 RGBA | 288.261 / 0.737 | 310.516 / 8.483 | 354.472 / 8.748 | 13.064 / 2.738 |
| 1920x1080 Mono8 | 344.208 / 2.770 | 353.336 / 3.045 | 431.095 / 3.049 | 15.883 / 0.336 |
| 1920x1080 RGB | 1936.463 / 1.319 | 3051.488 / 1.348 | 5170.130 / 1.367 | 608.399 / 0.020 |
| 1920x1080 RGBA | 1962.678 / 1.255 | 2531.817 / 1.333 | 3288.232 / 1.387 | 272.239 / 0.037 |

The cache retains one static frame per capture, at most 8,294,400 pixel bytes
for the tested RGBA geometry. Cold and warm traced peaks and process RSS are
reported separately, including this memory tradeoff. Warm heartbeat maximum-gap
medians were 1.09–1.67 milliseconds in the candidate; this is an event-loop
probe with a 1-millisecond heartbeat, not physical audio latency.

Initial whole-harness assembly timings appeared slower for smaller frames.
Repeating assembly alone with interleaved baseline/candidate runs resolved that
signal: all six workloads and both orders improved, with median reductions of
21.4–29.6%. Separate traced transient peaks fell approximately 7.2–8 times.
Both initial and repeated results remain in the evidence set; no size-dependent
dispatch or unverified copy counter was introduced.

### Swift release measurements

The following measurements use microseconds per operation. The receive rows
compare external source snapshots; send rows compare eager and prepared paths
in the same candidate binary. Raw reports retain all 31 samples and workload
seeds. These exclude physical capture, network transit, and rendering.

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

The cursor also has separate one-datagram, stalled-consumer, and backpressure
supersession workloads. Swift reports source-derived work counts; per-operation allocator counts were
not instrumented: the parser drops temporary arrays/serialization,
reassembly owns one destination per deadline, and senders reuse datagram storage.
RSS observations include the SwiftPM/test harness and are not per-operation
allocation counts. Synthetic packet timings do not establish network deadlines.

### Rust release measurements

Audio rows process 8,192 operations; JPEG rows process 16 frames. Timings are
microseconds per sample. Allocation measurements use separate passes with
counting disabled during timing; internal writer/ring measurements exclude
initial storage preparation. Baseline and candidate packet/JPEG byte lengths
and checksums match, with exact byte comparisons in the correctness suites.

| Workload | Median before / after | p95 before / after | p99 before / after | Allocated bytes before / after |
|---|---|---|---|---|
| Public audio builder | 1056.208 / 295.209 | 1380.583 / 306.792 | 1381.833 / 314.291 | 13524992 / 8732672 |
| Caller-buffered synthetic capture | 1445.083 / 1358.750 | 1551.375 / 1373.584 | 1589.959 / 1376.667 | 2097152 / 256 |
| RGB JPEG | 41239.000 / 37658.208 | 41613.375 / 38325.084 | 41614.708 / 38767.375 | 21555504 / 10496304 |
| Grayscale frame JPEG | 35906.958 / 32438.417 | 36472.750 / 32954.958 | 38347.750 / 33182.250 | 27371904 / 16312704 |

The public owned capture wrapper still allocates one block and had a repeated
median of 1,492.083 microseconds versus 1,445.083 in the baseline, within the
baseline range and variability. The production caller-buffered path avoids
those repeated allocations. Internal audio writing and callback-ring transfer
each performed 8,192 operations with zero steady-state allocations.

Preview polling uses a pre-published 96x96 RGB frame. Both changed-token and
unchanged-token reads allocated zero bytes; the old two-owned-copy oracle
allocated 452,984,832 bytes in 16,384 allocations over 8,192 reads. This measures
snapshot preparation and reuse, not publication, image conversion, or GPU upload.
The GUI generation gate is correctness-tested, including rapid session changes.

The bounded 50-microsecond wait reduced the median poll count from 4,968 to
7 for a synthetic 500-microsecond deadline, but moved median completion from
500.083 to 559.375 microseconds. Production yield polling remains unchanged.
Native callback cancellation/deadline behavior and CPU cost need physical
PortAudio/ASIO measurements before adopting a different waiting policy.

### Playout and verification

Final playout burst measurements use the original resampler and the retained
head-index accumulator. Each sample is eight 4,096-frame inputs split into
32-frame output blocks. Times are microseconds per sample.

| Channels | Median before / after | p95 before / after | p99 before / after | SD before / after |
|---|---|---|---|---|
| 2 | 296.625 / 154.583 | 316.459 / 169.167 | 322.292 / 169.583 | 7.370 / 6.144 |
| 8 | 833.209 / 220.000 | 840.833 / 228.375 | 851.792 / 241.375 | 4.493 / 4.113 |
| 64 | 8544.625 / 920.750 | 8649.084 / 945.083 | 8871.042 / 969.583 | 79.062 / 13.630 |

Process peak RSS for these equivalent playout harnesses was 77,578,240 bytes
before and 77,529,088 after. This includes SwiftPM and the test runner; it
does not measure the accumulator allocation in isolation. Other Swift datagram
RSS probes ran different workload sets and are excluded from memory comparisons.

Final architecture, Swift build/tests, Python Ruff/mypy/tests/self-test, both
Rust feature configurations, strict Clippy, repository quality, shell, workflow,
web, and PowerShell checks passed. The complete `make verify` exited zero with
`source-gate-verdict: pass` and `product-runtime-verdict: partial`. The final
Swift suite contained 54 tests and the Python suite contained 81 tests.
Documentation, source-documentation, and whitespace checks passed.

The duplication inventory was reconciled only for normalized import/declaration
prefixes and maximal-clone regrouping in unchanged files. Line, complexity,
and duplication thresholds were preserved. The independent ownership review
found and verified fixes for cross-session preview generations, send error
precedence, lock-wait exclusion from packetization metrics, and final cleanup
error reporting.

Windows/Npcap execution, ASIO and physical media devices, reference peers,
interactive GPU rendering, signing, notarization, and distribution remain
unverified. No CI cache was added, no production wait policy was changed, and
no dependency version was upgraded.

## Native Linux migration measurements

The [2026-09-08 verification record](linux-migration-verification.md) records
sustained session, allocation, and timing observations after the Linux
migration, including the shared-host contention that limits timing acceptance.
