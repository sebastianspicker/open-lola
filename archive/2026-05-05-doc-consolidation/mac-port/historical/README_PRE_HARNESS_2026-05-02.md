# Mac Port Documentation

This directory breaks the Mac port into resumable milestone documents. The root
entry point remains [../MAC_PORT_PLAN.md](../MAC_PORT_PLAN.md).

## Document Map

| Document | Purpose |
|---|---|
| [EVIDENCE_AND_CONFLICTS.md](EVIDENCE_AND_CONFLICTS.md) | Evidence labels, architectural decisions, and conflict resolutions. |
| [MILESTONE_INDEX.md](MILESTONE_INDEX.md) | One-line index for M00-M15. |
| [PROGRESS.md](PROGRESS.md) | Current implementation status and milestone completion rules. |
| [RISK_REGISTER.md](RISK_REGISTER.md) | Default risk register for the Mac port. |
| [OPEN_QUESTIONS.md](OPEN_QUESTIONS.md) | Questions that require measurement, hardware access, standards access, or user decisions. |
| [VALIDATION_CHECKLIST.md](VALIDATION_CHECKLIST.md) | Documentation and future source verification gates. |
| [milestones/](milestones/) | Resumable milestone docs with fixed section contracts. |
| [historical/](historical/) | Preserved earlier planning material. |

## Canonical Inputs

- [../research/RESEARCH_COMPANION_2026.md](../research/RESEARCH_COMPANION_2026.md)
- [../research/RESEARCH_AUDIO_ENGINE_2026.md](../research/RESEARCH_AUDIO_ENGINE_2026.md)
- [../research/RESEARCH_NETWORK_TIMING_2026.md](../research/RESEARCH_NETWORK_TIMING_2026.md)
- [../research/RESEARCH_VIDEO_PIPELINE_2026.md](../research/RESEARCH_VIDEO_PIPELINE_2026.md)
- [../research/RESEARCH_LIGHTING_SHOW_CONTROL_2026.md](../research/RESEARCH_LIGHTING_SHOW_CONTROL_2026.md)
- [../research/RESEARCH_BENCHMARK_ROADMAP_2026.md](../research/RESEARCH_BENCHMARK_ROADMAP_2026.md)
- [../reverse-engineering/REVERSE_ENGINEERING_COMPANION_2026.md](../reverse-engineering/REVERSE_ENGINEERING_COMPANION_2026.md)
- [../reverse-engineering/REVERSE_ENGINEERING_EVIDENCE_MATRIX_2026.md](../reverse-engineering/REVERSE_ENGINEERING_EVIDENCE_MATRIX_2026.md)

## Operating Rule

Audio is the latency gate. UI, recording, video, lighting, QoS, PLC, codecs,
and retransmission are accepted only when they preserve default audio playout
latency.

Resume here: open [MILESTONE_INDEX.md](MILESTONE_INDEX.md), then start the first
milestone whose status is not complete in [PROGRESS.md](PROGRESS.md).
