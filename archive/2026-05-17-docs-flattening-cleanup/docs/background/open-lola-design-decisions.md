# Open Lola Design Decisions From LoLa-Style Research

Date: 2026-05-03  
Status: publication-safe design decision ledger  
Scope: mapping observed requirements to open-lola choices

## Evidence Boundary

This ledger translates internal observations into open-lola design choices
without publishing the underlying proprietary evidence.

This table records open-lola design choices. It does not claim byte-exact
legacy compatibility.

## Decision Table

| Area | Original observed behavior or requirement | Why it matters | open-lola adaptation | open-lola change | open-lola improvement | Rationale | Trade-offs | Validation method | Remaining risks |
|---|---|---|---|---|---|---|---|---|---|
| AV TX/RX | Audio/video are organized as direct TX/RX media paths. | Media deadlines define the usable experience. | Keep TX/RX paths narrow and deadline-aware. | Use open-lola-owned packet/report contracts. | Make TX/RX assumptions visible in fixtures and reports. | Public design can reuse architecture lessons without copying private grammar. | Exact peer compatibility remains unproven. | open-lola implementation test; fixture-based validation. | Controlled peer testing is still required. |
| Networking | Control/session work is separate from media transport. | Session work must not block media timing. | Split session agreement from media route certification. | Use documented open control reports. | Add route diagnostics and explicit verdicts. | Separating paths makes latency and failure modes measurable. | More test artifacts are required. | route certification; black-box behavior test. | Real networks can still rewrite or drop traffic. |
| Timing | Small deadlines appear central to the design. | Latency is the primary value proposition. | Make audio deadline preservation the hard rule. | Reject adaptive default jitter growth. | Record timing budgets in machine-readable reports. | A failed timing budget is more useful than a hidden buffer increase. | Lower resilience in fastest mode. | timing measurement; integrated AV proof. | Hardware may not accept the target buffer. |
| Buffering | Minimal buffering is strongly supported. | Buffer growth trades speed for smoothness. | Validate zero or one receive-block playout targets. | Require explicit non-default modes for larger buffers. | Turn buffer depth into a visible report field. | Users need to know when latency was increased. | Some lossy paths will sound worse in fastest mode. | fixture-based validation; loopback tests. | Network variance can exceed the fixed target. |
| Codec/format handling | Low-overhead audio and CPU JPEG-like or raw/near-raw video paths are supported where evidence permits. | Codec cost can steal realtime budget. | Prefer simple measured formats first. | Keep advanced codecs optional. | Tie codec choices to latency and CPU evidence. | Compatibility is less valuable than a measured deadline. | Higher bandwidth in simple modes. | benchmark report; open-lola implementation test. | Hardware encoders and peer formats remain separate gates. |
| Platform abstraction | Legacy evidence is Windows-centered. | open-lola targets native macOS behavior. | Map concepts to Core Audio and macOS networking. | Avoid Windows driver dependencies. | Make platform assumptions explicit. | Native APIs reduce hidden compatibility debt. | Some legacy device behavior is not replicated. | public API behavior; hardware inventory. | Real device parity is incomplete. |
| Testing | Internal evidence is static and offline. | Public claims need reproducible proof. | Use fixture-first validation. | Treat internal notes as withheld evidence labels. | Add clear claim labels and verdicts. | Tests make the public layer maintainable. | Some claims stay `PARTIAL`. | fixture-based validation; controlled interoperability test. | Test fixtures can miss live peer behavior. |
| Maintainability | Legacy behavior is difficult to audit publicly. | Future contributors need clear boundaries. | Keep publication docs separate from internal evidence. | Do not expose private symbols or raw recovered detail. | Document redactions and evidence labels. | A clean public surface reduces accidental leakage. | Readers see less low-level evidence. | publication safety scan; link check. | Maintainer review is still required before release. |
| Portability | Original behavior depends on specific runtime assumptions. | open-lola must work on measured modern systems. | Isolate hardware and route assumptions. | Prefer reports over implicit machine state. | Make portability gaps explicit. | Portable proof needs reproducible artifacts. | More setup work before claims are upgraded. | hardware report; route report. | Other macOS hosts may differ. |
| Observability | Legacy runtime behavior is partly opaque. | Opaque latency failures are hard to fix. | Emit reports for timing, route, and feature gates. | Add explicit risk ledgers and verdicts. | Make partial status normal until evidence exists. | Honest visibility prevents false-green compatibility claims. | More documentation to maintain. | report validation; docs verification. | Observability must stay outside realtime deadlines. |

## Decision Rule

When an open-lola choice conflicts with low latency, the default mode preserves
audio timing. More resilient or more compatible modes must be explicit,
measured, and labeled.

VERDICT: PARTIAL
