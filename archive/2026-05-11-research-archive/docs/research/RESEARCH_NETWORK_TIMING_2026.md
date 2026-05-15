# Open Lola Network Timing Research 2026
Verdict: PARTIAL

Back to companion: [RESEARCH_COMPANION_2026.md](RESEARCH_COMPANION_2026.md)

Date: 2026-05-02  
Status: internal research ledger, current after public background-lane restructure
Evidence: [RESEARCH_EVIDENCE_MATRIX_2026.md](RESEARCH_EVIDENCE_MATRIX_2026.md),
matters 25-38 and 76-81

Source refresh checked 2026-05-02: Apple UDP/Ethernet-channel docs, Apple AVB
support, and the official AES67-2023 listing still support the current gated
interop plan. See
[../mac-port/sota-open-question-matrix.md](../mac-port/sota-open-question-matrix.md)
for milestone routing.

## Hard Rule

No DSCP/QoS rule, PTP profile, AVB/TSN schedule, AES67/RAVENNA/Dante mode,
video stream, lighting stream, retransmission behavior, or relay may increase
default audio playout latency.

## Network Decision

Fastest mode remains direct UDP PCM over a measured wired academic path. Network
features may improve reliability or interoperability, but only after they are
measured against the direct baseline.

| Topic | Decision | Implementation rule |
|---|---|---|
| Direct UDP on wired academic networks | adopt now | First benchmark path for Mac-to-Mac audio. |
| DSCP/QoS/service class | benchmark | Classify every route as honored, rewritten, ignored, or harmful. |
| PTP version/profile/domain | implementation gate | Record exact profile before timing claims. |
| AVB and TSN/WCRT | benchmark | Measure worst-case latency under load, not only idle mean. |
| AES67, RAVENNA, Dante, ST 2110 | implementation gate | Interop lanes only after full standards/vendor-profile review. |
| Mobile/5G and cross-domain QoS | defer | Fallback routes, never fastest default. |
| Retransmission waits | reject | They can hide loss only by risking more playout latency. |

## Academic Network Profile

Each route report must record:

- endpoint devices and interfaces;
- switch path and administrative domains;
- link rates and any Wi-Fi/mobile segment;
- VLAN, multicast, and broadcast policies;
- DSCP marking requested by the app;
- DSCP marking observed at each capture point;
- queueing behavior under idle and stressed traffic;
- packet loss, reordering, jitter, p99, and max delay;
- whether the route is accepted for fastest mode.

Fastest mode is allowed only on paths where packet age remains inside the fixed
playout target without automatic buffer growth.

## DSCP And QoS

DSCP can help only if the path honors it. It can also be rewritten or mapped to
unexpected queues. JackTrip's QoS hooks are useful prior art, but open-lola must
prove local behavior with packet capture.

Required classification:

- honored: marking survives and improves or stabilizes audio packet timing;
- rewritten: marking changes but behavior is still documented;
- ignored: no measurable effect;
- harmful: marking makes queueing or loss worse.

## PTP, AVB, TSN, And WCRT

PTP aligns clocks. It does not automatically reduce playout latency. AVB and
TSN can provide deterministic behavior only when the full network is configured
and measured as a system.

Any AVB/TSN report must include:

- PTP version, profile, domain, clock master, and lock state;
- switch features and firmware;
- link rates;
- traffic classes;
- audio schedule or stream-reservation settings;
- WCRT-style stress cases;
- p50, p95, p99, max, loss, and recovery behavior;
- comparison against direct UDP PCM on the same path.

Adding video or lighting to a deterministic schedule must never reduce the
audio-flow guarantee. Audio is the first protected stream.

## AES67, RAVENNA, Dante, And ST 2110

AES67, RAVENNA, Dante, and ST 2110 are important professional interop lanes.
They are not the first fastest-mode implementation path because they introduce
profile, session, PTP, endpoint, and vendor-buffer behavior outside direct app
control.

Implementation gates:

- read the current full standard or vendor profile before implementation;
- record public catalog/source metadata used during research;
- measure actual endpoint latency and clock behavior;
- compare with direct UDP PCM using identical audio hardware where possible;
- keep interop mode separately labeled from fastest default.

## Required Probes

1. Direct UDP route: packet age at playout, reordering, late/drop counters,
   p99/max jitter, and packet capture correlation.
2. DSCP/QoS route: marked and unmarked comparison under idle and loaded
   network conditions.
3. PTP route: clock offset, lock state, profile/domain, and failure behavior.
4. AVB/TSN route: WCRT-style load cases with simultaneous non-audio traffic.
5. AES67/RAVENNA/Dante route: endpoint latency and clocking compared with
   direct UDP PCM.
