# Deprecation And Simplification Audit

Date: 2026-05-16
Scope: current checkout source, tests, scripts, Linux connector, and active docs
needed to understand deprecation/simplification risk.
Verdict: PARTIAL. This pass used static source inspection and lightweight
Python/shell checks. It did not run Swift build/tests, runtime hardware probes,
native app UI checks, or git-history analysis.

This audit does not delete code. It records evidence-backed candidates for
deletion, inlining, deduplication, replacement, or further verification. If a
compatibility path may still be required by existing artifacts, external users,
or runtime state, the finding says so explicitly.

## Commands Run

```bash
rg -n "deprecated|DEPRECATED|legacy|compatib|Compatibility|compatibility|TODO|FIXME|HACK|obsolete|temporary|shim|fallback|backward|old behavior|oldBehaviour|unused|dead code|placeholder|prototype|Prototype" Sources Tests linux_connector scripts script docs -g '!Sources/opus-1.5.2/**' -g '!Sources/JPEG-XS-reference-iso21122/**'
find Sources/OpenLolaCore Sources/OpenLolaContracts Sources/open-lola Sources/open-lola-app Sources/open-lola-app-main linux_connector/lola_connector scripts script -type f \( -name '*.swift' -o -name '*.py' -o -name '*.sh' \) -exec wc -l {} +
rg -n "@available\(\*, deprecated|\.launch\(|launchPath|keyWindow|NSApplication\.shared\.mainWindow|onChange\(of:.*perform:|presentationMode|NavigationView\(" Sources Tests linux_connector scripts script
rg -n "KeyValueArgumentParser|while index < arguments.count|var index = 0" Sources/open-lola Sources/OpenLolaCore Tests/OpenLolaCoreTests linux_connector/lola_connector scripts script
find . -path './.build' -prune -o -path './.git' -prune -o -path './Sources/opus-1.5.2' -prune -o -path './Sources/JPEG-XS-reference-iso21122' -prune -o -type f \( -name '*.bak' -o -name '*~' -o -name '*.old' -o -name '*.orig' -o -name '*.tmp' -o -name '*.pyc' -o -name '.DS_Store' \) -print
ruff check linux_connector scripts/verify_docs scripts/lib/*.py
python -m mypy --strict linux_connector/lola_connector scripts/verify_docs scripts/lib/*.py
shellcheck -x scripts/*.sh scripts/lib/*.sh script/*.sh linux_connector/env/*.sh
```

Static checks run in this pass:

- `ruff check linux_connector scripts/verify_docs scripts/lib/*.py`: PASS.
- `python -m mypy --strict linux_connector/lola_connector scripts/verify_docs scripts/lib/*.py`: PASS.
- `shellcheck -x scripts/*.sh scripts/lib/*.sh script/*.sh linux_connector/env/*.sh`: PASS.

Generated cache/output observed after checks:

- `.ruff_cache`
- `.mypy_cache`
- `scripts/verify_docs/__pycache__`

The existing verification baseline already records that `scripts/verify_docs/__pycache__`
is release-hygiene residue. This pass did not remove generated output.

## Findings

### DS-001

- ID: DS-001
- Category: unused class / dead code
- Location: `linux_connector/lola_connector/backends.py:334`
- Evidence: `class ProcessBackendError(RuntimeError): pass` is defined, but
  `rg -n "ProcessBackendError" .` found only that declaration. It is not
  exported from `linux_connector/lola_connector/__init__.py`.
- Why it is likely obsolete or harmful: it is a dead exception type with no
  callers, no exported contract, and no behavior.
- What could break if changed: external code importing it directly from
  `linux_connector.lola_connector.backends` would fail; no in-repo evidence of
  that import exists.
- Suggested action: delete.
- Risk level: low.
- Verification needed: `ruff check linux_connector`, `python -m mypy --strict
  linux_connector/lola_connector`, `PYTHONDONTWRITEBYTECODE=1 python -m pytest
  -p no:cacheprovider linux_connector`, plus git-history/runtime verification
  only if this package has external consumers.

### DS-002

- ID: DS-002
- Category: unused protocol / single-use typing residue
- Location: `linux_connector/lola_connector/backends.py:24-27`
- Evidence: `AudioBackend(AudioCapture, Protocol)` adds only `aclose()`.
  `rg -n "AudioBackend"` found only its declaration; the CLI uses
  `AudioCapture` and `VideoCapture` annotations instead.
