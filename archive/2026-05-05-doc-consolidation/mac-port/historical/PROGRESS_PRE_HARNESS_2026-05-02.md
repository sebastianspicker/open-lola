# Progress

Date: 2026-05-02  
Status: roadmap documentation refreshed; implementation not started

## Completion Rule

A milestone is complete only when all of these are true:

- implementation exists;
- tests pass;
- validation report exists;
- relevant docs are updated;
- this file marks the milestone complete with a dated verdict.

## Milestone Status

| ID | Status | Verdict | Notes |
|---|---|---|---|
| M00 | Not started | None | No Swift scaffold exists yet. |
| M01 | Not started | None | Measurement reports and fixtures do not exist yet. |
| M02 | Not started | None | Core Audio inventory CLI does not exist yet. |
| M03 | Not started | None | Loopback matrix does not exist yet. |
| M04 | Not started | None | UDP PCM packet tests do not exist yet. |
| M05 | Not started | None | Route certification reports do not exist yet. |
| M06 | Not started | None | Drift and PLC telemetry do not exist yet. |
| M07 | Not started | None | Interop profile evidence does not exist yet. |
| M08 | Not started | None | Video capture probe does not exist yet. |
| M09 | Not started | None | Video transport probe does not exist yet. |
| M10 | Not started | None | Integrated headless A/V run does not exist yet. |
| M11 | Not started | None | OSC cue probe does not exist yet. |
| M12 | Not started | None | Lighting safety gate does not exist yet. |
| M13 | Not started | None | Native app shell does not exist yet. |
| M14 | Not started | None | Recording/session artifact lane does not exist yet. |
| M15 | Not started | None | Package, signing, and clean-Mac field tests do not exist yet. |

## Documentation Refresh Checklist

- [x] Preserve previous `MAC_PORT_PLAN.md` under `mac-port/historical/`.
- [x] Rewrite root `MAC_PORT_PLAN.md` as roadmap overview.
- [x] Add evidence, conflict, risk, validation, progress, open-question, and
  milestone index files.
- [x] Add M00-M15 milestone continuation docs.
- [ ] Start M00 implementation.

Resume here: implement M00 and update this file only after `swift build`,
`swift test`, and documentation checks pass.
