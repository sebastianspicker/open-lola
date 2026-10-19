# RME MADI routing

In code today: the macOS runtime has RME matrix metadata models and route
reports. Nothing reads or sets a TotalMix matrix, and no RME routing has been
tested on hardware. The rules below are a design note.

This page applies the [audio routing](audio-routing.md) rules to RME/MADI-class
devices.

## Evidence Labels

| Input | Label |
|---|---|
| Core Audio device and stream properties | `public API` |
| MADI channel and clock terminology | `public standard` |
| Stable channel descriptors and route reports | `original open-lola design` |
| Interface-specific matrix and buffer settings | `experimentally derived requirement` |

## Mapping rules

- Find the input and output devices by stable UID.
- Record physical stream and channel counts and the clock domain before applying
  a route.
- At each UI or file boundary, state whether channels are numbered from zero or
  one.
- Show capture order, network order, and playback order in the report.
- List unused channels and every gain, mute, or matrix operation.
- A successful Core Audio inventory or packet test says nothing about the
  physical TotalMix route.

Start with identity routing across the negotiated contiguous range. Use a matrix
only when every source, destination, and gain is validated and reported. A
sample-rate or clock mismatch must fail preflight or produce a visible
non-passing result.

## What a hardware result needs

- RME model, driver, and firmware;
- MADI mode and optical or coax topology;
- clock source and lock state;
- sample rate and channel count;
- requested and accepted buffer sizes;
- a matrix snapshot or sanitized description;
- sustained full-duplex results from the same build.

VERDICT: PARTIAL
