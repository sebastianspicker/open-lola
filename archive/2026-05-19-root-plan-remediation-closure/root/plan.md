# Full UltraGrid and JackTrip Runtime Implementation Plan

Date: 2026-05-18
Ledger: `plan-remediation-ledger.md`
Status: active implementation plan
Verdict: PARTIAL until measured external peer, live-device, route, and timing
evidence exists

## Purpose

This plan covers the remaining work required to turn the current bounded
UltraGrid and JackTrip connector runtimes into full, theoretically functional
runtime surfaces.

Current implemented baseline:

- UltraGrid has Swift-native RTP/MVTP packetization for PT20 raw video and PT21
  PCM audio, UDP socket TX/RX, synthetic/injected media generation, video
  fragmentation/reassembly, public provider selection, bounded decoded media
  sink counters, receive analysis, and session-runner routing.
- JackTrip has Swift-native UDP DEFAULT planar PCM packetization,
  8/16/24/32-bit DEFAULT PCM sizing, redundancy datagrams, stop-control accounting,
  UDP socket TX/RX, public provider selection, explicit `coreaudio`/`jack-graph`
  backend selection, bounded decoded PCM sink counters, peer learning, sequence
  quality analysis, and session-runner routing.

Current remaining gaps:

- Measured live-device sessions still need hardware evidence; provider selection
  exists, but it does not prove device or peer interoperability by itself.
- Bounded artifact sinks exist; production playback/render output still needs
  measured device evidence before any real-world claim.
- Reference-peer interoperability is still missing measured evidence, but that
  blocks `PASS` and field-readiness claims rather than local runtime
  implementation work.
- UltraGrid NAT/server-client topology is implemented locally, but field-route
  evidence is still missing.
- JackTrip WebRTC, WebTransport, JACK graph dry-run, plugin bridge, and
  Opus-extension packet models are implemented locally, but measured peer,
  dependency, and live-device evidence remains separate from `PASS`.
- UltraGrid and JackTrip media validators reject incomplete `PASS` reports and
  can only validate `PASS` when every required runtime evidence class is present.

## Success Criteria

A full runtime is complete only when all of these are true:

- The public CLI/session path can run TX, RX, and TX-RX modes with live media
  devices or explicit deterministic test providers.
- Synthetic/generated media is opt-in evidence, not the default implied runtime
  proof for real sessions.
- Received media is decoded into bounded playback/render sinks or measured
  capture artifacts without blocking realtime paths.
- Swift-native TX is accepted by public reference peers, and public reference TX
  is accepted by Swift-native RX, with packet captures and logs attached.
- Reports can return `PASS` only when measured reference-peer, live-device,
  field-route, packet-quality, timing, and teardown evidence all satisfy explicit
  validator rules.
- Unsupported modes fail loudly until each one has public protocol evidence,
  behavior tests, reference-peer validation, and documentation.
- Active app, CLI, docs, and release surfaces do not imply real-world readiness
  before the evidence exists.

## Non-Goals

- Do not bundle UltraGrid or JackTrip source code.
- Do not add production dependencies without explicit approval.
- Do not weaken existing false-success guards to make reports pass.
- Do not make the macOS app claim connector launch support until the runtime is
  actually wired and verified.
- Do not implement advanced modes as one broad rewrite. Each mode needs its own
  scoped slice, fixtures, and reference evidence.

## Implementation Slices

### RT-00: Lock The Evidence Contract

Outcome: define the exact report fields and validator preconditions required for
future `PASS` results before removing current `dryRunCannotPass` behavior.

Tasks:

- Inventory UltraGrid and JackTrip report schemas, validators, fixtures, source
  contracts, and CLI/session report wrappers.
- Add or update tests that prove synthetic, local-loopback, and incomplete
  reference runs remain `PARTIAL` or `FAIL`.
- Define required evidence classes for `PASS`: reference peer, live device,
  field route, packet capture, timing, teardown, and media quality.

Verification:

- `swift test --filter ExternalConnectorReportTests`
- `swift test --filter ReportSchemaInventoryTests`
- `swift test --filter SyntheticSmokeReportContractTests`

