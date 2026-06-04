# Codacy Status Ledger

Date: 2026-06-02
Status: PARTIALLY_REMEDIATED_LOCAL
Scope: Codacy Cloud repository findings for `gh/sebastianspicker/open-lola-priv`
on `main`.

This ledger records the current Codacy Cloud backlog for triage. It is not
field-readiness evidence and does not change the product verdict.

## Source Snapshot

| Field | Value |
|---|---|
| Codacy repository | `gh/sebastianspicker/open-lola-priv` |
| Branch | `main` |
| Last analyzed commit | `1d146118b39a9ac2d298330c679466da0f997aae` |
| Commit message | `chore: checkpoint local repo state` |
| Analysis completed | `2026-05-31T12:36:12Z` |
| PR findings surface | No usable PR data; Codacy returned `total: 0` pull requests. |
| Repository grade | `B` / `82` |
| Repository quality issues | `4,334` |
| Open SRM/security items | `403` |
| Local checkout state | Dirty; Codacy Cloud reflects the remote analyzed commit, not all local changes. |
| Local remediation state | Active Swift `force_try` findings fixed locally; active Python subprocess command paths mitigated locally; Codacy path policy configured locally, including vendored Opus DNN/build-script/doc/demo/debug lanes; selected active JPEG XS Critical C findings, active JPEG XS High format-type findings, active Opus copy/negative-index findings, active-source Swift `assert` findings, and all Linux connector Python test `assert` slices fixed locally; repo `Error` pages were re-audited against local source and path policy with no uncovered active-source row found; the first UDP media, LoLa control handshake validation failure construction, direct-peer AV configuration validation, direct-peer AV media-loop orchestration, direct-peer manual AV setup/proposal, direct-peer video RX loop configuration, direct-peer audio TX loop configuration/send split, direct-peer audio RX loop state/configuration split, UltraGrid control, UltraGrid compatibility media run orchestration, session protocol, UDP PCM v2 packet, UDP PCM loopback sender, UDP PCM localhost route smoke, continuous UDP PCM route, direct-peer two-peer, direct-peer session metrics/pass-evidence validation, direct-peer AV runtime metrics decoder, Mac-to-Mac connection, UDP PCM route certification, NAT-friendly route validator/runner, NMP external connector endpoint command construction, native app shell pass-verdict validation, network diagnostics ping parsing, AoIP synthetic report construction, Network AoIP certification pass-validation, lighting fixture gate pass-validation, video capture pass-validation, integrated AV run report construction, integrated-profile runtime benchmark row construction, realtime audio graph mapped-copy/stop-cleanup, realtime audio engine pass-validation, faster-than-LoLa closure pass-validation and latency tuple, field-ready runtime proof pass-validation, packaging field-test signing/notarization pass-validation, latency benchmark pass-verdict, E2E benchmark pass-profile, performance audit pass-validation, latency-tuning pass-validation, integrated AV pass-validation, video transport pass-validation, recording-session live-capture CoreAudio input, and recording-session artifact validator SwiftLint slices are remediated locally; Linux runtime/self-test/CLI/backend/connector, docs verifier milestone-contract, Windows binary verifier MC06, Windows control verifier MC07/MC02, Windows media verifier MC08-MC11, direct-peer AV configuration validation, direct-peer AV media-loop orchestration, direct-peer manual AV setup/proposal, direct-peer audio TX loop send split, direct-peer audio RX loop receive split, realtime audio graph mapped-copy/stop-cleanup, direct-peer session metrics/pass-evidence validation, realtime audio engine pass-validation, faster-than-LoLa closure pass-validation, field-ready runtime proof pass-validation, packaging field-test signing/notarization pass-validation, latency benchmark pass-verdict, latency-tuning pass-validation, integrated AV pass-validation, video capture pass-validation, and video transport pass-validation Lizard slices are remediated locally. Codacy Cloud counts are unchanged until reanalysis. |

## Quality Findings By Severity

Codacy MCP severity filters returned the following totals. These do not sum to
the repository total because Codacy also returns issue levels outside the MCP
filter enum, such as `High`.

| Severity | Count | Status |
|---|---:|---|
| Error | 168 | OPEN |
| Warning | 3,533 | OPEN |
| Info | 14 | OPEN |
| Other Codacy levels | 619 | OPEN |

