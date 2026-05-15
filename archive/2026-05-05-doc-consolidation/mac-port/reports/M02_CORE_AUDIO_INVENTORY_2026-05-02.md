# M02 Core Audio Inventory Validation Report

Date: 2026-05-02  
Milestone: [M02 Core Audio Device Inventory](../milestones/M02_CORE_AUDIO_DEVICE_INVENTORY.md)  
Status: PASS

## Scope

This report validates the M02 read-only Core Audio inventory path. It does not
measure analog loopback latency, callback p99/max, hidden sample-rate
conversion, or fastest endpoint mode. Those remain M03 work.

## Commands

```bash
swift test
swift build
swift run open-lola
swift run open-lola device-inventory
bash scripts/verify-docs.sh
shellcheck scripts/*.sh
```

## Local Device Probe

`swift run open-lola device-inventory` completed successfully on the local Mac
and emitted pretty-printed JSON. The probe captured 3 Core Audio devices.

The raw local JSON is not checked in because it includes host and device
identifiers. The committed machine-readable sample fixture is
[core-audio-inventory-valid.json](../../Tests/OpenLolaCoreTests/Fixtures/CoreAudioInventory/valid/core-audio-inventory-valid.json).

Observed fields in the local JSON:

- device id, name, UID, manufacturer, transport type, and aggregate-device flag;
- input/output channel and stream counts;
- nominal sample rate and available sample-rate ranges;
- current buffer-frame size and reported buffer-frame range;
- candidate buffer frames classified inside and outside the reported range;
- input/output latency frames and safety offsets;
- clock domain;
- diagnostic notes that explicitly mark API latency as diagnostic only.

## Verdict

M02 satisfies its read-only inventory and serialization gate.

VERDICT: PASS

## Resume here

Start [M03](../milestones/M03_ENDPOINT_LOOPBACK_FASTEST_MODE.md) by using the
inventory output to select a test device, then run the first 32-frame analog
loopback probe before filling the full 16/32/64/128-frame matrix.
