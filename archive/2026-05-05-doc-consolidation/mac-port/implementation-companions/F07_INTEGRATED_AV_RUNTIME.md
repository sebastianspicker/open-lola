# F07 Integrated AV Runtime

Date: 2026-05-03
Status: required 30-minute integrated proof
Verdict: PARTIAL

## Finding

The current integrated A/V source layer can compose bounded reports and now
rejects PASS unless the report includes an explicit 30-minute A/V overlap
window, cross-referenced subordinate report IDs, and concrete packet-capture
points. It has not run the required 30-minute measured runtime with RME audio,
Blackmagic video, ATEM read-only status, OSC cue traffic, and unchanged audio
timing.

## Current Surface

- [../../Sources/OpenLolaCore/IntegratedAvReport.swift](../../Sources/OpenLolaCore/IntegratedAvReport.swift)
  validates integrated reports, run-window evidence, subordinate report IDs,
  capture points, and audio-impact regressions.
- `open-lola integrated-av-run` writes bounded reports from supplied baseline
  inputs and records synthetic A/V overlap plus subordinate F05/F06 report
  references for source-level handoff.

## Required Inputs

- F01 RME hardware PASS or explicit PARTIAL blocker.
- F02 realtime engine PASS or measured report under test.
- F03 direct P2P route PASS.
- F04 drift/PLC fixed-target evidence.
- F05 Blackmagic/ATEM capture identity.
- F06 video transport or explicitly local preview-only video mode.
- M11 OSC cue loop report.
- ATEM read-only status report if ATEM hardware is in the rig.

## Required Runtime Proof

- Duration at least 30 minutes.
- Audio p99/max, playout target, loss, late packets, and underruns are recorded
  before and during the integrated run.
- Video frame age and drops are recorded.
- ATEM polling is read-only and bounded.
- OSC cue loop is bounded and independent of audio scheduling.
- Any overload drops or disables video/control before audio playout changes.
- PASS report IDs cross-reference the audio baseline, integrated report, video
  capture report, video transport or preview report, OSC report, and ATEM
  read-only report.
- PASS capture points include at least the accepted audio route packet-capture
  point and, when video transport is enabled, the video packet-capture point.

## PASS Criteria

- Integrated report emits `VERDICT: PASS` only with measured hardware evidence.
- Run-window overlap is at least 1,800 seconds.
- Audio timing is unchanged from the accepted audio-only baseline.
- Video/control/ATEM evidence is concrete, not synthetic.
- All report IDs and capture points are non-placeholder and cross-referenced.

## Resume here

Do not run the integrated proof until F01-F06 have measured reports or explicit
PARTIAL blockers. Then run the 30-minute headless test and validate the
integrated report.

VERDICT: PARTIAL
