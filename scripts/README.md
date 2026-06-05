# Scripts

Date: 2026-05-05
Status: active verification and release-hygiene helper index
Verdict: PARTIAL

This directory contains repository-local verification helpers.

## Codacy local parity gate

[verify-codacy-local.sh](verify-codacy-local.sh) is the pre-PR Codacy gate. It
refreshes `.codacy/codacy.config.json` from Codacy Cloud, removes generated
per-file exclude noise for archived/vendor/private trees, verifies that the
Cloud-enabled tools are runnable locally, and then runs local analysis with the
same repository exclusions as Cloud.

Run the inspect pass before opening a pull request:

```bash
bash scripts/verify-codacy-local.sh --inspect-only
```

Run the full local analysis when inspect is clean:

```bash
bash scripts/verify-codacy-local.sh
```

If inspect reports missing Codacy tool dependencies, either install them
locally for this checkout or align the Codacy Cloud tool configuration before
treating a local pass as predictive of Cloud.

## Native macOS app bundle helper

The legacy singular [../script](../script) lane is still active for native
macOS app bundle assembly. [../script/build_and_run.sh](../script/build_and_run.sh)
builds the SwiftPM products, stages `open-lola-app` with the bundled CLI helper
and privacy metadata, and supports the `--verify` contract used by the native
app surface probe. Keep this lane covered by shellcheck and release hygiene
until it is moved under `scripts/`.

## Local JackTrip Docker helpers

[start-local-jacktrip-docker.sh](start-local-jacktrip-docker.sh) starts a
reviewed JackTrip container image in P2P server mode with TCP and UDP
publishing for the JackTrip audio port, the auxiliary UDP range, and the
memory-lock settings needed on this macOS host. Set
`OPEN_LOLA_JACKTRIP_DOCKER_IMAGE` to a pinned tag or digest before running any
JackTrip Docker helper; the helpers reject unset images and the mutable
`latest` tag.

Run from the repository root:

```bash
export OPEN_LOLA_JACKTRIP_DOCKER_IMAGE=<reviewed-jacktrip-image-tag-or-digest>
bash scripts/start-local-jacktrip-docker.sh open-lola-jacktrip-local
docker exec open-lola-jacktrip-local systemctl is-active jacktrip
```

[open-lola-jacktrip-docker-client.sh](open-lola-jacktrip-docker-client.sh) is
a legacy/reference JackTrip client wrapper for parity checks against the public
`jacktrip` binary. The primary Open LoLa JackTrip connector path is now
Swift-native UDP DEFAULT audio packetization, so this wrapper is not required
for ordinary `external-connector-session-run --connector jacktrip` reports. It
still maps JackTrip-style launch arguments into `JACKTRIP_OPTS`; `-R` and
RtAudio device options are intentionally dropped because the container uses its
own JACK dummy backend, while `-T/--srate` and `-F/--bufsize` are mapped to the
container's `SAMPLE_RATE` and `BUFFER_SIZE` environment variables.

```bash
.build/debug/open-lola external-connector-session-run --connector jacktrip --role tx-rx --peer host.docker.internal --output /private/tmp/open-lola-jacktrip-docker-client.json --dry-run false --media audio --duration-seconds 8 --audio-port 4464 --channels 2 --sample-rate 48000 --frames 128 --executable scripts/open-lola-jacktrip-docker-client.sh
.build/debug/open-lola validate-external-connector-session-report /private/tmp/open-lola-jacktrip-docker-client.json
docker stop open-lola-jacktrip-local
```

The generated report is reference/parity evidence around a public JackTrip
container, not the primary native Open LoLa JackTrip runtime. It remains
`PARTIAL`, not `PASS`, until measured bidirectional audio, route, packet
capture, and timing evidence is attached.

## Local UltraGrid Docker helpers

