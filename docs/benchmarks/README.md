# Benchmark Documentation

Date: 2026-05-04
Status: active benchmark documentation index
Verdict: PARTIAL

This folder contains publication-safe benchmark methodology. Benchmark reports
and internal implementation status are review-only release material governed by
the compliance [release manifest](../compliance/release-manifest.md).

## Document Map

| Document | Purpose |
|---|---|
| [audio-latency-methodology.md](audio-latency-methodology.md) | Required hardware, route, latency-profile, RX-buffer, and acceptance fields for audio latency evidence. |
| [e2e-av-benchmark-methodology.md](e2e-av-benchmark-methodology.md) | Required source report shape and physical two-peer evidence for integrated audio/video benchmark closure. |

## Current Rule

Synthetic smokes and built-in-device probes are source-shape evidence only.
Physical RME/direct-route evidence is required before any fastest-path,
16-frame, 8-frame, or RX-buffer profile claim can become `PASS`.
The integrated E2E benchmark follows the same rule: the source validator and
synthetic smoke can produce `PARTIAL`, but `PASS` requires measured two-peer
Apple Silicon, RME/MADI, Blackmagic, route, impairment, recovery, and shutdown
evidence.

VERDICT: PARTIAL
