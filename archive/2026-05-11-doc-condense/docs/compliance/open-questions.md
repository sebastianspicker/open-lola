# Compliance Open Questions

Date: 2026-05-11
Status: maintainer/legal review questions with current release preflight blockers
Verdict: PARTIAL

## License And Publication

| ID | Question | Owner/reviewer | Needed for |
|---|---|---|---|
| CQ001 | Which open-source license should cover source code? | Maintainer/legal | Public release. |
| CQ002 | Should docs use the same license as code or a separate documentation license? | Maintainer/legal | Public docs. |
| CQ003 | Is the public release a curated export or the whole checkout? | Maintainer | Release manifest. |
| CQ004 | Are `win-compiled/` artifacts authorized for internal-only retention, public redistribution, or neither? | Maintainer/legal | Binary corpus boundary. |
| CQ005 | Which third-party notice format should be used? | Maintainer/legal | `THIRD_PARTY_NOTICES.md`. |

## Current Release Preflight Blockers

Latest local refresh: 2026-05-11.

| Report | Result | Blocking decisions |
|---|---|---|
| `/private/tmp/open-lola-open-source-release-readiness-current.json` | `VERDICT: PARTIAL`; 9 requirements, 6 blockers. | Final source license, documentation license, third-party notices, fixture provenance, reviewer signoff, and public release approval. |
| `/private/tmp/open-lola-goal-completion-audit-current.json` | `VERDICT: PARTIAL`; 93 mapped items, 77 pass, 16 partial, 26 blockers. | Release decisions here plus runtime evidence gates in `../../mac-port/OPEN_QUESTIONS.md`. |
| `/private/tmp/open-lola-goal-runtime-preflight-current.json` | `VERDICT: PARTIAL`; 10 runtime deliverables are partial. | Runtime/hardware/signing blockers remain outside pure legal text but still block full product completion. |

Current host signing evidence: one valid codesigning identity and no Developer
ID Application identity. Binary/app/package release remains blocked until
Developer ID signing, notarization, Gatekeeper, and clean-Mac evidence are
attached.

## Human TODO Markers

- TODO(human): [Source and documentation license] -> Choose final source-code license and documentation license before any public source/docs release -> [single shared license / separate code and documentation licenses / keep internal-only]
- TODO(human): [Third-party notices] -> Finalize notice format and review `THIRD_PARTY_NOTICES.md` against the exact release allowlist -> [root notice file / release packet appendix / defer publication]
- TODO(human): [Fixture provenance] -> Confirm all 53 JSON and 3 HEX fixtures are synthetic, public-standard, or approved measured data; otherwise keep unclear fixtures excluded -> [include confirmed fixtures / exclude unclear fixtures / exclude all fixtures from first release]
- TODO(human): [Release scope and public approval] -> Approve the final release scope, archive command, public entry points, and reviewer signoff path -> [curated source/docs archive / signed binary package too / defer public release]
- TODO(human): [Reviewer roles] -> Name maintainer, legal/compliance, clean-room, release, and security/privacy reviewers for final signoff -> [single maintainer-led review / separate named reviewers / defer release]

## SDKs And Standards

| ID | Question | Owner/reviewer | Needed for |
|---|---|---|---|
| CQ006 | Which Apple developer agreements govern CLI/app distribution? | Maintainer/legal | M15 packaging. |
| CQ007 | Can Blackmagic Desktop Video SDK headers/libs be used in optional adapters, and can anything be redistributed? | Maintainer/legal | M08/M09 video. |
| CQ008 | Which RME driver/package versions are allowed as user prerequisites? | Maintainer | M01/M03 audio. |
| CQ009 | Does Art-Net output require a specific OEM code for open-lola or the institution? | Maintainer/legal | M12 lighting. |
| CQ010 | Which sACN/E1.31 standard version and terms apply? | Maintainer/legal | M12 lighting. |
| CQ011 | Are Dante/Audinate integrations in scope, and under which license? | Maintainer/legal | M07 AoIP. |

## M05 Disposition

