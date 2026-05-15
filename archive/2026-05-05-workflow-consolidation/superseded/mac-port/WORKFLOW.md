# Mac Port Workflow

Date: 2026-05-03  
Status: required workflow for consolidated implementation sessions

Use this workflow for every feature or behavior change. Documentation-only
harness edits use the same verification discipline, but do not create Swift
source.

## Red

1. Read [../MAC_PORT_PLAN.md](../MAC_PORT_PLAN.md),
   [IMPLEMENTATION_COMPANION.md](IMPLEMENTATION_COMPANION.md),
   [OPEN_QUESTIONS.md](OPEN_QUESTIONS.md), and
   [SOTA_2026_OPEN_QUESTION_MATRIX.md](SOTA_2026_OPEN_QUESTION_MATRIX.md). Read
   [implementation-companions/README.md](implementation-companions/README.md)
   for faster-than-LoLa, RME, P2P, Blackmagic/ATEM, lighting, field, or
   benchmark-closure tasks. Read the target milestone document when detailed
   design history is needed.
2. Define the expected behavior in
   [IMPLEMENTATION_COMPANION.md](IMPLEMENTATION_COMPANION.md) before coding.
3. Add or update the focused test first.
4. When practical, run the focused test and record the expected failure reason.

## Green

1. Implement the smallest change that satisfies the focused test.
2. Run the relevant static checks, tests, and surface probes.
3. Keep feature work inside the milestone scope and the affected files listed
   in the milestone plan.

## Update

1. Update [IMPLEMENTATION_COMPANION.md](IMPLEMENTATION_COMPANION.md) with
   completed work, verified work, SOTA rows, touched files, blockers, and the
   latest command results.
2. Update the Current Progress and Open Evidence Gates sections in
   [IMPLEMENTATION_COMPANION.md](IMPLEMENTATION_COMPANION.md) only when a
   milestone or harness baseline gate has actually passed.
3. Update [RISK_REGISTER.md](RISK_REGISTER.md) and
   [OPEN_QUESTIONS.md](OPEN_QUESTIONS.md) only when risks or questions changed.
4. End the status update with one verdict line: `VERDICT: PASS`,
   `VERDICT: FAIL`, or `VERDICT: PARTIAL`.

## Required Commands

Before M00 source exists:

```bash
bash scripts/verify-docs.sh
shellcheck scripts/*.sh
```

After M00 source exists:

```bash
bash scripts/verify-docs.sh
shellcheck scripts/*.sh
swift build
swift test
```

Add milestone-specific CLI smoke tests and benchmark/report validators as soon
as those surfaces exist.

## Rollback Rules

- Documentation-only changes: restore the preserved historical copy when one
  exists, or revert the specific changed file.
- Source changes after M00: revert the smallest affected change set and rerun
  `swift test`.
- Hardware, network, audio, video, lighting, recording, or packaging reports:
  mark the report invalid rather than deleting it, then rerun measurement.

## Resume here

Start with [IMPLEMENTATION_COMPANION.md](IMPLEMENTATION_COMPANION.md), close
Q001 hardware inventory, and write the focused failing test before adding or
changing product source.
