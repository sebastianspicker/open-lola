# Mac Port Compliance Review

Date: 2026-05-11
Status: repository assessment and remediation plan with current blocker overlay
Review type: engineering compliance risk analysis, not legal advice
Verdict: PARTIAL

## Current Blocker Overlay

Latest local refresh: 2026-05-11.

| Current report | Result | Compliance impact |
|---|---|---|
| `/private/tmp/open-lola-open-source-release-readiness-current.json` | `VERDICT: PARTIAL`; 9 requirements, 6 blockers. | Public source/docs release is still blocked by final source license, documentation license, final notices, fixture provenance, reviewer signoff, and public release approval. |
| `/private/tmp/open-lola-goal-completion-audit-current.json` | `VERDICT: PARTIAL`; 93 mapped items, 77 pass, 16 partial, 26 blockers. | Compliance closure alone cannot complete the goal; runtime, hardware, signing, and package evidence remain open. |
| `/private/tmp/open-lola-goal-runtime-preflight-current.json` | `VERDICT: PARTIAL`; 10 runtime deliverables are partial. | Current host lacks visible Core Audio/RME/video/Blackmagic candidates, camera permission, and Developer ID Application signing evidence. |

<!-- TODO(human): [Compliance review closure] -> Provide final release decisions and reviewer signoff for license, notices, fixture provenance, public release scope, and internal evidence boundaries before changing this review from PARTIAL -> [Approve curated source/docs release / keep review packet internal / defer release] -->

## Repository Assessment

This checkout is not a Git worktree, so this review is filesystem-based. The
M08 remediation removed generated `.DS_Store` metadata, and the 2026-05-09
refresh removed regenerated `.DS_Store` files again; neither pass modified
implementation code, research notes, binaries, or test fixtures.

Inspected materials include:

- `README.md` and `archive/2026-05-05-workflow-consolidation/superseded/root/MAC_PORT_PLAN.md`;
- `docs/`, including architecture, public research, benchmarks, source
  contracts, and historical public snapshots;
- `mac-port/`, including milestones, implementation companions, progress,
  reports, risk, SOTA matrix, workflow, and validation checklist;
- `background/`, including current and deprecated research notes;
- `reverse-engineering/`, including canonical summaries, deprecated detail,
  the LoLa 2.0 compatibility harness, and generated evidence packages;
- `win-compiled/`, including Windows EXE, DLL, installer, camera/config, and
  vendor runtime artifacts;
- `Sources/`, `Tests/`, `Package.swift`, and `scripts/`.

Current high-level state:

| Area | Assessment | Release posture |
|---|---|---|
| Mac port roadmap | Clean-room intent is explicit and audio-first implementation is separated from Windows compatibility. | Safe after compliance edits. |
| Public docs | Mostly architecture-level and already contain redaction rules. | Publish after review and link audit. |
| Internal research | Useful planning layer, but some files cite source studies, SDK terms, and compatibility assumptions that need provenance review. | Internal until sanitized. |
| Reverse-engineering docs | Strong evidence value, but contain raw static-analysis facts, generated names, packet hypotheses, ports, symbols, strings, hashes, and provenance detail. | Internal only. |
| Generated evidence packages | Include machine-readable strings, hashes, static-analysis outputs, and compatibility decoding drafts. | Internal only; do not publish. |
| Windows binaries | Proprietary or third-party binaries and installers with unclear redistribution rights. | Internal only until rights are clarified. |
| Swift source/tests | M08 audit found open-lola-owned native packet/session contracts and no copied proprietary code in the source/test surface. | Safe after license, fixture provenance, and M08 reviewer signoff. |
| Dependencies | No external SwiftPM packages; links Apple frameworks only. | Needs LICENSE and SDK notes. |
| Notices | Root `LICENSE` placeholder and draft `THIRD_PARTY_NOTICES.md` exist after M05. | Release blocker until final license/notice signoff. |

## Content Classification

| Classification | Paths | Reason |
|---|---|---|
| Safe for public release | `docs/current-state.md`, most `docs/architecture/*.md`, `docs/benchmarks/*.md`, `docs/source-contracts/*.md`, `Sources/`, `Tests/**/*.swift` | Original architecture, source contracts, original tests, and explicit PARTIAL claims after M08 reviewer signoff. |
| Safe after sanitization | `README.md`, `archive/2026-05-05-workflow-consolidation/superseded/root/MAC_PORT_PLAN.md`, `docs/background/*.md`, `mac-port/*.md`, `mac-port/milestones/*.md`, `mac-port/reports/*.md` | Useful public material, but needs compliance notes, license state, claim labels, and no links into raw RE artifacts from public releases. |
| Internal only | `reverse-engineering/**`, `research/deprecated-research/**`, `win-compiled/**` | Contains static-analysis detail, proprietary binaries, vendor runtimes, generated strings, hashes, packet hypotheses, and compatibility reconstruction. |
| Requires maintainer/legal review | `Package.swift`, `LICENSE`, `THIRD_PARTY_NOTICES.md`, Blackmagic/RME/Art-Net/Dante/AoIP references, public release tarball contents | License selection, SDK terms, driver/API constraints, attribution, and redistribution rules need owner review. |
| Should be removed or rewritten for public release | Generated evidence package contents if included in a public bundle; deprecated RE docs if linked from public docs; raw Windows binaries in source release | High copyright and redistribution risk if published as open-source project material. |
| Unknown / needs source clarification | Windows corpus origin, rights to redistribute vendor DLLs/installers/config payloads, sample capture permissions, future public fixture provenance | Missing explicit license/provenance records. |

