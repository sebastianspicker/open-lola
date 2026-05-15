# M03 Sanitize Mac Port Roadmap

Date: 2026-05-04
Status: implemented sanitized roadmap export, pending reviewer signoff
Verdict: PARTIAL

## Objective

Ensure the Mac port roadmap is useful for implementation while remaining
clean-room defensible and safe for public or curated-public publication.

## Scope

Review `MAC_PORT_PLAN.md`, `mac-port/IMPLEMENTATION_COMPANION.md`,
`mac-port/milestones/**`, `mac-port/implementation-companions/**`,
`mac-port/reports/**`, `mac-port/RISK_REGISTER.md`, and `mac-port/OPEN_QUESTIONS.md`.

## Affected Files

- `MAC_PORT_PLAN.md`
- `mac-port/README.md`
- `mac-port/IMPLEMENTATION_COMPANION.md`
- `mac-port/milestones/*.md`
- `mac-port/reports/*.md`
- `mac-port/RISK_REGISTER.md`
- `mac-port/OPEN_QUESTIONS.md`
- `docs/roadmap/**`
- `docs/compliance/mac-port-roadmap-sanitization.md`
- `docs/compliance/**`

## Actions

- Keep `MAC_PORT_PLAN.md` and `mac-port/**` as review-only implementation
  handoff material.
- Replace direct raw-evidence references with sanitized requirement references
  in the public roadmap export under `docs/roadmap/**`.
- Keep `PARTIAL` verdicts where hardware/signing/peer evidence is missing.
- Add license and notice gates to release and packaging milestones.
- Add clean-room gates to protocol, compatibility, video, lighting, and
  benchmark milestones.
- Ensure every compatibility feature is optional and evidence-gated.

## Acceptance Criteria

- Roadmap distinguishes internal evidence, engineering requirements, clean
  implementation, and public wording.
- No milestone marks compatibility or performance complete without measured
  evidence.
- License/notices tasks are visible before release packaging.
- Public-safe export of the roadmap exists without raw RE links.

## Risks

- Implementation teams may still quote `MAC_PORT_PLAN.md` as public wording
  instead of using `docs/roadmap/**`.
- "Faster-than-LoLa" language may overclaim without measured baseline.
- Compatibility mode may become a default design constraint.

## Required Reviewer

Maintainer plus Mac port implementation reviewer.

## Progress Checklist

- [x] Roadmap release posture chosen.
- [x] Internal links reviewed.
- [x] License and notice gates added where needed.
- [x] Clean-room gates added where needed.
- [x] Claims remain confidence-labeled.
- [ ] Reviewer signoff recorded.

## Resume Point

Resume with M04 by enforcing the research-to-requirements translation process
before compatibility, protocol, video, lighting, or benchmark implementation
work.

VERDICT: PARTIAL
