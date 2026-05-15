# Session Handoff

Date: YYYY-MM-DD  
Status: session handoff template  
Milestone: Mxx  
Verdict: VERDICT: PARTIAL

## Modified files

- None.

## Current plan

1. Read the target milestone and implementation companion.
2. Add or update the focused test first.
3. Implement the smallest passing change.
4. Run verification and update status.

## Unresolved errors

- None recorded.

## Test status

- Not run.

## Verification commands

```bash
bash scripts/verify-docs.sh
shellcheck -x scripts/*.sh scripts/lib/*.sh
```

After M00 source exists:

```bash
swift build
swift test --no-parallel
```

## Resume here

Open `mac-port/IMPLEMENTATION_COMPANION.md`, then continue from its
`Resume here` section and the target row in `mac-port/IMPLEMENTATION_COMPANION.md`.