## Quality Findings By Rule

| ID | Severity | Rule | Count | Primary area | Status | Next action |
|---|---|---|---:|---|---|---|
| CODACY-Q-001 | Warning | `Lizard_nloc-medium` | 707 | Swift/Python test and source size | IN_PROGRESS | Verified slices split `LolaLinuxRuntime._rx_socket_loop`, `run_bidirectional_selftest`, CLI `run`, docs verifier milestone-contract plus Windows binary/control/media verifier policy checks, direct-peer AV configuration validation, direct-peer AV media-loop orchestration, direct-peer manual AV setup/proposal, direct-peer audio TX loop send handling, direct-peer audio RX loop receive handling, realtime graph mapped input/output copy plus stop-cleanup paths, direct-peer session metrics/pass-evidence validation, realtime audio engine pass-validation, faster-than-LoLa closure pass-validation, field-ready runtime proof pass-validation, packaging field-test signing/notarization pass-validation, latency benchmark pass-verdict validation, latency-tuning pass-validation, integrated AV pass-validation, video capture pass-validation, and video transport pass-validation; continue active-source offenders only when the split improves behavior or reviewability. |
| CODACY-Q-002 | Warning | `Lizard_ccn-medium` | 577 | Swift/Python complexity | IN_PROGRESS | Verified slices split `LolaLinuxRuntime._control_loop`, self-test media assertions, CLI `run` branch dispatch, diagnostic RGB frame color selection, connector control receive dispatch, docs verifier milestone-contract plus Windows binary/control/media verifier policy checks, direct-peer AV configuration validation, direct-peer AV media-loop orchestration, direct-peer audio TX transport dispatch, direct-peer audio RX transport dispatch, realtime graph mapped copy channel dispatch, direct-peer session metrics/pass-evidence validation, realtime audio engine pass-validation, faster-than-LoLa closure pass-validation, field-ready runtime proof pass-validation, packaging field-test signing/notarization pass-validation, latency benchmark pass-verdict validation, latency-tuning pass-validation, integrated AV pass-validation, video capture pass-validation, and video transport pass-validation; prioritize runtime validators, report validators, and active connector code before tests. |
| CODACY-Q-003 | Warning | `SwiftLint_function_body_length` | 345 | Swift runtime/report code | IN_PROGRESS | Verified slices split `UdpMediaPacket.decodeWithNestedPayload`, network diagnostics ping parsing, AoIP synthetic report construction, Network AoIP certification pass-validation, lighting fixture gate pass-validation, video capture pass-validation, UDP PCM packet decode, UDP PCM loopback sender loop, UDP PCM localhost route smoke, UDP PCM v2 packet decode/packetize functions, continuous UDP PCM localhost/receiver report functions, LoLa TCP control transmit handshake orchestration, LoLa parity deferred-feature fixture construction, goal codewise requirement table construction, goal runtime preflight deliverable construction, Drift PLC synthetic smoke route construction, direct-peer AV proposal construction, direct-peer mesh runtime route execution, direct-peer AV configuration validation, direct-peer AV media-loop orchestration, direct-peer audio TX loop send handling, direct-peer audio RX loop receive handling, UltraGrid compatibility media run orchestration, direct-peer session metrics/pass-evidence validation, direct-peer AV runtime metrics decoding, NAT-friendly route runner orchestration/report construction, NMP external connector endpoint command construction, integrated AV run report construction, integrated-profile runtime benchmark row construction, recording-session measured report construction, recording-session CoreAudio live input setup/lifecycle, recording-session artifact validators, realtime graph mapped input/output copy plus stop-cleanup paths, realtime audio engine pass-validation, faster-than-LoLa closure pass-validation, field-ready runtime proof pass-validation, packaging field-test signing/notarization pass-validation, latency benchmark pass-verdict validation, E2E benchmark pass-profile validation, performance audit real-time/profile pass validation, latency-tuning pass-validation, integrated AV pass-validation, and video transport pass-validation; continue grouping by subsystem and avoid broad rewrites in realtime paths. |
| CODACY-Q-004 | Warning | `cppcheck_variableScope` | 109 | Mostly archive/generated C | CONFIGURED_LOCAL | `.codacy.yaml` now excludes archive and uncompiled vendored/reference extras; Cloud closure requires reanalysis. |
| CODACY-Q-005 | Warning | `SwiftLint_function_parameter_count` | 81 | Swift helpers/runtime | IN_PROGRESS | Verified slices replaced LoLa control handshake validation failure's 7-parameter private helper, LoLa parity deferred-feature construction's 6-parameter helper, goal codewise requirement construction's 6-parameter helper, UltraGrid audio packet construction's 7-parameter helper, UltraGrid video fragment construction's 9-parameter helper, direct-peer video RX loop stable settings, direct-peer audio TX loop stable settings, and direct-peer audio RX loop stable settings/state with named context/configuration types; continue active helpers/runtime where a request/config type clarifies call contracts. |
| CODACY-Q-006 | Warning | `SwiftLint_cyclomatic_complexity` | 64 | Swift validators/runtime | IN_PROGRESS | Verified slices split UDP media nested audio/video validation predicates, `UltraGridControlCommand.parse`, `SessionStateMachine.apply`, UDP PCM v2 reassembly consistency checks, Network AoIP certification pass-validation, lighting fixture gate pass-validation, video capture pass-validation, direct-peer AV configuration validation, direct-peer AV media-loop orchestration, direct-peer audio RX transport dispatch, direct-peer session metrics/pass-evidence validation, Mac-to-Mac connection blocker construction, UDP PCM route pass-verdict validation, NAT-friendly route validation, native app shell pass-verdict validation, recording-session video artifact/pass-verdict validation, realtime graph mapped copy channel dispatch, realtime audio engine pass-validation, faster-than-LoLa closure pass-validation, field-ready runtime proof pass-validation, packaging field-test signing/notarization pass-validation, latency benchmark pass-verdict validation, E2E benchmark pass-profile validation, performance audit real-time/profile pass validation, latency-tuning pass-validation, integrated AV pass-validation, and video transport pass-validation without changing packet/control-command/protocol/report behavior. |
| CODACY-Q-007 | Warning | `cppcheck_unreadVariable` | 50 | Mostly archive/generated C | CONFIGURED_LOCAL | `.codacy.yaml` now excludes archive and uncompiled vendored/reference extras; Cloud closure requires reanalysis. |
| CODACY-Q-008 | Warning | `SwiftLint_large_tuple` | 17 | Swift validation/report code | IN_PROGRESS | Verified slices replaced the direct-peer two-peer local-run pass artifact tuple, recording-session callback metrics tuple, and faster-than-LoLa latency comparison tuple with named private types; continue replacing active tuples with named types where it reduces ambiguity. |
| CODACY-Q-009 | High | `cppcheck_knownConditionTrueFalse` | 16 | Archive/generated C | CONFIGURED_LOCAL | `.codacy.yaml` now excludes archive and uncompiled vendored/reference extras; Cloud closure requires reanalysis. |
| CODACY-Q-010 | Error | `SwiftLint_force_try` | 3 | UltraGrid Swift code | FIXED_LOCAL | Local code removed active `try! UltraGrid...` initialization and added a source regression. Latest repo `Error` page audit still shows only stale Cloud rows; Cloud closure requires reanalysis. |
| CODACY-Q-011 | Error | `PyLintPython3_E1102` | 1 | Uncompiled vendored Opus DNN Python | CONFIGURED_LOCAL | Codacy detail places this in Opus `dnn/torch`; `.codacy.yaml` excludes the uncompiled DNN lane. |

