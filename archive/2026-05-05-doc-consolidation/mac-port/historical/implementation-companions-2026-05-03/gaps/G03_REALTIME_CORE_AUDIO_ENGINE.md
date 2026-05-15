# G03 Realtime Core Audio Engine

## LoLa Comparison

LoLa's audio path keeps the callback bounded and uses a fixed remote playback
ring. The Mac engine must make the Core Audio callback the deadline owner and
move sockets, report writing, allocation, logging, and UI outside the callback.

## Current Repo State

- Related milestone: [../prototype/P02_REALTIME_AUDIO_ENGINE.md](../prototype/P02_REALTIME_AUDIO_ENGINE.md)
- Live status: [../prototype/status/P02_STATUS.md](../prototype/status/P02_STATUS.md)
- Existing source has report contracts, UDP packet types, route runners, a
  simple IOProc loopback runner, and a G03 `RealtimeAudioEngineReport`
  validator.
- G03 source validation now includes a bounded `RealtimeAudioBlockRing`, a
  due-block playout helper, callback-safety PASS gates, packet-handoff metrics,
  a partial fixture, `open-lola validate-realtime-audio-engine-report <path>`,
  and `open-lola realtime-audio-synthetic-smoke`.
- Missing piece: a production measured runtime that uses the selected RME path
  as the actual Core Audio callback owner and hands packets to/from a real
  two-Mac route.

## Implementation Plan

1. Add a small `RealtimeAudioEngine` boundary around the selected RME UID,
   sample rate, frame count, channel map, and wire format.
2. Preallocate input, output, network-send, network-receive, and metrics rings
   before `AudioDeviceStart`.
3. In the callback, do only bounded copy/mix, due-block playout, silence or
   same-deadline PLC, and counter increments.
4. Run UDP send/receive, report aggregation, drift correction, logging, and disk
   writes on non-realtime threads.
5. Add tests that fail if the engine API allows callback-time allocation,
   unbounded queue growth, blocking locks, file I/O, socket setup, or logging.
6. Add a short CLI runtime smoke after unit tests, then reuse the same engine
   for M05/M06 physical runs.

## Acceptance Tests

- Focused unit tests cover ring bounds, due-block behavior, callback safety
  PASS guards, bounded handoff accounting, and shutdown evidence.
- Runtime report records callback p99/max, underruns, overruns, missed
  deadlines, packet handoff, hidden playout growth, and shutdown.
- PASS reports cannot be emitted by synthetic-only or built-in-only paths.
- Callback safety rules are documented in P02 status before PASS, and the
  validator rejects PASS if allocation, logging, file I/O, locks/unbounded
  waits, network setup, or report writing are allowed in the callback.

## Blockers / TODO(human)

- Depends on G02 selected RME UID and fastest stable mode.
- TODO(human): [Realtime audio default] -> Confirm whether the first wire format should be float32 or int16 after RME inventory exists -> [float32 native / int16 LoLa baseline / benchmark both]

## Verification Commands

```bash
swift test --filter RealtimeAudio
swift run open-lola validate-realtime-audio-engine-report <validated-g03-report.json>
swift run open-lola realtime-audio-synthetic-smoke
swift run open-lola audio-loopback-run --input-uid <uid> --output-uid <uid> --sample-rate <hz> --frames <n> --duration-seconds 60 --output mac-port/reports/<report>.json
swift test
```

## Resume here

Wire the measured RME Core Audio callback owner into the G03 report after G02
provides an accepted RME hardware mode, then replace the synthetic report with
real packet-handoff and callback metrics.

VERDICT: PARTIAL
