# open-lola Product Goal

Date: 2026-05-05
Status: active product contract
Verdict: PARTIAL

Build open-lola into a clean-room, open-source, ultra-low-latency peer-to-peer AV system for professional remote music, performance, teaching, and rehearsal workflows.

The long-term goal is not to copy LoLa, but to learn from the general engineering problem it solves and build an independent, legally clean, modern implementation optimized for current hardware.

Primary product goal:
Enable two or more professional endpoints to exchange high-quality multichannel audio and low-latency video over a direct peer-to-peer connection with the lowest practical end-to-end latency.

Priority order:
1. Lowest possible stable audio latency.
2. Full-duplex multichannel audio over professional hardware such as RME MADI.
3. Robust direct P2P end-to-end session setup.
4. Low-latency Blackmagic / ATEM / DeckLink / UltraStudio video workflows.
5. Multiple video perspectives or streams.
6. Optional lighting/control integration.
7. Documentation, benchmarks, observability, and release hardening.

Core principles:
- Audio latency is the highest priority.
- The fastest profile must remain simple, direct, and minimally buffered.
- Video must never block or destabilize the audio-critical path.
- Lighting/control must be secondary and non-blocking.
- Every buffer, copy, conversion, and thread hop must be visible in the latency budget.
- Every major design choice must be benchmarked or explicitly marked as unvalidated.
- Prefer small, testable, reviewable milestones over large rewrites.

Clean-room and compliance principles:
- Do not copy proprietary LoLa code, binary logic, packet formats, symbols, internal names, or decompiled implementation details.
- Convert any research finding into an independent engineering requirement before implementation.
- Use public APIs, public SDKs, standards, original protocol design, original tests, and own measurements.
- Keep internal reverse-engineering notes separate from public implementation and documentation.
- Public documentation must be sanitized, architecture-level, and licensing-safe.
- Do not implement DRM bypass, license bypass, authentication bypass, credential extraction, binary patching, or exploit behavior.

Target architecture:
- macOS first, optimized for Apple Silicon.
- Professional audio via RME MADI or equivalent multichannel interfaces.
- Professional video via Blackmagic / ATEM / DeckLink / UltraStudio-style workflows.
- Direct peer-to-peer media path as the gold standard.
- UDP-first real-time media transport unless benchmarks prove another option is better.
- Separate control and media channels.
- Explicit stream IDs, timestamps, sequence numbers, latency profiles, and capability negotiation.
- Receiver-side audio mixing/routing so the receiver is not limited to a sender-side stereo mix.
- Optional RX buffer profiles for unstable connections.
- Direct/ultra-low-latency mode must remain available and measurable.

Definition of done for the long-term project:
open-lola is successful when it can demonstrate a documented, reproducible, low-latency end-to-end session between real machines where:

- multichannel audio TX/RX works in both directions,
- receiver-side routing/mixing works,
- direct P2P session setup works,
- audio latency is measured and documented,
- jitter, packet loss, underruns, and overruns are measured,
- RX buffer modes are configurable and benchmarked,
- Blackmagic video TX/RX works,
- multiple video streams are supported or clearly staged,
- AV timing behavior is documented,
- performance profiles are documented,
- tests and benchmarks exist for all critical paths,
- the implementation remains clean-room defensible,
- public documentation explains what open-lola does without exposing proprietary material.

Required project artifacts:
Maintain durable documentation so future Codex sessions and human maintainers can continue without chat history.

Keep these areas current:

docs/architecture/
docs/milestones/
docs/benchmarks/
docs/background/
docs/compliance/reverse-engineering-boundary.md/
docs/compliance/
docs/testing/
docs/diagrams/

Every milestone should include:
- objective,
- scope,
- affected files,
- assumptions,
- implementation plan,
- test plan,
- benchmark plan,
- acceptance criteria,
- risks,
- rollback notes,
- progress checklist,
- resume point.

Validation discipline:
No major behavior is complete unless it has:

- evidence or design rationale,
- tests or benchmark method,
- documented latency impact,
- documented failure modes,
- updated milestone progress,
- updated architecture docs if relevant.

Performance rules:
- no blocking I/O in real-time audio callbacks,
- no heap allocation in real-time audio callbacks,
- no locks in audio callbacks unless proven safe,
- no logging in audio callbacks except lock-free counters,
- no video/UI/lighting work on audio-critical threads,
- no hidden buffering,
- no unnecessary format conversions,
- no avoidable copies on hot paths,
- benchmark before and after performance-sensitive changes.

Decision rule:
When trade-offs conflict, choose in this order:

1. correctness and clean-room safety,
2. stable lowest audio latency,
3. measurable behavior,
4. maintainability,
5. video quality,
6. convenience features.

Always stop and document uncertainty instead of silently inventing behavior.