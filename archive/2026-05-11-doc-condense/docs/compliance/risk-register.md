# Compliance Risk Register

Date: 2026-05-11
Status: active compliance risk register with current blocker overlay
Verdict: PARTIAL

## Current Risk Snapshot

Latest local refresh: 2026-05-11.

| Report | Result | Risk implication |
|---|---|---|
| `/private/tmp/open-lola-open-source-release-readiness-current.json` | `VERDICT: PARTIAL`; 9 requirements, 6 blockers. | CR002, CR007, CR009, and reviewer/public-approval risks remain open. |
| `/private/tmp/open-lola-goal-completion-audit-current.json` | `VERDICT: PARTIAL`; 93 mapped items, 77 pass, 16 partial, 26 blockers. | Full-goal completion is still blocked; do not treat source-level or dry-run PASS rows as release completion. |
| `/private/tmp/open-lola-goal-runtime-preflight-current.json` | `VERDICT: PARTIAL`; 10 runtime deliverables are partial. | CR011 and CR014 remain open because measured runtime, Developer ID, notarization, Gatekeeper, and clean-Mac evidence are missing. |

<!-- TODO(human): [Risk register closure] -> Assign named maintainers/reviewers and attach signed decisions or measured evidence for each open risk before changing any risk status to closed -> [Close selected source-release risks / keep all release risks open / defer release] -->

| ID | Risk | Severity | Likelihood | Affected files | Mitigation | Owner/reviewer | Status |
|---|---|---|---|---|---|---|---|
| CR001 | Copyright risk from publishing binaries or generated static-analysis outputs. | High | High | `win-compiled/**`, `archive/2026-05-05-workflow-consolidation/internal-evidence/reverse-engineering/evidence-packages/**` | Exclude from public release; keep internal-only; obtain rights before redistribution; scan M09 archive contents. | Maintainer/legal | Open; M09 archive rule excludes binaries/evidence |
| CR002 | License risk because root `LICENSE` is only a pending placeholder. | High | High | Entire repo, `LICENSE` | Replace placeholder with selected project license before publication. | Maintainer/legal | Open |
| CR003 | SDK redistribution risk from future Blackmagic Desktop Video integration. | Medium | Medium | `M08`, future SDK adapter | Keep SDK optional; do not vendor SDK files; document terms. | Maintainer/legal | Open |
| CR004 | RME driver/API constraints misunderstood as redistributable project dependency. | Medium | Medium | RME docs, reports, source contracts | Treat RME driver as user-installed prerequisite; do not redistribute. | Maintainer | Open |
| CR005 | Clean-room contamination from implementing directly from RE protocol notes. | High | Medium | `reverse-engineering/**`, protocol/source work | Enforce research-to-requirements process, M08 implementation audit, and reviewer gate. | Maintainer/legal | Open; M08 source audit recorded |
| CR006 | Public docs leak raw message grammar, packet offsets, symbols, or ports. | High | Medium | `docs/**`, `archive/2026-05-05-workflow-consolidation/superseded/root/MAC_PORT_PLAN.md`, `mac-port/**` | Run M06 public-doc register, publication redaction review, curated release manifest, and M09 archive inspection. | Maintainer | Open; M09 excludes mixed/internal docs by default |
| CR007 | Dependency/license incompatibility from future SDK or protocol adapters. | Medium | Medium | M07, M08, M12, future adapters, `THIRD_PARTY_NOTICES.md` | Keep adapters optional, update dependency license table, maintain M07 notices register, and finalize notices before implementation/release. | Maintainer/legal | Open; M07 register drafted |
| CR008 | Trademark/naming risk around LoLa, Blackmagic, ATEM, RME, Dante, and Art-Net. | Medium | Medium | README, docs, app name, marketing | Use factual compatibility wording; add trademark/no-endorsement review to M07 notice packet. | Maintainer/legal | Open; M07 posture drafted |
| CR009 | Sample data or fixture provenance unclear. | Medium | Medium | `Tests/**/Fixtures/**`, `mac-port/reports/**` | Label synthetic vs measured; remove unclear samples from release; close CQ019 before fixture inclusion. | Maintainer | Open; M08 count confirmed |
| CR010 | Security-sensitive disclosure from network, NAT, packet, or control docs. | Medium | Medium | network docs, compatibility docs, `mac-port/reports/**` | Avoid exploit, bypass, secrets, private endpoints, raw packet dumps, and raw route context; redact reports before public use. | Maintainer/security reviewer | Open; M06 redactions applied to address examples |
| CR011 | Unsupported compatibility or performance claims. | High | Medium | README, docs, reports, F10/G16 | Keep PARTIAL until measured baselines and peer tests exist. | Maintainer | Open |
| CR012 | Contributor provenance risk from RE-aware contributors writing compatibility code. | High | Medium | Future compatibility code | Define contributor hygiene and separate review workflow; require M08 rerun and compatibility-work-gate signoff before source implementation. | Maintainer/legal | Open; current source surface audited |
| CR013 | Art-Net credit/OEM-code obligations missed. | Medium | Medium | M12 lighting docs/source | Verify terms, add required credit, record OEM-code disposition in M07 notices register. | Maintainer/legal | Open; M07 TODO recorded |
| CR014 | Apple SDK/distribution terms not reviewed before signed release. | Medium | Medium | M15 packaging/app | Record Apple agreement state and distribution mode. | Maintainer/legal | Open |
| CR015 | Internal-public boundary drifts as docs grow. | Medium | High | `docs/`, `background/`, `reverse-engineering/` | Maintain release manifest, public doc safety review, M09 archive recipe, and archive-content scan. | Maintainer | Open; M09 dry-run recipe recorded |
| CR016 | False-green release or goal-completion reporting from relying on source-level tests, dry-run archive PASS rows, or release verifier PASS while runtime/manual gates remain partial. | High | High | `README.md`, `docs/current-state.md`, `docs/compliance/**`, `mac-port/**`, release reports | Treat `goal-completion-audit-run`, runtime preflight, and open-source readiness reports as the blocker map; require human/legal/runtime evidence before any completion claim. | Maintainer/release reviewer | Open; May 9 reports record PARTIAL |

## Resume here

Review CR001-CR006 before any public release. Review CR007-CR014 before adding
optional SDK/protocol adapters. Revisit CR015 in every docs consolidation pass.
M05 reduces CR002/CR007 ambiguity but does not close them because final
maintainer/legal signoff is still missing. M06 reduces CR006/CR010 exposure but
does not close them until the final release manifest and reviewer signoff exist.
M07 reduces CR007/CR008/CR013 ambiguity with a notice register, but does not
close those risks until final license, attribution, and standards decisions are
signed off. M08 reduces CR005/CR009/CR012 ambiguity with an implementation audit
register and metadata cleanup, but does not close those risks until fixture
provenance, compatibility contributor policy, and reviewer signoff are complete.
M09 reduces CR001/CR006/CR015 with an allowlist archive recipe and inspection
gate, but does not close release risk until the final M10 archive and reviewer
signoff are complete. M10 assembles the final review packet and records BLOCK
decisions for public source and binary/package release, but does not close any
open risk until reviewer decisions and release blockers are complete. The May 9
current reports add CR016 explicitly: a release-readiness PASS, dry-run archive
PASS, or source-level PASS is not a full-goal PASS while 26 full-goal blockers,
six open-source-readiness blockers, and runtime preflight blockers remain.

VERDICT: PARTIAL