## Security Findings By Priority

| Priority | Count | Status |
|---|---:|---|
| Critical | 151 | OPEN |
| High | 201 | OPEN |
| Medium | 39 | OPEN |
| Low | 12 | OPEN |

## Security Findings By Category

The count column below is the open High/Critical SRM count for each category on
the stale Codacy Cloud analyzed commit.

| ID | Category | High/Critical count | Examples | Status | Next action |
|---|---|---:|---|---|---|
| CODACY-S-001 | UnexpectedBehaviour | 218 | C use-after-free, Python/Swift `assert`, and Opus negative-index findings | FIXED_LOCAL | `.codacy.yaml` excludes observed uncompiled Opus DNN/training/test/build-script, archive, and unselected architecture paths; active selected Opus negative-index rows, active non-test Swift `assert` rows, and all Linux connector Python test `assert` slices are fixed locally. Cloud may still show stale Python test assertion rows until reanalysis. Cloud closure requires reanalysis. |
| CODACY-S-002 | InputValidation | 75 | C `memcpy`, `strcpy`/`strncpy`, and format-string findings | FIXED_LOCAL | Active selected JPEG XS formatter/copy findings, active JPEG XS `%u` format-type findings, and active selected Opus copy findings are fixed locally; uncompiled converter/training/test and architecture findings are covered by `.codacy.yaml`; Cloud closure requires reanalysis. |
| CODACY-S-003 | CommandInjection | 28 | Python `subprocess`, `shell=True`, and dynamic command findings | MITIGATED_LOCAL | Active repo-owned subprocess launch paths now validate commands before launch. Vendored Opus DNN/build-script subprocess rows are covered by `.codacy.yaml` path policy, not ignored or marked false-positive. |
| CODACY-S-004 | InsecureModulesLibraries | 29 | Python dynamic import, FTP, pickle, C `strcpy`/`strncpy`, and C format-type findings | CONFIGURED_LOCAL | Observed Opus DNN/training/tests/doc/demo/debug lanes and JPEG XS program extras are excluded by `.codacy.yaml`; active selected JPEG XS format-type rows are fixed locally. No row was ignored or marked false-positive. |
| CODACY-S-005 | Other or unclassified | 0 | MCP query returned no open `Other` or `_other_` SRM items. | FIXED_LOCAL | Re-query after Cloud reanalysis to keep this row closed. |
| CODACY-S-006 | Cryptography | 2 | SHA1 in vendored Opus documentation and DNN export tooling | CONFIGURED_LOCAL | MCP High/Critical query returned two open stale SHA1 rows. Local scan maps them to `Sources/opus-1.5.2/doc/**` and `Sources/opus-1.5.2/dnn/**`, both outside Open LoLa runtime/SwiftPM-packaged codec source and covered by `.codacy.yaml`; Cloud closure requires reanalysis. |
| CODACY-S-007 | Other named SRM categories | 0 | Auth, Cookies, CSRF, DoS, FileAccess, HTTP, Regex, SQLInjection, Visibility, and XSS | FIXED_LOCAL | MCP High/Critical query returned zero rows for these categories; re-query after Cloud reanalysis. |

