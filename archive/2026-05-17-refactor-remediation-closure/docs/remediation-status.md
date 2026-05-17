# Remediation Status

Source of truth: `docs/refactor-plan.md`

Overall state: COMPLETE

Current/last slice: RP-016 COMPLETE; final closure gate completed.

Counts by status:

- COMPLETE: 16
- VERIFIED: 0
- IMPLEMENTED: 0
- IN_PROGRESS: 0
- BLOCKED: 0
- DEFERRED: 0
- NOT_STARTED: 0

Product runtime verdict: PARTIAL. Hardware, signing, notarization, clean-Mac,
benchmark, and real-world media evidence gates remain outside this refactor
remediation scope.

Last commands and results:

- `bash scripts/verify-release-readiness.sh` - PASS as a command after SwiftPM
  sandbox rerun outside the sandbox; source gate passed, native app launch probe
  passed, and product runtime verdict remains intentionally `PARTIAL`
- `OPEN_LOLA_APP_LAUNCH_EVIDENCE_DIR=/private/tmp/open-lola-app-evidence bash
  script/build_and_run.sh --verify` - PASS after making the launch probe accept
  the active persisted workflow's remote-stream status label
- `swift test --build-path /private/tmp/open-lola2-refactor-closure --filter
  AppBundleScriptSourcePolicyTests` - PASS, 2 tests passed
- `swift test --build-path /private/tmp/open-lola2-refactor-closure --filter
  AppShellBehaviorTests` - PASS, 1 semantic test passed
- `shellcheck -x script/build_and_run.sh` - PASS
- `swift test --build-path /private/tmp/open-lola2-refactor-closure
  --no-parallel` - PASS after line-budget correction, 475 tests passed
- `swift test --build-path /private/tmp/open-lola2-refactor-closure
  --no-parallel --filter CodeLineBudgetTests` - PASS, 1 test passed
- `swift build --build-path /private/tmp/open-lola2-refactor-closure` - PASS
  after SwiftPM manifest sandbox rerun outside the sandbox
- `python3 -m scripts.verify_docs` - PASS
- `PYTHONDONTWRITEBYTECODE=1 python -m pytest -p no:cacheprovider
  linux_connector` - PASS, 98 passed and 2 skipped
- `shellcheck -x scripts/*.sh scripts/lib/*.sh script/*.sh
  linux_connector/env/*.sh` - PASS
- `git diff --check` - PASS
- `ruff check linux_connector scripts/verify_docs scripts/lib/*.py` - PASS
- `python -m mypy --strict linux_connector/lola_connector
  scripts/verify_docs scripts/lib/*.py` - PASS, no issues in 22 source files
- `bash scripts/verify-release-hygiene.sh` - PASS, `HYGIENE_VERDICT: PASS`
- `bash scripts/verify-docs.sh` - PASS, documentation verification passed
- `find . -name .ruff_cache -o -name .mypy_cache -o -name __pycache__ -o
  -name .pytest_cache -o -name "*.pyc" -o -name "*.pyo"` - PASS after
  deleting generated `.ruff_cache` and `.mypy_cache`; follow-up scan returned no
  matches
- `find Sources/opus-1.5.2 Sources/xs_ref_sw_ed2 -maxdepth 3 -type d` - PASS,
  vendored/reference extras remain present and were not pruned without
  provenance/license/build proof
- `swift build --build-path /private/tmp/open-lola2-refactor-rp016` - PASS after
  rerun outside SwiftPM manifest sandbox; warnings came from vendored Opus/JPEG
  XS C sources
- `swift test --build-path /private/tmp/open-lola2-refactor-rp016 --filter
  Opus` - PASS, 17 tests passed
- `swift test --build-path /private/tmp/open-lola2-refactor-rp016 --filter
  JPEG` - PASS, 2 tests passed
- `bash scripts/verify-release-hygiene.sh` - PASS, `HYGIENE_VERDICT: PASS`
- `bash scripts/verify-docs.sh` - PASS, documentation verification passed
- `rg -n "JackTrip|UltraGrid|NMP|external-connector" Sources Tests docs
  scripts` - PASS, active usage found in CLI commands, report schema inventory,
  connector/NMP tests, Docker/native helper scripts, and docs
