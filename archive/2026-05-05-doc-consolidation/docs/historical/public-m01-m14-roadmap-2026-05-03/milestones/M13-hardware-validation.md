# M13 Hardware Validation

Date: 2026-05-03  
Status: publication-safe milestone plan  
Verdict: PARTIAL

## Objective

Validate the integrated profile against the real reference hardware and network
routes.

## Scope

Cover RME MADI or compatible audio hardware, Blackmagic/ATEM video path,
direct/switch/campus routes, lighting/control bridge, and field run evidence.

## Affected Files

- [../architecture/audio-rme-madi.md](../architecture/audio-rme-madi.md)
- [../architecture/video-blackmagic-atem.md](../architecture/video-blackmagic-atem.md)
- [../architecture/lighting-control.md](../architecture/lighting-control.md)
- [../architecture/benchmark-methodology.md](../architecture/benchmark-methodology.md)
- `mac-port/OPEN_QUESTIONS.md`
- `mac-port/PROGRESS.md`
- `mac-port/reports/`

## Implementation Tasks

- Record final hardware identity, driver versions, firmware, OS version, and
  cabling.
- Run accepted audio, video, control, and integrated benchmark matrix.
- Record route labels, packet capture points, and venue constraints.
- Separate field evidence from synthetic and lab evidence.

## Test Plan

- Validate all hardware reports.
- Run full source test matrix relevant to touched report validators.
- Verify docs and report links.

## Benchmark Plan

Run RME, Blackmagic/ATEM, route, OSC, and lighting benchmarks on the physical
rig. Repeat enough to expose stability and warm-run behavior.

## Acceptance Criteria

- Physical rig evidence exists.
- No synthetic report is used for PASS.
- Audio latency remains within the accepted fastest profile.
- Hardware and route identities are complete.

### Implementation Addendum

The source-level M13 implementation now lives in
`Sources/OpenLolaCore/HardwareValidationReport.swift` and
`Sources/OpenLolaCore/HardwareValidationRun.swift`. It defines an aggregate
hardware-validation report for:

- reference-rig identity;
- RME MADI fastest-audio evidence;
- Blackmagic/ATEM video path evidence;
- ATEM read-only control evidence;
- OSC-to-lighting bridge evidence;
- integrated-profile evidence;
- direct, dedicated-switch, and campus route evidence;
- field-run duration, evidence boundary, and machine-readable verdict.

PASS validation rejects:

- synthetic run mode;
- synthetic evidence in any lane;
- missing measured or physical evidence;
- non-PASS subordinate evidence;
- missing direct, dedicated-switch, or campus route rows;
- unclassified or harmful DSCP results on PASS routes;
- field runs shorter than 30 minutes;
- PASS claims that do not separate field evidence from synthetic/lab evidence;
- PASS claims where the fastest profile is not within accepted latency;
- placeholder hardware, route, packet-capture, cabling, or firmware fields;
- non-RME-MADI audio identity;
- missing Blackmagic/ATEM production identity.

The CLI surface is:

```bash
open-lola validate-hardware-validation-report <path>
open-lola hardware-validation-synthetic-smoke
open-lola hardware-validation-run --reference-rig <path> --rme-fastest-audio <path> --video-capture <path> --atem-control <path> --lighting-gate <path> --integrated-profile <path> --field-run-report <id> --duration-seconds <seconds> --output <path>
```

This is a source-level contract and report aggregator. It does not manufacture
physical evidence. The milestone remains `PARTIAL` until the real RME,
Blackmagic/ATEM, lighting bridge, direct/switch/campus routes, packet captures,
and field run are attached.

## Risks

- Hardware availability may be intermittent.
- Venue routes may differ from lab routes.
- Driver updates can invalidate previous measurements.

## Blockers

Q001-Q012 hardware, route, lighting, and field facts as applicable.

## Rollback Plan

Keep lab/source validation as PARTIAL and do not claim field readiness.

## Progress Checklist

- [x] Hardware validation source contract implemented.
- [x] PASS/PARTIAL boundaries audited at source level.
- [x] Synthetic fixture and smoke report stored.
- [ ] Real hardware identity recorded.
- [ ] Real route identity recorded.
- [ ] Full physical matrix run.
- [x] M13 source-validation report stored.

## Resume Point

Resume at M13 physical evidence capture: run the RME, Blackmagic/ATEM,
lighting/control, direct-link, dedicated-switch, campus-route, and integrated
field matrix; then validate the aggregate with
`open-lola validate-hardware-validation-report <path>`. Resume at M14 only
after the physical evidence boundary is clean and documented.

VERDICT: PARTIAL