- Why it is likely obsolete or harmful: it increases the apparent backend
  surface without constraining any current code path.
- What could break if changed: external imports from `backends.py`; no in-repo
  usage was found.
- Suggested action: delete after confirming it is not part of a documented
  external Python API.
- Risk level: low.
- Verification needed: same Python ruff/mypy/pytest slice as DS-001; needs
  runtime or git-history verification for out-of-repo imports.

### DS-003

- ID: DS-003
- Category: deprecated internal API
- Location: `Sources/OpenLolaCore/Release/LoLaParityDeferredFeatures.swift:216-220`
- Evidence: `LoLaParityDeferredSyntheticSmoke` is marked
  `@available(*, deprecated, ...)` and only delegates to
  `LoLaParityDeferredFixtures.partialLedger()`. `rg` found tests using
  `LoLaParityDeferredFixtures.partialLedger()` directly and no in-repo caller of
  `LoLaParityDeferredSyntheticSmoke`.
- Why it is likely obsolete or harmful: it is retained scaffold for an old
  synthetic smoke name and duplicates the fixture entry point.
- What could break if changed: any external source importing the deprecated
  symbol, or an archived command path if one existed outside the searched tree.
- Suggested action: delete if git history and release notes show no external
  dependency; otherwise keep until a documented deprecation window closes.
- Risk level: low to medium.
- Verification needed: `rg -n "LoLaParityDeferredSyntheticSmoke" .`, full Swift
  build, `swift test --filter LoLaParityDeferredFeaturesTests`, and git-history
  verification.

### DS-004

- ID: DS-004
- Category: obsolete compatibility branch / hidden CLI alias
- Location:
  `Sources/open-lola/Commands/Network/DirectP2PSessionRunArgumentSupport.swift:1-31`,
  `Sources/open-lola/Commands/Network/DirectP2PSessionRunCommandSupport.swift:225-242`,
  `Sources/OpenLolaCore/Network/P2P/DirectPeerTwoPeerRunPlan.swift:445-464`,
  `Sources/open-lola-app/AppShellStoredDefaults.swift:88-96`,
  `Sources/OpenLolaCore/Network/P2P/DirectPeerSessionAVRuntimeReport.swift:201-225`
- Evidence: `--audio-compression` is accepted in the allowed argument set but
  intentionally removed from public arguments. CLI tests assert that help output
  does not show it while a test named
  `directPeerSessionCLIStillAcceptsHiddenLegacyAudioCompressionForMigration`
  verifies the hidden alias still works. App defaults migrate
  `openLola.audioCompression` into `audioTransport`, and runtime reports still
  encode/decode an `audioCompression` compatibility field.
- Why it is likely obsolete or harmful: canonical code now uses
  `audioTransport`; the hidden alias adds parser branches, duplicate conflict
  handling, stored-default migration, and report schema compatibility.
- What could break if changed: existing user defaults, old scripts using
  `--audio-compression`, old two-peer plans, old report fixtures, or downstream
  consumers expecting `audioCompression`.
- Suggested action: investigate first. If runtime/git-history evidence shows no
  active old artifacts, remove the hidden CLI flag, stored-default migration,
  initializer fallback, and legacy JSON field together. If still required,
  document an explicit deprecation horizon.
- Risk level: medium to high because this touches CLI, app defaults, and report
  compatibility.
- Verification needed: `swift test --filter DirectPeerSessionOpusCLITests`,
  `swift test --filter NativeAppShellOpusCommandTests`, two-peer run-plan tests,
  report fixture validation, plus runtime or git-history verification of old
  artifacts.

### DS-005

- ID: DS-005
- Category: deprecated internal API / obsolete config compatibility
- Location:
  `Sources/OpenLolaCore/Audio/Realtime/DirectPeerRealtimeAudioGraphTypes.swift:108-173`
- Evidence: `audioDeviceUID` is marked deprecated with message "Use
  inputDeviceUID and outputDeviceUID; audioDeviceUID is retained for legacy
  config migration only." Decoding still accepts `audioDeviceUID` as a fallback
  for both `inputDeviceUID` and `outputDeviceUID`.
