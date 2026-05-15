# Mac Port Development Harness

Date: 2026-05-04  
Status: harness baseline for consolidated implementation sessions

This harness is the operating layer for the Mac-native port. It does not
replace [../MAC_PORT_PLAN.md](../MAC_PORT_PLAN.md),
[MILESTONE_INDEX.md](MILESTONE_INDEX.md), or the canonical milestone documents
under [milestones/](milestones/).

## Entry Points

Start each implementation session by reading these files in order:

1. [../MAC_PORT_PLAN.md](../MAC_PORT_PLAN.md)
2. [MILESTONE_INDEX.md](MILESTONE_INDEX.md)
3. [IMPLEMENTATION_COMPANION.md](IMPLEMENTATION_COMPANION.md)
4. [implementation-companions/README.md](implementation-companions/README.md)
   when the task names faster-than-LoLa, RME, P2P, Blackmagic/ATEM, lighting,
   field readiness, or benchmark closure.
5. [../docs/source-contracts/README.md](../docs/source-contracts/README.md)
   when the task names multichannel routing, 16-frame or 8-frame profiles, or
   RX buffering.
6. [../docs/benchmarks/README.md](../docs/benchmarks/README.md)
   when the task names latency benchmarks or profile acceptance.
7. [PROGRESS.md](PROGRESS.md)
8. [OPEN_QUESTIONS.md](OPEN_QUESTIONS.md)
9. [SOTA_2026_OPEN_QUESTION_MATRIX.md](SOTA_2026_OPEN_QUESTION_MATRIX.md)
10. The target file under [milestones/](milestones/) when detailed design
   history is needed.

Use the first incomplete row in [PROGRESS.md](PROGRESS.md) as the product
implementation target unless the user names a different milestone. Use the lane
order in [IMPLEMENTATION_COMPANION.md](IMPLEMENTATION_COMPANION.md) when the
task is broad missing-feature implementation.

## Harness Baseline

The harness baseline is complete when these documentation/tooling gates pass:

```bash
bash ../scripts/verify-docs.sh
shellcheck ../scripts/*.sh
```

Run those commands from this directory by using the paths above, or from the
repository root by using:

```bash
bash scripts/verify-docs.sh
shellcheck scripts/*.sh
```

After M00 creates the Swift package, add:

```bash
swift build
swift test
```

## Implementation Companion

[IMPLEMENTATION_COMPANION.md](IMPLEMENTATION_COMPANION.md) is the active handoff
companion. It records current state, verification, blockers, missing evidence,
and the next resume point. The canonical milestone plans remain in
[milestones/](milestones/).

The older `gaps/`, `prototype/`, and `status/` companion layers are preserved as
historical snapshots under
[historical/implementation-companions-2026-05-03/](historical/implementation-companions-2026-05-03/).

## SOTA Question Routing

[SOTA_2026_OPEN_QUESTION_MATRIX.md](SOTA_2026_OPEN_QUESTION_MATRIX.md) is the
handoff ledger for Q001-Q010 and the 85 SOTA evidence probes. Before changing a
milestone implementation plan, first check that file, then update
[IMPLEMENTATION_COMPANION.md](IMPLEMENTATION_COMPANION.md) with the expected
evidence and latest verdict.

## Historical Copies

Pre-harness copies and archived implementation companions are preserved under
[historical/](historical/). Do not edit them to make current links prettier;
they are snapshots, not active documentation.

## Resume here

Open [WORKFLOW.md](WORKFLOW.md), then continue from
[IMPLEMENTATION_COMPANION.md](IMPLEMENTATION_COMPANION.md). Start with Q001
hardware inventory unless the user names a later measured lane.
