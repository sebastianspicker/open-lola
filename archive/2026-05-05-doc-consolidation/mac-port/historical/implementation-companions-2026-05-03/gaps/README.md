# Gap Companion Index

Date: 2026-05-02  
Status: implementation-planning layer for missing and not-ready features

This directory compares the Mac-native roadmap with LoLa-class behavior and
turns every missing or not-ready feature into a dedicated implementation
companion. The canonical milestone plans remain in
[../milestones/](../milestones/). Live status remains in
[../status/](../status/). These gap companions are the ordered implementation
plans for closing the remaining `VERDICT: PARTIAL` surfaces.

## Comparison Baseline

External LoLa baseline:

- Official LoLa site: <https://lola.conts.it/>
- LoLa Manual 2.0.0:
  <https://lola.conts.it/downloads/Lola_Manual_2.0.0_rev_001.pdf>
- Original LoLa paper:
  <https://www.internetsociety.org/wp-content/uploads/2013/09/32_LOLA.pdf>

Local evidence:

- [../../MAC_PORT_PLAN.md](../../MAC_PORT_PLAN.md)
- [../PROGRESS.md](../PROGRESS.md)
- [../STATUS_INDEX.md](../STATUS_INDEX.md)
- [../prototype/P00_PROTOTYPE_INDEX.md](../prototype/P00_PROTOTYPE_INDEX.md)
- [../../reverse-engineering/REVERSE_ENGINEERING_EVIDENCE_MATRIX_2026.md](../../reverse-engineering/REVERSE_ENGINEERING_EVIDENCE_MATRIX_2026.md)
- [../../research/RESEARCH_BENCHMARK_ROADMAP_2026.md](../../research/RESEARCH_BENCHMARK_ROADMAP_2026.md)

## Ordered Gap Plan

| Order | Companion | Closes or advances |
|---:|---|---|
| 1 | [G01_MEASUREMENT_RIG_AND_REFERENCE_HARDWARE.md](G01_MEASUREMENT_RIG_AND_REFERENCE_HARDWARE.md) | M01, Q001, shared labels and thresholds |
| 2 | [G02_RME_MADI_FASTEST_AUDIO_PATH.md](G02_RME_MADI_FASTEST_AUDIO_PATH.md) | P01, M03, Q002-Q003 |
| 3 | [G03_REALTIME_CORE_AUDIO_ENGINE.md](G03_REALTIME_CORE_AUDIO_ENGINE.md) | P02 callback ownership and realtime safety |
| 4 | [G04_MAC_TO_MAC_UDP_PCM_ROUTE.md](G04_MAC_TO_MAC_UDP_PCM_ROUTE.md) | M05, Q004 |
| 5 | [G05_DRIFT_PLC_FIXED_TARGET.md](G05_DRIFT_PLC_FIXED_TARGET.md) | M06 |
| 6 | [G06_NETWORK_TIMING_AND_AOIP.md](G06_NETWORK_TIMING_AND_AOIP.md) | M07, Q005-Q006 |
| 7 | [G07_AVFOUNDATION_CAPTURE.md](G07_AVFOUNDATION_CAPTURE.md) | M08, P03 capture |
| 8 | [G08_BLACKMAGIC_ATEM_READONLY.md](G08_BLACKMAGIC_ATEM_READONLY.md) | P03 ATEM control evidence |
| 9 | [G09_VIDEO_TRANSPORT_DEGRADES_FIRST.md](G09_VIDEO_TRANSPORT_DEGRADES_FIRST.md) | M09 |
| 10 | [G10_INTEGRATED_HEADLESS_AV_PROOF.md](G10_INTEGRATED_HEADLESS_AV_PROOF.md) | M10, P04 |
| 11 | [G11_OSC_CUE_LOOP.md](G11_OSC_CUE_LOOP.md) | M11 |
| 12 | [G12_LIGHTING_FIXTURE_GATE.md](G12_LIGHTING_FIXTURE_GATE.md) | M12, Q009 |
| 13 | [G13_NATIVE_APP_RUNTIME.md](G13_NATIVE_APP_RUNTIME.md) | M13 |
| 14 | [G14_RECORDING_SESSION_ARTIFACTS.md](G14_RECORDING_SESSION_ARTIFACTS.md) | M14 |
| 15 | [G15_PACKAGING_CLEAN_MAC_FIELD_TEST.md](G15_PACKAGING_CLEAN_MAC_FIELD_TEST.md) | M15, Q010, P05 |
| 16 | [G16_LOLA_PARITY_DEFERRED_FEATURES.md](G16_LOLA_PARITY_DEFERRED_FEATURES.md) | Deferred LoLa parity ledger outside fastest path |

## Execution Rule

Work in order unless the user explicitly selects a later hardware lane. Do not
mark a gap PASS from synthetic fixtures. PASS requires measured evidence, a
validated report, and unchanged default audio playout latency.

Resume here: start with
[G01_MEASUREMENT_RIG_AND_REFERENCE_HARDWARE.md](G01_MEASUREMENT_RIG_AND_REFERENCE_HARDWARE.md),
then continue in numeric order until a blocker requires explicit human input.

VERDICT: PARTIAL