- Why it is likely obsolete or harmful: it keeps a single-device config shape in
  the realtime graph while current runtime code has explicit input/output UIDs.
  That can hide accidental separate-device or migration behavior.
- What could break if changed: old JSON configurations and tests constructing
  `DirectPeerRealtimeAudioGraphConfiguration` with only `audioDeviceUID`.
- Suggested action: investigate and then delete the decode fallback and
  deprecated accessor if no old configs need to be opened. Keep only with a
  documented migration horizon.
- Risk level: high because this is realtime Core Audio configuration.
- Verification needed: full search for old JSON artifacts, git-history check,
  `swift test --filter DirectPeerRealtimeAudioGraphTests`, AV/session tests, and
  a runtime Core Audio smoke on a known full-duplex device.

### DS-006

- ID: DS-006
- Category: obsolete compatibility branch / protocol dialect compatibility
- Location:
  `linux_connector/lola_connector/cli.py:44-45`,
  `linux_connector/lola_connector/protocol.py:175-180`,
  `linux_connector/lola_connector/protocol.py:295-369`,
  `linux_connector/lola_connector/connector.py:267-309`,
  `linux_connector/lola_connector/runtime.py:317-340`
- Evidence: the Python connector exposes `--control-dialect` choices
  `ascii`, `osc15`, and `auto`; protocol parsing explicitly says it parses
  "the older OSC15 dialect"; connector/runtime code builds OSC15 responses and
  comments mention LoLa 1.5/Tester compatibility.
- Why it is likely obsolete or harmful: it keeps a second control dialect inside
  the active connector path. If no OSC15 peer is still tested, the extra parser
  and handshake branches can drift from the main LoLa 2.0 ASCII path.
- What could break if changed: LoLa 1.5/Tester experiments, archived capture
  reproduction, or any Windows compatibility probe using `--control-dialect
  osc15|auto`.
- Suggested action: investigate. Keep if there is a live compatibility lane or
  fixture coverage that still matters; otherwise delete the dialect branch and
  reduce the connector to the actively verified ASCII control path.
- Risk level: medium.
- Verification needed: Python tests for protocol/control/runtime, a live or
  fixture-backed OSC15 probe if retained, and git-history verification before
  deletion.

### DS-007

- ID: DS-007
- Category: legacy protocol compatibility path
- Location:
  `Sources/OpenLolaCore/Audio/Routing/AudioRoutingAssumptionLedger.swift:47-70`,
  `Sources/OpenLolaCore/Network/UDP/MultichannelTransport.swift:334-417`,
  `Sources/OpenLolaCore/Core/OpenLolaCLI.swift:14`
- Evidence: the assumption ledger classifies v1 stereo fixtures as
  `legacyV1Compatibility`, says to "retain for legacy callers", and capability
  summary advertises both `.udpPcmV2` and `.udpPcmV1`. Transport negotiation
  still falls back to v1 when shared protocols contain `.udpPcmV1`.
- Why it is likely obsolete or harmful: v1 stereo fallback increases protocol
  negotiation surface while the project appears to route multichannel/realtime
  work through v2.
- What could break if changed: old packet fixtures, v1-only peers, route smoke
  commands, or tests that intentionally prove v1 compatibility.
- Suggested action: keep for now, but audit as a compatibility contract. Delete
  only if there is measured evidence that no supported peer or fixture requires
  v1.
- Risk level: high because packet/protocol compatibility can silently break
  peer communication.
- Verification needed: `swift test --filter MultichannelTransportTests`,
  UDP packet tests, route report tests, fixture validation, and runtime or
  git-history verification of v1 peers.

### DS-008

- ID: DS-008
- Category: single-use abstraction
- Location:
  `Sources/OpenLolaCore/Evidence/ReportValidatorSurface.swift:16-25`,
  `Sources/OpenLolaCore/Integration/IntegratedAvReportValidation.swift:3-5`
- Evidence: `ReportValidationLifecycle` and `validateLifecycle()` are used by
  only `IntegratedAvReport`; `rg -n "ReportValidationLifecycle|validateLifecycle"`
  found one conforming report plus the protocol/extension definition.
- Why it is likely obsolete or harmful: a lifecycle protocol for one report is
  indirection without reuse. It makes validation style look broader than it is.
- What could break if changed: only `IntegratedAvReport` validation if inlining
  changes call ordering or error behavior.