- `swift test --build-path /private/tmp/open-lola2-refactor-rp015 --filter
  ExternalConnector` - PASS, 53 tests passed
- `swift test --build-path /private/tmp/open-lola2-refactor-rp015 --filter
  VerificationToolingPairScriptTests` - PASS, 1 semantic test passed
- `bash scripts/verify-docs.sh` - PASS, documentation verification passed
- `rg -n
  "DirectPeerTwoPeerPrototype|direct-p2p-two-peer-prototype|two-peer-prototype|PrototypeReport"
  Sources Tests docs scripts -g '!archive/**'` - PASS, active usage found in
  CLI command routing, schema inventory, local-run aggregation, tests, and docs
- `git log --oneline -S DirectPeerTwoPeerPrototype -- Sources Tests docs` -
  PASS, history only showed the current backup commit in this checkout
- `swift test --build-path /private/tmp/open-lola2-refactor-rp014 --filter
  DirectPeerTwoPeerPrototypeReportTests` - PASS, 7 tests passed
- `swift test --build-path /private/tmp/open-lola2-refactor-rp014 --filter
  DirectPeerTwoPeerRunPlanTests` - PASS, 1 semantic test passed
- `swift test --build-path /private/tmp/open-lola2-refactor-rp014 --filter
  ReportSchemaInventoryTests` - PASS, 4 tests passed
- `swift test --build-path /private/tmp/open-lola2-refactor-rp014 --filter
  SourceNamingConventionTests` - PASS, 1 test passed
- `bash scripts/verify-docs.sh` - PASS, documentation verification passed
- `rg -n "audioDeviceUID|audio-device-uid|inputDeviceUID|outputDeviceUID"
  Sources Tests docs -g '!archive/**'` - PASS, active usage found in realtime
  config migration, Direct P2P CLI compatibility, runtime reports, tests, and
  docs
- `git log --oneline -S audioDeviceUID -- Sources Tests docs` - PASS, history
  only showed the current backup commit in this checkout
- `swift test --build-path /private/tmp/open-lola2-refactor-rp013 --filter
  DirectPeerRealtimeAudioGraphTests` - PASS after first test fixture corrected
  `UdpPcmSampleFormat` JSON from string to raw value; 2 tests passed
- `swift test --build-path /private/tmp/open-lola2-refactor-rp013 --filter
  DirectPeerSessionProductionAVRegressionTests` - PASS, 5 tests passed
- `bash scripts/verify-docs.sh` - PASS, documentation verification passed
- `git diff --check` - PASS
- `find . -name .ruff_cache -o -name .mypy_cache -o -name __pycache__` -
  PASS, no generated cache residue found
- `wc -l linux_connector/tests/test_process_runtime.py
  linux_connector/tests/test_process_backends.py` - PASS, 473 and 367 lines
- `PYTHONDONTWRITEBYTECODE=1 python -m pytest -p no:cacheprovider
  linux_connector/tests/test_process_runtime.py
  linux_connector/tests/test_process_backends.py` - PASS, 47 tests passed
- `swift test --build-path /private/tmp/open-lola2-refactor-rp002
  --no-parallel --filter CodeLineBudgetTests` - PASS, 1 test passed
- `swift test --build-path /private/tmp/open-lola2-refactor-rp002
  --no-parallel` - PASS, 472 tests passed
- `PYTHONDONTWRITEBYTECODE=1 python -m pytest -p no:cacheprovider
  linux_connector/tests -k "selftest or loopback_alias"` - PASS, 4 passed and
  2 skipped
- `PYTHONDONTWRITEBYTECODE=1 python -m pytest -p no:cacheprovider
  linux_connector` - PASS, 97 passed and 2 skipped
- `PYTHONDONTWRITEBYTECODE=1 python -m pytest -p no:cacheprovider
  linux_connector/tests/test_runtime_contracts.py` - PASS, 12 passed
- `PYTHONDONTWRITEBYTECODE=1 python -m pytest -p no:cacheprovider
  linux_connector` - PASS, 98 passed and 2 skipped
