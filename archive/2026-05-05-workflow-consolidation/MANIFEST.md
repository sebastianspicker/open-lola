# Workflow Documentation Consolidation Manifest

Date: 2026-05-05
Status: generated from the post-move filesystem tree
Verdict: PASS

This manifest records the documentation/workflow consolidation pass that moved superseded workflow docs and internal generated reverse-engineering evidence out of the active documentation surface. The checkout is not a Git worktree, so evidence is filesystem- and command-based.

## Active Entry Points

- `README.md`
- `docs/README.md`
- `mac-port/README.md`
- `mac-port/IMPLEMENTATION_COMPANION.md`
- `docs/testing/verification-matrix.md`
- `docs/compliance/public-internal-boundary.md`

Supporting active surfaces kept because they are source/verifier dependent or canonical ledgers: `GOAL.md`, `THIRD_PARTY_NOTICES.md`, public architecture/benchmark/source-contract docs, active compliance registers, active internal research/RE companions, and `mac-port` ledgers.

## Move Ledger

| Old path | New path | Classification | Reason | Active replacement |
|---|---|---|---|---|
| `MAC_PORT_PLAN.md` | `archive/2026-05-05-workflow-consolidation/superseded/root/MAC_PORT_PLAN.md` | Superseded | Root roadmap duplicate; replaced by README, docs roadmap, and implementation companion. | README.md; docs/roadmap/README.md; mac-port/IMPLEMENTATION_COMPANION.md |
| `SOURCE_AUDIT.md` | `archive/2026-05-05-workflow-consolidation/superseded/root/SOURCE_AUDIT.md` | Superseded | Completed source-structure audit; no longer an active workflow entry point. | mac-port/IMPLEMENTATION_COMPANION.md; SourceOwnershipInventory.swift |
| `docs/compliance/milestones/M01-inventory.md` | `archive/2026-05-05-workflow-consolidation/superseded/docs/compliance/milestones/M01-inventory.md` | Superseded | Compliance milestone snapshot replaced by current compliance registers and final review packet. | docs/compliance/README.md; docs/compliance/final-review-packet.md |
| `docs/compliance/milestones/M02-internal-vs-public-separation.md` | `archive/2026-05-05-workflow-consolidation/superseded/docs/compliance/milestones/M02-internal-vs-public-separation.md` | Superseded | Compliance milestone snapshot replaced by current compliance registers and final review packet. | docs/compliance/README.md; docs/compliance/final-review-packet.md |
| `docs/compliance/milestones/M03-sanitize-mac-port-roadmap.md` | `archive/2026-05-05-workflow-consolidation/superseded/docs/compliance/milestones/M03-sanitize-mac-port-roadmap.md` | Superseded | Compliance milestone snapshot replaced by current compliance registers and final review packet. | docs/compliance/README.md; docs/compliance/final-review-packet.md |
| `docs/compliance/milestones/M04-clean-room-requirements.md` | `archive/2026-05-05-workflow-consolidation/superseded/docs/compliance/milestones/M04-clean-room-requirements.md` | Superseded | Compliance milestone snapshot replaced by current compliance registers and final review packet. | docs/compliance/README.md; docs/compliance/final-review-packet.md |
| `docs/compliance/milestones/M05-license-review.md` | `archive/2026-05-05-workflow-consolidation/superseded/docs/compliance/milestones/M05-license-review.md` | Superseded | Compliance milestone snapshot replaced by current compliance registers and final review packet. | docs/compliance/README.md; docs/compliance/final-review-packet.md |
| `docs/compliance/milestones/M06-public-doc-review.md` | `archive/2026-05-05-workflow-consolidation/superseded/docs/compliance/milestones/M06-public-doc-review.md` | Superseded | Compliance milestone snapshot replaced by current compliance registers and final review packet. | docs/compliance/README.md; docs/compliance/final-review-packet.md |
| `docs/compliance/milestones/M07-notices-attribution.md` | `archive/2026-05-05-workflow-consolidation/superseded/docs/compliance/milestones/M07-notices-attribution.md` | Superseded | Compliance milestone snapshot replaced by current compliance registers and final review packet. | docs/compliance/README.md; docs/compliance/final-review-packet.md |
| `docs/compliance/milestones/M08-implementation-audit.md` | `archive/2026-05-05-workflow-consolidation/superseded/docs/compliance/milestones/M08-implementation-audit.md` | Superseded | Compliance milestone snapshot replaced by current compliance registers and final review packet. | docs/compliance/README.md; docs/compliance/final-review-packet.md |
| `docs/compliance/milestones/M09-release-checklist.md` | `archive/2026-05-05-workflow-consolidation/superseded/docs/compliance/milestones/M09-release-checklist.md` | Superseded | Compliance milestone snapshot replaced by current compliance registers and final review packet. | docs/compliance/README.md; docs/compliance/final-review-packet.md |
| `docs/compliance/milestones/M10-review-packet.md` | `archive/2026-05-05-workflow-consolidation/superseded/docs/compliance/milestones/M10-review-packet.md` | Superseded | Compliance milestone snapshot replaced by current compliance registers and final review packet. | docs/compliance/README.md; docs/compliance/final-review-packet.md |
| `docs/compliance/release-readiness-checklist-run.md` | `archive/2026-05-05-workflow-consolidation/superseded/docs/compliance/release-readiness-checklist-run.md` | Superseded | Dry-run checklist snapshot replaced by active verification matrix and release gates. | docs/testing/verification-matrix.md; docs/compliance/release-manifest.md; docs/compliance/release-artifact-hygiene.md |
| `mac-port/WORKFLOW.md` | `archive/2026-05-05-workflow-consolidation/superseded/mac-port/WORKFLOW.md` | Superseded | Workflow duplicate; active workflow is in the implementation companion. | mac-port/IMPLEMENTATION_COMPANION.md |
| `reverse-engineering/evidence-packages/folder-analysis-20260503-1747/README.md` | `archive/2026-05-05-workflow-consolidation/internal-evidence/reverse-engineering/evidence-packages/folder-analysis-20260503-1747/README.md` | Internal/private-boundary | Generated static-analysis evidence moved out of the active workflow tree. | reverse-engineering/REVERSE_ENGINEERING_COMPANION_2026.md; docs/compliance/reverse-engineering-boundary.md |
| `reverse-engineering/evidence-packages/folder-analysis-20260503-1747/artifact-inventory.md` | `archive/2026-05-05-workflow-consolidation/internal-evidence/reverse-engineering/evidence-packages/folder-analysis-20260503-1747/artifact-inventory.md` | Internal/private-boundary | Generated static-analysis evidence moved out of the active workflow tree. | reverse-engineering/REVERSE_ENGINEERING_COMPANION_2026.md; docs/compliance/reverse-engineering-boundary.md |
| `reverse-engineering/evidence-packages/folder-analysis-20260503-1747/av-tx-rx-analysis.md` | `archive/2026-05-05-workflow-consolidation/internal-evidence/reverse-engineering/evidence-packages/folder-analysis-20260503-1747/av-tx-rx-analysis.md` | Internal/private-boundary | Generated static-analysis evidence moved out of the active workflow tree. | reverse-engineering/REVERSE_ENGINEERING_COMPANION_2026.md; docs/compliance/reverse-engineering-boundary.md |
| `reverse-engineering/evidence-packages/folder-analysis-20260503-1747/data/artifacts.json` | `archive/2026-05-05-workflow-consolidation/internal-evidence/reverse-engineering/evidence-packages/folder-analysis-20260503-1747/data/artifacts.json` | Internal/private-boundary | Generated static-analysis evidence moved out of the active workflow tree. | reverse-engineering/REVERSE_ENGINEERING_COMPANION_2026.md; docs/compliance/reverse-engineering-boundary.md |
| `reverse-engineering/evidence-packages/folder-analysis-20260503-1747/data/strings-interest.json` | `archive/2026-05-05-workflow-consolidation/internal-evidence/reverse-engineering/evidence-packages/folder-analysis-20260503-1747/data/strings-interest.json` | Internal/private-boundary | Generated static-analysis evidence moved out of the active workflow tree. | reverse-engineering/REVERSE_ENGINEERING_COMPANION_2026.md; docs/compliance/reverse-engineering-boundary.md |
| `reverse-engineering/evidence-packages/folder-analysis-20260503-1747/diagrams.md` | `archive/2026-05-05-workflow-consolidation/internal-evidence/reverse-engineering/evidence-packages/folder-analysis-20260503-1747/diagrams.md` | Internal/private-boundary | Generated static-analysis evidence moved out of the active workflow tree. | reverse-engineering/REVERSE_ENGINEERING_COMPANION_2026.md; docs/compliance/reverse-engineering-boundary.md |
| `reverse-engineering/evidence-packages/folder-analysis-20260503-1747/findings.md` | `archive/2026-05-05-workflow-consolidation/internal-evidence/reverse-engineering/evidence-packages/folder-analysis-20260503-1747/findings.md` | Internal/private-boundary | Generated static-analysis evidence moved out of the active workflow tree. | reverse-engineering/REVERSE_ENGINEERING_COMPANION_2026.md; docs/compliance/reverse-engineering-boundary.md |
| `reverse-engineering/evidence-packages/folder-analysis-20260503-1747/ghidra/v2-main.audio-deep.md` | `archive/2026-05-05-workflow-consolidation/internal-evidence/reverse-engineering/evidence-packages/folder-analysis-20260503-1747/ghidra/v2-main.audio-deep.md` | Internal/private-boundary | Generated static-analysis evidence moved out of the active workflow tree. | reverse-engineering/REVERSE_ENGINEERING_COMPANION_2026.md; docs/compliance/reverse-engineering-boundary.md |
| `reverse-engineering/evidence-packages/folder-analysis-20260503-1747/ghidra/v2-main.ghidra-summary.md` | `archive/2026-05-05-workflow-consolidation/internal-evidence/reverse-engineering/evidence-packages/folder-analysis-20260503-1747/ghidra/v2-main.ghidra-summary.md` | Internal/private-boundary | Generated static-analysis evidence moved out of the active workflow tree. | reverse-engineering/REVERSE_ENGINEERING_COMPANION_2026.md; docs/compliance/reverse-engineering-boundary.md |
| `reverse-engineering/evidence-packages/folder-analysis-20260503-1747/ghidra/v2-main.network-session-deep.md` | `archive/2026-05-05-workflow-consolidation/internal-evidence/reverse-engineering/evidence-packages/folder-analysis-20260503-1747/ghidra/v2-main.network-session-deep.md` | Internal/private-boundary | Generated static-analysis evidence moved out of the active workflow tree. | reverse-engineering/REVERSE_ENGINEERING_COMPANION_2026.md; docs/compliance/reverse-engineering-boundary.md |
| `reverse-engineering/evidence-packages/folder-analysis-20260503-1747/ghidra/v2-main.video-deep.md` | `archive/2026-05-05-workflow-consolidation/internal-evidence/reverse-engineering/evidence-packages/folder-analysis-20260503-1747/ghidra/v2-main.video-deep.md` | Internal/private-boundary | Generated static-analysis evidence moved out of the active workflow tree. | reverse-engineering/REVERSE_ENGINEERING_COMPANION_2026.md; docs/compliance/reverse-engineering-boundary.md |
| `reverse-engineering/evidence-packages/folder-analysis-20260503-1747/ghidra/v2-tester.ghidra-summary.md` | `archive/2026-05-05-workflow-consolidation/internal-evidence/reverse-engineering/evidence-packages/folder-analysis-20260503-1747/ghidra/v2-tester.ghidra-summary.md` | Internal/private-boundary | Generated static-analysis evidence moved out of the active workflow tree. | reverse-engineering/REVERSE_ENGINEERING_COMPANION_2026.md; docs/compliance/reverse-engineering-boundary.md |
| `reverse-engineering/evidence-packages/folder-analysis-20260503-1747/ghidra/v2-video-converter.ghidra-summary.md` | `archive/2026-05-05-workflow-consolidation/internal-evidence/reverse-engineering/evidence-packages/folder-analysis-20260503-1747/ghidra/v2-video-converter.ghidra-summary.md` | Internal/private-boundary | Generated static-analysis evidence moved out of the active workflow tree. | reverse-engineering/REVERSE_ENGINEERING_COMPANION_2026.md; docs/compliance/reverse-engineering-boundary.md |
| `reverse-engineering/evidence-packages/folder-analysis-20260503-1747/ghidra/v2-wav-splitter.ghidra-summary.md` | `archive/2026-05-05-workflow-consolidation/internal-evidence/reverse-engineering/evidence-packages/folder-analysis-20260503-1747/ghidra/v2-wav-splitter.ghidra-summary.md` | Internal/private-boundary | Generated static-analysis evidence moved out of the active workflow tree. | reverse-engineering/REVERSE_ENGINEERING_COMPANION_2026.md; docs/compliance/reverse-engineering-boundary.md |
| `reverse-engineering/evidence-packages/folder-analysis-20260503-1747/legacy-compatibility-mode/README.md` | `archive/2026-05-05-workflow-consolidation/internal-evidence/reverse-engineering/evidence-packages/folder-analysis-20260503-1747/legacy-compatibility-mode/README.md` | Internal/private-boundary | Generated static-analysis evidence moved out of the active workflow tree. | reverse-engineering/REVERSE_ENGINEERING_COMPANION_2026.md; docs/compliance/reverse-engineering-boundary.md |
| `reverse-engineering/evidence-packages/folder-analysis-20260503-1747/legacy-compatibility-mode/av-tx-rx-protocol-decoding.md` | `archive/2026-05-05-workflow-consolidation/internal-evidence/reverse-engineering/evidence-packages/folder-analysis-20260503-1747/legacy-compatibility-mode/av-tx-rx-protocol-decoding.md` | Internal/private-boundary | Generated static-analysis evidence moved out of the active workflow tree. | reverse-engineering/REVERSE_ENGINEERING_COMPANION_2026.md; docs/compliance/reverse-engineering-boundary.md |
| `reverse-engineering/evidence-packages/folder-analysis-20260503-1747/legacy-compatibility-mode/codec-and-media-findings.md` | `archive/2026-05-05-workflow-consolidation/internal-evidence/reverse-engineering/evidence-packages/folder-analysis-20260503-1747/legacy-compatibility-mode/codec-and-media-findings.md` | Internal/private-boundary | Generated static-analysis evidence moved out of the active workflow tree. | reverse-engineering/REVERSE_ENGINEERING_COMPANION_2026.md; docs/compliance/reverse-engineering-boundary.md |
| `reverse-engineering/evidence-packages/folder-analysis-20260503-1747/legacy-compatibility-mode/compatibility-artifact-map.md` | `archive/2026-05-05-workflow-consolidation/internal-evidence/reverse-engineering/evidence-packages/folder-analysis-20260503-1747/legacy-compatibility-mode/compatibility-artifact-map.md` | Internal/private-boundary | Generated static-analysis evidence moved out of the active workflow tree. | reverse-engineering/REVERSE_ENGINEERING_COMPANION_2026.md; docs/compliance/reverse-engineering-boundary.md |
| `reverse-engineering/evidence-packages/folder-analysis-20260503-1747/legacy-compatibility-mode/data/compatibility-artifacts.json` | `archive/2026-05-05-workflow-consolidation/internal-evidence/reverse-engineering/evidence-packages/folder-analysis-20260503-1747/legacy-compatibility-mode/data/compatibility-artifacts.json` | Internal/private-boundary | Generated static-analysis evidence moved out of the active workflow tree. | reverse-engineering/REVERSE_ENGINEERING_COMPANION_2026.md; docs/compliance/reverse-engineering-boundary.md |
| `reverse-engineering/evidence-packages/folder-analysis-20260503-1747/legacy-compatibility-mode/definition-of-done-ledger.md` | `archive/2026-05-05-workflow-consolidation/internal-evidence/reverse-engineering/evidence-packages/folder-analysis-20260503-1747/legacy-compatibility-mode/definition-of-done-ledger.md` | Internal/private-boundary | Generated static-analysis evidence moved out of the active workflow tree. | reverse-engineering/REVERSE_ENGINEERING_COMPANION_2026.md; docs/compliance/reverse-engineering-boundary.md |
| `reverse-engineering/evidence-packages/folder-analysis-20260503-1747/legacy-compatibility-mode/exe-deep-summary.md` | `archive/2026-05-05-workflow-consolidation/internal-evidence/reverse-engineering/evidence-packages/folder-analysis-20260503-1747/legacy-compatibility-mode/exe-deep-summary.md` | Internal/private-boundary | Generated static-analysis evidence moved out of the active workflow tree. | reverse-engineering/REVERSE_ENGINEERING_COMPANION_2026.md; docs/compliance/reverse-engineering-boundary.md |
| `reverse-engineering/evidence-packages/folder-analysis-20260503-1747/legacy-compatibility-mode/legacy-compatibility-roadmap.md` | `archive/2026-05-05-workflow-consolidation/internal-evidence/reverse-engineering/evidence-packages/folder-analysis-20260503-1747/legacy-compatibility-mode/legacy-compatibility-roadmap.md` | Internal/private-boundary | Generated static-analysis evidence moved out of the active workflow tree. | reverse-engineering/REVERSE_ENGINEERING_COMPANION_2026.md; docs/compliance/reverse-engineering-boundary.md |
| `reverse-engineering/evidence-packages/folder-analysis-20260503-1747/legacy-compatibility-mode/string-interest-triage.md` | `archive/2026-05-05-workflow-consolidation/internal-evidence/reverse-engineering/evidence-packages/folder-analysis-20260503-1747/legacy-compatibility-mode/string-interest-triage.md` | Internal/private-boundary | Generated static-analysis evidence moved out of the active workflow tree. | reverse-engineering/REVERSE_ENGINEERING_COMPANION_2026.md; docs/compliance/reverse-engineering-boundary.md |
| `reverse-engineering/evidence-packages/folder-analysis-20260503-1747/strings-of-interest.md` | `archive/2026-05-05-workflow-consolidation/internal-evidence/reverse-engineering/evidence-packages/folder-analysis-20260503-1747/strings-of-interest.md` | Internal/private-boundary | Generated static-analysis evidence moved out of the active workflow tree. | reverse-engineering/REVERSE_ENGINEERING_COMPANION_2026.md; docs/compliance/reverse-engineering-boundary.md |
| `reverse-engineering/evidence-packages/folder-analysis-20260503-1747/tool-evidence.md` | `archive/2026-05-05-workflow-consolidation/internal-evidence/reverse-engineering/evidence-packages/folder-analysis-20260503-1747/tool-evidence.md` | Internal/private-boundary | Generated static-analysis evidence moved out of the active workflow tree. | reverse-engineering/REVERSE_ENGINEERING_COMPANION_2026.md; docs/compliance/reverse-engineering-boundary.md |
| `reverse-engineering/evidence-packages/folder-analysis-20260503-1747/tools/compatibility_dossier.py` | `archive/2026-05-05-workflow-consolidation/internal-evidence/reverse-engineering/evidence-packages/folder-analysis-20260503-1747/tools/compatibility_dossier.py` | Internal/private-boundary | Generated static-analysis evidence moved out of the active workflow tree. | reverse-engineering/REVERSE_ENGINEERING_COMPANION_2026.md; docs/compliance/reverse-engineering-boundary.md |
| `reverse-engineering/evidence-packages/folder-analysis-20260503-1747/tools/compatibility_model.py` | `archive/2026-05-05-workflow-consolidation/internal-evidence/reverse-engineering/evidence-packages/folder-analysis-20260503-1747/tools/compatibility_model.py` | Internal/private-boundary | Generated static-analysis evidence moved out of the active workflow tree. | reverse-engineering/REVERSE_ENGINEERING_COMPANION_2026.md; docs/compliance/reverse-engineering-boundary.md |
| `reverse-engineering/evidence-packages/folder-analysis-20260503-1747/tools/compatibility_roadmap.py` | `archive/2026-05-05-workflow-consolidation/internal-evidence/reverse-engineering/evidence-packages/folder-analysis-20260503-1747/tools/compatibility_roadmap.py` | Internal/private-boundary | Generated static-analysis evidence moved out of the active workflow tree. | reverse-engineering/REVERSE_ENGINEERING_COMPANION_2026.md; docs/compliance/reverse-engineering-boundary.md |
| `reverse-engineering/evidence-packages/folder-analysis-20260503-1747/tools/compatibility_writers.py` | `archive/2026-05-05-workflow-consolidation/internal-evidence/reverse-engineering/evidence-packages/folder-analysis-20260503-1747/tools/compatibility_writers.py` | Internal/private-boundary | Generated static-analysis evidence moved out of the active workflow tree. | reverse-engineering/REVERSE_ENGINEERING_COMPANION_2026.md; docs/compliance/reverse-engineering-boundary.md |
| `reverse-engineering/evidence-packages/folder-analysis-20260503-1747/tools/static_inventory.py` | `archive/2026-05-05-workflow-consolidation/internal-evidence/reverse-engineering/evidence-packages/folder-analysis-20260503-1747/tools/static_inventory.py` | Internal/private-boundary | Generated static-analysis evidence moved out of the active workflow tree. | reverse-engineering/REVERSE_ENGINEERING_COMPANION_2026.md; docs/compliance/reverse-engineering-boundary.md |
| `reverse-engineering/evidence-packages/folder-analysis-20260503-1747/tools/static_inventory_core.py` | `archive/2026-05-05-workflow-consolidation/internal-evidence/reverse-engineering/evidence-packages/folder-analysis-20260503-1747/tools/static_inventory_core.py` | Internal/private-boundary | Generated static-analysis evidence moved out of the active workflow tree. | reverse-engineering/REVERSE_ENGINEERING_COMPANION_2026.md; docs/compliance/reverse-engineering-boundary.md |
| `reverse-engineering/evidence-packages/folder-analysis-20260503-1747/tools/static_inventory_evidence.py` | `archive/2026-05-05-workflow-consolidation/internal-evidence/reverse-engineering/evidence-packages/folder-analysis-20260503-1747/tools/static_inventory_evidence.py` | Internal/private-boundary | Generated static-analysis evidence moved out of the active workflow tree. | reverse-engineering/REVERSE_ENGINEERING_COMPANION_2026.md; docs/compliance/reverse-engineering-boundary.md |
| `reverse-engineering/evidence-packages/folder-analysis-20260503-1747/tools/static_inventory_writers.py` | `archive/2026-05-05-workflow-consolidation/internal-evidence/reverse-engineering/evidence-packages/folder-analysis-20260503-1747/tools/static_inventory_writers.py` | Internal/private-boundary | Generated static-analysis evidence moved out of the active workflow tree. | reverse-engineering/REVERSE_ENGINEERING_COMPANION_2026.md; docs/compliance/reverse-engineering-boundary.md |