- Suggested action: inline `validateLifecycle()` into
  `IntegratedAvReport.validate()` unless a second real report adopts the same
  lifecycle during the same task.
- Risk level: low to medium.
- Verification needed: `swift test --filter IntegratedAvReportTests` and report
  fixture validation.

### DS-009

- ID: DS-009
- Category: duplicated parser logic / boilerplate
- Location:
  `Sources/OpenLolaCore/Core/KeyValueArgumentParser.swift:1-200`,
  `Sources/OpenLolaCore/Control/LightingFixtureGateRun.swift:69-70`,
  `Sources/OpenLolaCore/Control/AtemReadOnlyControl.swift:133-135`,
  `Sources/OpenLolaCore/Control/OscCueProbe.swift:509-511`,
  `Sources/open-lola/Commands/Audio/MadiFullDuplexCommands.swift:105-106`,
  `Sources/open-lola/Commands/Network/DirectP2PTwoPeerPrototypeCommandSupport.swift:30-57`
- Evidence: a shared strict key/value parser exists, but many command parsers
  still hand-roll `var index = 0` / `while index < arguments.count` loops with
  duplicate unknown/duplicate/missing-value handling.
- Why it is likely obsolete or harmful: duplicate parser code makes CLI error
  behavior drift across commands and keeps boilerplate in runtime command
  types.
- What could break if changed: command-specific acceptance of `--`-prefixed
  values, exact error text, and tests asserting parser behavior.
- Suggested action: replace hand-rolled loops with `KeyValueArgumentParser`
  only when editing those commands for another reason. Do not add a new parser
  abstraction; one already exists.
- Risk level: medium because CLI compatibility depends on exact parsing.
- Verification needed: command-specific tests, `swift test --filter
  KeyValueArgumentParserTests`, and CLI smoke commands for changed parsers.

### DS-010

- ID: DS-010
- Category: duplicated validation helpers
- Location:
  `Sources/OpenLolaCore/Video/VideoCaptureHelpers.swift:3-72`,
  `Sources/OpenLolaCore/Core/ValidationPrimitives.swift:109-173`,
  `Sources/OpenLolaCore/Video/VideoCaptureReport.swift:157-248`,
  `Sources/OpenLolaCore/Video/VideoCaptureAVFoundation.swift:124-147`
- Evidence: video capture helpers locally implement non-empty, positive,
  non-negative, and finite validation while core `ValidationPrimitives` already
  provides the same primitive checks. The video helpers are used throughout
  video report and inventory validation.
- Why it is likely obsolete or harmful: duplicate validation primitives create
  two styles and increase the chance that one validation family gets fixed while
  the other does not.
- What could break if changed: exact thrown `VideoCaptureValidationError`
  cases, UInt32/UInt64 positive checks, and packet-age ordering behavior.
- Suggested action: replace the primitive video helper functions with
  `ValidationPrimitives` or a `ReportPrimitiveValidating` video validator.
  Keep domain-specific helpers such as packet-age ordering if they encode video
  semantics.
- Risk level: medium.
- Verification needed: `swift test --filter VideoCaptureReportTests`,
  video inventory/capture tests, and fixture validation.

### DS-011

- ID: DS-011
- Category: endless switch chain / command-surface boilerplate
- Location:
  `Sources/open-lola/Commands/Validation/MilestoneValidationCommands.swift:4-294`,
  `Sources/open-lola/Commands/MilestoneCommands.swift:4-150` and later cases,
  `Sources/open-lola/Commands/Network/NetworkCommands.swift:5-170` and later
  cases
- Evidence: validation dispatch is a 290-line switch with repeated
  `args.count == 2 && args[0] == "validate-..."` cases. Milestone and network
  command handlers use similar case chains for report generation and validation.
- Why it is likely obsolete or harmful: adding a report requires touching
  command dispatch, schema inventory, tests, and docs manually. This increases
  drift risk and hides command ownership.
- What could break if changed: command names, stdout lines, `VERDICT` behavior,
  and app/script calls that shell out to exact command names.
- Suggested action: investigate a table-driven replacement only if a command
  surface change is already in scope. At least two real command routers would
  benefit, but do not introduce a broad framework solely for cleanup.
