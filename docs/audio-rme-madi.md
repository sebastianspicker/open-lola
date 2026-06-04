# RME MADI Audio Plan

Date: 2026-05-21
Status: source-level RME/MADI architecture and validation gates implemented; physical RME evidence pending
Verdict: PARTIAL

## Evidence Labels

| Design choice | Label |
|---|---|
| Core Audio HAL, `AudioDeviceIOProc`, AUHAL, and device property access | `public API` |
| RME MADI as the first professional hardware target | `implementation hypothesis` |
| Rejection of sample-rate conversion for fastest mode | `original open-lola design` |
| Fixture and loopback reports as closure evidence | `experimentally derived requirement` |

## Objective

Make professional low-latency Core Audio hardware the first implementation
priority. RME MADI or compatible hardware is the initial target because it can
expose stable low-buffer operation through macOS drivers.

## Public API Path

Use public macOS Core Audio APIs:

- Core Audio device enumeration;
- `AudioDeviceIOProc` or AUHAL for full-duplex IO;
- host-time and device-time reporting;
- device buffer size and sample-rate properties.

RME-specific control is limited to public driver-visible behavior unless an
official public SDK path is selected later.

## Core Audio HAL Property API Compatibility

Checked 2026-05-22 against Apple Developer documentation and the local Xcode
26.3 macOS 26.2 SDK.

Decision: keep the current `AudioObjectGetPropertyData`,
`AudioObjectGetPropertyDataSize`, and `AudioObjectSetPropertyData` HAL calls
while the package targets macOS 14. Apple documents these as public Core Audio
functions, and the newer `AudioHardwareObject.propertyData(address:qualifier:)`
and `AudioHardwareObject.setPropertyData(address:qualifier:data:)` helpers are
macOS 15+ in the local SDK.

The accepted boundary is narrow: direct HAL property access remains in typed
helpers under `CoreAudioInventoryReader.swift` and `AudioLoopbackHelpers.swift`.
Do not spread raw property calls into unrelated runtime code. Revisit migration
when the package deployment target moves to macOS 15+ and property-set behavior
can be checked on real devices.

## Device Enumeration

The reference rig report must record:

- device name, UID, manufacturer, transport, and clock domain;
- input and output stream/channel counts;
- Core Audio stream-derived input/output channel layout snapshots;
- nominal sample rate and available ranges;
- buffer frame size and accepted candidates;
- safety offsets and device latency where reported;
- aggregate-device status;
- driver, firmware, and TotalMix state when known.

## Sample Rate Strategy

Benchmark 48 kHz, 96 kHz, and 192 kHz. The default is the fastest stable
corrected one-way mode, not the highest rate. Sample-rate conversion is rejected
for fastest mode.

## Channel Strategy

Stereo remains the explicit UDP PCM v1 fallback and fixture lane. The active
source path now supports MADI-scale UDP PCM v2 channel-range fragments,
negotiated channel counts, selected channel maps, receiver-local mix snapshots,
and full-duplex MADI reports. Do not claim multichannel `PASS` or send unused
channels in the fastest default profile until the selected physical RME route,
callback behavior, packet capture, and loopback/output evidence are measured.

## Buffer Strategy

Benchmark 16, 32, 64, and 128 frames where the hardware accepts them. PASS
requires stability, callback deadline evidence, no hidden buffering, and analog
loopback latency evidence.

## Fastest Path PASS Gate

The RME fastest-audio report can only pass when the selected mode is measured as
the fastest stable analog loopback mode and the inventory agrees with that mode:

- selected sample rate is inside the reported Core Audio sample-rate ranges;
- selected buffer frame count is in the inventory's reported candidate set;
- selected channel count fits both input and output channel layouts;
- clock domain is recorded;
- device and route are not aggregate or multi-output paths;
- sample-rate conversion is absent;
- driver mode is known and uses a dedicated RME driver path.

## Low-Copy And Realtime Strategy

- preallocate audio rings and packet buffers;
- avoid `Data` allocation in callbacks;
- keep socket operations outside the callback;
- use lock-free counters for underruns, overruns, late packets, and drops;
- run drift correction and report writing outside the realtime path.

## Measurement Hooks

Required outputs:

- one-way latency estimate;
- round-trip latency where applicable;
- jitter;
- underruns and overruns;
- callback interval p50/p95/p99/max;
- memory allocation warnings on realtime path;
- CPU load;
- thread scheduling warnings;
- hardware mode and route identity.

## Validation

Use test tones and impulse loopbacks. Built-in devices and synthetic fixtures
can validate code shape, but cannot close RME MADI hardware gates.

## Resume here

Resume at Q001/F01: connect the real RME path, run Core Audio inventory,
choose same-device input/output UIDs, run the loopback matrix, and attach
packet-captured MADI TX/RX evidence before promoting any route to `PASS`.

VERDICT: PARTIAL