[build-local-ultragrid-docker.sh](build-local-ultragrid-docker.sh) builds a
minimal local `open-lola-ultragrid:1.10.4` image from the official CESNET
UltraGrid 1.10.4 source release. The image intentionally enables only the
headless modules needed for local probes: video `testcard`/`dummy` and audio
`testcard`/`dummy`/`none`. Set `OPEN_LOLA_ULTRAGRID_DOCKER_IMAGE` only to a
reviewed pinned tag or digest; the UltraGrid Docker helpers reject the mutable
`latest` tag and otherwise default to the local pinned
`open-lola-ultragrid:1.10.4` image.

```bash
bash scripts/build-local-ultragrid-docker.sh
```

[start-local-ultragrid-docker.sh](start-local-ultragrid-docker.sh) starts that
image as a local UltraGrid `--server` endpoint on UDP `5004` video and UDP
`5006` audio.

```bash
bash scripts/start-local-ultragrid-docker.sh open-lola-ultragrid-local
```

[open-lola-ultragrid-docker-client.sh](open-lola-ultragrid-docker-client.sh) is
a reference/parity wrapper for a public UltraGrid peer, not the primary
`mvtp-ultragrid` runtime. Open LoLa's connector now uses its Swift-native
RTP/MVTP media path; this helper remains useful when comparing that path against
a bounded Docker UltraGrid client container that rewrites Open LoLa's peer host
argument to UltraGrid's `--client <host>` mode.

```bash
.build/debug/open-lola external-connector-session-run --connector mvtp-ultragrid --role tx-rx --peer host.docker.internal --output /private/tmp/open-lola-ultragrid-docker-client.json --dry-run false --media audio-video --duration-seconds 8 --video-port 5004 --audio-port 5006 --video-display dummy --audio-playback dummy --video-capture testcard:640:360:10:RGB --audio-capture testcard --executable scripts/open-lola-ultragrid-docker-client.sh
.build/debug/open-lola validate-external-connector-session-report /private/tmp/open-lola-ultragrid-docker-client.json
docker logs --tail 120 open-lola-ultragrid-local
docker stop open-lola-ultragrid-local
```

The generated reports are reference peer evidence for a bounded Docker
UltraGrid tx-rx endpoint. They remain `PARTIAL`, not `PASS`, until measured
bidirectional audio/video, route, timing, and Swift-native packet-capture
evidence is attached.

[open-lola-ultragrid-native-client.sh](open-lola-ultragrid-native-client.sh) is
the equivalent reference/parity wrapper for a native UltraGrid executable. It
maps Open LoLa's role environment into UltraGrid `--server` or
`--client <host>` mode and refuses Astral's Python `uv` when it is found under
the expected UltraGrid command name. [run-local-ultragrid-rxtx-native.sh](run-local-ultragrid-rxtx-native.sh)
preflights the native reference executable, launches both UltraGrid peer roles
through Open LoLa's external process surface, writes live native logs, and
records
`ultragrid-connection-metrics.json`. On hosts without native UltraGrid it exits
with code `77` after writing `ultragrid-native-preflight.json`; that is a host
readiness skip, not parity evidence.
[compare-local-ultragrid-parity-native.sh](compare-local-ultragrid-parity-native.sh)
runs the native direct UltraGrid RX/TX baseline and then the Open LoLa-managed
native UltraGrid RX/TX path, writing `ultragrid-native-parity-metrics.json`
with the same connection, packet, decode, media-format, endpoint-health, and
worst-display-FPS comparison shape as the Docker parity gate.
[stress-local-ultragrid-parity-native.sh](stress-local-ultragrid-parity-native.sh)
runs that native comparator repeatedly and writes
`ultragrid-native-parity-stability-summary.json`. If native UltraGrid is not
installed, it records `hostReady: false` after the first preflight report and
exits with code `77`.

```bash
bash scripts/run-local-ultragrid-rxtx-native.sh /private/tmp/open-lola-ultragrid-rxtx-native
bash scripts/compare-local-ultragrid-parity-native.sh /private/tmp/open-lola-ultragrid-parity-native
bash scripts/stress-local-ultragrid-parity-native.sh /private/tmp/open-lola-ultragrid-parity-native-stability
```

## Legacy paired Open LoLa RX/TX Docker probes