- `ruff check linux_connector scripts/verify_docs scripts/lib/*.py` - PASS
- `python -m mypy --strict linux_connector/lola_connector
  scripts/verify_docs scripts/lib/*.py` - PASS, no issues in 22 source files
- `swift test --build-path /private/tmp/open-lola2-refactor-rp011 --filter
  KeyValueArgumentParserTests` - PASS, 4 tests passed
- `swift test --build-path /private/tmp/open-lola2-refactor-rp011 --filter
  DirectPeerTwoPeerRunPlanTests` - PASS, 1 semantic test passed
- `swift build --build-path /private/tmp/open-lola2-refactor-rp011 --product
  open-lola` - PASS after rerun outside SwiftPM manifest sandbox; product
  built
- `/private/tmp/open-lola2-refactor-rp011/debug/open-lola
  direct-p2p-two-peer-local-run ...` - PASS for compatibility probes: unknown
  option, missing value, dash-prefixed value rejection, duplicate key, and
  invalid boolean all returned expected invalid-argument failures
- `rg -n
  "audioCompression|audio-compression|legacyAudioCompression|AppStorageKeys.audioCompression"
  . -g '!archive/**' -g '!.build/**' -g '!docs/remediation-*'` - PASS,
  active usage found in CLI parsing, app default migration, public runtime
  report decoding/encoding, tests, and docs
- `git log --oneline -S audioCompression -- Sources Tests docs` - PASS,
  history only showed the current backup commit in this checkout
- `git log --oneline -S --audio-compression -- Sources Tests docs` - PASS,
  history only showed the current backup commit in this checkout
- `swift test --build-path /private/tmp/open-lola2-refactor-rp012 --filter
  DirectPeerSessionOpusCLITests` - PASS, 5 tests passed
- `swift test --build-path /private/tmp/open-lola2-refactor-rp012 --filter
  NativeAppShellOpusCommandTests` - PASS, 2 tests passed
- `swift test --build-path /private/tmp/open-lola2-refactor-rp012 --filter
  ReportFixtureValidation` - PASS, 1 test passed
- `bash scripts/verify-docs.sh` - PASS, documentation verification passed
- `swift test --build-path /private/tmp/open-lola2-refactor-rp005 --filter
  AppShellBehaviorTests` - PASS, 1 semantic test passed
- `swift test --build-path /private/tmp/open-lola2-refactor-rp005 --filter
  NativeAppShell` - PASS, 10 tests passed
- `bash scripts/verify-docs.sh` - PASS, documentation verification passed
- `swift test --build-path /private/tmp/open-lola2-refactor-rp006 --filter
  LoLaCompatibilityMediaSessionTests` - PASS, regression first failed with
  `truncatedPayload(3)`, then 1 semantic test passed after the fix
- `swift test --build-path /private/tmp/open-lola2-refactor-rp006 --filter
  LoLaCompatibilityMediaCodecTests` - PASS, 6 tests passed
- `swift test --build-path /private/tmp/open-lola2-refactor-rp006 --filter
  ExternalConnectorLoLaCompatibilityTests` - PASS, 7 tests passed
- `swift test --build-path /private/tmp/open-lola2-refactor-rp006 --filter
  LoLaCompatibilityMediaEnvelopeValidationTests` - PASS, 1 semantic test passed
- `bash scripts/verify-docs.sh` - PASS, documentation verification passed
- `swift test --build-path /private/tmp/open-lola2-refactor-rp007 --filter
  DirectPeerRealtimeAudioGraphRxBufferingTests` - PASS, 2 tests passed
- `swift test --build-path /private/tmp/open-lola2-refactor-rp007 --filter
  RxBufferingTests` - PASS, 3 tests passed
- `swift test --build-path /private/tmp/open-lola2-refactor-rp007 --filter
  DirectPeerRealtimeAudioGraphTests` - PASS, 1 semantic test passed
- `swift test --build-path /private/tmp/open-lola2-refactor-rp008 --filter
  RxBufferingTests` - PASS after first failed compile exposed missing `return`;
  3 tests passed
- `swift test --build-path /private/tmp/open-lola2-refactor-rp008 --filter
  RealtimeAudioEngineTests` - PASS, 1 semantic test passed
