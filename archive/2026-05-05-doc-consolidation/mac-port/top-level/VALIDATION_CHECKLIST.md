# Validation Checklist

Date: 2026-05-04  
Status: documentation and Swift source gates

## Documentation Gates

Run the canonical documentation gate after documentation changes:

```bash
bash scripts/verify-docs.sh
```

The script prints this Markdown inventory:

```bash
find . -maxdepth 3 -type f -name '*.md' | sort
```

It also runs a Markdown relative-link checker over active files in:

- `MAC_PORT_PLAN.md`
- `docs/**/*.md`
- `mac-port/**/*.md`
- `research/**/*.md`
- `reverse-engineering/**/*.md`

Historical snapshots under `docs/historical/` are excluded from active docs
contract checks.

The consolidated implementation handoff
[IMPLEMENTATION_COMPANION.md](IMPLEMENTATION_COMPANION.md) is included through
the `mac-port/**/*.md` pattern and must remain ASCII-only.

Preserved snapshots in `mac-port/historical/` are included in inventory and
ASCII checks, but their relocated links are not active documentation links.

The topic gate covers the same documentation set. Required topics:

- Core Audio
- AudioDeviceIOProc
- AUHAL
- UDP PCM
- drift
- PLC
- AVB
- DSCP
- PTP
- AVFoundation
- VideoToolbox
- OSC
- sACN
- Art-Net
- validation
- risk
- progress
- Resume here

The ASCII gate covers `MAC_PORT_PLAN.md` and `mac-port/**/*.md`:

```bash
LC_ALL=C grep -n '[^ -~]' MAC_PORT_PLAN.md mac-port/**/*.md
```

Expected result: no matches.

The script also checks:

- M00-M15 milestone section contracts under `mac-port/milestones/`;
- publication-safe current-state and architecture docs under `docs/`;
- active public source-contract docs under `docs/source-contracts/`;
- active public benchmark docs under `docs/benchmarks/`;
- consolidated implementation companion existence and required section contract;
- [SOTA_2026_OPEN_QUESTION_MATRIX.md](SOTA_2026_OPEN_QUESTION_MATRIX.md)
  existence, Q001-Q010 coverage, and coverage of every SOTA probe extracted
  from [../research/RESEARCH_EVIDENCE_MATRIX_2026.md](../research/RESEARCH_EVIDENCE_MATRIX_2026.md);
- ASCII `TODO(human)` markers using `->` separators.

## Source Gates

Run these after source or implementation-documentation changes:

```bash
find Sources Tests scripts -type f \( -name '*.swift' -o -name '*.sh' \) -print0 | xargs -0 wc -l | sort -nr | head
swift build
swift test
```

Add CLI smoke tests as each headless tool appears:

- device inventory CLI;
- reference-rig report validator;
- measurement report fixture validator;
- endpoint loopback report validator;
- RME fastest-audio report validator;
- realtime audio engine report validator;
- realtime audio synthetic smoke;
- UDP PCM packet fixture validator;
- UDP PCM localhost smoke;
- UDP PCM route report validator;
- Mac-to-Mac route certification report validator;
- UDP PCM route localhost smoke;
- UDP PCM loopback report validator;
- UDP PCM loopback localhost smoke;
- network diagnostics report validator;
- network diagnostics localhost run;
- NAT-friendly route report validator;
- NAT-friendly route localhost smoke;
- NAT rendezvous localhost smoke;
- NAT rendezvous/forwarder launcher localhost smoke;
- NAT relay fallback localhost smoke;
- route certification synthetic smoke;
- UDP PCM one-shot sender and receiver smoke;
- drift/PLC report validator;
- drift/PLC synthetic smoke;
- drift/PLC fixed-target certification report validator;
- drift/PLC certification synthetic smoke;
- AoIP evaluation report validator;
- AoIP synthetic smoke;
- network AoIP certification report validator;
- network AoIP certification synthetic smoke;
- video capture report validator;
- video capture production evidence PASS gates;
- video capture synthetic smoke;
- video capture inventory validator;
- video capture live run CLI;
- video transport report validator;
- video transport fragmentation/reassembly PASS gates;
- video transport synthetic smoke;
- video transport raw run CLI;
- integrated A/V report validator;
- integrated A/V run-window and report/capture-point PASS gates;
- integrated A/V synthetic smoke;
- integrated A/V bounded run report writer;
- hardware validation aggregate report validator;
- hardware validation synthetic smoke;
- hardware validation bounded aggregate report writer;
- OSC cue report validator;
- OSC cue synthetic smoke;
- OSC cue external-peer handoff writer;
- ATEM read-only control report validator;
- ATEM read-only reachability probe;
- lighting fixture gate report validator;
- lighting OSC-first cue workflow PASS gates;
- lighting fixture gate synthetic smoke;
- lighting fixture gate bounded handoff writer;
- native app shell report validator;
- native app shell synthetic smoke;
- native app runtime smoke handoff writer;
- native app shell target build;
- recording session artifact report validator;
- recording session synthetic smoke;
- recording session bounded artifact handoff writer;
- packaging field-test report validator;
- packaging field-test synthetic smoke;
- packaging field-test bounded ad-hoc package handoff writer;
- field-runtime aggregate proof handoff writer;
- field-runtime aggregate proof validator;
- field-runtime synthetic smoke;
- F09 composite field-readiness handoff writer;
- LoLa parity deferred ledger validator;
- LoLa parity deferred synthetic smoke;
- faster-than-LoLa closure validator;
- faster-than-LoLa closure synthetic smoke;
- faster-than-LoLa closure bounded handoff writer;
- release hardening report validator;
- release hardening synthetic smoke;
- release hardening bounded handoff writer;
- audio loopback rig;
- UDP PCM packet fixture parser;
- route certification reporter;
- video capture probe;
- OSC cue probe;
- lighting isolated-universe probe.