## Risky Items

| Path | Issue | Risk type | Severity | Why it matters | Recommended action | Public-safe replacement wording |
|---|---|---|---|---|---|---|
| `win-compiled/**` | Bundled Windows EXE, DLL, installer, and camera/config artifacts have unclear redistribution rights. | License, copyright, redistribution | High | A public open-source release that includes these files may redistribute proprietary vendor or project binaries without permission. | Exclude from public release artifacts unless maintainer/legal review confirms rights. Keep as internal evidence. | "Internal static evidence corpus retained separately from the public source release." |
| `archive/2026-05-05-workflow-consolidation/internal-evidence/reverse-engineering/evidence-packages/**` | Generated inventories include hashes, strings, static-analysis summaries, and machine-readable evidence. | Proprietary information, clean-room contamination, copyright | High | Raw evidence can expose binary-derived implementation detail and contaminate implementation work. | Mark internal-only; never link from public docs. Create sanitized summaries only. | "Internal static analysis supports the requirement; raw evidence is withheld." |
| `archive/2026-05-05-workflow-consolidation/internal-evidence/reverse-engineering/evidence-packages/.../legacy-compatibility-mode/av-tx-rx-protocol-decoding.md` | Contains protocol grammar, byte offsets, packet hypotheses, function labels, and derived media-size reasoning. | Clean-room, public documentation, copyright | High | It is useful internal evidence, but unsafe as a public implementation spec. | Internal-only; convert only to independent requirements. | "Legacy systems use distinct media/control lanes; open-lola defines its own native packet contract." |
| `reverse-engineering/deprecated-reverse-engineering/**` | Historical reports contain address-level and function-cluster detail. | Public documentation, clean-room contamination | High | Deprecated docs are easier to accidentally cite because they remain readable. | Keep internal, add public release exclusion, avoid public links. | "Historical internal static notes exist for traceability." |
| `reverse-engineering/REVERSE_ENGINEERING_EVIDENCE_MATRIX_2026.md` | Matrix includes binary-derived symbols, imports, message classes, ports, and activation/identity observations. | Clean-room, security-sensitive disclosure | Medium | It is a valuable internal claim register but should not become a public roadmap. | Keep internal; convert rows through the research-to-requirements process. | "Observed legacy behavior suggests separate media/control responsibilities." |
| `reverse-engineering/lola-2-windows/**` | Compatibility harness plans parsers and synthetic packet fixtures from static evidence. | Clean-room, compatibility overclaim | Medium | Parser implementation can drift from observation into copied protocol behavior. | Require maintainer/legal review before implementing any compatibility parser. | "Compatibility mode is deferred until independently captured and authorized evidence exists." |
| `docs/background/*.md` | Public docs repeatedly say details are validated against internal RE notes. | Public documentation safety | Medium | This is acceptable if sanitized, but release reviewers must confirm no raw details or internal links leak. | Publish after release-surface audit. | "Claims are labeled and supported by sanitized internal evidence or open-lola tests." |
| `archive/2026-05-05-workflow-consolidation/superseded/root/MAC_PORT_PLAN.md` | Roadmap links directly to internal reverse-engineering evidence. | Public documentation boundary | Medium | Fine for repository-internal planning, unsafe if used as public landing page without context. | Keep as internal/public-mixed roadmap or provide sanitized public export. | "Internal evidence is maintained separately; public docs describe only architecture and validation." |
| `docs/architecture/open-lola-protocol.md` and UDP PCM source contracts | Defines native packet fields and guards. | Clean-room defense | Low | M08 found these are open-lola-owned contracts, but reviewer signoff is still required before release. | Keep tied to `CRQ-100`/`CRQ-101` and rerun the implementation audit before M10. | "open-lola UDP PCM is an original protocol, not a legacy packet grammar." |
| `.DS_Store` files | Generated macOS metadata was present in release/source paths and regenerated later. | Release hygiene | Low | Generated metadata should not be present in source archives. | Removed during M08 and again during the 2026-05-09 refresh; keep `.gitignore` rule. | Not applicable. |
| `Tests/OpenLolaCoreTests/Fixtures/**/*.hex` and JSON reports | Synthetic fixtures need explicit provenance. | Sample data license, clean-room | Medium | Fixture origin must be documented before public release. | Label as generated/open-lola-owned or exclude unclear samples. | "Synthetic fixture generated by open-lola tests." |
| `LICENSE` | Placeholder grants no final open-source license. | License | High | Users cannot know final reuse terms. | Replace placeholder with maintainer/legal-approved project license before publication. | "License pending maintainer/legal review." |
| `THIRD_PARTY_NOTICES.md` draft | Consolidated attribution/notice record is not final. | Attribution | High | Required for binaries, docs, SDK references, and public release clarity. | Finalize root notice file against the exact release allowlist before public release. | "Third-party notices are tracked in the release packet." |
| `mac-port/milestones/M12_SACN_ARTNET_FIXTURE_GATE.md` | Art-Net and sACN work depends on current standards and Art-Net terms. | Standards/license | Medium | Public docs and product guides may require credit and OEM code disposition. | Verify current standard/spec access and Art-Net requirements before release. | "Lighting protocols are gated by standards review and required acknowledgements." |
| `mac-port/milestones/M08_GENERIC_VIDEO_CAPTURE_PROBE.md` | Optional Blackmagic Desktop Video SDK path needs license and redistribution review. | SDK license | Medium | SDK headers/libraries may not be freely vendorable. | Keep optional SDK boundary out of generic builds; do not commit SDK files without permission. | "Blackmagic hardware may be accessed through public macOS capture APIs or an optional SDK adapter." |
| `mac-port/milestones/M07_AVB_PROFESSIONAL_AOIP_EVALUATION.md` | Dante and some AoIP paths can involve proprietary tooling and licensing. | SDK/license | Medium | Proprietary APIs or products may impose distribution and activation constraints. | Treat Dante/RAVENNA/AES67 as gated adapters; record license status per adapter. | "Professional AoIP interop is optional and license-gated." |

