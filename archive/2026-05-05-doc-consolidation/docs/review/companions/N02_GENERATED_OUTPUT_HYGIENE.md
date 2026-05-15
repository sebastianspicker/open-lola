# N02 Generated Output Hygiene

Date: 2026-05-04  
Status: companion updated after C12 hygiene implementation  
Priority: P0  
Verdict: PARTIAL

## Objective

Decide how to handle `.build/` generated SwiftPM output in this filesystem
snapshot.

## Affected Paths

- `.build/`
- `.gitignore`
- `scripts/verify-release-hygiene.sh`
- future release/export scripts

## Current Finding

`.build/` is ignored by `.gitignore` but exists locally and contains generated
SwiftPM build products, debug binaries, test bundles, debug symbols, module
caches, object files, index records, and build databases.

C12 now implements a non-destructive hygiene gate:

```bash
bash scripts/verify-release-hygiene.sh
```

If a staged release candidate is supplied, the gate fails when `.build/**` or
other generated/internal/vendor artifacts are present.

## Allowed Actions In A Future Cleanup Pass

- verify `.build/` is generated,
- delete `.build/` only after explicit approval,
- rebuild with `swift build` and `swift test`,
- wire any future release/export script to
  `OPEN_LOLA_RELEASE_CANDIDATE=/path/to/candidate bash scripts/verify-release-hygiene.sh`.

## Not Allowed In This Companion

- deleting `.build/`,
- editing source,
- changing build configuration,
- claiming the generated binaries are release artifacts.

## Acceptance Criteria

- `.build/` is either explicitly retained as local-only or removed after
  approval.
- Release/public export excludes `.build/` and passes C12 candidate scanning.
- Rebuild/test status is recorded after any deletion.

## Validation

If cleanup is approved later:

```bash
bash scripts/verify-release-hygiene.sh
swift build
swift test
bash scripts/verify-docs.sh
```

## Resume Here

If cleanup is not approved, leave `.build/` untouched. Continue with a release
export script only if it stages output outside the raw checkout and runs the
C12 hygiene scan against that staged directory.

VERDICT: PARTIAL