## Highest Priority Remediation Slices

| Slice | Scope | Why first | Verification |
|---|---|---|---|
| C-001 | Codacy path policy plus selected active C remediation for `archive/`, uncompiled Opus/JPEG XS extras, selected JPEG XS, and Opus | Large finding volume is archive/vendored/reference noise; selected SwiftPM C sources stay analyzable and are fixed in source, including JPEG XS copy/format rows and Opus copy/negative-index rows. | `.codacy.yaml` structural validation, focused build/tests, and Cloud reanalysis. |
| C-002 | Swift runtime/report complexity in UDP, P2P, release, and validation files | Active source maintainability risk in high-risk runtime/report surfaces; first UDP media packet decode, LoLa control handshake validation failure construction, direct-peer AV configuration validation, direct-peer AV media-loop orchestration, direct-peer video RX loop configuration, direct-peer audio TX loop configuration/send split, direct-peer audio RX loop state/configuration split, UltraGrid control parser, UltraGrid compatibility media run orchestration, session protocol state-machine, UDP PCM v2 packet, UDP PCM loopback sender, UDP PCM localhost route smoke, continuous UDP PCM route, direct-peer two-peer tuple, direct-peer session metrics/pass-evidence validation, direct-peer AV runtime metrics decoder, Mac-to-Mac connection blocker, UDP PCM route certification pass-verdict, NAT-friendly route validation and runner orchestration/report construction, NMP external connector endpoint command construction, native app shell pass-verdict validation, network diagnostics ping parsing, AoIP synthetic report construction, Network AoIP certification pass-validation, lighting fixture gate pass-validation, video capture pass-validation, integrated AV run report construction, integrated-profile runtime benchmark row construction, recording-session live-capture CoreAudio input, recording-session artifact validator, realtime audio graph mapped-copy/stop-cleanup, realtime audio engine pass-validation, faster-than-LoLa closure pass-validation, field-ready runtime proof pass-validation, packaging field-test signing/notarization pass-validation, latency benchmark pass-verdict, E2E benchmark pass-profile, performance audit pass-validation, latency-tuning pass-validation, integrated AV pass-validation, and video transport pass-validation slices are locally remediated. | Focused subsystem tests, then `swift test --no-parallel` when the slice is source-wide. |
| C-003 | Active Lizard backlog after path-policy decisions | Remaining active-source complexity/size backlog; Linux connector runtime, self-test, CLI, backend, connector control-receive, docs verifier milestone-contract, Windows binary verifier MC06, Windows control verifier MC07/MC02, Windows media verifier MC08-MC11, direct-peer AV configuration validation, direct-peer AV media-loop orchestration, direct-peer manual AV setup/proposal, direct-peer audio TX loop send split, direct-peer audio RX loop receive split, realtime graph mapped-copy/stop-cleanup, direct-peer session metrics/pass-evidence validation, realtime audio engine pass-validation, faster-than-LoLa closure pass-validation, field-ready runtime proof pass-validation, packaging field-test signing/notarization pass-validation, latency benchmark pass-verdict, latency-tuning pass-validation, integrated AV pass-validation, video capture pass-validation, and video transport pass-validation slices are locally remediated. | Focused subsystem tests, line-budget/Lizard proxy if configured, then broader language gates. |
| C-004 | Codacy Cloud reanalysis for locally fixed/mitigated rows | Required to move local fixes to Cloud closure. | Push changes and wait for Codacy reanalysis of the new commit. |