- `swift test --build-path /private/tmp/open-lola2-refactor-rp008 --filter
  DirectPeerSessionAVRXBufferProfileTests` - PASS, 7 tests passed
- `swift test --build-path /private/tmp/open-lola2-refactor-rp009 --filter
  ReleaseArtifactHygieneContractTests` - PASS, 5 tests passed
- `swift test --build-path /private/tmp/open-lola2-refactor-rp009 --filter
  VerificationToolingContractTests` - PASS, 1 semantic test passed
- `swift test --build-path /private/tmp/open-lola2-refactor-rp009 --filter
  RealtimeAudioPathInventoryTests` - PASS, 3 tests passed
- `bash scripts/verify-docs.sh` - PASS, documentation verification passed
- `PYTHONDONTWRITEBYTECODE=1 python -m pytest -p no:cacheprovider
  linux_connector/tests/test_process_runtime.py
  linux_connector/tests/test_process_backends.py` - PASS, 46 passed and
  2 skipped
- `ruff check linux_connector scripts/verify_docs scripts/lib/*.py` - PASS
- `python -m mypy --strict linux_connector/lola_connector
  scripts/verify_docs scripts/lib/*.py` - PASS, no issues in 22 source files

Uncertainty:

- Full release-candidate hygiene scanning was not run because RP-001 only
  required live checkout generated-residue cleanup.
- The broad Swift test gate and final release-readiness closure gate are now
  verified in this remediation run.
- The live UDP selftests were skipped on this host because `127.0.0.2` is not
  available; this is now explicit test output, not a false pass.
- RP-004 leaves receive-mode video binding unchanged because `_media_rx_loop`
  currently receives both audio and video.
- RP-005 changes `NativeAppShellExecutionReport.verdict` for direct-Mac
  validation reports to mirror validated supervisor verdicts; product-level
  field readiness remains separately noted as externally gated.
- RP-006 did not add a persisted JSON schema field for malformed count; the
  failure is carried by report verdict, runtime error, frame packet kind, and
  payload confidence, with malformed count available as a computed property.
- RP-007 leaves invalid `RxBufferPolicy` values constructible through the
  public initializer; graph setup now rejects them explicitly and RP-008 owns
  the public initializer trap/validation question.
- RP-008 preserves the non-throwing public `RxBufferPolicy` initializer, but
  invalid `framesPerPacket` values now produce typed validation/factory errors
  and guarded packet-count inspection instead of a construction-time trap.
- RP-009 does not make policy/text checks prove runtime behavior; it documents
  that boundary and adds a realtime inventory machine-readable surface gate.
- RP-010 only centralized repeated process command/startup setup inside the
  existing lifecycle mixin; it intentionally avoided a broader process
  framework.
- RP-011 did not add a direct unit test for the private executable-target parser
  helper; compatibility is covered by shared parser tests, run-plan tests, and
  executable CLI probes.
- RP-012 found no safe deletion proof for `audioCompression` /
  `--audio-compression`; the path remains hidden compatibility, with
  `audioTransport` documented as canonical in `docs/source-contracts/README.md`.
- RP-013 found no safe deletion proof for legacy realtime graph
  `audioDeviceUID`; the path remains decode-only/canonical-encode
  compatibility, with split UIDs documented as canonical.
- RP-014 found no safe rename/deletion proof for
  `DirectPeerTwoPeerPrototypeReport`; the prototype name remains an active
  measured public contract until a promoted replacement exists.
- RP-015 found no safe deletion proof for JackTrip, UltraGrid, NMP, or external
  executable preflight surfaces; they remain classified as active comparison,
  verification, or safety-gate contracts. No live Docker/native parity run was
  performed for this classification slice.
- RP-016 removed regenerated local cache residue, but did not prune vendored
  Opus or JPEG XS reference extras because active build/linkage, license, and
  release-boundary evidence do not prove safe live-checkout deletion.
- The working tree contains many pre-existing unrelated modified/untracked
  files; this status tracks only slices from `docs/refactor-plan.md`.

Next gate:

- None for `docs/refactor-plan.md` slices RP-001 through RP-016. Product
  runtime remains `PARTIAL` until separate real-world hardware, signing,
  notarization, clean-Mac, and benchmark evidence gates are completed.
