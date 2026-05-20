# Full UltraGrid and JackTrip Runtime Remediation Status

Date: 2026-05-18
Plan: `plan.md`
Ledger: `plan-remediation-ledger.md`
Status: active implementation packet
Verdict: PARTIAL

## Current Status

- RT-00 is complete: the shared runtime `PASS` evidence contract now names
  reference-peer, live-device, field-route, packet-capture, timing, teardown, and
  media-quality evidence.
- UltraGrid and JackTrip media reports now expose observed evidence classes and
  missing evidence classes for future runtime `PASS`.
- UG-01 and JT-01 are complete: the public UltraGrid and JackTrip runners now
  record structured provider reports, can use deterministic fixture providers,
  and expose live CoreAudio/AVFoundation provider selection as live-device
  evidence without claiming peer interoperability.
- UG-02 and JT-02 are complete for bounded artifact sinks: received UltraGrid
  PT21/PT20 media and JackTrip DEFAULT PCM are decoded into sink counters, and
  rejected media remains explicit.
- UG-05 is complete for local topology implementation: UltraGrid now has
  direct-peer and server-client topology configuration, explicit server/client
  report state, server-side listener behavior without a required peer, and NMP
  connection plans that do not require `uv` preflight for the Swift-native
  UltraGrid runtime.
- UG-04 is complete for validator scaffolding: UltraGrid media reports can only
  validate `PASS` when all required runtime evidence classes are observed,
  missing evidence is empty, no runtime error is present, and a real link was
  used. Synthetic/incomplete PASS remains rejected.
- UG-06A is complete for dynamic RTP negotiation scaffolding: UltraGrid can map
  configured dynamic payload types to the implemented PCM-audio, raw-video, and
  RTP/JPEG codecs, while unmapped dynamic payload types and unsupported H.264
  codec mappings fail loudly.
- UG-06B is complete for local RTP/JPEG packet support: UltraGrid now classifies
  static PT26 and dynamic `jpeg` payload mappings as video, validates the RFC
  2435 main JPEG header and scan payload bounds, and rejects malformed RTP/JPEG
  payloads without claiming reference-peer parity.
- UG-06C is complete for local RTP/H.264 packet support: UltraGrid now
  classifies dynamic `h264` payload mappings as video, validates RFC 6184 single
  NAL, STAP-A, and FU-A payloads, and rejects malformed H.264 RTP payloads
  without claiming reference-peer parity.
- UG-06F is complete for local control command modeling: UltraGrid now has a
  Swift-native CRLF-delimited TCP control command model, report state, parser
  and launch-plan propagation, and tests for safe stats/mute/volume/av-delay/
  compress/module command framing without claiming reference-peer control-plane
  success.
- UG-06D is complete for local FEC runtime behavior: UltraGrid now has explicit
  `--ultragrid-fec` configuration, PT22 FEC envelope encode/decode, launch/NMP
  propagation, and bounded single-parity recovery for one missing raw-video
  fragment. Reference LDGM parity and reference-peer interoperability evidence
  remain required before any `PASS` claim.
- UG-06E is complete for local encryption runtime behavior: UltraGrid now has
  PT24/PT25 AES-128-GCM packet wrapping for raw-video and PCM-audio payloads,
  explicit `--ultragrid-encryption` configuration, redacted passphrase metadata,
  missing-key rejection, and encrypted TX/RX sink tests. Encrypted
  reference-peer interoperability evidence remains required before any `PASS`
  claim.
- JT-04 is complete: JackTrip DEFAULT packets now support 8/16/24/32-bit PCM
  payload sizing and parser-selected `--jacktrip-bit-resolution`.
- JT-05A is complete for backend selection: `--jacktrip-audio-backend` and
  connection-plan endpoint commands now carry explicit `coreaudio` or
  `jack-graph` selection. `jack-graph` dry runs produce deterministic local
  packet evidence; measured JACK graph capture still requires local JACK
  evidence before any field-readiness claim.
- JT-05B is complete for local hub topology implementation: JackTrip now has
  explicit direct-peer and hub virtual-studio topology configuration,
  hub-server/hub-client report state, launch-plan mapping to the reference
  `-S`/`-C`/`-p` mode flags, and NMP connection plans that make the local side
  the hub server and the remote side the hub client. Measured hub route evidence
  remains required before any `PASS` claim.
- JT-05C is complete for unauthenticated TCP hub handshake modeling: JackTrip now
  has a Swift-native codec for the public TCP UDP-port exchange, optional fixed
  remote-client-name framing, media-report handshake state, launch-plan/session/
  connection-plan propagation, and malformed/auth-code rejection tests.
- JT-05D is complete for local auth/TLS protocol framing: JackTrip now has auth
  response codes, authenticated request/client-info frame encoding, credential
  length validation, redacted report state, and tests proving credentials are not
  persisted in reports. Measured TLS peer evidence remains required before any
  field-readiness or `PASS` claim.
- JT-06E is complete for local EMPTY header runtime behavior: JackTrip now has
  `--jacktrip-header empty`, raw planar PCM datagram encoding without the DEFAULT
  header, explicit session-derived decode metadata, report propagation, and
  fail-loud rejection for redundancy because headerless datagrams cannot delimit
  concatenated DEFAULT packets.
- JT-06C is complete for local JAMLINK header runtime behavior: JackTrip now has
  `--jacktrip-header jamlink`, compact stream-type bitfield encoding/decoding
  for representable 16-bit mono/stereo PCM, sequence and timestamp propagation,
  and malformed/unrepresentable header rejection.
- JT-06A is complete for WebRTC packet support: JackTrip now has a native
  WebRTC data-channel packet model using the same packet bytes as UDP and
  length-prefixed JSON signaling frame helpers. ICE/DTLS peer evidence remains
  required before any field-readiness or `PASS` claim.