[run-local-jacktrip-rxtx-docker.sh](run-local-jacktrip-rxtx-docker.sh) is a
reference/parity helper for the public JackTrip Docker path. It is retained for
comparison evidence while Open LoLa's primary JackTrip connector uses native UDP
DEFAULT audio packetization. The probe fails when the RX journal does not record
a JackTrip peer connection.

```bash
bash scripts/run-local-jacktrip-rxtx-docker.sh /private/tmp/open-lola-jacktrip-rxtx
```

[compare-local-jacktrip-parity-docker.sh](compare-local-jacktrip-parity-docker.sh)
runs a same-host direct JackTrip Docker RX/TX baseline and then the retained
Open LoLa reference-helper path with the same sample-rate, buffer-size, queue,
redundancy, and port settings. It is a local stability/configuration
comparison for public JackTrip tooling, not a physical latency parity claim or
proof that the Swift-native connector has passed real-peer interop.

```bash
bash scripts/compare-local-jacktrip-parity-docker.sh /private/tmp/open-lola-jacktrip-parity
```

[run-local-ultragrid-rxtx-docker.sh](run-local-ultragrid-rxtx-docker.sh)
launches both reference UltraGrid roles through Open LoLa's external process
surface: RX starts the Docker-backed UltraGrid `--server` endpoint and
publishes UDP video/audio ports; TX starts a Docker-backed `--client` endpoint
against `host.docker.internal`.
`OPEN_LOLA_CONNECTOR_DURATION_SECONDS` controls the RX server window, and
`OPEN_LOLA_ULTRAGRID_TX_DURATION_SECONDS` controls the TX client window. The
script also writes `ultragrid-connection-metrics.json`, measuring from the
reference TX command start until the RX Docker log first shows incoming
audio and video formats. `OPEN_LOLA_ULTRAGRID_CONNECTION_POLL_SECONDS`
controls the connection-log polling interval; the default is `0.1`. TX starts
only after the managed RX container reports UltraGrid audio/video runtime
readiness, avoiding blind startup sleeps before the measured connection window.

```bash
bash scripts/run-local-ultragrid-rxtx-docker.sh /private/tmp/open-lola-ultragrid-rxtx
```

[compare-local-ultragrid-parity-docker.sh](compare-local-ultragrid-parity-docker.sh)
runs a same-host direct UltraGrid Docker RX/TX baseline and then the Open
LoLa-managed reference UltraGrid RX/TX path with the same testcard, dummy
playback, port-map, and server/client host-published route shape. It fails
unless both
paths show audio/video send/receive startup, incoming audio and video formats,
packet-buffer output with `100.0000%` received and `0 lost`, plus cumulative
audio/video decoder stats with no video drops or misses. It also writes
`ultragrid-parity-metrics.json`, which compares direct and managed packet
receipt, audio decode, video decode, media formats, and connection setup time
as a machine-readable local parity artifact. It also compares UltraGrid display
FPS lines for the configured display device so smoothness regressions are
reported even when packet and decoder counters look clean.
`OPEN_LOLA_ULTRAGRID_MAX_MANAGED_CONNECTION_DELTA_MS` sets the allowed managed
connection setup overhead over the direct Docker baseline; the default is
`250`. `OPEN_LOLA_ULTRAGRID_CONNECTION_POLL_SECONDS` controls the direct and
managed timing probe resolution; the default is `0.1`.
`OPEN_LOLA_ULTRAGRID_MAX_MANAGED_DISPLAY_FPS_DELTA` sets the allowed managed
deficit against direct UltraGrid for the worst observed display-FPS sample; the
default is `0.5`. This is a local stability/configuration comparison, not a
physical latency parity claim. `OPEN_LOLA_ULTRAGRID_MANAGED_RX_DURATION_SECONDS`
defaults to two seconds longer than the TX media window so the smoothness check
does not include a long idle RX tail after TX exits.
The metrics report keeps parity failures in `errors` and records absolute
direct/managed endpoint health separately under `endpointHealth`, so a dirty
direct Docker baseline is visible without being misreported as a managed
regression.