## Verification And Caveats

- Codacy Cloud was read through MCP tools because the local `codacy` CLI was not
  installed and `npx @codacy/codacy-cloud-cli` reported no API token.
- No Codacy Cloud reanalysis was triggered.
- Latest Codacy MCP repository refresh still reports `main` last analyzed at
  `1d146118b39a9ac2d298330c679466da0f997aae`; repository grade, quality issue
  count, and Cloud finding counts are therefore still stale.
- Local remediation changes now exist for active Swift `force_try`, active
  Python subprocess command validation, Codacy path policy, selected JPEG XS C
  copy/format findings, selected Opus C copy/negative-index findings, active-source Swift
  assert findings, all Linux connector Python test assert slices, the first UDP media,
  LoLa control handshake validation failure construction,
  direct-peer AV configuration validation,
  direct-peer AV media-loop orchestration,
  direct-peer video RX loop configuration,
  direct-peer audio TX loop configuration/send split,
  direct-peer audio RX loop state/configuration split,
  UltraGrid control, UltraGrid compatibility media run orchestration,
  session protocol, UDP PCM v2 packet, UDP PCM localhost
  route smoke, continuous UDP PCM
  route, network diagnostics ping parsing, AoIP synthetic report construction,
  Network AoIP certification pass-validation, lighting fixture gate
  pass-validation,
  direct-peer two-peer, direct-peer session metrics/pass-evidence
  validation, Mac-to-Mac connection, UDP PCM route
  certification, NAT-friendly route, NMP external connector endpoint command
  construction, native app shell pass-verdict validation,
  integrated AV run report construction,
  integrated-profile runtime benchmark row construction,
  realtime audio graph mapped-copy/stop-cleanup,
  realtime audio engine pass-validation, faster-than-LoLa closure pass-validation,
  field-ready runtime proof pass-validation,
  packaging field-test signing/notarization pass-validation,
  latency benchmark pass-verdict, E2E benchmark pass-profile, performance
  audit pass-validation, latency-tuning pass-validation, integrated AV
  pass-validation, and video transport pass-validation SwiftLint
  complexity/length/tuple slices,
  and the first Linux runtime/self-test/CLI/backend/connector plus docs verifier
  milestone-contract, Windows binary verifier MC06, Windows control verifier
  MC07/MC02, Windows media verifier MC08-MC11, realtime audio graph
  mapped-copy/stop-cleanup, direct-peer session metrics/pass-evidence
  validation, realtime audio engine pass-validation,
  faster-than-LoLa closure pass-validation,
  field-ready runtime proof pass-validation,
  packaging field-test signing/notarization pass-validation,
  latency benchmark pass-verdict, latency-tuning
  pass-validation, integrated AV pass-validation, and video transport
  pass-validation
  Lizard slices, but Codacy Cloud has not reanalyzed those changes.
