# F10 Faster Than LoLa Closure

Date: 2026-05-03
Status: source closure ledger implemented; measured benchmark evidence open
Verdict: PARTIAL

## Finding

"Faster than LoLa" is not a source milestone. It is a measured benchmark claim
that must be proven by a ledger. Synthetic fixtures, localhost routes, built-in
devices, and placeholder reports cannot satisfy it.

## Required Ledger Inputs

- F01 RME MADI hardware baseline.
- F02 realtime duplex audio engine.
- F03 direct peer-to-peer route.
- F11 network loopback diagnostics for the same raw route.
- F12 NAT/ISP-friendly route only as compatibility evidence; relay fallback
  cannot satisfy the fastest-path gate.
- F04 60-minute drift/PLC and LoLa baseline comparison.
- F05 Blackmagic/ATEM capture path if video is part of the claim.
- F06 physical video transport if remote video is part of the claim.
- F07 integrated runtime if A/V is part of the claim.
- F08 lighting cue/output proof if lighting is part of the claim.
- F09 clean-Mac field proof if field readiness is part of the claim.

## Implemented Source Surface

The source-level F10 closure contract is implemented in
`Sources/OpenLolaCore/FasterThanLoLaClosure.swift`.

It provides:

- `FasterThanLoLaClosureReport` for the final benchmark ledger;
- exact claim scopes: `audioOnly`, `audioVideo`, `audioVideoLighting`, and
  `fieldReady`;
- required evidence lanes F01-F09, scoped by claim;
- benchmark comparison fields for same-hardware Open LoLa versus LoLa latency,
  fixed playout target, duration, packet loss, late packets, underruns, drift,
  artifacts, and result;
- PASS guards that reject synthetic runs, missing required evidence, non-PASS
  evidence, missing physical or clean-Mac proof, missing packet-capture or
  artifact proof, missing measured LoLa baseline, different hardware or route,
  non-faster Open LoLa results, any non-winning latency percentile, runs shorter
  than 60 minutes, missing fixed playout target, packet loss, late packets,
  underruns, artifacts, or parity features blocking the fastest path.

The CLI exposes:

```bash
open-lola validate-faster-than-lola-closure <path>
open-lola faster-than-lola-closure-synthetic-smoke
open-lola faster-than-lola-closure-run --claim-scope audioOnly|audioVideo|audioVideoLighting|fieldReady --f01-report <id> --f02-report <id> --f03-report <id> --f04-report <id> [--f05-report <id>] [--f06-report <id>] [--f07-report <id>] [--f08-report <id>] [--f09-report <id>] --output <path>
```

The bounded run writes a valid `VERDICT: PARTIAL` ledger from referenced report
IDs. It is a handoff artifact, not measured PASS evidence.

## Minimum Audio Claim

The smallest claim is audio-only:

- same reference Macs or documented equivalent pair;
- same or better interface class than LoLa baseline;
- direct wired P2P route;
- fixed playout target;
- p50/p95/p99/max latency;
- loss, late packets, underruns, artifacts, and drift over 60 minutes;
- explicit comparison against measured LoLa settings.

## Expanded Claim

An A/V/L claim adds:

- Blackmagic/ATEM capture identity and frame-age data;
- raw/intra-frame or VideoToolbox transport evidence;
- 30-minute integrated run;
- OSC and lighting evidence;
- proof that video/control/lighting degrade before audio.

## PASS Criteria

- Every claim names its exact scope: audio-only, audio+video, or audio+video+
  lighting.
- Every PASS row links to measured reports.
- LoLa baseline is measured, not inferred.
- ICMP RTT is comparison evidence only and cannot replace UDP PCM loopback or
  route latency.
- NAT relay fallback is excluded from fastest-path PASS evidence.
- Open-lola beats the chosen LoLa baseline or the ledger reports
  `VERDICT: PARTIAL`.
- Any missing physical hardware, clean-Mac, or packet-capture proof keeps the
  closure verdict PARTIAL.
- The G16 LoLa parity ledger must stay deferred and must not block the fastest
  path unless the user explicitly promotes one compatibility feature later.
- Public "faster than LoLa" wording requires the sanitized public roadmap,
  release-hardening public-claims review, license/notices closure, and
  maintainer/legal approval.

## Validation Report

Current source validation is recorded in
[../reports/F10_FASTER_THAN_LOLA_CLOSURE_2026-05-03.md](../reports/F10_FASTER_THAN_LOLA_CLOSURE_2026-05-03.md).

## Resume here

Use `faster-than-lola-closure-run` to create a bounded PARTIAL handoff from the
current source reports. Create a PASS benchmark ledger only after F01-F04 plus
F11 have measured evidence for the audio-only claim, or F01-F11 for field-ready
claims. Keep F12 NAT evidence separate from raw fastest-path closure unless the
user explicitly promotes a measured compatibility claim.

VERDICT: PARTIAL