Definition of done:

- The repo has an explicit `PASS` contract before either runtime can emit
  `PASS`.
- Existing partial/fail behavior remains intact for incomplete evidence.

### UG-01: Wire Live UltraGrid Media Providers

Outcome: make UltraGrid TX use live audio/video provider selection through the
public runner/session path instead of always using `UltraGridSyntheticMediaProvider`.

Tasks:

- Add public configuration for synthetic, deterministic fixture, CoreAudio audio,
  and AVFoundation/raw video provider selection.
- Keep provider selection outside realtime callbacks and avoid unbounded buffers.
- Reuse existing audio/video runtime surfaces where possible instead of adding
  one-off connector-only abstractions.
- Add behavior tests proving selected provider bytes reach PT21 audio and PT20
  video packets.

Verification:

- `swift test --filter UltraGridCompatibilityTests`
- `swift test --filter ExternalConnectorSessionTests`
- `swift test --filter ExternalConnectorAvMatrixTests`

Definition of done:

- UltraGrid TX can run from the public session path with explicit live or fixture
  providers.
- Synthetic provider use is explicit in reports and cannot be mistaken for live
  media evidence.

### UG-02: Wire UltraGrid Playback And Render Sinks

Outcome: make UltraGrid RX consume received PT21 audio and PT20 video into
bounded sinks that can be tested and measured.

Tasks:

- Add bounded audio playback or capture sink integration for PT21 PCM.
- Add bounded video frame sink/render integration for reassembled PT20 raw
  frames.
- Report dropped, late, malformed, and sink-rejected media explicitly.
- Keep raw frame reassembly memory bounded by configured frame size and timeout.

Verification:

- `swift test --filter UltraGridCompatibilityTests`
- `swift test --filter VideoTransportRunnerTests`
- `swift test --filter ExternalConnectorSessionTests`

Definition of done:

- UltraGrid RX no longer stops at datagram analysis for full-runtime paths.
- Tests prove decoded media reaches sinks or fails loudly with report evidence.

### UG-03: Measure Direct UltraGrid Reference-Peer Parity

Outcome: prove Swift-native UltraGrid direct-peer interoperability in both
directions before adding topology complexity.

Tasks:

- Run Swift TX to public UltraGrid RX and public UltraGrid TX to Swift RX.
- Capture peer versions, launch commands, RTP/UDP packet captures, logs, report
  JSON, validator output, and timing summaries.
- Keep the parity gate opt-in and skip-loud when prerequisites are missing.

Verification:

- `bash scripts/run-reference-peer-parity-gate.sh <output> ultragrid`
- `swift test --filter VerificationToolingPairScriptTests`
- `swift test --filter UltraGridCompatibilityTests`

Definition of done:

- Both direct-peer directions produce measured artifacts.
- Reports remain below `PASS` unless every RT-00 evidence precondition is met.

### UG-04: Add UltraGrid PASS-Capable Validation

Outcome: replace unconditional UltraGrid `PASS` rejection with evidence-gated
validation.

Tasks:

- Update `UltraGridCompatibilityMediaReport.validate()` to allow `PASS` only
  with measured evidence fields populated.
- Add invalid fixtures for synthetic pass, missing reference peer, missing route,
  missing timing, and incomplete media evidence.
- Add valid measured fixture only from real captured artifacts.

Verification:

- `swift test --filter UltraGridCompatibilityTests`
- `swift test --filter ReportFixtureValidationContractTests`
- `swift test --filter ExternalConnectorReportTests`

Definition of done:

- UltraGrid can emit `PASS` only from measured full-runtime evidence.
- Current synthetic and local-only paths continue to validate as `PARTIAL` or
  `FAIL`.

Status: done for validator scaffolding. UltraGrid media reports reject PASS
unless runtime error is absent, real-link transmission is recorded, all runtime
PASS evidence classes are observed, and no missing PASS evidence remains.
Measured valid PASS artifacts still require UG-03 external peer evidence.

### UG-05: Add UltraGrid NAT And Server-Client Topology

Outcome: implement UltraGrid topology modes locally without treating missing
reference-peer parity as a blocker for code; measured route evidence is still
required before any field-readiness or `PASS` claim.

