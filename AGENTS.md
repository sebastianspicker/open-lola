# AGENTS.md

Durable guidance for Codex and other coding agents working in this repository.
Keep this file compact. Put one-off prompts, detailed audits, and large
remediation plans in task-specific documents.

## Project Purpose

Open LoLa is a clean-room, Mac-native SwiftPM workspace for audio-first,
low-latency networked audio/video research and implementation. The goal is an
original implementation backed by public APIs, public standards, original
tests, and measured reports, not a copy of proprietary LoLa behavior.

The product verdict is still `PARTIAL`: source-level and synthetic evidence do
not prove field readiness. Do not promote localhost, built-in-device,
synthetic, archived, or placeholder evidence to product `PASS`.

High-risk areas include realtime audio, Core Audio device I/O, UDP/P2P media,
TX/RX/local RX, packet formats, video capture/transmit/receive, control
messages, buffers, timing, packet loss/jitter/reordering, state machines,
concurrency, startup/shutdown, error handling, logging, UI status, and any
`connected`, `streaming`, `healthy`, or `PASS` claim.

## Important Directories

- `Sources/OpenLolaCore/`: core runtime, protocols, reports, validators,
  release harnesses, audio/video/network/control implementations.
- `Sources/OpenLolaContracts/`: shared report/verdict contracts used across
  source and validation surfaces.
- `Sources/open-lola/`: Swift CLI entry point and command routing.
- `Sources/open-lola-app/` and `Sources/open-lola-app-main/`: SwiftUI macOS app
  support and app entry point.
- `Sources/COpenLolaAtomics/`, `Sources/xs_ref_sw_ed2/`, `Sources/opus-1.5.2/`:
  C bridge and vendored/reference codec code. Treat as high-risk integration
  surfaces.
- `Tests/OpenLolaCoreTests/`: Swift Testing suite and fixtures.
- `linux_connector/`: Python LoLa compatibility seed and tests; not merged into
  SwiftPM packaging.
- `docs/`: active public documentation. Start with `docs/current-state.md`,
  `docs/testing.md`, `docs/source-contracts.md`, and relevant architecture
  docs.
- `scripts/`: release, verification, Docker/native connector, and hygiene
  helpers. `script/` remains active for native app bundle assembly.
- `archive/`: historical trace evidence only. Do not resume from archived plans
  unless the task explicitly asks for archival trace work.
- `private/`: local/private evidence. Do not include private evidence in public
  release surfaces without explicit review.

## Build Commands

Discover current commands from repo files before adding or changing gates.
Known build commands:

```bash
swift build
swift build --product open-lola
swift build --product open-lola-app
bash script/build_and_run.sh --verify
bash script/build_cli_app_bundle.sh
```

SwiftPM may need to run outside strict sandboxing on this Mac if manifest
sandboxing fails with `sandbox-exec: sandbox_apply: Operation not permitted`.

## Test Commands

Use the narrowest meaningful test first, then broaden when risk warrants it.
Known tests:

```bash
swift test --filter <RelevantSwiftTestName>
swift test --no-parallel
PYTHONDONTWRITEBYTECODE=1 python -m pytest -p no:cacheprovider linux_connector
bash scripts/verify-release-readiness.sh
```

For LoLa compatibility work, include focused Swift compatibility filters such
as `LoLaCompatibilityMediaCodecTests` and
`LoLaCompatibilityMediaSessionTests` when relevant.

## Lint And Typecheck Commands

Known lint/typecheck and docs gates:

```bash
bash scripts/verify-docs.sh
python3 -m scripts.verify_docs
ruff check linux_connector scripts/verify_docs scripts/lib/*.py
python -m mypy --strict linux_connector/lola_connector scripts/verify_docs scripts/lib/*.py
shellcheck -x scripts/*.sh scripts/lib/*.sh script/*.sh linux_connector/env/*.sh
bash scripts/verify-release-hygiene.sh
```

For docs-only changes, at minimum run `bash scripts/verify-docs.sh` when
practical. For source, CLI, verifier, report-schema, release, or user-facing
runtime changes, run the broader matrix from `docs/testing.md` or state
exactly why it was skipped.

## Runtime Entry Points