- Risk level: medium to high because CLI output is a public contract.
- Verification needed: `command-inventory`, `report-schema-inventory`, CLI
  command inventory tests, report validator tests, release-readiness CLI probes,
  and scripts that call `open-lola`.

### DS-012

- ID: DS-012
- Category: generated residue / unused files
- Location:
  `scripts/verify_docs/__pycache__/*.pyc`, `.ruff_cache`, `.mypy_cache`
- Evidence: `find` found Python bytecode under `scripts/verify_docs/__pycache__`
  and cache directories at repo root. Release hygiene explicitly rejects
  `__pycache__` and `*.pyc`, and the verification baseline records the live
  checkout is red because of `scripts/verify_docs/__pycache__`.
- Why it is likely obsolete or harmful: generated caches are not source, are
  forbidden by release policy, and can make hygiene gates fail.
- What could break if changed: nothing in production should depend on generated
  caches. Removing them can only affect local tool speed.
- Suggested action: delete generated caches in a cleanup-only task; run Python
  tools with `PYTHONDONTWRITEBYTECODE=1` and cache dirs under `/private/tmp`.
- Risk level: low.
- Verification needed: `find linux_connector scripts -path '*/__pycache__/*'
  -o -name '*.pyc'`, `bash scripts/verify-release-hygiene.sh`, and relevant
  Python checks.

### DS-013

- ID: DS-013
- Category: archived generated residue / likely dead files
- Location:
  `archive/2026-05-10-superseded-plans-audits-goals/generated/re_out/ghidra_proj/LolaGhidra.rep/versioned/~index.bak`,
  `archive/2026-05-10-superseded-plans-audits-goals/generated/re_out/ghidra_proj/LolaGhidra.rep/idata/~index.bak`
- Evidence: `find` found `~index.bak` backup files under an archived generated
  reverse-engineering output tree. Existing archived compliance notes classify
  `generated/re_out/**` as deprecated generated reverse-engineering output for
  traceability only, not current runtime input.
- Why it is likely obsolete or harmful: editor/tool backup files add noise to
  archived evidence and are unlikely to be intentional source artifacts.
- What could break if changed: forensic traceability if those backup files were
  intentionally kept as part of the archived Ghidra project. No active runtime
  dependency was found.
- Suggested action: investigate archive provenance, then delete backup files if
  no audit trail requires them.
- Risk level: low.
- Verification needed: docs verifier, release hygiene, and git-history/archive
  verification before deletion.

### DS-014

- ID: DS-014
- Category: wrapper/compatibility re-export
- Location:
  `Sources/OpenLolaCore/Core/OpenLolaContractsAliases.swift:1-7`,
  `Tests/OpenLolaCoreTests/OpenLolaContractsTargetTests.swift:23-31`
- Evidence: `OpenLolaCore` re-exports five `OpenLolaContracts` symbols with
  public typealiases. Tests explicitly verify that `OpenLolaCore` still exposes
  those extracted contracts for existing callers.
- Why it is likely obsolete or harmful: the wrapper exists only to preserve old
  import behavior after contract extraction. It duplicates public names across
  targets and can hide whether callers are using the intended lightweight
  `OpenLolaContracts` target.
- What could break if changed: existing Swift callers importing only
  `OpenLolaCore`, plus tests that assert compatibility.
- Suggested action: keep for now. Delete only after a deliberate public API
  cleanup with release notes and external caller verification.
- Risk level: high because this is public API compatibility.
- Verification needed: full Swift build/tests, external package import checks,
  and git-history verification.

### DS-015

- ID: DS-015
- Category: misleading names / stale prototype terminology
- Location:
  `Sources/open-lola/Commands/Network/DirectP2PTwoPeerPrototypeCommandSupport.swift:4-24`,
  `Sources/OpenLolaCore/Network/P2P/DirectPeerTwoPeerRunPlanReportTypes.swift:135-249`,
  `Sources/OpenLolaCore/Evidence/ReportSchemaInventory.swift:114`,
  `Tests/OpenLolaCoreTests/SourceNamingConventionTests.swift:34-40`
- Evidence: the command support file says to keep "prototype" until a promoted
  non-prototype schema exists. Schema inventory and tests intentionally preserve
  `DirectPeerTwoPeerPrototypeReport` and command names.
- Why it is likely obsolete or harmful: "prototype" in an active measured report
  can mislead future cleanup work into treating the path as dead or lesser than
  it is. The code itself says the name is waiting for promotion.