Tasks:

- Model server/client endpoint state, peer discovery, port mapping, and timeout
  behavior explicitly.
- Add topology configuration without changing direct-peer defaults.
- Add two-process local topology tests before any field-route claim.

Verification:

- `swift test --filter UltraGridCompatibilityTests`
- `swift test --filter ExternalConnectorConnectionPlanTests`
- `swift test --filter ExternalConnectorSessionTests`

Definition of done:

- Direct-peer behavior remains unchanged.
- NAT/server-client topology has explicit state transitions and fail-loud
  reports.

Status: done for local runtime topology. Direct-peer remains the default,
server-client endpoint plans emit local server and remote client roles, server
RX can listen without a configured peer, and topology state is recorded in the
UltraGrid media report. Measured field-route evidence remains outside this
slice.

### UG-06: Implement Advanced UltraGrid Modes One At A Time

Outcome: remove UltraGrid unsupported modes only after scoped implementation and
reference validation.

Mode order:

1. Dynamic RTP and codec-specific payload negotiation.
2. JPEG.
3. H.264.
4. FEC.
5. Encryption.
6. Advanced UltraGrid control APIs.

Status: dynamic RTP and codec-specific negotiation are done for implemented
PCM-audio, raw-video, RTP/JPEG, and RTP/H.264 codecs. PT26 static RTP/JPEG and
dynamic JPEG mappings decode through a Swift-native RFC 2435 payload header
model with bounded malformed-payload validation. Dynamic H.264 mappings decode
single NAL, STAP-A, and FU-A RFC 6184 payloads with malformed-payload rejection.
PT22 FEC envelope encode/decode and bounded single-parity video loss recovery
are implemented for local runtime testing. PT24/PT25 AES-128-GCM encryption is
implemented for raw-video and PCM-audio packet payloads with redacted key
material in public launch metadata. Unmapped dynamic payload types still fail
loudly. Reference JPEG/H.264, LDGM parity, and encrypted reference-peer
interoperability remain evidence-gated before `PASS` claims. TCP control command
framing is implemented as a Swift-native CRLF-delimited model from the public
control socket source; reference-peer control-plane responses remain
evidence-gated before any field-readiness claim.

Verification per mode:

- Mode-specific packet codec tests.
- Swift-to-reference and reference-to-Swift parity artifacts.
- Report-schema and docs updates.

Definition of done:

- A mode leaves `unsupportedModes` when its local codec/runtime/report path is
  implemented and tested. Reference-peer, route, and timing evidence remain
  required before any runtime `PASS` claim.

### JT-01: Wire Live JackTrip Audio Providers

Outcome: make JackTrip TX use live audio through the public runner/session path
instead of always using `JackTripSyntheticAudioFrameProvider`.

Tasks:

- Add public provider selection for synthetic, deterministic fixture, CoreAudio,
  and JACK-style graph input where supported.
- Convert live interleaved samples into JackTrip planar payloads without blocking
  realtime callbacks.
- Report provider source, sample format, channel count, buffer size, underruns,
  and conversion failures.

Verification:

- `swift test --filter JackTripCompatibilityTests`
- `swift test --filter ExternalConnectorSessionTests`
- `swift test --filter ExternalConnectorAvMatrixTests`

Definition of done:

- JackTrip TX can run from the public session path with explicit live or fixture
  audio providers.
- Synthetic provider use is explicit and cannot satisfy live-device evidence.

### JT-02: Wire JackTrip Playback And Timing Sinks

Outcome: make JackTrip RX consume decoded DEFAULT packets into bounded playback
or measured capture sinks.

Tasks:

- Add bounded jitter/playout handling for decoded PCM.
- Add playback or artifact sink integration with underrun/overrun accounting.
- Preserve stop-control, peer-learning, redundancy, duplicate, loss, and reorder
  reporting.

Verification:

- `swift test --filter JackTripCompatibilityTests`
- `swift test --filter ExternalConnectorSessionTests`

Definition of done:

- JackTrip RX no longer stops at packet accounting for full-runtime paths.
- Tests prove decoded PCM reaches sinks or fails loudly with report evidence.

### JT-03: Measure Direct JackTrip Reference-Peer Parity

Outcome: prove Swift-native JackTrip direct UDP DEFAULT interoperability in both
directions.

Tasks:

- Run Swift TX to public JackTrip RX and public JackTrip TX to Swift RX.
- Capture JackTrip version, command line, packet capture, route evidence, logs,
  report JSON, and audio timing evidence.
- Include queue depth, redundancy, bind port, peer port, sample rate, frames, and
  channel-count variants.

Verification:

- `bash scripts/run-reference-peer-parity-gate.sh <output> jacktrip`
- `swift test --filter VerificationToolingPairScriptTests`
- `swift test --filter JackTripCompatibilityTests`

Definition of done:

- Both direct-peer directions produce measured artifacts.
- Reports remain below `PASS` unless every RT-00 evidence precondition is met.

### JT-04: Implement Non-16-Bit JackTrip Audio

Outcome: support 8-bit, 24-bit, and 32-bit JackTrip DEFAULT audio only with
explicit conversion and validation.

Tasks:

- Add bit-depth-specific payload length validation and planar/interleaved
  conversion.
- Add clipping, endian, and boundary tests for each bit depth.
- Keep unsupported/non-PCM modes separate from PCM bit-depth support.

Verification:

- `swift test --filter JackTripCompatibilityTests`

Definition of done:

- 8/16/24/32-bit PCM packets decode, encode, and route correctly.
- Invalid payload sizes and unsupported sample formats still fail loud.

### JT-05: Add JackTrip Hub, TCP, Auth, And JACK Backend Modes

Outcome: implement JackTrip control/topology modes in small, independently
reviewable slices.

Mode order:

1. JACK-style local graph backend selection. The selector exists now as an
   explicit `jack-graph` mode; dry runs use deterministic local frames, while
   measured JACK graph capture still requires local JACK evidence before
   field-readiness or `PASS`.
2. Hub virtual-studio topology. The local topology model is implemented with
   explicit hub-server and hub-client roles; measured hub route evidence is
   still required before any field-readiness or `PASS` claim.
3. TCP hub handshake. The unauthenticated hub port exchange is implemented as a
   Swift-native codec/report path; measured hub route evidence is still required
   before any field-readiness or `PASS` claim.
4. Authentication/TLS behavior. The local auth response and credential-frame
   model is implemented with redacted reporting; measured TLS peer evidence is
   still required before any field-readiness or `PASS` claim.

Verification per mode:

- Public protocol evidence or fixture transcripts.
- Local handshake/topology tests.
- Reference-peer validation where applicable.

Definition of done:

- Each mode has explicit state, timeout, error, and teardown behavior.
- A locally implemented mode can leave `unsupportedModes` when covered by public
  evidence, tests, and truthful report state; reference-peer evidence remains a
  separate requirement for field readiness and `PASS`.

### JT-06: Add JackTrip WebRTC, WebTransport, JamLink, Plugin, Empty-Header, And Non-PCM Modes

Outcome: treat advanced JackTrip ecosystem modes as separately scoped runtime
features.

Tasks:

- For each mode, first gather public protocol evidence and decide whether the
  mode belongs in this clean-room runtime.
- Add fixtures, codecs, state machines, and reference validation only after the
  evidence is sufficient.
- Keep modes explicitly unsupported until implemented.
- `WebRTC` data-channel mode is implemented locally as the same JackTrip packet
  bytes as UDP plus length-prefixed JSON signaling frame helpers; ICE/DTLS peer
  evidence remains required before interoperability or `PASS`.
- `WebTransport` datagram mode is implemented locally as the same JackTrip
  packet bytes as UDP after a QUIC varint quarter-stream ID prefix; HTTP/3 peer
  evidence remains required before interoperability or `PASS`.
- `EMPTY` header mode is implemented locally as raw planar PCM datagrams with
  explicit session-derived decode metadata and redundancy rejection; measured
  reference-peer evidence remains required before interoperability or `PASS`.
