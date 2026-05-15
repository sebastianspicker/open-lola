# P02 Realtime Audio Engine

## Objective

Implement the actual Core Audio I/O loop and UDP PCM route, using RME MADI as
the measured reference path.

## Background/Context

The existing source validates report contracts and packet formats. P02 is the
prototype milestone that moves from schema and smoke probes to the realtime
audio path: Core Audio input/output callbacks, bounded handoff, UDP PCM
sender/receiver integration, and measured route telemetry.

## Canonical Roadmap Links

- [../milestones/M03_ENDPOINT_LOOPBACK_FASTEST_MODE.md](../milestones/M03_ENDPOINT_LOOPBACK_FASTEST_MODE.md)
- [../milestones/M04_UDP_PCM_PACKET_CONTRACT.md](../milestones/M04_UDP_PCM_PACKET_CONTRACT.md)
- [../milestones/M05_MAC_TO_MAC_ROUTE_CERTIFICATION.md](../milestones/M05_MAC_TO_MAC_ROUTE_CERTIFICATION.md)
- [../milestones/M06_DRIFT_AND_SAME_DEADLINE_PLC.md](../milestones/M06_DRIFT_AND_SAME_DEADLINE_PLC.md)
- [P01_RME_MADI_HARDWARE_PATH.md](P01_RME_MADI_HARDWARE_PATH.md)

## Assumptions

- P01 has selected visible RME input/output device UID values.
- UDP PCM packet shape remains the existing M04 contract.
- Logging, allocation, file I/O, network setup, and report writing stay outside
  the realtime callback.
- The first implementation is headless and CLI-owned.

## Dependencies

- P01 RME device visibility and loopback evidence.
- Existing UDP PCM packet contract.
- Wired route for two-Mac measurement.
- Packet capture point for DSCP and route correlation.

## Affected Modules/Files

- [../../Sources/OpenLolaCore/UdpPcmPacket.swift](../../Sources/OpenLolaCore/UdpPcmPacket.swift)
- [../../Sources/OpenLolaCore/UdpPcmRouteCertification.swift](../../Sources/OpenLolaCore/UdpPcmRouteCertification.swift)
- [../../Sources/OpenLolaCore/DriftPlcReport.swift](../../Sources/OpenLolaCore/DriftPlcReport.swift)
- [../../Sources/open-lola/main.swift](../../Sources/open-lola/main.swift)
- [status/P02_STATUS.md](status/P02_STATUS.md)

## Implementation Plan

1. Add a headless audio engine module around Core Audio input/output callbacks.
2. Use fixed-size, preallocated buffers and a lock-free or bounded
   realtime-safe ring handoff.
3. Add UDP PCM sender/receiver integration using the existing packet contract.
4. Add CLI commands for single-host loopback, sender, receiver, and two-Mac
   route measurement.
5. Record callback p99/max, packet age, late packets, lost packets, underruns,
   drift, and playout target.
6. Keep every non-realtime operation outside the callback.

## Realtime Callback Safety Checklist

- [x] Source validator rejects PASS if allocation is allowed in callback.
- [x] Source validator rejects PASS if logging is allowed in callback.
- [x] Source validator rejects PASS if file I/O is allowed in callback.
- [x] Source validator rejects PASS if locks or unbounded waits are allowed in
  callback.
- [x] Source validator rejects PASS if network setup is allowed in callback.
- [x] Bounded handoff helper drops on overflow and reports counters.
- [x] Source validator rejects PASS if report writing happens before stop.
- [ ] Measured Core Audio callback proof on the selected RME path.
- [ ] Measured two-Mac packet handoff using the same engine boundary.

## Companion Status Fields

[status/P02_STATUS.md](status/P02_STATUS.md) records:

- realtime callback safety checklist;
- selected RME input/output UID and sample format;
- route topology: single-host, direct wired, switch, or campus;
- packet capture point and DSCP observation;
- drift/PLC run status.

## Test Plan

Before: report contracts and synthetic route smoke exist, but no realtime Core
Audio I/O loop is proven.

After:

- `swift build` passes;
- `swift test` passes;
- `bash scripts/verify-docs.sh` passes;
- `shellcheck scripts/*.sh` passes;
- RME loopback run records no callback violations;
- two-Mac wired route produces a measured report;
- `swift run open-lola validate-route-report <path>` passes;
- `swift run open-lola validate-drift-plc-report <path>` passes when drift/PLC
  evidence is included.

## Validation Method

Compare route telemetry against the RME loopback baseline. P02 cannot claim PASS
unless callback p99/max, underruns, lost packets, late packets, drift, and
playout target are recorded from the actual route under test.

## Acceptance Criteria

- RME loopback runs without callback violations.
- Two-Mac wired route produces a measured report with packet capture
  correlation.
- M03, M05, and M06 can move from PARTIAL toward PASS using real data.
- All non-realtime operations are outside the callback path.

## Risks and Mitigations

- Callback code can accidentally allocate or block. Mitigation: keep the
  callback surface small and test the safety checklist before accepting a run.
- UDP send/receive setup may leak into realtime work. Mitigation: create and
  bind sockets before callbacks start.
- Route timing may look acceptable on localhost only. Mitigation: require
  wired two-Mac measurement for PASS.

## Known Blockers

- Requires P01 RME hardware selection.
- Requires a second Mac or agreed two-host wired route for PASS.
- Requires packet capture access for route correlation.

## Progress Checklist

- [ ] Add measured Core Audio I/O loop on selected RME hardware.
- [x] Add bounded realtime-safe handoff source helper.
- [ ] Integrate UDP PCM sender/receiver with existing packet contract.
- [x] Add CLI source validator and synthetic smoke for the engine report.
- [ ] Add measured engine loopback, sender, receiver, and two-Mac measurement
  commands.
- [x] Record callback, packet, underrun, and playout metrics in the G03 report
  contract.
- [ ] Record measured drift metrics through the M06 path.
- [ ] Validate route and drift/PLC reports.
- [ ] Update [status/P02_STATUS.md](status/P02_STATUS.md).

## Next Recommended Action

After P01 records RME UID values, replace the synthetic G03 proof with the
smallest measured Core Audio callback owner that can feed and drain the
preallocated handoff and emit a `RealtimeAudioEngineReport`.

## Resume here

Start from [status/P02_STATUS.md](status/P02_STATUS.md), then wire the measured
RME callback owner into the existing G03 report validator after P01 has a
visible RME device and at least one measured loopback row.