```bash
bash scripts/compare-local-ultragrid-parity-docker.sh /private/tmp/open-lola-ultragrid-parity
```

[stress-local-ultragrid-parity-docker.sh](stress-local-ultragrid-parity-docker.sh)
runs the UltraGrid local parity comparator repeatedly and writes
`ultragrid-parity-stability-summary.json`. `OPEN_LOLA_ULTRAGRID_PARITY_TRIALS`
controls the trial count; the default is `3`. The summary fails if any trial
fails, if any trial omits `ultragrid-parity-metrics.json`, or if any comparison
inside a trial is false. It also reports `allDirectBaselinesClean` and
`allManagedEndpointsClean` for separating noisy Docker baseline runs from
actual managed-path regressions.

```bash
bash scripts/stress-local-ultragrid-parity-docker.sh /private/tmp/open-lola-ultragrid-parity-stability
```

Both paired probes write and validate separate legacy RX and TX session
reports. They remain useful as compatibility/process checks, but the primary
connector contract is explicit simultaneous `tx-rx`. They remain `PARTIAL`, not
`PASS`, until measured bidirectional media, route, and timing evidence is
attached.

## export-release-candidate.sh

[export-release-candidate.sh](export-release-candidate.sh) stages an
allowlisted source release candidate outside the raw checkout and immediately
runs the C12 hygiene scan against the staged directory. It is for inspection,
not publication approval.

Run from the repository root:

```bash
bash scripts/export-release-candidate.sh /path/to/output-parent
```

If no output parent is supplied, the script uses `TMPDIR` or `/tmp`. The final
line reports `RELEASE_CANDIDATE_EXPORT_VERDICT: PASS` when staging and
candidate hygiene scanning succeed, while product release readiness remains
partial until license, notices, reviewer, signing, clean-Mac, hardware, and
benchmark evidence gates close.

## verify-release-readiness.sh

[verify-release-readiness.sh](verify-release-readiness.sh) is the C10 local
release-readiness parity gate. It runs the documentation gate, shellcheck, the
C12 release hygiene gate, SwiftPM build, SwiftPM tests, manual gate reminders,
the executable C01/C02/C03/C05/C06/C07/C08/C11 review probes, and the
open-source release-readiness blocker preflight. The SwiftPM steps are bounded
locally: `SWIFT_BUILD_TIMEOUT_SECONDS` defaults to `600`, and
`SWIFT_TEST_TIMEOUT_SECONDS` defaults to `1800`.

Run from the repository root:

```bash
bash scripts/verify-release-readiness.sh
```

CI uses the same command through
[../.github/workflows/release-readiness.yml](../.github/workflows/release-readiness.yml).
The workflow is read-only and must not upload or publish artifacts.

## verify-pmr-external-proof-bundle.sh

[verify-pmr-external-proof-bundle.sh](verify-pmr-external-proof-bundle.sh)
validates the artifact bundle required to close the externally blocked
`archive/2026-05-22-plan-md-external-proof-closure/root/plan-missed-remediation-ledger.md`
rows PMR-04, PMR-14, PMR-16, and PMR-23. It does not generate hardware or
live-peer evidence; it only checks that the expected reports exist, run through
the existing `open-lola` validators, and carry the verdicts needed by the PMR
rows.

Run from the repository root after building the CLI:

```bash
swift build --product open-lola
bash scripts/verify-pmr-external-proof-bundle.sh /path/to/pmr-external-proof-bundle
```

