# M12 Lighting Fixture Gate Validation Report

Date: 2026-05-02  
Updated: 2026-05-03  
Milestone: [M12 sACN Art-Net Fixture Gate](../milestones/M12_SACN_ARTNET_FIXTURE_GATE.md)  
Status: PARTIAL

## Scope

This report validates the M12 source-level lighting safety harness: current
standards evidence fields, an explicit arm/isolation policy, one-universe probe
request, packet-capture requirement, setup-only fixture metadata policy,
blackout/hold/drop policy, audio-impact PASS guards, fixture validation, and
synthetic smoke output. The 2026-05-03 addendum also validates a bounded
`lighting-gate-run` handoff report writer that records the audio baseline ID,
OSC cue report ID, protocol, interop target, universe, network mode,
explicit-arm state, OSC-first workflow fields, and packet-capture setup fields
without sending packets. It does not validate real sACN or Art-Net packet
output, QLC+, OLA, fixture behavior, or lighting traffic while live audio is
running.

## Current Reference Check

Checked sources:

- ESTA published documents page:
  [https://tsp.esta.org/tsp/documents/published_docs.php](https://tsp.esta.org/tsp/documents/published_docs.php)
- ANSI E1.31-2025 listing:
  [https://webstore.ansi.org/standards/esta/ansie1312025](https://webstore.ansi.org/standards/esta/ansie1312025)
- Official Art-Net site:
  [https://art-net.org.uk/](https://art-net.org.uk/)
- QLC+ sACN documentation:
  [https://docs.qlcplus.org/v5/plugins/e1-31-sacn](https://docs.qlcplus.org/v5/plugins/e1-31-sacn)
- QLC+ Art-Net documentation:
  [https://docs.qlcplus.org/v5/plugins/art-net](https://docs.qlcplus.org/v5/plugins/art-net)
- OLA latest developer documentation:
  [https://docs.openlighting.org/ola/doc/latest/index.html](https://docs.openlighting.org/ola/doc/latest/index.html)

Source-derived implementation constraints:

- Treat ANSI E1.31-2025 as the current sACN reference for this gate.
- Treat Art-Net 4 as official Artistic Licence material; product use still
  needs required credit and OEM-code/licensing disposition.
- Prefer QLC+ or OLA interop before direct DMX-over-IP output.
- Keep sACN/Art-Net output behind explicit arm, isolated route, allowed
  universe, packet capture, and audio-impact checks.

## Lighting Gate Contract

The report records:

- protocol standards evidence and licensing disposition;
- OSC-first cue workflow evidence and cue report ID;
- explicit arm/isolation state;
- broadcast and multicast policy;
- allowed protocol, universe, destination, port, and refresh limit;
- hold, blackout, drop-on-audio-impact, and disable-on-peer-loss policy;
- one-universe probe request;
- packet-capture tool, capture point, packet count, observed universes, and
  broadcast/multicast counts;
- setup-only fixture metadata policy;
- baseline and lighting-on audio callback p99/max, playout target, underruns,
  and hidden audio-impact flag;
- PASS, FAIL, or PARTIAL verdict.

PASS reports require reviewed standards, OSC cue workflow evidence, explicit
arming, verified isolation, one local OLA/QLC+ fixture owner, no direct fixture
streaming over the performance link, one allowed universe, permitted
broadcast/multicast behavior, packet capture, setup-only fixture metadata,
unchanged audio callback p99/max, unchanged playout target, zero underruns, and
no hidden audio impact.

## Commands

```bash
swift test --filter LightingFixtureGate
swift test
swift build
.build/debug/open-lola lighting-gate-run --audio-baseline m05-route-baseline-required --osc-cue-report m11-osc-cue-required --protocol sacn --interop-target qlcPlus --universe 1 --network-mode loopbackUnicast --destination 127.0.0.1 --port 5568 --isolated-network true --explicitly-armed false --capture-tool not-run --capture-point not-run --duration-seconds 0 --output /private/tmp/open-lola-m12-lighting-gate-run-f08.json
.build/debug/open-lola validate-lighting-gate-report /private/tmp/open-lola-m12-lighting-gate-run-f08.json
.build/debug/open-lola validate-lighting-gate-report Tests/OpenLolaCoreTests/Fixtures/LightingFixtureGateReports/valid/lighting-gate-partial.json
.build/debug/open-lola lighting-gate-synthetic-smoke
bash scripts/verify-docs.sh
shellcheck scripts/*.sh
```

## Results

- Red F08 test run before implementation failed on missing OSC cue workflow
  fields, report parsing, and PASS rejection errors.
- `swift test --filter LightingFixtureGate` passed with 20 M12/F08 tests.
- `swift test` passed with 340 tests.
- `swift build` passed after rerunning outside the SwiftPM sandbox failure.
- The bounded `lighting-gate-run` command wrote a valid PARTIAL handoff report
  with `oscCueReportId: m11-osc-cue-required`, `localFixtureOwner: qlcPlus`,
  `directFixtureStreamingOnPerformanceLink: false`, and output blocked because
  explicit arming was false.
- 2026-05-03 F08 addendum: PASS validation now rejects missing OSC cue workflow
  evidence, missing or placeholder OSC cue report IDs, missing local fixture
  owner, owner mismatch with the interop target, and direct fixture streaming on
  the performance link.
- The synthetic PARTIAL lighting gate fixture passed CLI validation.
- The synthetic smoke command emitted a PARTIAL report.
- Documentation verification passed.
- Shellcheck passed for the docs verifier script.

## Deferred Runtime Evidence

M12 cannot be marked PASS until real reports exist for:

- Q009 isolated universe, network, fixture or virtual target, blackout behavior,
  and packet-capture point;
- one configured sACN universe against QLC+ or OLA;
- one configured Art-Net universe if Art-Net remains required;
- packet capture proving only the configured universe and expected
  broadcast/multicast behavior;
- audio-on/lighting-on comparison proving unchanged callback p99/max, playout
  target, and underrun count;
- Art-Net credit/OEM-code disposition before release;
- setup-time fixture metadata validation with actual target fixtures.

## Verdict

M12 source validation is complete, but real lighting output, packet capture,
fixture, and audio-impact certification remain open.

VERDICT: PARTIAL

## Resume here

Use `open-lola lighting-gate-run ... --explicitly-armed false` to record the
Q009 safety handoff first, then use
`open-lola validate-lighting-gate-report <path>` for the first measured
QLC+/OLA one-universe report. Keep M12 PARTIAL until the report proves isolated
lighting output with unchanged audio timing.