- JT-06B is complete for WebTransport packet support: JackTrip now has a native
  WebTransport datagram model with QUIC varint quarter-stream ID prefix
  handling. HTTP/3/msquic peer evidence remains required before any
  field-readiness or `PASS` claim.
- JT-06D is complete for plugin bridge mode: JackTrip now has
  `--jacktrip-plugin audio-bridge` configuration and launch-plan propagation as
  an explicit plugin-host boundary over the native packet runtime.
- JT-06F is complete for non-PCM source-level support: JackTrip now has
  `--jacktrip-payload-encoding opus-celt-low-delay` and an Open LoLa Opus
  extension envelope backed by the existing vendored Opus bridge.
- JT-07 is complete for validator scaffolding: JackTrip media reports can only
  validate `PASS` when all required runtime evidence classes are observed,
  missing evidence is empty, no runtime error is present, and a real link was
  used. Synthetic/incomplete PASS remains rejected.
- SH-01 is complete: public source contracts, schema inventory, app-shell
  availability tests, docs, release hygiene, and skip-loud parity tooling remain
  aligned with the bounded evidence boundary.
- Broad local Swift verification is green after splitting the UltraGrid
  compatibility implementation across provider, media-I/O, and runner files to
  stay inside the source line-budget contract.
- Current media-report validators reject incomplete `PASS`; evidence-gated
  `PASS` remains blocked until reference-peer and live runtime evidence exists.
- UG-03 is blocked only for measured external reference-peer evidence. That
  must block interoperability and `PASS` claims, not implementation-capable
  runtime work.
- JT-03 is blocked on external reference-peer host evidence and a local
  `jacktrip` executable. That must block interoperability and `PASS` claims,
  not implementation-capable runtime work.
- Measured JACK graph runtime evidence remains unavailable in this environment;
  that blocks field-readiness claims, not dry-run packet support.
- UltraGrid JPEG/H.264 implementation work is complete for local RTP packet
  handling; reference-peer parity still blocks field-readiness claims.
- `PASS` remains blocked until measured external peer, live-device, field-route,
  timing, packet-quality, teardown, and media-quality evidence exists.

## Next Slice

External reference-peer evidence capture is the next non-local evidence slice.
UG-03 and JT-03 still wait for external reference-peer prerequisites, but those
rows now block measured interop evidence and final `PASS`, not runtime
implementation that can be built and tested locally.

## Counts

| Priority | Open | Blocked | Done |
| --- | ---: | ---: | ---: |
| P0 | 0 | 0 | 3 |
| P1 | 0 | 2 | 7 |
| P2 | 0 | 0 | 12 |
| P3 | 0 | 0 | 5 |

## Verification For This Planning Packet

Verification completed for RT-00:

```bash
swift test --filter ExternalConnectorReportTests
swift test --filter ReportSchemaInventoryTests
swift test --filter SyntheticSmokeReportContractTests
swift test --filter UltraGridCompatibilityTests
swift test --filter UltraGridDynamicRTPTests --no-parallel
swift test --filter UltraGridCompatibilityTests --no-parallel
swift test --filter JackTripCompatibilityTests
bash scripts/verify-docs.sh
git diff --check
```

Additional implementation verification completed:

```bash
swift test --filter UltraGridCompatibilityTests
swift test --filter JackTripCompatibilityTests
swift test --filter JackTripTopologyTests --no-parallel
swift test --filter JackTripCompatibilityTests --no-parallel
swift test --filter JackTripPassValidationTests --no-parallel
swift test --filter ExternalConnectorConnectionPlanTests --no-parallel
swift test --filter JackTripTCPHandshakeTests --no-parallel
swift test --filter ReportFixtureValidationContractTests --no-parallel
swift test --filter ExternalConnectorSessionTests
swift test --filter ExternalConnectorAvMatrixTests
swift test --filter VideoTransportRunnerTests
swift test --filter ExternalConnectorConnectionPlanTests
swift test --filter ExternalConnectorNmpPlanTests
swift test --filter ExternalConnectorNmpWorkflowTests
swift test --filter ReportFixtureValidationContractTests
swift test --filter ExternalConnectorReportTests
command -v jackd
swift test --filter ReportSchemaInventoryTests
swift test --filter ExternalConnectorReportTests
swift test --filter CodeLineBudgetTests
swift test --filter SourceOwnershipInventoryTests
swift test --filter ReleaseArtifactHygieneContractTests
swift test --filter VerificationToolingPairScriptTests
swift test --filter SyntheticSmokeReportContractTests
swift test --filter AppShellSlice05Tests
swift build
swift test --no-parallel
bash scripts/run-reference-peer-parity-gate.sh /private/tmp/open-lola-reference-peer-parity-ultragrid ultragrid
bash scripts/run-reference-peer-parity-gate.sh /private/tmp/open-lola-reference-peer-parity-jacktrip jacktrip
bash scripts/verify-docs.sh
bash scripts/verify-release-hygiene.sh
git diff --check
```

The two reference-peer parity gates exited 77 as skip-loud readiness reports,
not measured interoperability passes.

Latest blocker recheck:

- UltraGrid parity gate:
  `/private/tmp/open-lola-reference-peer-parity-ultragrid/reference-peer-parity-gate.json`
  reported `missingPrerequisites: ["OPEN_LOLA_REFERENCE_PEER_HOST"]`.
- JackTrip parity gate:
  `/private/tmp/open-lola-reference-peer-parity-jacktrip/reference-peer-parity-gate.json`
  reported `missingPrerequisites: ["OPEN_LOLA_REFERENCE_PEER_HOST", "JackTrip executable: jacktrip"]`.
