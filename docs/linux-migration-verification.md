# Native Linux migration verification

Date: 2026-09-08. Software checks passed. Execution on Linux and Windows hosts
with real devices, and stable timing results, are still outstanding.

The Rust station now runs Windows and native Linux sessions. This page lists
which software checks were run and what remains to be tested on devices, peers,
and desktops. For operator use, see
[migration and command replacements](linux-migration.md).

## Source and environment

The working tree's parent commit is `4add2df44cfd8cade3106e3a8f734a105059f288`.
An external manifest of 158 Rust source, Cargo, and interop files has SHA-256
`2c2dff0171a51390ef76dca7f3151b2cfbffbba00552061f0f4d4f46ebe972ca`. The last
change made the control-flood regression test deterministic by injecting a
fixed receive queue. The socket adapter and the 64-packet quantum did not
change, and the timing samples were taken before this test-only change.

Measurements ran on Darwin arm64 with Rust/Cargo 1.96.0, Xcode 26.6, Swift
6.3.3, and uv 0.10.7. Python tooling ran on 3.14.7 because the installed uv
catalog could not provide the pinned 3.14.6; the pin was left unchanged.

## Software checks

| Check | Result and scope |
|---|---|
| `make verify` | Passed with `UV_PYTHON=3.14.7`; `source-gate-verdict: pass`, `product-runtime-verdict: partial`. |
| Rust test configurations | 143 library tests passed with all features and 144 with CLI-only features; three integration tests passed in each. Integration tests cover all 25 shared vectors and 110 Python-generated control cases. |
| Strict Clippy | Passed for all targets and features on the host, Linux GNU, and Windows MSVC targets, including the unsafe-block and safety-documentation lints. |
| Native Linux code | Substitute-API tests cover format coercion, partial transfers, underruns, cancellation, failure ordering during start and stop, color conversion, inventory budgets, and malformed media recovery. Linux integration cases compile. |
| Linux builds | CLI and GUI x86_64 ELF executables linked against glibc 2.39 with cargo-zigbuild and Zig 0.13. These are development cross-builds. |
| Windows builds | CLI and GUI x86_64 PE executables (console subsystem) linked with an external Zig GNU-linker adapter; MSVC target checking also passed. These are development cross-builds. |
| Swift | Build and tests passed with warnings as errors; security regression tests cover bounded file and process reads and remote targets. |
| Rust controller | Tests passed for readiness, stale arming, asynchronous device discovery, stale inventory results, and measured/unmeasured audio health. |
| Web demo | Browser interactions passed for setup, loading, error and empty states, Arm/Start/Stop, recording, chat, preview, review, Escape key, light/dark appearance, and 320/390/1024/1440-pixel layouts. No browser errors appeared. |
| Architecture and quality | 902 first-party files passed the 600-line, CCN 19, and 70-token duplication limits. Documentation, source documentation, lint, tooling self-tests, and whitespace checks passed. |
| Retired Python connector | Before deletion, all 81 connector tests and its bidirectional selftest passed. Python no longer has a runtime package or distribution entry point. |

The duplication baseline dropped retired entries and regrouped ten clone groups
in unchanged Swift command files. A byte comparison, and an external inventory
with the Python source restored, showed that removing the corpus only regrouped
existing clones. Thresholds and checker behavior were not relaxed.

The external Windows linker adapter translates GNU driver flags that Zig does
not support and lets Zig supply its MinGW runtime and SEH unwinder. The
executable headers keep ASLR and NX. This shows that the code links, not that it
runs on Windows or works with its drivers. Normal Windows builds still use the
repository manifest.

## Sustained workload and timing

The sustained release harness runs three warm-ups and 31 one-second samples.
Each session uses:

- localhost UDP;
- 640×480 synthetic capture scaled to 160×120 RGB24 at 30 FPS;
- 44.1 kHz stereo 16-bit PCM in 64-frame blocks.

Both cadence comparison runs use CLI-only features. The allocator records calls
and live bytes; process CPU and RSS include every session thread. Queue-age and
lateness p95 values are fixed-bucket upper bounds, not exact percentiles or
hardware latency.

Two scheduler problems were found and fixed. A diagnostic relay that waited for
a full video frame let through only 31 audio blocks per sample in the first
workload; separate audio and video quanta removed that bottleneck. A separate
deterministic clock test showed drift, because each deadline was reset to the
delayed current time. The scheduler now keeps its phase, skips stale slots, and
never sends a catch-up burst.

Rows are medians, except the session elapsed p95 row.

| Metric | Before cadence fix | After cadence fix | Later contended repeat |
|---|---:|---:|---:|
| Session elapsed, ms | 1029.25 | 1031.05 | 1028.68 |
| Session elapsed p95, ms | 1057.16 | 1035.50 | 1072.35 |
| Audio blocks sent | 584 | 690 | 664 |
| Audio blocks received | 510 | 602 | 577 |
| Skipped audio clock slots | Not instrumented | 0 | 26 |
| CPU, percent of one core | 19.61 | 18.86 | 26.88 |
| Allocation calls | 11721 | 12274 | 12105 |
| Peak additional live bytes | 1546773 | 1530657 | 1568731 |
| Audio lateness p95 upper bound, µs | 2000 | 250 | 1000 |

The later run overlapped with unrelated Simulator and Node activity. On the same
host, timings also varied widely in audio and JPEG code that had not changed:
the software capture, audio packetization, and JPEG source files were
byte-identical to the earlier source snapshot. All samples were kept.
Regressions above five percent were investigated, but no stable timing result
was reached on this shared host. These rows do not show a general speedup or
anything about field latency.

After the Simulator workload ended, another 31-sample run gave, at the median,
690 sent blocks, 601 received blocks, zero skipped slots, 18.76 % CPU, and a
250 µs lateness p95 upper bound. Session elapsed median/p95 was
1030.58/1034.19 ms. RGB and grayscale JPEG medians returned to
38.89/32.79 ms, but capture and several tail timings still varied by more than
five percent. The timing result therefore stays inconclusive, and the
unfavorable runs are kept.

All four internal release benchmark checks passed:

- The audio writer, callback ring, and both preview-poll paths allocated zero
  bytes in steady state.
- Caller-buffered synthetic capture allocated one 256-byte buffer at the start
  over 8,192 operations.
- Streaming 1080p BGRA packetization produced the same 8,494,716 wire bytes
  with two allocations and 8,295,808 allocated bytes, against 6,072
  allocations and 17,080,412 bytes for the eager reference implementation.

The existing audio, JPEG, reassembly, and packetization workloads completed with
31 samples each; the raw results are stored outside the repository. Repeat them
on an otherwise idle host before comparing timings at the five-percent
threshold.

## Not yet run

- ALSA loopback and V4L2 virtual-device runs need a Linux test host. The cases
  and setup are in [ALSA](linux-alsa.md) and [V4L2](linux-v4l2.md).
  Cross-compiling does not replace them.
- The native macOS Session and Devices windows were inspected in light mode.
  Further inspection (the Rust window, dark and compact desktop states, and
  resizing) stopped when the inspection tool's connection to the desktop
  failed.
- Windows process execution, native media devices, Npcap, reference peers,
  field latency, signing, notarization, and distribution are untested. Physical
  validation follows the separate hardware procedures.