| ID | M05 disposition | Closure requirement |
|---|---|---|
| CQ001 | Explicitly deferred. | Replace root `LICENSE` placeholder with selected source license. |
| CQ002 | Explicitly deferred. | Record documentation license in `LICENSE`, README, and notices. |
| CQ003 | Partially resolved. | Curated allowlist is required; exact archive command remains CQ018. |
| CQ004 | Explicitly deferred with default exclusion. | Keep `win-compiled/**` internal-only unless rights are documented. |
| CQ005 | Partially resolved. | M07 `THIRD_PARTY_NOTICES.md` and notice attribution register exist; maintainer/legal signoff must mark them final. |
| CQ006 | Explicitly deferred. | Record accepted Apple developer agreements before binary/app distribution. |
| CQ007 | Explicitly deferred with default exclusion. | Do not vendor Blackmagic SDK files until terms permit and review is recorded. |
| CQ008 | Explicitly deferred as user-installed prerequisite. | Record RME model, driver, firmware, Core Audio UID, and TotalMix state in measured reports. |
| CQ009 | Explicitly deferred. | Record Art-Net OEM-code disposition before Art-Net product/output release. |
| CQ010 | Explicitly deferred. | Record sACN/E1.31 version and standard access terms before implementation/release claim. |
| CQ011 | Explicitly deferred. | Keep Dante/Audinate out of scope until licensed integration path is approved. |

## M06 Disposition

| ID | M06 disposition | Closure requirement |
|---|---|---|
| CQ015 | Partially resolved. | Public docs may mention internal evidence only as withheld/sanitized context; reviewer signoff still required. |
| CQ017 | Explicitly deferred. | Decide during M10 whether `docs/compliance/**` is public governance material or internal review packet. |
| CQ018 | Still open. | Define the exact allowlist/export command after M06 and M07 are signed off. |
| CQ020 | Partially resolved. | Default public research lane remains `docs/background/**`; root `research/RESEARCH_*.md` stays internal or sanitized-copy only. |
| CQ022 | Partially resolved. | `docs/roadmap/**` is the default public roadmap; `archive/2026-05-05-workflow-consolidation/superseded/root/MAC_PORT_PLAN.md` and `mac-port/**` stay review-only unless separately approved. |
| CQ023 | Partially resolved. | M06 public-link audit has no direct internal links in the curated surface; reviewer signoff still required. |

## M07 Disposition

| ID | M07 disposition | Closure requirement |
|---|---|---|
| CQ001 | Still open. | Root `LICENSE` remains a pending placeholder. |
| CQ002 | Still open. | Documentation license must be recorded before public docs release. |
| CQ005 | Partially resolved. | Root `THIRD_PARTY_NOTICES.md` and `notices-attribution-register.md` exist as M07 drafts; maintainer/legal signoff must mark them final. |
| CQ006 | Still open. | Apple developer agreement state must be recorded before binary/app distribution. |
| CQ007 | Explicitly deferred with default exclusion. | Blackmagic SDK files remain non-vendored; adapter notices are required only if SDK-backed code lands. |
| CQ008 | Partially resolved as prerequisite wording. | RME driver/TotalMix are user-installed external dependencies; measured reports must record exact versions. |
| CQ009 | Still open. | Art-Net credit and OEM-code disposition must be recorded before product/output release. |
| CQ010 | Still open. | sACN/E1.31 authorized standards copy/version/terms must be recorded before implementation or release claim. |
| CQ011 | Explicitly deferred. | Dante/Audinate remains out of scope until licensed integration is approved. |
| CQ019 | Still open. | Fixture provenance must be signed off or unclear fixtures excluded. |

## M08 Disposition

| ID | M08 disposition | Closure requirement |
|---|---|---|
| CQ012 | Partially resolved for current source surface. | Name who may read internal RE notes and still contribute source, especially compatibility code. |
| CQ013 | Partially resolved by default-off gate. | Decide whether compatibility-mode implementation requires separate contributors, separate reviewers, or both. |
| CQ014 | Still open. | Confirm fixture provenance for all 53 JSON and 3 HEX fixtures or exclude unclear fixtures. |
| CQ016 | Partially resolved by `CRQ-500`, `CRQ-501`, and the M08 audit register. | Define exact authorized peer/capture evidence before any compatibility claim. |
| CQ019 | Still open. | Sign off fixture provenance or exclude unclear fixtures from release artifacts. |
| CQ024 | Still open. | Name the clean-room reviewer and record M08 signoff. |

## M09 Disposition