- `JAMLINK` header mode is implemented locally for representable 16-bit
  mono/stereo PCM with compact stream-type, sequence, timestamp, sample-rate,
  and samples-per-packet fields; measured reference-peer evidence remains
  required before interoperability or `PASS`.
- JackTrip plugin bridge mode is implemented locally as
  `--jacktrip-plugin audio-bridge`, an explicit plugin-host boundary over the
  native packet runtime. Plugin host loading remains external evidence.
- JackTrip non-PCM audio is implemented locally as
  `--jacktrip-payload-encoding opus-celt-low-delay`, an Open LoLa Opus extension
  envelope over the JackTrip packet model. Reference-peer evidence remains
  required before interoperability or `PASS`.

Verification per mode:

- Mode-specific unit tests.
- Reference-peer or public fixture validation.
- Report-schema and docs updates.

Definition of done:

- Each advanced mode has an implementation, tests, and evidence boundary.
- Implemented modes leave `unsupportedModes`; measured peer evidence remains
  separate from source-level support.

### JT-07: Add JackTrip PASS-Capable Validation

Outcome: replace unconditional JackTrip `PASS` rejection with evidence-gated
validation.

Tasks:

- Update `JackTripCompatibilityMediaReport.validate()` to allow `PASS` only with
  measured evidence fields populated.
- Add invalid fixtures for synthetic pass, missing peer, missing route, missing
  timing, missing live audio, and incomplete teardown.
- Add valid measured fixture only from real captured artifacts.

Verification:

- `swift test --filter JackTripCompatibilityTests`
- `swift test --filter ReportFixtureValidationContractTests`
- `swift test --filter ExternalConnectorReportTests`

Definition of done:

- JackTrip can emit `PASS` only from measured full-runtime evidence.
- Current synthetic and local-only paths continue to validate as `PARTIAL` or
  `FAIL`.

Status: done for validator scaffolding. JackTrip media reports reject PASS
unless runtime error is absent, real-link transmission is recorded, all runtime
PASS evidence classes are observed, and no missing PASS evidence remains.
Measured valid PASS artifacts still require JT-03 external peer evidence.

### SH-01: Update Public Surfaces After Runtime Evidence Exists

Outcome: keep CLI, app, docs, scripts, fixtures, and release policy aligned with
implemented runtime truth.

Tasks:

- Update CLI help, session parsing, source contracts, script README, and report
  schema inventory as each runtime slice lands.
- Keep macOS app connector modes planning-only until app runtime launch is wired
  and tested.
- Update release hygiene only after active root plan artifacts are archived.

Verification:

- `swift test --filter AppShellSlice05Tests`
- `swift test --filter ExternalConnectorSessionTests`
- `bash scripts/verify-docs.sh`
- `bash scripts/verify-release-hygiene.sh`

Definition of done:

- No public surface claims launchability, compatibility, health, or `PASS`
  without matching runtime evidence.

## Broad Verification

Run narrow checks after each slice and broad checks before handoff:

```bash
swift test --filter UltraGridCompatibilityTests
swift test --filter JackTripCompatibilityTests
swift test --filter ExternalConnectorSessionTests
swift test --filter ExternalConnectorProcessGroupTests
swift test --filter ExternalConnectorConnectionPlanTests
swift test --filter ExternalConnectorReportTests
swift test --filter ExternalConnectorAvMatrixTests
swift test --filter VerificationToolingPairScriptTests
swift test --filter AppShellSlice05Tests
swift test --no-parallel
swift build
bash scripts/verify-docs.sh
bash scripts/verify-release-hygiene.sh
```

Reference-peer and hardware gates must be explicit opt-in runs with recorded
environment, commands, artifacts, logs, packet captures, route evidence, and
validator output.

## Rollback

Each implementation slice should be independently revertible. If a slice touches
public report schemas, include fixture migration notes and keep old invalid
fixtures proving that partial evidence cannot be promoted to `PASS`.

## Next Slice

The remaining non-local slice is measured reference-peer and live-device
evidence capture for UG-03 and JT-03. That work must stay separate from native
runtime implementation and cannot use skip-loud readiness reports as
interoperability proof.
