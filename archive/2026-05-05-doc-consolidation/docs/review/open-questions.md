# Open Questions

Date: 2026-05-04  
Status: human decision ledger for repository review  
Verdict: PARTIAL

## Publication And Compliance

| Question | Context | Options | Recommendation | Priority |
|---|---|---|---|---|
| Should `docs/review/` be public-safe, internal-only, or excluded from release long term? | The user requested review docs under `docs/review/`, but they discuss internal evidence and cleanup risks. C12 now excludes them from release candidates by default. | Public-safe after review / internal-only / excluded from release archive. | Internal-only until compliance review; keep C12 exclusion unless explicitly changed. | P1 |
| What is the final source and documentation license? | Root `LICENSE` is pending. | Open-source license / source-available terms / private only. | Decide before public release. | P0 |
| What is the final third-party notices posture? | `THIRD_PARTY_NOTICES.md` is a draft and Windows corpus includes external/vendor artifacts. | Notices for public source only / notices plus binary exclusions / no public release. | Tie to release manifest and license decision. | P0 |
| Should `win-compiled/` remain in the working repository long term? | It is valuable static evidence but high-risk for publication. | Keep internal / move to private evidence store / replace with hashes/manifests only. | Keep internal until evidence strategy is decided. | P0 |
| Should generated RE packages be regenerated, frozen, or archived? | `reverse-engineering/evidence-packages/folder-analysis-20260503-1747/` mixes generated docs, data, and tools. | Regenerate on demand / freeze snapshot / archive after distilled docs. | Freeze with manifest unless new RE work is requested. | P2 |

## Source And Architecture

| Question | Context | Options | Recommendation | Priority |
|---|---|---|---|---|
| Should `Sources/OpenLolaCore/` be physically split into subfolders? | 139 Swift files share one flat directory. | Keep flat / split by function / split only tests/docs. | Create crosswalk first, then split by function. | P1 |
| Who owns each functional module? | Ownership is inferable but not recorded. | Single maintainer / domain owners / no owner labels. | Record module ownership in a crosswalk after human review. | P2 |
| Should the CLI adopt a typed parser? | Manual parsing appears across command files. | Keep manual / tiny local parser / external parser dependency. | Audit duplication first; avoid external dependency unless needed. | P2 |
| Should tests mirror future source folders? | Current tests are flat except fixtures. | Keep flat / mirror source folders / split only fixtures. | Mirror source folders if source moves happen. | P2 |
| Where should RE analysis tools live? | Python tooling currently lives inside an evidence package. | Keep in package / promote to `tools/analysis/` / archive. | Keep in package until reused. | P3 |

## Verification And Runtime Evidence

| Question | Context | Options | Recommendation | Priority |
|---|---|---|---|---|
| What is the next real hardware evidence target? | Many milestones are source-level `PARTIAL`. | RME/MADI audio first / Blackmagic video / ATEM/lighting / packaging clean-Mac. | RME/MADI audio first, then integrated AV. | P1 |
| Which benchmark results are accepted as measured evidence? | Methodology exists but measured ledger is not centralized. | Synthetic only / measured local reports / externally witnessed reports. | Create a measured evidence ledger before PASS claims. | P1 |
| How should C10 CI be read back? | `.github/workflows/release-readiness.yml` now exists locally, but this folder is not a Git worktree. | Attach Git context and read back GitHub Actions / keep local-only until publication / replace workflow. | Attach Git context and verify CI before release claims. | P1 |
| Should `.build/` be deleted immediately? | It is generated and ignored, but may be the latest local build proof. | Delete now / leave for now / delete after verification. | Delete only after explicit approval. | P0 |

## Documentation

| Question | Context | Options | Recommendation | Priority |
|---|---|---|---|---|
| Should review docs be linked from `docs/README.md`? | They are useful but may not be public-safe. | Link now / link from internal docs only / do not link. | Do not link from public docs until reviewed. | P1 |
| Should `docs/testing/` be created? | Verification docs are split between README, scripts, mac-port. | Create public-safe testing docs / keep scripts README only. | Create later after boundary review. | P2 |
| Should historical docs be frozen? | Historical folders are intentionally preserved. | Freeze / periodically update links / delete. | Freeze except link hygiene. | P3 |

VERDICT: PARTIAL
