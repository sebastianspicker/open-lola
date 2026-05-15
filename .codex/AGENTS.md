# AGENTS.md

Durable repository guidance for Codex and other coding agents.

Keep this file compact. Put one-off instructions, long audit prompts, and large
remediation plans in task prompts or `plan.md`.

---

## Project context

This repository may contain legacy code, deprecated paths, boilerplate,
duplicated logic, UI flaws, and high-risk runtime code.

High-risk areas: real-time audio, audio device I/O, UDP, P2P, TX/RX/local RX,
packet send/receive, video capture/transmit/receive, control messages, buffers,
timing, packet loss/jitter/reordering, state machines, concurrency,
startup/shutdown, error handling, logging, and false-success states.

---

## Core rules

Act as a cautious senior engineer.

Before changing code:
- Identify the outcome, success criteria, side effects, and verification needed.
- Inspect relevant files before editing.
- State material assumptions, tradeoffs, and ambiguity.
- Prefer the smallest correct change.
- Do not claim completion without evidence.

Do not assume a code path, dependency, config value, API, protocol contract, or
test exists. Inspect first.

---

## Simplicity and surgical changes

Prefer direct, explicit, deterministic, verifiable code.

Avoid speculative features, single-use abstractions, unnecessary configurability,
boilerplate that hides behavior, endless if/else chains, stale compatibility
layers, deprecated APIs, wrappers that add no value, and broad rewrites disguised
as cleanup.

When editing:
- Touch only files required by the task.
- Do not refactor adjacent code unless it blocks the requested change.
- Do not reformat unrelated files.
- Do not clean up unrelated dead code.
- Match existing style unless it directly causes the problem.
- Remove only unused code made obsolete by your own change.
- Every changed line should trace to the task.

Report unrelated issues instead of fixing them.

---

## Read before writing

Before modifying a file, inspect the file, exports/public surface, immediate
callers, relevant tests, shared utilities, affected runtime contracts, and
config/schema/protocol/storage assumptions.

For high-risk runtime paths, also inspect state transitions, concurrency,
buffers, timing, startup/shutdown, fallback behavior, errors, and logs.

---

## Runtime safety

For runtime-critical code:
- Do not add blocking work to real-time paths.
- Do not add unbounded queues or buffers.
- Do not swallow errors.
- Do not report connected/streaming/healthy states without evidence.
- Do not convert partial success into full success.
- Do not preserve deprecated behavior without evidence that it is required.
- Prefer explicit state transitions over implicit flags.

Silent packet drops, fake success, and invalid state transitions are high-risk.

---

## UI correctness

For UI work, verify user-visible behavior.

Check for unreadable text, poor contrast, clipped labels, missing menu items,
dead menu actions, unreachable views, misleading status indicators, controls not
wired to behavior, settings that do not affect runtime behavior, missing
loading/empty/error states, hidden failures, placeholder UI, and duplicated UI
state logic.

A UI that says connected, streaming, valid, or healthy must reflect real runtime
state, not optimistic assumptions.

---

## Tests

Tests must verify intent, not implementation trivia. A useful test should fail
when meaningful behavior breaks.

For bug fixes:
1. Reproduce the bug with an existing or new test.
2. Make the minimum fix.
3. Run the targeted test.
4. Run broader verification when appropriate.

Avoid tests that mirror implementation details, assert hardcoded trivia, only
prove mocks were called, or ignore null/empty/zero/invalid/boundary/timing/failure
cases.

---

## Deterministic tools vs model judgment

Use model judgment for review, classification, risk ranking, audit planning,
summarization, messy-code interpretation, design comparison, and remediation
planning.

Use deterministic tools or code for protocol parsing, status-code handling,
retries, routing, schema validation, exact transforms, formatting, dependency
resolution, and build/lint/typecheck/test pass-fail decisions.

If a compiler, type checker, linter, test runner, schema, protocol rule, or
status code answers the question, use that evidence.

---

## Conflicting patterns

If existing patterns conflict, identify both, do not blend them, prefer the
newer/simpler/better-tested/more central pattern, flag the other for cleanup,
and explain the choice.

