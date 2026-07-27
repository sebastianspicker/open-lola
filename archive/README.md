# Local Archive Boundary

Date: 2026-07-16
Status: public-safe repository policy

Only this summary is permitted in version control. Everything else under
`archive/` is local-only, ignored by Git, and rejected by the tracked-boundary
check.

Archive payloads belong outside the tracked public tree and are not part of a
source candidate.

## Purpose

The local archive may hold superseded working documents or evidence that a
maintainer still needs temporarily. It is not public documentation,
implementation authority, release evidence, or a release-candidate lane.

## Rules

- Never force-add archive payloads.
- Never store secrets or credentials in the repository, including ignored
  paths.
- Keep long-term internal evidence in an approved store outside the repository.
- Keep local workflow records and review notes outside version control.
- Use current source, tests, and public documentation as the only repository
  authority.
- Run `bash scripts/verify-tracked-boundary.sh` before committing.

The repository cannot erase material from existing Git history through ignore
rules. Any history rewrite requires a separate, explicitly authorized security
operation.
