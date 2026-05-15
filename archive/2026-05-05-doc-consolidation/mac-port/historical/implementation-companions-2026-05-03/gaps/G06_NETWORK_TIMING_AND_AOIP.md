# G06 Network Timing And AoIP

## LoLa Comparison

LoLa assumes clean high-performance academic networks. The Mac roadmap adds
AVB, PTP, AES67, RAVENNA, Dante, and TSN only as measured interop modes. None
may replace direct UDP PCM unless they beat it on the same path without adding
audio latency.

## Current Repo State

- Related milestone: [../milestones/M07_AVB_PROFESSIONAL_AOIP_EVALUATION.md](../milestones/M07_AVB_PROFESSIONAL_AOIP_EVALUATION.md)
- Live status: [../status/M07_STATUS.md](../status/M07_STATUS.md)
- Existing source validates AoIP evaluation reports and synthetic smoke.
- G06 now has a network AoIP certification wrapper that composes accepted G04
  route certification, G05 fixed-target drift/PLC certification, and an M07
  AoIP evaluation report.
- Missing piece: real PTP/AVB/professional endpoint evidence, profile
  artifacts, and WCRT-style stress artifacts.

## Implementation Plan

1. Record candidate switches, endpoints, clock domains, PTP version/profile,
   domain, grandmaster, lock state, and failure behavior.
2. Run direct UDP PCM baseline on the same physical path first.
3. Run AVB or other professional AoIP profile under idle and competing-traffic
   stress.
4. Compare endpoint latency, p99/max jitter, clock stability, underruns,
   packet loss, and required playout target against the UDP PCM baseline.
5. Label each profile as accepted, rejected, or not tested with reason.
6. Keep vendor-specific control software outside the realtime callback and
   outside generic builds.

## Acceptance Tests

- `validate-aoip-report` accepts measured reports.
- `validate-network-aoip-certification-report` accepts the wrapper that ties
  measured AoIP evidence to accepted G04/G05 direct baselines.
- PASS requires explicit PTP profile, same-path baseline, measured stress, and
  no default replacement without measured superiority.
- A mode that requires larger audio playout target is rejected or fallback-only.
- G06 certification PASS rejects synthetic mode, missing G04/G05 baselines,
  missing AoIP report, direct UDP-only reports, baseline mismatch, route
  mismatch, missing PTP/stress/profile artifacts, and placeholder evidence.

## Blockers / TODO(human)

- TODO(human): [M07 timing network] -> Identify PTP, AVB, AES67, RAVENNA, or Dante-capable switches/endpoints -> [no interop hardware / AVB-only / professional AoIP endpoints]
- Requires standards/profile access when implementation depends on paid or
  member-only clauses.

## Verification Commands

```bash
swift run open-lola validate-aoip-report <aoip-report.json>
swift run open-lola validate-network-aoip-certification-report <g06-certification.json>
swift run open-lola network-aoip-certification-synthetic-smoke
swift test --filter Aoip
bash scripts/verify-docs.sh
```

## Resume here

Do not start with vendor AoIP. First capture the direct UDP PCM baseline on the
same physical path, then validate the G06 certification wrapper with measured
PTP/profile/stress artifacts.

VERDICT: PARTIAL