| ID | M09 disposition | Closure requirement |
|---|---|---|
| CQ003 | Partially resolved. | M09 uses an allowlist dry-run archive; M10 must approve final public release contents. |
| CQ017 | Partially resolved for dry run. | M09 includes `docs/compliance/**` as a review packet; M10 must decide whether it is public governance or internal-only. |
| CQ018 | Partially resolved. | M09 records an exact archive command; M10 must approve or revise it for the final release. |
| CQ019 | Still open. | M09 excludes fixtures from the dry-run archive until provenance is signed off. |
| CQ023 | Still open. | Reviewer must sign off public entry point links against the final archive contents. |
| CQ024 | Still open. | Clean-room reviewer must sign off M08/M09 before public release. |

## M10 Disposition

| ID | M10 disposition | Closure requirement |
|---|---|---|
| CQ001 | Blocking. | Replace root `LICENSE` placeholder with final selected license. |
| CQ002 | Blocking. | Record final documentation license and align README/notices. |
| CQ003 | Partially resolved. | M10 packet recommends allowlist release only; maintainer must approve final scope. |
| CQ005 | Blocking. | Finalize root `THIRD_PARTY_NOTICES.md` against exact release contents. |
| CQ006 | Blocking for binaries/packages. | Record Apple distribution agreement state and package distribution mode. |
| CQ012 | Blocking for compatibility work. | Define contributor hygiene for RE-aware contributors. |
| CQ017 | Deferred. | Decide whether `docs/compliance/**` is public governance material or internal-only packet. |
| CQ018 | Partially resolved. | M09/M10 archive recipe exists; release reviewer must approve or revise it. |
| CQ019 | Blocking for fixtures. | Sign off fixture provenance or keep fixtures excluded. |
| CQ023 | Blocking. | Public entry-point reviewer must sign off final archive links. |
| CQ024 | Blocking. | Name clean-room reviewer and record signoff. |

## Clean-Room And Evidence

| ID | Question | Owner/reviewer | Needed for |
|---|---|---|---|
| CQ012 | Who is allowed to read internal RE notes and still contribute implementation code? | Maintainer/legal | Contributor hygiene. |
| CQ013 | Should compatibility-mode implementation require a separate contributor or review process? | Maintainer/legal | Legacy compatibility. |
| CQ014 | Which fixture files are synthetic and which came from measured runs? | Maintainer | Fixture provenance. |
| CQ015 | Should public docs mention the existence of internal reverse-engineering evidence at all? | Maintainer/legal | Public documentation safety. |
| CQ016 | What exact evidence is required before any "compatible" claim is allowed? | Maintainer/legal | Compatibility claims. |

## Inventory And Release Manifest

| ID | Question | Owner/reviewer | Needed for |
|---|---|---|---|
| CQ017 | Is `docs/compliance/**` intended to be part of the public release or only internal governance material? | Maintainer/legal | Release manifest. |
| CQ018 | Which exact archive/export command should create the public release from the allowlist? | Maintainer/release reviewer | M09 release checklist. |
| CQ019 | Are all 53 JSON and 3 hex files under `Tests/OpenLolaCoreTests/Fixtures/` synthetic and redistributable? | Maintainer | Fixture provenance. |
| CQ020 | Should `research/RESEARCH_*.md` be excluded entirely or copied into a sanitized public research bundle? | Maintainer/legal | M02 public/internal separation. |
| CQ021 | What retention and access-control policy applies to `win-compiled/**` and `reverse-engineering/**` after public release? | Maintainer/legal | Internal evidence governance. |
| CQ022 | Is the M03 sanitized `docs/roadmap/**` export sufficient for public release, or should selected `archive/2026-05-05-workflow-consolidation/superseded/root/MAC_PORT_PLAN.md` / `mac-port/**` files receive separate curated exports? | Maintainer/legal | M10 review packet. |
| CQ023 | Who signs off that public entry points link only to curated summaries and not raw evidence paths? | Maintainer/compliance reviewer | M02 boundary closure. |
| CQ024 | Who is the named clean-room reviewer for `CRQ-*` requirement translations and compatibility-work gates? | Maintainer/legal | M04 clean-room closure. |

## Resume here

Close CQ001-CQ005 and CQ017-CQ024 before public release packaging. Close
CQ006-CQ011 before SDK-backed features. Close CQ012-CQ016 before
compatibility-mode code. Use [final-review-packet.md](final-review-packet.md) as
the M10 handoff and do not publish until its reviewer decisions are complete.

VERDICT: PARTIAL
