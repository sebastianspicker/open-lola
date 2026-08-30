# Risk register

Open LoLa is an experimental source alpha. These risks remain open until the
listed evidence exists for the exact build and environment under review.

| Risk | Mitigation in the repository | Evidence still required |
|---|---|---|
| Small Core Audio buffers may be unstable or unsupported on target devices. | Device inventory, explicit buffer modes, fallback reporting, and bounded callback work. | Measured accepted and rejected modes for each supported interface, sample rate, and channel count. |
| Audio callback work may allocate, block, log, or perform unbounded I/O. | Realtime ownership boundaries, preallocated handoff paths, and callback timing reports. | Runtime tracing and sustained stress on supported hardware. |
| High-rate UDP traffic may cause scheduling instability, loss, or excessive jitter. | Bounded packet sizes, queue limits, admission controls, and packet-age/drop accounting. | Direct, campus, and NAT route measurements under competing traffic. |
| Drift correction or packet-loss concealment may add artifacts or latency. | Fixed-target buffer policy and explicit PLC/drift report fields. | Long-running measured comparisons using representative musical material. |
| DSCP, PTP, AVB, AES67, RAVENNA, Dante, and TSN behavior depends on the network and endpoints. | Reports record standards profiles, clock state, QoS observations, and route classification. | Measurements on the actual switches, endpoints, profiles, and traffic conditions being claimed. |
| Video, control, lighting, or recording load may interfere with the audio path. | Bounded side lanes, drop-before-audio policies, and separate timing/accounting reports. | Integrated stress showing that auxiliary work degrades or stops before the audio target changes. |
| Lighting broadcast or multicast may affect media traffic or unintended devices. | Explicit arming, universe allowlists, isolation policy, and packet-capture requirements. | Controlled OLA or QLC+ tests on an isolated network. |
| Compatibility inputs may be mistaken for authenticated peer identity. | Endpoints and process identity are recorded as observations; parsers and admission are bounded. | An approved authenticated-peer and replay-protection design, or an enforceable isolated-network policy. |
| Signing, permissions, notarization, Gatekeeper, or clean-machine behavior may block distribution. | Packaging and field-test reports model required identities, entitlements, prompts, and checks. | A signed and notarized build tested on a clean supported Mac. |
| Third-party codecs, protocol fixtures, and compatibility documentation may not be publishable as assembled. | Vendor fences, notices, candidate export, clean-room rules, and release-hygiene checks. | Exact-tree provenance, legal review, independent clean-room review, and explicit maintainer approval. |

Local source or synthetic checks do not close physical, interoperability,
security, signing, legal, or release risks.
