# M01 Clean-Room Requirements

Date: 2026-05-03  
Status: publication-safe milestone plan  
Verdict: PARTIAL

## Objective

Create the public clean-room architecture layer and make the docs verifier guard
the M01 documentation surface.

## Scope

M01 is docs-only. It does not implement media transport, audio IO, video IO, or
lighting output.

## Affected Files

- [../architecture/clean-room-design-rules.md](../architecture/clean-room-design-rules.md)
- [../architecture/latency-first-architecture.md](../architecture/latency-first-architecture.md)
- [../architecture/latency-budget.md](../architecture/latency-budget.md)
- [../architecture/p2p-networking.md](../architecture/p2p-networking.md)
- [../architecture/audio-rme-madi.md](../architecture/audio-rme-madi.md)
- [../architecture/video-blackmagic-atem.md](../architecture/video-blackmagic-atem.md)
- [../architecture/lighting-control.md](../architecture/lighting-control.md)
- [../architecture/benchmark-methodology.md](../architecture/benchmark-methodology.md)
- [../architecture/implementation-roadmap.md](../architecture/implementation-roadmap.md)
- [../README.md](../README.md)
- [../../scripts/verify_docs/constants.py](../../scripts/verify_docs/constants.py)
- [../../scripts/verify_docs/markdown_checks.py](../../scripts/verify_docs/markdown_checks.py)
- [../../scripts/verify_docs/main.py](../../scripts/verify_docs/main.py)

## Implementation Tasks

- [x] Add publication-safe architecture docs under `docs/architecture/`.
- [x] Add public milestone docs under `docs/milestones/`.
- [x] Update the public docs index.
- [x] Add verifier coverage for required public planning docs.

## Test Plan

Run:

```bash
bash scripts/verify-docs.sh
shellcheck scripts/verify-docs.sh
```

The docs verifier must check links, required topics, milestone contracts,
implementation companion contracts, public architecture files, and public
milestone files.

## Benchmark Plan

No media benchmark is part of M01. M01 defines the benchmark contract for M02.

## Acceptance Criteria

- Public docs contain no proprietary packet grammar, control templates, private
  strings, symbols, addresses, decompiled logic, binary excerpts, or licensing
  reconstruction.
- Reverse-engineering findings are converted only into independent
  requirements.
- Every design choice is labelable as public standard, public API, original
  open-lola design, experimentally derived requirement, compatibility
  requirement, or implementation hypothesis.
- Windows LoLa compatibility is not the default design constraint.
- Fastest audio path remains the default architecture.

## Risks

- Public docs may accidentally expose internal reverse-engineering detail.
- A new docs tree can drift from `mac-port/` unless the verifier checks it.
- M01 could be mistaken for hardware validation. It is not.

## Blockers

No hardware blocker exists for M01. Hardware remains Q001 and belongs to M02/M03
closure.

## Rollback Plan

Remove the new public docs and verifier requirements. No runtime source is
affected.

## Progress Checklist

- [x] Current repository docs inspected.
- [x] Public/private evidence boundary preserved.
- [x] Public architecture docs created.
- [x] Public milestone docs created.
- [x] Public docs index updated.
- [x] Verifier updated.
- [x] Verification run recorded after full M01-M14 expansion.

## Resume Point

After verification passes, start M02 with
[../architecture/benchmark-methodology.md](../architecture/benchmark-methodology.md)
and [../architecture/latency-budget.md](../architecture/latency-budget.md) as
the source documents. Do not start video, lighting, NAT, or UI implementation
before the audio benchmark contract is concrete.

VERDICT: PARTIAL