- CLI: `.build/debug/open-lola <command>`.
- App: `.build/debug/open-lola-app` or the `dist/OpenLoLa.app` bundle assembled
  by `script/build_and_run.sh`.
- Python connector seed:
  `python -m linux_connector.lola_connector.cli ...`.
- Release and evidence probes include `session-capabilities`,
  `goal-runtime-preflight-run`, `goal-completion-audit-run`,
  `open-source-release-readiness-run`, `direct-p2p-session-run`,
  `external-connector-session-run`, and matching `validate-*` commands.

Before changing a command, inspect `Sources/open-lola/main.swift`, the relevant
command implementation, report builders, validators, tests, docs, and any app
surface that emits the command.

## Public Contracts

- Verdict vocabulary, report schemas, validation rules, and JSON fixtures are
  compatibility contracts. Changes require matching tests and docs.
- `OpenLolaContracts` types, `MeasurementVerdict`, release reports, CLI command
  names, flags, generated report fields, and validator behavior are public
  surface area.
- UDP PCM, Direct P2P, LoLa compatibility packets, RTP/AES67-shaped transport,
  RX-buffer profiles, timing policy, and media degradation behavior are protocol
  contracts. Inspect `docs/source-contracts.md`, relevant protocol/architecture
  docs, and `linux_connector/docs/protocol-reference.md` before editing.
- The Linux connector is the authoritative Python compatibility seed. Keep it
  runnable from this checkout with `python -m linux_connector...` commands.
- Release candidates must be staged through
  `bash scripts/export-release-candidate.sh /path/to/output-parent`; the raw
  checkout is not a release artifact.
- UI storage keys, app defaults, fixture names, and report artifact paths are
  storage/compatibility surfaces. Do not rename or migrate them casually.

## Deprecated-Code Policy

Do not keep deprecated compatibility paths unless there is evidence they are
still required by an active CLI, app action, validator, fixture/schema test,
manual evidence gate, or documented compatibility workflow. Do not silently
preserve old behavior if it is wrong; document the compatibility impact and add
or update behavior tests for the intended contract.

Archived documents and generated historical outputs are trace evidence, not
active authority. Prefer current `README.md`, `docs/current-state.md`, and
`docs/testing.md` over archived plans.

## Code-Change Rules

Act as a cautious senior engineer.

- Define outcome, success criteria, side effects, and verification before
  editing.
- Prefer the minimum code that solves the actual problem.
- No speculative features.
- No abstractions for single-use code.
- No broad rewrites without a written plan.
- Touch only files required by the task.
- Read relevant files, exports, callers, tests, shared utilities, configs,
  schemas, protocol docs, and storage assumptions before editing.
- Do not assume dependencies, code paths, APIs, protocols, schemas, config
  values, or storage contracts exist. Inspect them.
- Do not refactor adjacent code, reformat unrelated files, or clean unrelated
  dead code while passing through.
- For realtime paths, do not add blocking work, unbounded queues, hidden packet
  drops, swallowed errors, optimistic health states, or implicit state changes.
- For UI work, status text must reflect runtime/report evidence. No fake
  `connected`, `streaming`, `healthy`, `100`, or `PASS` states.
- Tests must verify why behavior matters, not only what output appears or which
  private helper was called.

## Verification Expectations

Use deterministic tools for build, lint, typecheck, schema/protocol validation,
format, dependency, and test pass/fail decisions. Do not claim completion
without evidence.

For bug fixes, reproduce the broken contract with an existing or new test when
practical, make the minimum fix, run the targeted test, then run broader checks
when the risk or blast radius justifies it.

If any build, test, lint, migration, edge case, runtime probe, hardware gate, or
manual evidence check was skipped, say so explicitly. Never say tests pass when
only a subset ran. Never call a runtime path working if report teardown,
packet/media evidence, or critical edge cases were not verified.

## Final Response Expectations

For implementation tasks, include:

1. Files changed
2. Why each file changed
3. Commands run
4. Tests/checks passed
5. Tests/checks skipped or unavailable
6. Remaining uncertainty
7. Follow-up risks

For audit-only or planning-only tasks, include the document changed, scope
covered, finding categories/counts when applicable, highest-risk findings, areas
not fully inspected, remaining uncertainty, and the next suggested
implementation slice.
