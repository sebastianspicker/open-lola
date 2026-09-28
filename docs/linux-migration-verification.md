# Native Linux migration verification

Status: source verification passed; platform execution and timing evidence partial
Date: 2026-09-08

The Rust station now owns Windows and native Linux sessions. This record
separates software checks from device, peer, and desktop execution evidence. See
[migration and command replacements](linux-migration.md) for operator use.

## Source and environment

The working tree has parent commit `4add2df44cfd8cade3106e3a8f734a105059f288`.
The external manifest of 158 Rust source, Cargo, and interop files has SHA-256
`2c2dff0171a51390ef76dca7f3151b2cfbffbba00552061f0f4d4f46ebe972ca`. The final
change makes the control-flood regression deterministic by injecting an exact
receive queue; the socket adapter and 64-packet quantum are unchanged, and the
timing samples precede this testability-only extraction.

Measurements used Darwin arm64, Rust/Cargo 1.96.0, Xcode 26.6, Swift 6.3.3, and
uv 0.10.7. Python tooling ran on 3.14.7 because the installed uv catalog could
not provision the pinned 3.14.6. The pin remains unchanged.

## Completed software checks

| Check | Result and scope |
|---|---|
| `make verify` | Passed with `UV_PYTHON=3.14.7`; `source-gate-verdict: pass`, `product-runtime-verdict: partial`. |
| Rust test configurations | 143 library tests passed with all features and 144 with CLI-only features; three integration tests passed in each configuration. Integration tests cover all 25 shared vectors and 110 Python-generated control cases. |
| Strict Clippy | Passed all targets/features on the host, Linux GNU, and Windows MSVC targets, including unsafe-block and safety-documentation checks. |
| Native Linux implementations | Deterministic substitutes cover negotiation coercion, partial transfers, underruns, cancellation, lifecycle failure ordering, color conversion, inventory budgets, and malformed media recovery. Linux integration cases compile. |
| Linux builds | CLI and GUI-feature x86_64 ELF executables linked against glibc 2.39 using cargo-zigbuild and Zig 0.13. These are development cross-builds. |
| Windows builds | CLI and GUI-feature x86_64 PE executables linked using an external Zig GNU-linker adapter; MSVC target checking also passed. These are development cross-builds, with a console subsystem. |
| Swift | Build and tests passed with warnings treated as errors; security regressions cover bounded file/process reads and remote targets. |
| Rust controller | Readiness, stale arming, asynchronous device discovery, stale inventory results, and measured/unmeasured audio health tests passed. |
| Web demo | Browser interactions passed for setup/loading/error/empty states, Arm/Start/Stop, recording/chat/preview, review, keyboard Escape, light/dark appearance, and 320/390/1024/1440-pixel layouts. No browser errors were observed. |
| Architecture and quality | 902 first-party files passed the 600-line, CCN 19, and 70-token duplication gates. Documentation, source documentation, lint, tooling self-tests, and whitespace checks passed. |
| Retired connector oracle | Before deletion, all 81 Python connector tests and its bidirectional selftest passed. Python now has no runtime package or distribution entry point. |

The duplication baseline removed retired entries and reconciled ten maximal clone
groups in unchanged Swift command files. Byte comparison and an external
inventory with the Python source restored demonstrated clone regrouping after
corpus removal. Thresholds and verifier behavior were not relaxed.

The external Windows linker adapter translates unsupported GNU driver flags and
lets Zig supply its MinGW runtime and SEH unwinder. Executable headers retain
ASLR and NX. This establishes linking, not Windows execution or driver
compatibility; normal Windows builds continue to use the repository manifest.

## Sustained workload and timing limits

The sustained release harness runs three warmups and 31 one-second samples. Each
session uses localhost UDP, 640×480 synthetic capture scaled to 160×120 RGB24 at
30 FPS, and 44.1 kHz stereo 16-bit PCM in 64-frame blocks. Both cadence comparison
runs use CLI-only features. The allocator records calls and live bytes; process
CPU and RSS include every session thread. Queue-age and lateness p95 fields are
fixed-bucket upper bounds, not exact percentiles or hardware latency.

A diagnostic relay that waited for a full video frame admitted only 31 audio
blocks per sample in the initial workload; independent audio and video quanta
removed that bottleneck. A separate deterministic clock test exposed drift from
resetting each deadline to the delayed current time. The scheduler now preserves
phase, skips stale slots, and never sends a catch-up burst.

Rows show medians except the explicitly labeled session elapsed p95.

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

The later run coincided with unrelated Simulator and Node activity. The same host
also produced large timing variation in unchanged audio and JPEG code: software
capture, public audio packetization, and JPEG source files were byte-identical to
the earlier external source snapshot. Samples and process observations were
retained. Regressions above five percent were investigated, but a stable timing
acceptance result remains inconclusive on this shared host. These rows do not
establish a general speedup or field latency.

After the visible Simulator workload ended, another 31-sample run returned 690
sent blocks, 601 received blocks, zero skipped slots, 18.76% CPU, and a 250 µs
lateness p95 upper bound at the median. Session elapsed median/p95 was
1030.58/1034.19 ms. RGB and grayscale JPEG medians returned to 38.89/32.79 ms, but
capture and several tail timings still varied by more than five percent. The
timing acceptance limitation therefore remains, and the unfavorable runs are not
discarded.

All four internal release benchmark checks passed. The audio writer, callback
ring, and both preview-poll paths allocated zero bytes during steady-state
measurement. Caller-buffered synthetic capture allocated one initial 256-byte
buffer over 8,192 operations. Streaming 1080p BGRA packetization preserved
8,494,716 wire bytes while using two allocations and 8,295,808 allocated bytes,
versus 6,072 allocations and 17,080,412 bytes for the retained eager reference.
Existing audio, JPEG, reassembly, and packetization workloads completed with 31
samples each; raw results remain external. Repeat them on an otherwise idle host
before accepting timing comparisons at the five-percent threshold.

## Unverified execution lanes

- ALSA loopback and V4L2 virtual-device execution require a Linux test host;
  runnable cases and setup procedures are in [ALSA](linux-alsa.md) and
  [V4L2](linux-v4l2.md). Cross-compilation does not replace these runs.
- Native macOS Session/Devices light-mode inspection succeeded. Further native
  inspection, including the Rust window, dark and compact desktop states, and
  resizing, was blocked when the computer-use native pipe closed.
- Windows process execution, native media devices, Npcap, reference peers, field
  latency, signing, notarization, and distribution remain unverified. Physical
  validation follows the separate hardware procedures.

No commit, publication, or operational deployment is part of this record.