- What could break if changed: public command names, report IDs, schema
  inventory, app/supervisor output paths, and tests.
- Suggested action: investigate promotion status. If the report is now an
  active contract, rename in one compatibility-aware slice or keep the old name
  with an explicit deprecation timeline. Do not silently rename.
- Risk level: high because it is report and CLI contract surface.
- Verification needed: command inventory, schema inventory, two-peer run-plan
  tests, source naming convention tests, and runtime/git-history verification.

### DS-016

- ID: DS-016
- Category: duplicated subprocess backend logic / overengineering risk
- Location:
  `linux_connector/lola_connector/backends.py:342-527`,
  `linux_connector/lola_connector/backends.py:568-591`
- Evidence: `ProcessAudioCapture`, `ProcessRawVideoCapture`, and
  `ProcessJpegVideoCapture` repeat very similar subprocess start, stdout
  readiness, return-code, and cleanup branches. `ProcessAudioPlayback` and
  `ProcessVideoDisplay` repeat stdin write/drain/error handling.
- Why it is likely obsolete or harmful: repeated lifecycle code makes process
  cleanup fixes easy to miss in one media backend. The file already has a
  `ProcessLifecycleMixin`, so part of the abstraction exists, but start/read
  duplication remains.
- What could break if changed: subprocess cleanup, cancellation behavior,
  backend error messages, and tests that simulate early process exit.
- Suggested action: simplify only when touching process backends for a real bug.
  Because there are at least three read-side call sites and two write-side call
  sites, a small helper may be justified; do not add a new framework.
- Risk level: medium.
- Verification needed: `python -m pytest linux_connector/tests/test_process_runtime.py`,
  mypy, and a real subprocess capture/playback smoke if available.

## Highest-Value Deletion Candidates

1. `ProcessBackendError` in `linux_connector/lola_connector/backends.py`.
2. `AudioBackend` in `linux_connector/lola_connector/backends.py` if not part
   of an external API.
3. `LoLaParityDeferredSyntheticSmoke` if git history confirms no external
   caller.
4. Generated caches and backup residue after a cleanup-only approval.

## Highest-Risk Compatibility Candidates

1. Hidden `--audio-compression` / `audioCompression` migration path.
2. Deprecated `audioDeviceUID` realtime graph config fallback.
3. UDP PCM v1 compatibility path.
4. Direct P2P "prototype" report naming and command surface.
5. OpenLolaCore contract re-export aliases.

## Likely Overcomplicated Areas

- CLI validation and milestone command routers.
- Remaining hand-rolled key/value CLI parsers despite `KeyValueArgumentParser`.
- Video capture validation helpers duplicating core validation primitives.
- Python process backend lifecycle code.
- App execution/process/report controller, which was identified in the code
  index as large and mixed-responsibility but was not deeply audited in this
  pass.

## Areas Not Proven Safe To Delete

- Vendored Opus and JPEG XS sources. They are large and noisy, but active
  package targets depend on them.
- LoLa compatibility code. It contains old-dialect and reverse-engineered
  behavior, but compatibility is an explicit project lane.
- `OpenLolaContractsAliases.swift`. It is a wrapper, but tests prove it is a
  deliberate compatibility contract.
- UDP PCM v1 packet support. It appears legacy, but the capability summary and
  tests still advertise it.

## Recommended Next Audit Targets

1. Run a git-history/public-API check for hidden `--audio-compression`,
   `audioCompression`, `audioDeviceUID`, and `LoLaParityDeferredSyntheticSmoke`.
2. Inventory old JSON fixtures/reports for legacy config keys before deleting
   any decode fallback.
3. Audit the command inventory and schema inventory together before simplifying
   CLI routers.
4. Do a focused Python process-backend cleanup plan if process lifecycle bugs
   recur.
5. Do a runtime-focused audit of `AppExecutionController` before splitting or
   simplifying the app execution surface.

## Coverage Gaps And Uncertainty

- No Swift build or Swift tests were run in this pass.
- No live audio/video/network/device/app runtime checks were run.
- No git-history analysis was run, so compatibility paths that look stale are
  marked investigate or keep.
- Public API usage outside this checkout was not checked.
- Archive cleanup recommendations need provenance review before deletion.