## Classification Inventory

| Path | Classification | Note |
|---|---|---|
| `GOAL.md` | Active | Active product contract referenced by report schemas |
| `README.md` | Active | Active public entry point |
| `THIRD_PARTY_NOTICES.md` | Active | Active release notice draft |
| `archive/2026-05-05-doc-consolidation/MANIFEST.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/README.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/docs/historical/README.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/docs/historical/public-m01-m14-implementation-plans-2026-05-04/README.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/docs/historical/public-m01-m14-implementation-plans-2026-05-04/milestones/M01-current-state-audit.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/docs/historical/public-m01-m14-implementation-plans-2026-05-04/milestones/M02-core-protocol-session-model.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/docs/historical/public-m01-m14-implementation-plans-2026-05-04/milestones/M03-madi-tx.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/docs/historical/public-m01-m14-implementation-plans-2026-05-04/milestones/M04-madi-rx.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/docs/historical/public-m01-m14-implementation-plans-2026-05-04/milestones/M05-madi-full-duplex-e2e.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/docs/historical/public-m01-m14-implementation-plans-2026-05-04/milestones/M06-direct-p2p-media-transport.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/docs/historical/public-m01-m14-implementation-plans-2026-05-04/milestones/M07-latency-profiles-rx-buffer.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/docs/historical/public-m01-m14-implementation-plans-2026-05-04/milestones/M08-blackmagic-capture-tx.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/docs/historical/public-m01-m14-implementation-plans-2026-05-04/milestones/M09-blackmagic-rx-render-output.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/docs/historical/public-m01-m14-implementation-plans-2026-05-04/milestones/M10-multiple-video-streams.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/docs/historical/public-m01-m14-implementation-plans-2026-05-04/milestones/M11-av-sync-timing.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/docs/historical/public-m01-m14-implementation-plans-2026-05-04/milestones/M12-apple-silicon-performance.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/docs/historical/public-m01-m14-implementation-plans-2026-05-04/milestones/M13-e2e-integrated-benchmark.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/docs/historical/public-m01-m14-implementation-plans-2026-05-04/milestones/M14-release-hardening.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/docs/historical/public-m01-m14-roadmap-2026-05-03/README.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/docs/historical/public-m01-m14-roadmap-2026-05-03/architecture/implementation-roadmap.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/docs/historical/public-m01-m14-roadmap-2026-05-03/milestones/M01-clean-room-requirements.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/docs/historical/public-m01-m14-roadmap-2026-05-03/milestones/M02-latency-budget-benchmarks.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/docs/historical/public-m01-m14-roadmap-2026-05-03/milestones/M03-audio-device-abstraction.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/docs/historical/public-m01-m14-roadmap-2026-05-03/milestones/M04-audio-loopback.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/docs/historical/public-m01-m14-roadmap-2026-05-03/milestones/M05-p2p-audio-transport.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/docs/historical/public-m01-m14-roadmap-2026-05-03/milestones/M06-jitter-clock-drift.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/docs/historical/public-m01-m14-roadmap-2026-05-03/milestones/M07-latency-tuning.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/docs/historical/public-m01-m14-roadmap-2026-05-03/milestones/M08-video-capture.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/docs/historical/public-m01-m14-roadmap-2026-05-03/milestones/M09-video-transport.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/docs/historical/public-m01-m14-roadmap-2026-05-03/milestones/M10-av-sync.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/docs/historical/public-m01-m14-roadmap-2026-05-03/milestones/M11-lighting-control.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/docs/historical/public-m01-m14-roadmap-2026-05-03/milestones/M12-integrated-profile.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/docs/historical/public-m01-m14-roadmap-2026-05-03/milestones/M13-hardware-validation.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/docs/historical/public-m01-m14-roadmap-2026-05-03/milestones/M14-release-hardening.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/docs/review/README.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/docs/review/cleanup-candidates.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/docs/review/cli-command-inventory.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/docs/review/companions/C01_CLI_COMMAND_ROUTER_AND_ARGUMENT_PARSING.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/docs/review/companions/C02_CORE_SOURCE_OWNERSHIP_SPLIT.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/docs/review/companions/C03_REPORT_VALIDATOR_DEDUP_AND_EVIDENCE_SCHEMA.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/docs/review/companions/C04_RUNTIME_CLAIM_GATES_SYNTHETIC_VS_MEASURED.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/docs/review/companions/C05_NETWORK_TRANSPORT_ROUTE_AND_ARGUMENTS.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/docs/review/companions/C06_REALTIME_AUDIO_BUFFERING_AND_LATENCY.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/docs/review/companions/C07_VIDEO_CONTROL_DEGRADE_FIRST_PATH.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/docs/review/companions/C08_TEST_FIXTURE_AND_CLI_SMOKE_MATRIX.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/docs/review/companions/C09_PACKAGING_SIGNING_CLEAN_MAC_RELEASE_GATE.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/docs/review/companions/C10_VERIFICATION_TOOLING_AND_CI_PARITY.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/docs/review/companions/C11_MACOS_APP_SHELL_RUNTIME_READINESS.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/docs/review/companions/C12_ARTIFACT_DEPENDENCY_GENERATED_OUTPUT_HYGIENE.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/docs/review/companions/CODE_IMPROVEMENT_MILESTONES.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/docs/review/companions/CODE_RELEASE_READINESS_ROADMAP.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/docs/review/companions/M-REVIEW-01_DOCUMENTATION_AUDIT.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/docs/review/companions/M-REVIEW-02_SOURCE_TEST_DOC_CROSSWALK_AND_BOUNDARY_CLOSURE.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/docs/review/companions/N01_REVIEW_BOUNDARY_DECISION.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/docs/review/companions/N02_GENERATED_OUTPUT_HYGIENE.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/docs/review/companions/N03_RELEASE_MANIFEST_POLICY.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/docs/review/companions/N04_LICENSE_NOTICES_CLOSURE.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/docs/review/companions/N05_SOURCE_TEST_DOC_CROSSWALK.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/docs/review/companions/N06_MEASURED_EVIDENCE_LEDGER.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/docs/review/companions/N07_SOURCE_RESTRUCTURE_PLAN.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/docs/review/companions/N08_INCREMENTAL_SOURCE_MOVES.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/docs/review/companions/N09_CI_AFTER_GIT_CONTEXT.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/docs/review/companions/README.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/docs/review/documentation-restructure-proposal.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/docs/review/file-classification-index.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/docs/review/fixture-cli-smoke-matrix.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/docs/review/functional-categorization.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/docs/review/improvement-roadmap.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/docs/review/module-responsibility-map.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/docs/review/network-route-command-matrix.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/docs/review/next-actions.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/docs/review/open-questions.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/docs/review/realtime-audio-path-inventory.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/docs/review/release-artifact-hygiene.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/docs/review/report-schema-inventory.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/docs/review/risk-register.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/docs/review/source-ownership-inventory.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/docs/review/source-restructure-proposal.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/docs/review/verification-matrix.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/docs/review/video-control-degrade-matrix.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/mac-port/historical/AUDIO_FIRST_LATENCY_PLAN.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/mac-port/historical/MAC_PORT_PLAN_PRE_MILESTONE_ROADMAP_2026.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/mac-port/historical/PROGRESS_PRE_HARNESS_2026-05-02.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/mac-port/historical/README.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/mac-port/historical/README_PRE_HARNESS_2026-05-02.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/mac-port/historical/implementation-companions-2026-05-03/gaps/G01_MEASUREMENT_RIG_AND_REFERENCE_HARDWARE.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/mac-port/historical/implementation-companions-2026-05-03/gaps/G02_RME_MADI_FASTEST_AUDIO_PATH.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/mac-port/historical/implementation-companions-2026-05-03/gaps/G03_REALTIME_CORE_AUDIO_ENGINE.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/mac-port/historical/implementation-companions-2026-05-03/gaps/G04_MAC_TO_MAC_UDP_PCM_ROUTE.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/mac-port/historical/implementation-companions-2026-05-03/gaps/G05_DRIFT_PLC_FIXED_TARGET.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/mac-port/historical/implementation-companions-2026-05-03/gaps/G06_NETWORK_TIMING_AND_AOIP.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/mac-port/historical/implementation-companions-2026-05-03/gaps/G07_AVFOUNDATION_CAPTURE.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/mac-port/historical/implementation-companions-2026-05-03/gaps/G08_BLACKMAGIC_ATEM_READONLY.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/mac-port/historical/implementation-companions-2026-05-03/gaps/G09_VIDEO_TRANSPORT_DEGRADES_FIRST.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/mac-port/historical/implementation-companions-2026-05-03/gaps/G10_INTEGRATED_HEADLESS_AV_PROOF.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/mac-port/historical/implementation-companions-2026-05-03/gaps/G11_OSC_CUE_LOOP.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/mac-port/historical/implementation-companions-2026-05-03/gaps/G12_LIGHTING_FIXTURE_GATE.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/mac-port/historical/implementation-companions-2026-05-03/gaps/G13_NATIVE_APP_RUNTIME.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/mac-port/historical/implementation-companions-2026-05-03/gaps/G14_RECORDING_SESSION_ARTIFACTS.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/mac-port/historical/implementation-companions-2026-05-03/gaps/G15_PACKAGING_CLEAN_MAC_FIELD_TEST.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/mac-port/historical/implementation-companions-2026-05-03/gaps/G16_LOLA_PARITY_DEFERRED_FEATURES.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/mac-port/historical/implementation-companions-2026-05-03/gaps/README.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/mac-port/historical/implementation-companions-2026-05-03/prototype/P00_PROTOTYPE_INDEX.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/mac-port/historical/implementation-companions-2026-05-03/prototype/P01_RME_MADI_HARDWARE_PATH.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/mac-port/historical/implementation-companions-2026-05-03/prototype/P02_REALTIME_AUDIO_ENGINE.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/mac-port/historical/implementation-companions-2026-05-03/prototype/P03_BLACKMAGIC_ATEM_PATH.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/mac-port/historical/implementation-companions-2026-05-03/prototype/P04_INTEGRATED_AV_PROOF.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/mac-port/historical/implementation-companions-2026-05-03/prototype/P05_FIELD_READY_RUNTIME.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/mac-port/historical/implementation-companions-2026-05-03/prototype/README.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/mac-port/historical/implementation-companions-2026-05-03/prototype/status/P01_STATUS.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/mac-port/historical/implementation-companions-2026-05-03/prototype/status/P02_STATUS.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/mac-port/historical/implementation-companions-2026-05-03/prototype/status/P03_STATUS.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/mac-port/historical/implementation-companions-2026-05-03/prototype/status/P04_STATUS.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/mac-port/historical/implementation-companions-2026-05-03/prototype/status/P05_STATUS.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/mac-port/historical/implementation-companions-2026-05-03/status/M00_STATUS.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/mac-port/historical/implementation-companions-2026-05-03/status/M01_STATUS.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/mac-port/historical/implementation-companions-2026-05-03/status/M02_STATUS.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/mac-port/historical/implementation-companions-2026-05-03/status/M03_STATUS.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/mac-port/historical/implementation-companions-2026-05-03/status/M04_STATUS.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/mac-port/historical/implementation-companions-2026-05-03/status/M05_STATUS.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/mac-port/historical/implementation-companions-2026-05-03/status/M06_STATUS.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/mac-port/historical/implementation-companions-2026-05-03/status/M07_STATUS.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/mac-port/historical/implementation-companions-2026-05-03/status/M08_STATUS.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/mac-port/historical/implementation-companions-2026-05-03/status/M09_STATUS.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/mac-port/historical/implementation-companions-2026-05-03/status/M10_STATUS.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/mac-port/historical/implementation-companions-2026-05-03/status/M11_STATUS.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/mac-port/historical/implementation-companions-2026-05-03/status/M12_STATUS.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/mac-port/historical/implementation-companions-2026-05-03/status/M13_STATUS.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/mac-port/historical/implementation-companions-2026-05-03/status/M14_STATUS.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/mac-port/historical/implementation-companions-2026-05-03/status/M15_STATUS.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/mac-port/historical/reports-2026-05-03/F12_RENDEZVOUS_SERVICE_2026-05-03.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/mac-port/historical/reports-2026-05-03/M05_ROUTE_CERTIFICATION_2026-05-02.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/mac-port/historical/reports-2026-05-03/README.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/mac-port/implementation-companions/F01_RME_MADI_THUNDERBOLT_AUDIO.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/mac-port/implementation-companions/F02_REALTIME_DUPLEX_AUDIO_ENGINE.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/mac-port/implementation-companions/F03_P2P_NETWORK_ROUTE.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/mac-port/implementation-companions/F04_AUDIO_DRIFT_PLC_AND_BENCHMARK.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/mac-port/implementation-companions/F05_BLACKMAGIC_ATEM_CAPTURE.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/mac-port/implementation-companions/F06_VIDEO_TRANSPORT.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/mac-port/implementation-companions/F07_INTEGRATED_AV_RUNTIME.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/mac-port/implementation-companions/F08_LIGHTING_P2P_WORKFLOW.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/mac-port/implementation-companions/F09_APP_RECORDING_PACKAGING_FIELD.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/mac-port/implementation-companions/F10_FASTER_THAN_LOLA_CLOSURE.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/mac-port/implementation-companions/F11_NETWORK_LOOPBACK_DIAGNOSTICS.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/mac-port/implementation-companions/F12_NAT_ISP_FRIENDLY_ROUTE.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/mac-port/milestones/M00_EVIDENCE_BASELINE_AND_REPO_SCAFFOLD.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/mac-port/milestones/M01_MEASUREMENT_HARDWARE_NETWORK_PROFILE.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/mac-port/milestones/M02_CORE_AUDIO_DEVICE_INVENTORY.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/mac-port/milestones/M03_ENDPOINT_LOOPBACK_FASTEST_MODE.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/mac-port/milestones/M04_UDP_PCM_PACKET_CONTRACT.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/mac-port/milestones/M05_MAC_TO_MAC_ROUTE_CERTIFICATION.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/mac-port/milestones/M06_DRIFT_AND_SAME_DEADLINE_PLC.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/mac-port/milestones/M07_AVB_PROFESSIONAL_AOIP_EVALUATION.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/mac-port/milestones/M08_GENERIC_VIDEO_CAPTURE_PROBE.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/mac-port/milestones/M09_NATIVE_VIDEO_TRANSPORT.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/mac-port/milestones/M10_INTEGRATED_HEADLESS_AV.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/mac-port/milestones/M11_OSC_SHOW_CONTROL_PROBE.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/mac-port/milestones/M12_SACN_ARTNET_FIXTURE_GATE.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/mac-port/milestones/M13_NATIVE_APP_SHELL.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/mac-port/milestones/M14_RECORDING_SESSION_ARTIFACTS.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/mac-port/milestones/M15_PACKAGING_FIELD_TEST.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/mac-port/reports/F10_FASTER_THAN_LOLA_CLOSURE_2026-05-03.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/mac-port/reports/F11_DIRECT_LINK_LOOPBACK_2026-05-03.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/mac-port/reports/F11_NETWORK_LOOPBACK_DIAGNOSTICS_2026-05-03.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/mac-port/reports/F11_SESSION_AGREEMENT_2026-05-03.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/mac-port/reports/F12_NAT_DIRECT_TRAVERSAL_2026-05-03.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/mac-port/reports/F12_NAT_ISP_FRIENDLY_ROUTE_2026-05-03.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/mac-port/reports/F12_RELAY_FALLBACK_2026-05-03.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/mac-port/reports/F12_RENDEZVOUS_FORWARDER_LAUNCHER_2026-05-03.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/mac-port/reports/G16_LOLA_PARITY_DEFERRED_FEATURES_2026-05-03.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/mac-port/reports/GOAL_CODEWISE_CLOSURE_2026-05-05.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/mac-port/reports/GOAL_RUNTIME_COMPLETION_BLOCKERS_2026-05-05.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/mac-port/reports/M02_CORE_AUDIO_INVENTORY_2026-05-02.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/mac-port/reports/M02_LATENCY_BENCHMARKS_2026-05-03.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/mac-port/reports/M03_AUDIO_DEVICE_ABSTRACTION_2026-05-03.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/mac-port/reports/M03_ENDPOINT_LOOPBACK_2026-05-02.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/mac-port/reports/M04_AUDIO_LOOPBACK_2026-05-03.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/mac-port/reports/M04_UDP_PCM_PACKET_CONTRACT_2026-05-02.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/mac-port/reports/M05_ROUTE_CERTIFICATION_2026-05-03.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/mac-port/reports/M06_DRIFT_PLC_2026-05-02.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/mac-port/reports/M07_AOIP_EVALUATION_2026-05-02.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/mac-port/reports/M07_LATENCY_TUNING_2026-05-03.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/mac-port/reports/M08_VIDEO_CAPTURE_2026-05-02.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/mac-port/reports/M09_VIDEO_TRANSPORT_2026-05-02.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/mac-port/reports/M10_INTEGRATED_AV_2026-05-02.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/mac-port/reports/M11_LIGHTING_CONTROL_2026-05-03.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/mac-port/reports/M11_OSC_CUE_2026-05-02.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/mac-port/reports/M12_INTEGRATED_PROFILE_2026-05-03.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/mac-port/reports/M12_LIGHTING_FIXTURE_GATE_2026-05-02.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/mac-port/reports/M13_E2E_INTEGRATED_BENCHMARK_2026-05-04.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/mac-port/reports/M13_HARDWARE_VALIDATION_2026-05-03.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/mac-port/reports/M13_NATIVE_APP_SHELL_2026-05-02.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/mac-port/reports/M14_RECORDING_SESSION_ARTIFACTS_2026-05-02.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/mac-port/reports/M14_RELEASE_HARDENING_2026-05-03.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/mac-port/reports/M15_PACKAGING_FIELD_TEST_2026-05-02.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/mac-port/top-level/EVIDENCE_AND_CONFLICTS.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/mac-port/top-level/HARNESS.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/mac-port/top-level/MILESTONE_INDEX.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/mac-port/top-level/PROGRESS.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/mac-port/top-level/STATUS_INDEX.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/mac-port/top-level/VALIDATION_CHECKLIST.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/research/deprecated-research/MAC_NATIVE_SOTA_AV_STRATEGY_2026.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/research/deprecated-research/README.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/research/deprecated-research/RESEARCH_DOSSIER_AUDIO_FIRST_2026.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/research/deprecated-research/RESEARCH_SURVEY_2022_2026.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/research/deprecated-research/RESEARCH_SURVEY_2024_2026_DEEP.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/research/deprecated-research/RESEARCH_SURVEY_2024_2026_EVIDENCE_MATRIX.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/reverse-engineering/deprecated-reverse-engineering/ARTIFACTS_AND_VERSIONING.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/reverse-engineering/deprecated-reverse-engineering/AUDIO_VIDEO_CAMERA_SURFACE.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/reverse-engineering/deprecated-reverse-engineering/AUDIO_WORKFLOW_REVERSE_ENGINEERING.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/reverse-engineering/deprecated-reverse-engineering/CORPUS_ORIGINS_AND_INTEGRATION.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/reverse-engineering/deprecated-reverse-engineering/NETWORK_AND_SESSION_PROTOCOL.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/reverse-engineering/deprecated-reverse-engineering/README.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/reverse-engineering/deprecated-reverse-engineering/SECURITY_COMMANDS_CONFIDENCE.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/reverse-engineering/deprecated-reverse-engineering/VIDEO_WORKFLOW_REVERSE_ENGINEERING.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-doc-consolidation/reverse-engineering/deprecated-reverse-engineering/WIRING_AND_E2E_STRATEGY.md` | Historical/reference | Prior archive snapshot; do not use as active status. |
| `archive/2026-05-05-workflow-consolidation/MANIFEST.md` | Active | Active consolidation manifest artifact |
| `archive/2026-05-05-workflow-consolidation/PLAN.md` | Active | Active consolidation plan artifact |
| `archive/2026-05-05-workflow-consolidation/WORDING_AND_STRUCTURE_AUDIT.md` | Active | Active wording, information, and folder-structure audit artifact |
| `archive/2026-05-05-workflow-consolidation/internal-evidence/reverse-engineering/evidence-packages/folder-analysis-20260503-1747/README.md` | Internal/private-boundary | Internal generated evidence moved out of active workflow tree. |
| `archive/2026-05-05-workflow-consolidation/internal-evidence/reverse-engineering/evidence-packages/folder-analysis-20260503-1747/artifact-inventory.md` | Internal/private-boundary | Internal generated evidence moved out of active workflow tree. |
| `archive/2026-05-05-workflow-consolidation/internal-evidence/reverse-engineering/evidence-packages/folder-analysis-20260503-1747/av-tx-rx-analysis.md` | Internal/private-boundary | Internal generated evidence moved out of active workflow tree. |
| `archive/2026-05-05-workflow-consolidation/internal-evidence/reverse-engineering/evidence-packages/folder-analysis-20260503-1747/diagrams.md` | Internal/private-boundary | Internal generated evidence moved out of active workflow tree. |
| `archive/2026-05-05-workflow-consolidation/internal-evidence/reverse-engineering/evidence-packages/folder-analysis-20260503-1747/findings.md` | Internal/private-boundary | Internal generated evidence moved out of active workflow tree. |
| `archive/2026-05-05-workflow-consolidation/internal-evidence/reverse-engineering/evidence-packages/folder-analysis-20260503-1747/ghidra/v2-main.audio-deep.md` | Internal/private-boundary | Internal generated evidence moved out of active workflow tree. |
| `archive/2026-05-05-workflow-consolidation/internal-evidence/reverse-engineering/evidence-packages/folder-analysis-20260503-1747/ghidra/v2-main.ghidra-summary.md` | Internal/private-boundary | Internal generated evidence moved out of active workflow tree. |
| `archive/2026-05-05-workflow-consolidation/internal-evidence/reverse-engineering/evidence-packages/folder-analysis-20260503-1747/ghidra/v2-main.network-session-deep.md` | Internal/private-boundary | Internal generated evidence moved out of active workflow tree. |
| `archive/2026-05-05-workflow-consolidation/internal-evidence/reverse-engineering/evidence-packages/folder-analysis-20260503-1747/ghidra/v2-main.video-deep.md` | Internal/private-boundary | Internal generated evidence moved out of active workflow tree. |
| `archive/2026-05-05-workflow-consolidation/internal-evidence/reverse-engineering/evidence-packages/folder-analysis-20260503-1747/ghidra/v2-tester.ghidra-summary.md` | Internal/private-boundary | Internal generated evidence moved out of active workflow tree. |
| `archive/2026-05-05-workflow-consolidation/internal-evidence/reverse-engineering/evidence-packages/folder-analysis-20260503-1747/ghidra/v2-video-converter.ghidra-summary.md` | Internal/private-boundary | Internal generated evidence moved out of active workflow tree. |
| `archive/2026-05-05-workflow-consolidation/internal-evidence/reverse-engineering/evidence-packages/folder-analysis-20260503-1747/ghidra/v2-wav-splitter.ghidra-summary.md` | Internal/private-boundary | Internal generated evidence moved out of active workflow tree. |
| `archive/2026-05-05-workflow-consolidation/internal-evidence/reverse-engineering/evidence-packages/folder-analysis-20260503-1747/legacy-compatibility-mode/README.md` | Internal/private-boundary | Internal generated evidence moved out of active workflow tree. |
| `archive/2026-05-05-workflow-consolidation/internal-evidence/reverse-engineering/evidence-packages/folder-analysis-20260503-1747/legacy-compatibility-mode/av-tx-rx-protocol-decoding.md` | Internal/private-boundary | Internal generated evidence moved out of active workflow tree. |
| `archive/2026-05-05-workflow-consolidation/internal-evidence/reverse-engineering/evidence-packages/folder-analysis-20260503-1747/legacy-compatibility-mode/codec-and-media-findings.md` | Internal/private-boundary | Internal generated evidence moved out of active workflow tree. |
| `archive/2026-05-05-workflow-consolidation/internal-evidence/reverse-engineering/evidence-packages/folder-analysis-20260503-1747/legacy-compatibility-mode/compatibility-artifact-map.md` | Internal/private-boundary | Internal generated evidence moved out of active workflow tree. |
| `archive/2026-05-05-workflow-consolidation/internal-evidence/reverse-engineering/evidence-packages/folder-analysis-20260503-1747/legacy-compatibility-mode/definition-of-done-ledger.md` | Internal/private-boundary | Internal generated evidence moved out of active workflow tree. |
| `archive/2026-05-05-workflow-consolidation/internal-evidence/reverse-engineering/evidence-packages/folder-analysis-20260503-1747/legacy-compatibility-mode/exe-deep-summary.md` | Internal/private-boundary | Internal generated evidence moved out of active workflow tree. |
| `archive/2026-05-05-workflow-consolidation/internal-evidence/reverse-engineering/evidence-packages/folder-analysis-20260503-1747/legacy-compatibility-mode/legacy-compatibility-roadmap.md` | Internal/private-boundary | Internal generated evidence moved out of active workflow tree. |
| `archive/2026-05-05-workflow-consolidation/internal-evidence/reverse-engineering/evidence-packages/folder-analysis-20260503-1747/legacy-compatibility-mode/string-interest-triage.md` | Internal/private-boundary | Internal generated evidence moved out of active workflow tree. |
| `archive/2026-05-05-workflow-consolidation/internal-evidence/reverse-engineering/evidence-packages/folder-analysis-20260503-1747/strings-of-interest.md` | Internal/private-boundary | Internal generated evidence moved out of active workflow tree. |
| `archive/2026-05-05-workflow-consolidation/internal-evidence/reverse-engineering/evidence-packages/folder-analysis-20260503-1747/tool-evidence.md` | Internal/private-boundary | Internal generated evidence moved out of active workflow tree. |
| `archive/2026-05-05-workflow-consolidation/superseded/docs/compliance/milestones/M01-inventory.md` | Superseded | Moved in this consolidation pass; see move ledger. |
| `archive/2026-05-05-workflow-consolidation/superseded/docs/compliance/milestones/M02-internal-vs-public-separation.md` | Superseded | Moved in this consolidation pass; see move ledger. |
| `archive/2026-05-05-workflow-consolidation/superseded/docs/compliance/milestones/M03-sanitize-mac-port-roadmap.md` | Superseded | Moved in this consolidation pass; see move ledger. |
| `archive/2026-05-05-workflow-consolidation/superseded/docs/compliance/milestones/M04-clean-room-requirements.md` | Superseded | Moved in this consolidation pass; see move ledger. |
| `archive/2026-05-05-workflow-consolidation/superseded/docs/compliance/milestones/M05-license-review.md` | Superseded | Moved in this consolidation pass; see move ledger. |
| `archive/2026-05-05-workflow-consolidation/superseded/docs/compliance/milestones/M06-public-doc-review.md` | Superseded | Moved in this consolidation pass; see move ledger. |
| `archive/2026-05-05-workflow-consolidation/superseded/docs/compliance/milestones/M07-notices-attribution.md` | Superseded | Moved in this consolidation pass; see move ledger. |
| `archive/2026-05-05-workflow-consolidation/superseded/docs/compliance/milestones/M08-implementation-audit.md` | Superseded | Moved in this consolidation pass; see move ledger. |
| `archive/2026-05-05-workflow-consolidation/superseded/docs/compliance/milestones/M09-release-checklist.md` | Superseded | Moved in this consolidation pass; see move ledger. |
| `archive/2026-05-05-workflow-consolidation/superseded/docs/compliance/milestones/M10-review-packet.md` | Superseded | Moved in this consolidation pass; see move ledger. |
| `archive/2026-05-05-workflow-consolidation/superseded/docs/compliance/release-readiness-checklist-run.md` | Superseded | Moved in this consolidation pass; see move ledger. |
| `archive/2026-05-05-workflow-consolidation/superseded/mac-port/WORKFLOW.md` | Superseded | Moved in this consolidation pass; see move ledger. |
| `archive/2026-05-05-workflow-consolidation/superseded/root/MAC_PORT_PLAN.md` | Superseded | Moved in this consolidation pass; see move ledger. |
| `archive/2026-05-05-workflow-consolidation/superseded/root/SOURCE_AUDIT.md` | Superseded | Moved in this consolidation pass; see move ledger. |
| `archive/README.md` | Active | Active archive index |
| `docs/README.md` | Active | Active public docs index |
| `docs/architecture/apple-silicon-performance.md` | Active | Public-safe architecture reference. |
| `docs/architecture/audio-rme-madi.md` | Active | Public-safe architecture reference. |
| `docs/architecture/audio-routing.md` | Active | Public-safe architecture reference. |
| `docs/architecture/av-sync-and-timing.md` | Active | Public-safe architecture reference. |
| `docs/architecture/benchmark-methodology.md` | Active | Public-safe architecture reference. |
| `docs/architecture/blackmagic-video-rx-tx.md` | Active | Public-safe architecture reference. |
| `docs/architecture/clean-room-design-rules.md` | Active | Public-safe architecture reference. |
| `docs/architecture/e2e-p2p-session.md` | Active | Public-safe architecture reference. |
| `docs/architecture/latency-budget.md` | Active | Public-safe architecture reference. |
| `docs/architecture/latency-first-architecture.md` | Active | Public-safe architecture reference. |
| `docs/architecture/latency-profiles.md` | Active | Public-safe architecture reference. |
| `docs/architecture/lighting-control.md` | Active | Public-safe architecture reference. |
| `docs/architecture/madi-full-rx-tx.md` | Active | Public-safe architecture reference. |
| `docs/architecture/multichannel-audio-routing.md` | Active | Public-safe architecture reference. |
| `docs/architecture/multichannel-transport.md` | Active | Public-safe architecture reference. |
| `docs/architecture/multiple-video-streams.md` | Active | Public-safe architecture reference. |
| `docs/architecture/open-lola-protocol.md` | Active | Public-safe architecture reference. |
| `docs/architecture/p2p-networking.md` | Active | Public-safe architecture reference. |
| `docs/architecture/rme-madi-routing.md` | Active | Public-safe architecture reference. |
| `docs/architecture/rx-buffering.md` | Active | Public-safe architecture reference. |
| `docs/architecture/video-blackmagic-atem.md` | Active | Public-safe architecture reference. |
| `docs/benchmarks/README.md` | Active | Public-safe benchmark reference. |
| `docs/benchmarks/audio-latency-methodology.md` | Active | Public-safe benchmark reference. |
| `docs/benchmarks/e2e-av-benchmark-methodology.md` | Active | Public-safe benchmark reference. |
| `docs/compliance/README.md` | Active | Compliance governance/register surface. |
| `docs/compliance/clean-room-requirement-ledger.md` | Active | Compliance governance/register surface. |
| `docs/compliance/clean-room-rules.md` | Active | Compliance governance/register surface. |
| `docs/compliance/compatibility-work-gate.md` | Active | Compliance governance/register surface. |
| `docs/compliance/compliance-inventory.md` | Active | Compliance governance/register surface. |
| `docs/compliance/dependency-license-review.md` | Active | Compliance governance/register surface. |
| `docs/compliance/evidence-governance.md` | Active | Compliance governance/register surface. |
| `docs/compliance/final-review-packet.md` | Active | Compliance governance/register surface. |
| `docs/compliance/fixture-provenance.md` | Active | Compliance governance/register surface. |
| `docs/compliance/implementation-audit-register.md` | Active | Compliance governance/register surface. |
| `docs/compliance/license-decision-record.md` | Active | Compliance governance/register surface. |
| `docs/compliance/mac-port-compliance-review.md` | Active | Compliance governance/register surface. |
| `docs/compliance/mac-port-roadmap-sanitization.md` | Active | Compliance governance/register surface. |
| `docs/compliance/notices-attribution-register.md` | Active | Compliance governance/register surface. |
| `docs/compliance/open-questions.md` | Active | Compliance governance/register surface. |
| `docs/compliance/public-doc-review-register.md` | Active | Compliance governance/register surface. |
| `docs/compliance/public-documentation-safety.md` | Active | Compliance governance/register surface. |
| `docs/compliance/public-internal-boundary.md` | Active | Active public/internal boundary |
| `docs/compliance/public-link-audit.md` | Active | Compliance governance/register surface. |
| `docs/compliance/publication-redactions.md` | Active | Compliance governance/register surface. |
| `docs/compliance/release-artifact-hygiene.md` | Active | Compliance governance/register surface. |
| `docs/compliance/release-compliance-checklist.md` | Active | Compliance governance/register surface. |
| `docs/compliance/release-manifest.md` | Active | Compliance governance/register surface. |
| `docs/compliance/research-to-requirements-process.md` | Active | Compliance governance/register surface. |
| `docs/compliance/risk-register.md` | Active | Compliance governance/register surface. |
| `docs/compliance/sdk-license-notes.md` | Active | Compliance governance/register surface. |
| `docs/compliance/third-party-notices-plan.md` | Active | Compliance governance/register surface. |
| `docs/current-state.md` | Active | Active public current-state summary |
| `docs/diagrams/README.md` | Active | Public-safe diagram index. |
| `docs/milestones/M14-release-hardening.md` | Active | Verifier/source-dependent public release-hardening contract. |
| `docs/background/README.md` | Active | Public-safe research summary. |
| `docs/background/lola-av-architecture.md` | Active | Public-safe research summary. |
| `docs/background/lola-av-tx-rx-model.md` | Active | Public-safe research summary. |
| `docs/background/lola-latency-analysis.md` | Active | Public-safe research summary. |
| `docs/background/lola-networking-model.md` | Active | Public-safe research summary. |
| `docs/background/open-lola-compatibility-scope.md` | Active | Public-safe research summary. |
| `docs/background/open-lola-design-decisions.md` | Active | Public-safe research summary. |
| `docs/background/open-lola-deviations-and-improvements.md` | Active | Public-safe research summary. |
| `docs/background/publication-redactions.md` | Active | Public-safe research summary. |
| `docs/background/validation-and-test-methodology.md` | Active | Public-safe research summary. |
| `docs/compliance/reverse-engineering-boundary.md` | Active | Public-safe reverse-engineering boundary note. |
| `docs/roadmap/README.md` | Active | Public-safe roadmap surface. |
| `docs/roadmap/mac-port-public-roadmap.md` | Active | Public-safe roadmap surface. |
| `docs/source-contracts/MXX-rme-matrix-multichannel.md` | Active | Public-safe source contract. |
| `docs/source-contracts/MXX-rx-buffering.md` | Active | Public-safe source contract. |
| `docs/source-contracts/MXX-ultra-low-buffer-profiles.md` | Active | Public-safe source contract. |
| `docs/source-contracts/README.md` | Active | Public-safe source contract. |
| `docs/testing/README.md` | Active | Public-safe testing surface. |
| `docs/testing/verification-matrix.md` | Active | Active verification matrix |
| `mac-port/IMPLEMENTATION_COMPANION.md` | Active | Active implementation/workflow source of truth |
| `mac-port/OPEN_QUESTIONS.md` | Active | Active internal Mac-port ledger or router. |
| `mac-port/README.md` | Active | Active internal router |
| `mac-port/RISK_REGISTER.md` | Active | Active internal Mac-port ledger or router. |
| `mac-port/SOTA_2026_OPEN_QUESTION_MATRIX.md` | Active | Active internal Mac-port ledger or router. |
| `mac-port/implementation-companions/README.md` | Active | Active subordinate implementation companion. |
| `mac-port/implementation-companions/app-release-field.md` | Active | Active subordinate implementation companion. |
| `mac-port/implementation-companions/audio-network.md` | Active | Active subordinate implementation companion. |
| `mac-port/implementation-companions/evidence-compliance.md` | Active | Active subordinate implementation companion. |
| `mac-port/implementation-companions/video-control.md` | Active | Active subordinate implementation companion. |
| `mac-port/templates/MILESTONE_STATUS_TEMPLATE.md` | Active | Reusable session/status template. |
| `mac-port/templates/SESSION_HANDOFF_TEMPLATE.md` | Active | Reusable session/status template. |
| `research/RESEARCH_AUDIO_ENGINE_2026.md` | Internal/private-boundary | Internal research evidence and source-refresh matrix. |
| `research/RESEARCH_BENCHMARK_ROADMAP_2026.md` | Internal/private-boundary | Internal research evidence and source-refresh matrix. |
| `research/RESEARCH_COMPANION_2026.md` | Internal/private-boundary | Internal research evidence and source-refresh matrix. |
| `research/RESEARCH_EVIDENCE_MATRIX_2026.md` | Internal/private-boundary | Internal research evidence and source-refresh matrix. |
| `research/RESEARCH_LIGHTING_SHOW_CONTROL_2026.md` | Internal/private-boundary | Internal research evidence and source-refresh matrix. |
| `research/RESEARCH_NETWORK_TIMING_2026.md` | Internal/private-boundary | Internal research evidence and source-refresh matrix. |
| `research/RESEARCH_VIDEO_PIPELINE_2026.md` | Internal/private-boundary | Internal research evidence and source-refresh matrix. |
| `reverse-engineering/README.md` | Internal/private-boundary | Internal reverse-engineering companion set. |
| `reverse-engineering/REVERSE_ENGINEERING_ARTIFACTS_AND_ORIGINS_2026.md` | Internal/private-boundary | Internal reverse-engineering companion set. |
| `reverse-engineering/REVERSE_ENGINEERING_COMPANION_2026.md` | Internal/private-boundary | Internal reverse-engineering companion set. |
| `reverse-engineering/REVERSE_ENGINEERING_EVIDENCE_MATRIX_2026.md` | Internal/private-boundary | Internal reverse-engineering companion set. |
| `reverse-engineering/REVERSE_ENGINEERING_LOLA_E2E_WORKFLOW_2026.md` | Internal/private-boundary | Internal reverse-engineering companion set. |
| `reverse-engineering/REVERSE_ENGINEERING_SECURITY_COMMANDS_CONFIDENCE_2026.md` | Internal/private-boundary | Internal reverse-engineering companion set. |
| `reverse-engineering/lola-2-windows/README.md` | Internal/private-boundary | Internal legacy compatibility harness. |
| `reverse-engineering/lola-2-windows/legacy-compatibility-roadmap.md` | Internal/private-boundary | Internal legacy compatibility harness. |
| `reverse-engineering/lola-2-windows/runtime-analysis.md` | Internal/private-boundary | Internal legacy compatibility harness. |
| `reverse-engineering/lola-2-windows/static-analysis.md` | Internal/private-boundary | Internal legacy compatibility harness. |
| `reverse-engineering/lola-2-windows/validation-checklist.md` | Internal/private-boundary | Internal legacy compatibility harness. |
| `scripts/README.md` | Active | Repository-local script documentation. |