Set `OPEN_LOLA_CLI=/path/to/open-lola` to validate with a staged CLI binary.
The script reports `VERDICT: PASS` only when the PMR bundle validates; it is
not part of `verify-release-readiness.sh` because the artifacts require real
hardware, sanitizer/runtime, and live-peer evidence. The PMR-14 reports must
show a `pass` physical-reference RX benchmark with a direct fastest-eligible
row, measured `pass` drift certification with a measured LoLa baseline on the
same hardware/route and an `openLolaFaster` or `openLolaEquivalent` result,
`pass` physical two-peer P2P evidence with packet-capture, DSCP, and clock
artifacts, nonzero sent/received/routed/queued audio payloads, and zero explicit
loss/drop/underrun/deadline counters. The PMR-04 realtime report must be a
measured RME MADI run with `audioDeviceIOProc` callback ownership, UDP setup
before start, report writing after stop, completed shutdown, and nonzero
handoff counters; sanitizer evidence must contain both `ASAN: PASS` and
`TSAN: PASS` or `SANITIZER_RUNTIME_BLOCKED: <reason>`. The PMR-23 CoreAudio run
uses `validate-audio-loopback-run-report` and requires a completed
`audio-loopback-run` report with `can-start-ioproc: true` and no preflight
blockers plus `audioDeviceIOProc`, callback samples, nonzero handoff counters,
completed handoff shutdown, and empty cleanup failures. The PMR-23 LoLa report
must be a bidirectional `tx-rx` live-link artifact with a non-loopback peer,
distinct local/peer hosts, sent bytes, expected datagrams, audio frames, wire
bytes, and envelope validation. The PMR-16 hardware notes must name RME MADI
hardware and provide non-empty, distinct `input UID:` and `output UID:` values,
peer-readiness exchange, teardown completion, and packet-capture notes; its
MADI report must show distinct two-peer hosts and nonzero TX/RX/rendered
packet-block metrics. Blocked-preflight reports document why the local host
cannot close the row, but do not pass this gate.

## verify-release-hygiene.sh

[verify-release-hygiene.sh](verify-release-hygiene.sh) is the C12
artifact/dependency/generated-output hygiene gate. It checks `.gitignore`,
`Package.swift`, `THIRD_PARTY_NOTICES.md`, the dependency review, the release
manifest, and the compliance hygiene doc for release-boundary drift. Without a
candidate argument it scans the live checkout for generated residue such as
`.DS_Store`, `__pycache__`, `.pytest_cache`, `.ruff_cache`, and `.mypy_cache`
before reporting `LIVE_RESIDUE_HYGIENE_VERDICT: PASS`. Candidate scans report
`RELEASE_HYGIENE_VERDICT: PASS`.

Run the repository policy check from the repository root:

```bash
bash scripts/verify-release-hygiene.sh
```

Scan a staged release candidate directory explicitly:

```bash
bash scripts/verify-release-hygiene.sh /path/to/release-candidate
OPEN_LOLA_RELEASE_CANDIDATE=/path/to/release-candidate bash scripts/verify-release-hygiene.sh
```

The candidate scan is non-destructive. It fails if generated output, app/package
artifacts, debug symbols, local secrets, raw reverse-engineering evidence,
`archive/2026-05-11-win-compiled/`, `private/`, `archive/`, generated
`private/reports/`, or restored internal `docs/review/` planning files
appear in the candidate. It also rejects uncompiled vendored upstream CI, test,
training, demo, and build-system folders under the Opus and JPEG XS drops; the
exporter removes those from staged candidates while keeping the compiled subset
and notices.

## verify-docs.sh

[verify-docs.sh](verify-docs.sh) is the canonical documentation gate for the
Mac port harness. It is non-mutating: it prints the Markdown inventory and then
checks relative links, required topic coverage, ASCII constraints, active
topology contracts, active public-doc contracts, the consolidated
implementation companion, SOTA 2026 probe coverage, archive manifest coverage,
and ASCII `TODO(human)` markers.
The gate includes the root [../README.md](../README.md), the public
[../docs/](../docs/README.md) surface, including active source-contract,
benchmark, and reverse-engineering-boundary docs, and the internal
[../private/reverse-engineering/](../private/reverse-engineering-boundary.md)
evidence lane.

Run from the repository root:

```bash
bash scripts/verify-docs.sh
shellcheck -x scripts/*.sh scripts/lib/*.sh
```

Superseded snapshots under `archive/2026-05-05-doc-consolidation/`,
`archive/2026-05-11-doc-cleanup/`, and
`archive/2026-05-11-doc-condense/` are preserved as archive copies. They are
printed in the archive inventory, while their stale internal links are not
treated as active documentation links.