Avoid compromise code that preserves incompatible conventions.

---

## Audit-only tasks

When asked for an audit, inventory, review, remediation plan, or `plan.md`:
- Do not change production code.
- Do not refactor.
- Do not delete files.
- Do not reformat files.
- Do not update tests.
- Only create or modify the requested audit/planning document.

Findings must be evidence-backed and enumerated:

```text
- ID:
- Severity: P0 / P1 / P2 / P3
- Category:
- Subsystem:
- File:
- Line range or symbol:
- Evidence:
- Why it matters:
- Runtime/user impact:
- Suggested remediation:
- Verification required:
- Suggested test:
- Risk of change:
- Confidence: high / medium / low
```

Severity:
- P0: core runtime breakage, crash, data loss, security issue, severe
  audio/video/network failure, invalid state transition, or false success in a
  critical runtime path.
- P1: likely correctness bug, serious UX flaw, fragile API use, missing
  validation, important runtime weakness, or major maintainability risk.
- P2: code quality issue, duplication, dead-code candidate, boilerplate, stale
  compatibility path, confusing structure, or non-critical UI flaw.
- P3: cosmetic, docs, naming, minor style, or optional cleanup.

Do not say an audit is complete unless every relevant file is fully inspected,
partially inspected with explanation, or explicitly listed as not inspected.

---

## Planning

For complex changes, risky runtime work, broad refactors, migrations, or
multi-step implementation:
1. Define success criteria.
2. Define verification commands.
3. Split work into small reviewable slices.
4. Implement one slice at a time.
5. Verify each slice before moving on.
6. Update the plan when scope or evidence changes.

Use `plan.md` for large audits and remediation roadmaps.

---

## Subagents

Use subagents only when explicitly requested or clearly useful.

Good roles: inventory auditor, runtime auditor, logic/correctness auditor,
slop/dead-code/dedup auditor, UI/UX auditor, test/verification auditor, security
auditor, remediation planner.

Subagents must return evidence-backed findings. Consolidate, deduplicate, and
preserve uncertainty.

---

## Verification

Discover project commands from repo files before inventing commands. Check
README, package files, lockfiles, Makefile, CMake, pyproject, requirements,
Cargo, Go, justfile, and CI workflows.

Use the narrowest relevant check first, then broader checks: format, lint,
typecheck, unit tests, integration tests, build, smoke/manual runtime check.

If a check cannot be run, name it, explain why, give the next-best verification
path, and do not claim full success.

Never say tests pass if only a subset ran. Never say feature works if critical
edge cases were not verified. Never say audit complete if files were not
accounted for.

---

## Final responses

For code changes, include:
1. Summary
2. Files changed and why
3. Behavior changed
4. Tests added/updated
5. Commands run and results
6. Checks skipped/unavailable
7. Remaining uncertainty
8. Follow-up risks

For audit-only tasks, include:
1. Audit document created/updated
2. Scope covered
3. Finding categories or count
4. Highest-risk findings
5. Files or areas not fully inspected
6. Remaining uncertainty
7. Suggested next implementation slice

---

## Dependencies, security, and privacy

Do not add production dependencies without explicit approval. Before adding one,
explain why existing code is insufficient and the dependency's runtime,
maintenance, license, and security impact.

Do not commit secrets, credentials, private keys, tokens, local machine paths, or
personal data.

For security findings, validate against real code context, avoid speculative
claims, provide evidence, rank severity, suggest remediation, and include
verification.

---

## Repository commands

Fill these in after inspecting the repository:

```text
Install: UNKNOWN
Format: UNKNOWN
Lint: UNKNOWN
Typecheck: UNKNOWN
Unit tests: UNKNOWN
Integration tests: UNKNOWN
Build: UNKNOWN
Smoke/manual runtime checks: UNKNOWN
```

---

## Non-goals unless explicitly requested

Do not perform broad rewrites, redesign architecture, replace frameworks, add
speculative features, add new abstractions, remove pre-existing dead code, change
public APIs or behavior, alter storage formats, change protocols, modify
generated files, or reformat unrelated files.