## Milestone Closure Gate

Before marking any milestone complete in [PROGRESS.md](PROGRESS.md), verify:

- implementation exists;
- tests pass;
- runtime or surface probe passes where applicable;
- validation report exists;
- [RISK_REGISTER.md](RISK_REGISTER.md) is updated if risk changed;
- [OPEN_QUESTIONS.md](OPEN_QUESTIONS.md) is updated if questions were answered
  or discovered;
- [SOTA_2026_OPEN_QUESTION_MATRIX.md](SOTA_2026_OPEN_QUESTION_MATRIX.md) is
  updated if a SOTA probe changes owner, disposition, or gate;
- the milestone doc ends with a current Resume here handoff.

## Hardware-Gated Proofs

These commands are required before claiming production readiness. They are not
expected to PASS on a machine without the target hardware, route, or signing
material.

Audio and route:

```bash
swift run open-lola device-inventory
swift run open-lola audio-loopback-run --input-uid <rme-input-uid> --output-uid <rme-output-uid> --sample-rate <hz> --frames <n> --duration-seconds <n> --output <path>
swift run open-lola validate-rme-fastest-audio-report <path>
swift run open-lola validate-realtime-audio-engine-report <path>
swift run open-lola udp-pcm-route-run --role receiver --bind-host <receiver-ip> --peer <sender-ip> --port <port> --sample-rate <hz> --frames <n> --channels <n> --duration-seconds <n> --output <receiver-report> --route-kind directLink --sender-interface <sender-interface> --sender-ip <sender-ip> --receiver-interface <receiver-interface> --receiver-ip <receiver-ip> --capture-point <capture-label> --capture-correlated true --capture-notes <capture-note> --dscp-observed <0-63> --dscp-classification honored --verdict pass
swift run open-lola udp-pcm-route-run --role sender --bind-host <sender-ip> --peer <receiver-ip> --port <port> --sample-rate <hz> --frames <n> --channels <n> --duration-seconds <n> --output <sender-summary>
swift run open-lola validate-route-report <receiver-report>
swift run open-lola udp-pcm-loopback-run --session-id <id> --role looper --bind-host <receiver-ip> --peer <sender-ip> --port <port> --sample-rate <hz> --frames <n> --channels <n> --duration-seconds <n> --output <looper-report>
swift run open-lola udp-pcm-loopback-run --session-id <id> --role sender --bind-host <sender-ip> --peer <receiver-ip> --port <port> --sample-rate <hz> --frames <n> --channels <n> --duration-seconds <n> --diagnostics on --output <loopback-report>
swift run open-lola network-diagnostics-run --peer <receiver-ip> --ping-count <n> --max-hops <n> --output <diagnostics-report>
swift run open-lola validate-route-certification-report <path>
swift run open-lola validate-udp-pcm-loopback-report <loopback-report>
swift run open-lola validate-udp-pcm-loopback-session <loopback-report> <looper-report>
swift run open-lola validate-network-diagnostics-report <diagnostics-report>
swift run open-lola drift-plc-run --route-report <path> --duration-seconds 3600 --policy silence --artifact-assessment-completed true --artifact-notes <text> --output <path>
swift run open-lola validate-drift-plc-certification-report <path>
swift run open-lola nat-rendezvous-run --bind-host <rendezvous-ip> --port <port> --session-id <id> --mode rendezvousOnly --expected-peers 2 --timeout-seconds <n> --output <rendezvous-report>
swift run open-lola nat-friendly-route-run --role sender --bind-host <sender-ip> --peer-id <sender-id> --rendezvous-host <rendezvous-ip> --rendezvous-port <port> --session-id <id> --port <local-udp-port> --duration-seconds <n> --raw-rtt-microseconds <f11-raw-rtt-us> --output <sender-nat-report>
swift run open-lola nat-friendly-route-run --role looper --bind-host <looper-ip> --peer-id <looper-id> --rendezvous-host <rendezvous-ip> --rendezvous-port <port> --session-id <id> --port <local-udp-port> --duration-seconds <n> --raw-rtt-microseconds <f11-raw-rtt-us> --output <looper-nat-report>
swift run open-lola validate-nat-friendly-route-report <sender-nat-report>
swift run open-lola validate-nat-friendly-route-report <looper-nat-report>
```

