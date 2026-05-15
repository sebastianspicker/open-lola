# G01 Measurement Rig And Reference Hardware

## LoLa Comparison

LoLa depends on tightly specified workstations, professional audio hardware,
specific video devices, and clean 1 Gbps-class network paths. The Mac-native
alternative cannot claim faster-than-LoLa behavior until the reference Macs,
audio interface, route labels, packet-capture points, and PASS thresholds are
stable enough for repeated measurement.

## Current Repo State

- Related milestone: [../milestones/M01_MEASUREMENT_HARDWARE_NETWORK_PROFILE.md](../milestones/M01_MEASUREMENT_HARDWARE_NETWORK_PROFILE.md)
- Live status: [../status/M01_STATUS.md](../status/M01_STATUS.md)
- Open question: Q001 in [../OPEN_QUESTIONS.md](../OPEN_QUESTIONS.md)
- Existing code now validates both broad M01 measurement fixtures and the
  stricter G01 reference-rig report shape. The checked-in G01 fixture remains
  PARTIAL and uses explicit `TODO(human)` fields rather than inferred hardware
  labels.
- Current local inventory shows only Apple built-in/iPhone devices and no RME
  hardware.

## Implementation Plan

1. Define two reference Macs with exact model, Apple silicon generation, RAM,
   macOS version/build, Ethernet adapter path, and power settings.
2. Define the reference audio path: RME MADI model, driver package, firmware,
   TotalMix route, clock source, input/output channel labels, and cable loop.
3. Define the reference network profiles: single-host, direct wired link,
   dedicated switch, and campus path, each with interface names, IP addresses,
   VLAN state, DSCP policy, and packet-capture location.
4. Add a measured M01 report file only after those values are real. Do not
   replace unknown fields with inferred labels.
5. Update `M01_STATUS.md`, `OPEN_QUESTIONS.md`, and `PROGRESS.md` only when
   the measured report validates and Q001 facts are concrete.

## Acceptance Tests

- `swift run open-lola device-inventory`
- `swift run open-lola validate-reference-rig-report Tests/OpenLolaCoreTests/Fixtures/ReferenceRigReports/valid/reference-rig-partial.json`
- `swift test`
- `bash scripts/verify-docs.sh`
- `shellcheck scripts/*.sh`
- Measured M01 report validates with exact hardware and route fields.

## Blockers / TODO(human)

- TODO(human): [M01 hardware inventory] -> Identify the real reference Macs, RME MADI path, and route labels -> [Use current HfMT Mac pair / borrow dedicated test Macs / defer hardware closure]
- Requires physical access to both Macs, RME interface, cabling, and network
  capture points.

## Verification Commands

```bash
swift run open-lola device-inventory
swift run open-lola validate-reference-rig-report Tests/OpenLolaCoreTests/Fixtures/ReferenceRigReports/valid/reference-rig-partial.json
swift test
bash scripts/verify-docs.sh
shellcheck scripts/*.sh
```

## Resume here

Fill the explicit `TODO(human)` fields in the G01 reference-rig report with
real hardware identities first. Do not start fastest-mode claims until Q001 has
a dated evidence row.

VERDICT: PARTIAL