## Clean-Room Concerns

The public Mac-native path is mostly clean-room defensible because it:

- rejects Windows wire compatibility as a default constraint;
- implements native UDP PCM and session models with open-lola identifiers;
- keeps generated RE artifacts under `reverse-engineering/`;
- marks many runtime claims as `PARTIAL`.

Remaining concerns:

- internal compatibility docs contain enough protocol detail to contaminate
  implementation work if used directly;
- some source/test names contain "LoLa baseline" and "faster-than-LoLa" claims,
  which are acceptable as benchmark labels but should not imply copied behavior;
- public docs link from roadmap files to internal evidence, so public export
  must use a curated include list.

## Licensing Concerns

- Root `LICENSE` exists only as a pending placeholder.
- Root `THIRD_PARTY_NOTICES.md` exists only as an M07 notice and attribution
  draft.
- `Package.swift` declares no external SwiftPM dependencies, but links Apple
  frameworks: `AVFoundation`, `CoreAudio`, and `CoreMedia`.
- Blackmagic Desktop Video SDK is not committed, but optional SDK use must stay
  behind a non-default adapter and must not require SDK files for generic builds.
- RME driver/TotalMix behavior should be treated as installed user software,
  not vendored project material.
- Art-Net implementation requires current credit/OEM-code review before any
  product documentation or release claim.
- Dante and other proprietary AoIP lanes require separate vendor-license
  review before any integration.
- Windows DLLs/installers/config payloads in `win-compiled/` are release
  blockers if included in public artifacts.

## Public Documentation Concerns

Public docs should not publish:

- decompiled code or source-like pseudocode;
- generated function labels, offsets, addresses, or binary strings;
- raw packet dumps, byte maps, payload grammars, or control templates;
- license/authentication/host-identity observations;
- secrets, credentials, private endpoints, or live venue data;
- unsupported compatibility or performance claims.

Public docs may publish:

- architecture-level lessons;
- open-lola-owned design decisions;
- public standards and public API references;
- original tests, synthetic fixtures, and measured reports with sanitized
  metadata;
- confidence labels and explicit `PARTIAL` status.

## Current Recommended Action

Use the current blocker reports above as the active handoff. M01-M10 produced
the inventory, public/internal boundary, release manifest, dry-run archive, and
review packet, but they did not approve publication. Before any publication,
close the six open-source-readiness blockers, keep `win-compiled/`,
`reverse-engineering/`, raw/generated evidence packages, unclear fixtures,
private captures, and SDK/vendor files out of public artifacts unless
maintainer/legal review explicitly approves a different boundary, and attach
runtime/signing evidence for any binary/package claim.

VERDICT: PARTIAL