Video, control, lighting, and integrated runtime:

```bash
swift run open-lola video-capture-inventory --output <path>
swift run open-lola video-capture-run --device-id <id|auto> --duration-seconds <n> --output <path>
swift run open-lola video-transport-run --mode raw --peer <ip> --port <port> --duration-seconds <n> --max-packet-bytes <mtu-safe-bytes> --route-kind directWired --packet-capture-point <label> --output <path>
swift run open-lola integrated-av-run --audio-baseline <report-id> --video-capture on --video-transport on --osc-control on --atem-readonly <host|off> --duration-seconds 1800 --output <path>
swift run open-lola hardware-validation-run --reference-rig <path> --rme-fastest-audio <path> --video-capture <path> --atem-control <path> --lighting-gate <path> --integrated-profile <path> --field-run-report <id> --duration-seconds 1800 --output <path>
swift run open-lola validate-hardware-validation-report <path>
swift run open-lola osc-cue-external-run --audio-baseline <report-id> --port <port> --count <n> --first-external-peer chataigne --external-host <host> --external-port <port> --external-available true --output <path>
swift run open-lola lighting-gate-run --audio-baseline <report-id> --osc-cue-report <report-id> --protocol sacn --interop-target qlcPlus --universe <n> --network-mode isolatedUnicast --destination <host> --port <port> --isolated-network true --explicitly-armed true --capture-tool <tool> --capture-point <label> --duration-seconds <n> --output <path>
```

Field and closure:

```bash
swift run open-lola native-app-runtime-smoke --headless-report <path> --output <path>
swift run open-lola recording-session-run --integrated-baseline <path> --duration-seconds <n> --output-dir <dir> --report <path>
swift run open-lola packaging-field-run --integrated-report <path> --app-report <path> --recording-report <path> --output-dir <dir> --report <path>
swift run open-lola field-runtime-proof-run --integrated-report <path> --app-report <path> --recording-report <path> --packaging-report <path> --output <path>
swift run open-lola validate-field-runtime-proof <path>
swift run open-lola field-readiness-run --integrated-report <path> --duration-seconds <n> --output-dir <dir>
swift run open-lola faster-than-lola-closure-run --claim-scope audioOnly --f01-report <report-id> --f02-report <report-id> --f03-report <report-id> --f04-report <report-id> --output <path>
swift run open-lola validate-faster-than-lola-closure <path>
swift run open-lola release-hardening-run --output <path>
swift run open-lola validate-release-hardening-report <path>
```

The faster-than-LoLa closure in
[implementation-companions/F10_FASTER_THAN_LOLA_CLOSURE.md](implementation-companions/F10_FASTER_THAN_LOLA_CLOSURE.md)
requires accepted F01-F04 evidence, accepted F05-F09 evidence for expanded
claims, and a measured LoLa baseline on the same hardware and route. If the
baseline or any physical proof is missing, report `VERDICT: PARTIAL`.

The public M14 release-hardening ledger in
[../docs/current-state.md](../docs/current-state.md)
requires public docs, tests, measured reports, packaging/signing/clean-Mac
evidence, and benchmark comparison to agree before release PASS.

Resume here: after any roadmap edit, run `bash scripts/verify-docs.sh` first;
then run `shellcheck scripts/*.sh`, `swift build`, `swift test`, and the
surface probes listed in [IMPLEMENTATION_COMPANION.md](IMPLEMENTATION_COMPANION.md).