- The latest repo `Error` issue-page audit found no uncovered active-source
  row beyond already fixed local source or documented path-policy lanes.
- `swiftlint` is not installed locally, so SwiftLint closure for the UDP media,
  LoLa control handshake validation failure construction,
  network diagnostics ping parsing, AoIP synthetic report construction,
  Network AoIP certification pass-validation, lighting fixture gate
  pass-validation,
  direct-peer AV configuration validation,
  direct-peer AV media-loop orchestration,
  direct-peer video RX loop configuration,
  direct-peer audio TX loop configuration/send split,
  direct-peer audio RX loop state/configuration split,
  UDP PCM v2 packet, UDP PCM localhost route smoke, continuous UDP PCM route,
  UltraGrid compatibility media run orchestration, direct-peer two-peer,
  Mac-to-Mac connection, UDP PCM route certification, NAT-friendly route
  validator/runner, NMP external connector endpoint command construction,
  native app shell pass-verdict validation,
  integrated AV run report construction,
  integrated-profile runtime benchmark row construction,
  direct-peer session metrics/pass-evidence validation,
  direct-peer AV runtime metrics decoder, realtime audio graph
  mapped-copy/stop-cleanup, realtime audio engine, faster-than-LoLa closure,
  field-ready runtime proof, packaging field-test, latency benchmark, E2E benchmark, performance audit, latency tuning, integrated AV, video transport, recording-session
  live-capture, and recording-session artifact validator
  slices is inferred from source splits, focused test passes, span proxies, or
  recorded partial checks until Codacy Cloud reanalysis runs.
- Performance audit report fixture validation passes after the local split, but
  synthetic-smoke-backed `PerformanceAuditTests` currently hit `sendFailed(35)`
  before the validator path on this host. Do not count that focused filter as
  fully passed until the send failure is resolved or isolated.
- Realtime audio engine focused tests and report fixture validation pass after
  the local split, but the broader `SyntheticSmokeReportContractTests` sweep
  still hit `sendFailed(35)` before completing
  `syntheticSmokeReportsValidateAsPartialWithoutClaimingRuntimePass` on this
  host. Do not count that synthetic-smoke sweep as fully passed until the send
  failure is resolved or isolated.
- `lizard` is not installed locally, so Lizard closure for the Linux runtime,
  self-test, CLI, backend, connector, docs verifier milestone-contract, Windows
  binary verifier MC06, Windows control verifier MC07/MC02, Windows media
  verifier MC08-MC11, realtime audio graph mapped-copy/stop-cleanup,
  direct-peer AV configuration validation,
  direct-peer audio TX loop send split,
  direct-peer audio RX loop receive split,
  direct-peer session metrics/pass-evidence validation,
  realtime audio engine pass-validation, faster-than-LoLa closure pass-validation,
  field-ready runtime proof pass-validation,
  packaging field-test signing/notarization pass-validation,
  latency-tuning pass-validation,
  integrated AV pass-validation, and video transport pass-validation slices
  is inferred from source
  line-span reduction and focused/full local verification passes until Codacy
  Cloud reanalysis runs.
- High SRM `assert` rows remain open in Codacy Cloud on the stale analyzed
  commit. Local active non-test Swift source no longer contains `assert(`;
  `linux_connector/tests/` also no longer contains `assert`. Cloud may still
  show stale Python test assertion rows until reanalysis; none were ignored or
  marked false-positive.
- Unselected Opus architecture-specific rows are handled through path policy,
  not ignored or marked false-positive.
- High/Critical `Cryptography` rows are mapped to vendored Opus documentation
  and DNN tooling lanes and are handled through path policy, not ignored or
  marked false-positive.
- The local worktree was dirty during the readout, so this ledger records the
  remote analyzed Codacy state, not every local file change.
- Local closure and Codacy Cloud closure must remain separate. A finding is not
  remotely closed until the relevant commit is pushed and Codacy reanalysis
  completes.