## Verification Results

Executed on 2026-05-05 after the workflow/documentation moves:

| Command or probe | Result |
|---|---|
| `bash scripts/verify-docs.sh` | PASS; documentation contract passed after moved paths and active links were updated. |
| `ruff check .` | PASS; Python-backed documentation verification helpers are lint-clean. |
| `shellcheck scripts/*.sh` | PASS. |
| `bash scripts/verify-release-hygiene.sh` | PASS; no candidate supplied, repository policy gate ended with `VERDICT: PASS`. |
| `swift test` | PASS; 767 tests passed after updating source-level documentation path metadata for the folder restructure. |
| Required entry-point probe | PASS; `README.md`, `docs/README.md`, `mac-port/README.md`, `mac-port/IMPLEMENTATION_COMPANION.md`, `docs/testing/verification-matrix.md`, `docs/compliance/public-internal-boundary.md`, this manifest, and the consolidation plan exist. |
| Superseded-path absence probe | PASS; `MAC_PORT_PLAN.md`, `SOURCE_AUDIT.md`, `mac-port/WORKFLOW.md`, `docs/compliance/milestones/`, `docs/compliance/release-readiness-checklist-run.md`, and `reverse-engineering/evidence-packages/` no longer exist in active locations. |
| Moved-destination probe | PASS; all corresponding archive destinations exist under `archive/2026-05-05-workflow-consolidation/`. |
| Main entry link surface probe | PASS; relative links in the required entry points, consolidation plan, and manifest resolve. |
| Manifest coverage probe | PASS; manifest covers all 364 Markdown files in the filesystem tree. |
| Non-archived metadata probe | PASS; all 108 non-archived Markdown files have heading, date, status, and verdict metadata. |
| Active duplicate-prose probe | PASS; zero exact normalized prose duplicates across the 108 non-archived Markdown files. |
| Folder-topology probe | PASS; `docs/research/` and `docs/reverse-engineering/` are removed; public background summaries are under `docs/background/`, and the public RE boundary is under `docs/compliance/`. |

VERDICT: PASS
