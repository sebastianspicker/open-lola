# UltraGrid and JackTrip Connector Remediation Plan

Date: 2026-05-18
Source audit: `plan-draft.md`
Status: active remediation plan
Verdict: PARTIAL until measured external peer evidence exists

## Summary

This plan turns the UltraGrid and JackTrip gap audit into reviewable remediation
slices. The priority order is verification trust, false-success prevention,
packet/datagram correctness, receive analysis, live media integration, and only
then measured reference-peer evidence.

Current audit baseline:

- The dirty worktree already contains first-slice Swift-native UltraGrid and
  JackTrip connector work.
- Focused connector/session/app tests are mostly green.
- The expanded focused gate is blocked by a release-hardening fixture/test
  mismatch in `ReportSchemaInventoryTests`: the validator reports
  `claimUsesInternalEvidence(...)` before `passWithoutMeasuredRun`.
- No connector should claim real-world `PASS` until external peer, route, and
  media evidence are measured.

## Remediation Slices

### 1. Restore verification trust

- Fix the `ReportSchemaInventoryTests` false-pass fixture or expectation so the
  expected boundary reason matches current validator policy.
- Verify `swift test --filter ReportSchemaInventoryTests`.
- Do not change connector behavior in this slice.

Definition of done:

- `ReportSchemaInventoryTests` passes on its own.
- The false-pass fixture still proves that synthetic `PASS` evidence is
  rejected by the public validator surface.

### 2. Harden evidence and report contracts

- Make connector reports distinguish synthetic, local loopback, reference-peer,
  live-device, and field evidence.
- Keep UltraGrid and JackTrip media verdicts below `PASS` unless measured
  external peer and route evidence exists.
- Update report schema inventory, fixtures, validators, and source-contract docs
  in one reviewable change.

Definition of done:

- Reports cannot silently promote synthetic or local-only runs to real-world
  success.
- Fixture and schema inventory tests cover the evidence boundary.

### 3. Complete JackTrip DEFAULT packet correctness

- Implement DEFAULT channel sentinel behavior for supported modes.
- Either narrow unsupported bit-depth claims or implement missing conversions.
- Model redundancy as multiple complete JackTrip packets in one UDP datagram.
- Report filtered stop-control datagrams instead of hiding them.

Definition of done:

- Tests cover DEFAULT sentinels, malformed headers, redundancy encode/decode,
  unsupported bit depths, and stop-control accounting.

### 4. Complete JackTrip UDP runtime semantics

- Complete P2P peer learning from inbound UDP source endpoints.
- Track sequence gaps, duplicates, out-of-order packets, loss, and redundancy
  recovery.
- Report QoS/DSCP or macOS service-class attempts as applied, failed, or
  unavailable without treating them as field success.

Definition of done:

- Local UDP tests prove learned-peer behavior and sequence/redundancy counters.
- Runtime reports expose packet-quality evidence instead of only packet counts.

### 5. Complete UltraGrid RTP/MVTP receive analysis

- Track SSRC, sequence, RTP timestamp, packet loss, duplicates, reorder events,
  and frame reassembly failures.
- Populate existing report counters from observed receive data.
- Keep FEC, encryption, H.264/JPEG, and advanced UltraGrid control APIs
  fail-loud until implemented with public packet evidence.

Definition of done:

- Unit tests cover normal sequence, gaps, duplicates, reordering, timestamp
  mismatch, SSRC changes, and partial raw-video frame reassembly.

### 6. Make UltraGrid generated payloads field-realistic

- Remove the small generated raw-video payload cap for explicit generated-frame
  tests.
- Fragment and reassemble full configured raw frames.
- Add media provider injection so generated media, fixtures, and future live
  media use the same runner path.

Definition of done:

- A generated 640x360 RGB frame produces the expected fragment count and
  reassembles byte-for-byte.
- Report byte and packet counters reflect the full configured frame.

### 7. Integrate shared live media providers

- Reuse or generalize existing native audio/video bridges without adding
  blocking work to realtime paths.
- Add injectable CoreAudio, MADI/direct-audio, or deterministic fixture audio
  providers for connector TX/RX paths.
- Add generated and AVFoundation raw-video providers for UltraGrid.
- Keep live-device success separate from synthetic and reference evidence.

Definition of done:

- Tests with deterministic providers prove provider bytes reach encoded packets.
- Optional live-device smoke reports remain `PARTIAL` unless external peer
  evidence is also present.

### 8. Add measured reference-peer parity gates

- Keep uv, UltraGrid, and JackTrip helpers as reference tools, not primary
  runtime.
- Add opt-in Swift-native TX to reference RX and reference TX to Swift-native RX
  scripts.
- Produce machine-readable artifacts: command line, environment, packet counts,
  reference logs, report JSON, and validator output.

Definition of done:

- Parity scripts skip clearly when reference images or binaries are missing.
- Successful parity creates evidence but does not promote product verdict to
  `PASS` without defined field thresholds.

### 9. Keep app and docs truthful

- Keep JackTrip and UltraGrid app modes CLI/planning-only unless a separate app
  runtime slice is requested.
- Update app labels and tests only to avoid misleading launchability or
  readiness claims.
- Update `docs/source-contracts.md`, `scripts/README.md`, report fixtures, and
  schema inventory whenever connector public contracts change.

Definition of done:

- The app does not imply JackTrip or UltraGrid can be launched internally from
  the UI.
- Active docs match the implemented runtime and evidence boundaries.

## Verification Plan

Run the narrowest relevant gate after each slice, then broaden before handoff:

```bash
swift test --filter ReportSchemaInventoryTests
swift test --filter JackTripCompatibilityTests
swift test --filter UltraGridCompatibilityTests
swift test --filter ExternalConnectorSessionTests
swift test --filter ExternalConnectorProcessGroupTests
swift test --filter ExternalConnectorReportTests
swift test --filter AppShellSlice05Tests
swift test --no-parallel
swift build
bash scripts/verify-docs.sh
bash scripts/verify-release-hygiene.sh
```

Parity and hardware gates are opt-in and must name their prerequisites. Do not
run them silently as a substitute for unit or report-schema validation.

## Assumptions

- First supported modes remain unencrypted/no-FEC UltraGrid RTP/MVTP PT20/PT21
  and JackTrip UDP DEFAULT 16-bit PCM.
- UltraGrid FEC, encryption, H.264/JPEG, dynamic codec modes, and advanced
  control APIs are deferred.
- JackTrip hub, TLS/auth, WebRTC, WebTransport, JACK graph integration,
  plugins, JamLink, and non-PCM or non-16-bit audio modes are deferred.
- No production dependency is added without explicit approval.
- `plan-draft.md` remains the supporting audit record unless explicitly
  archived or removed.
