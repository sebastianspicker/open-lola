# Risk Register

Date: 2026-05-21
Status: active risk register after audit archive cleanup
Verdict: PARTIAL

| ID | Risk | Status | Mitigation | Validation |
|---|---|---|---|---|
| R001 | No current source scaffold. | Closed 2026-05-02 | M00 created a minimal build/test surface. | Latest doc-refresh evidence: `swift build --product open-lola` passed outside the sandbox on 2026-05-21, and runtime/release readiness reports validated as `PARTIAL`. Full Swift suite was not rerun for the doc refresh. |
| R002 | Hardware may not support 32-frame or 16-frame operation. | Open | M02 reports device buffer-frame ranges; M03 must measure and record fallback modes. | Device/frame matrix with accepted and rejected modes. |
| R003 | Audio callback may accidentally allocate, block, lock, log, perform file I/O, or perform unbounded work. | Open | Callback safety tests and review checklist; M11 OSC cue validation keeps control timing outside the audio callback; M13 validates that SwiftUI does not own realtime paths; M14 rejects realtime callback file I/O in recording reports. | Callback p99/max and code review gate. |
| R004 | UDP packet rate may exceed scheduling stability at high sample rates. | Open | M04 defines the audio packet contract; M05 has source-level route reports and localhost smoke; M09 adds video transport accounting; M10 adds combined-load report fields. Physical audio and video routes still need measurement. | Packet age, drop, late, p99, max, and loss reports. |
| R005 | Drift correction may add artifacts or latency. | Open | M06 now validates same-deadline PLC and no target growth in source reports; real policies still need a 60-minute fixed-target run with artifact notes. | 60-minute fixed-target run with artifact notes. |
| R006 | DSCP, PTP, AVB, and TSN claims may not hold on target networks. | Open | M05 validates DSCP fields and M07 validates AoIP/PTP report gates; physical target networks still need measurement. | Honored/rewritten/ignored/harmful DSCP and profile reports. |
| R007 | Video, control, lighting, or recording work may steal CPU, GPU, disk, or network budget from audio. | Open | M08 has a Blackmagic/ATEM-first source policy, AVFoundation fallback harness, latest-frame queue, and PASS guards; M09 adds receiver accounting, degradation gates, and VideoToolbox policy gates; M10 adds integrated ownership and 30-minute PASS gates; M11 adds OSC cue audio-impact gates; M12 adds lighting audio-impact PASS gates; M14 adds opt-in raw recording artifacts, no default fake media artifacts, and side-lane/drop-on-pressure PASS guards. Real integrated stress still must prove video/control/lighting/recording load degrades, drops, or turns off before audio target changes. | Audio callback metrics under video/control/lighting/recording stress remain unchanged. |
| R008 | Lighting broadcast or multicast may harm media paths. | Open | M12 now requires explicit arm, isolated network, allowed universe list, broadcast/multicast policy, and packet capture before PASS. | One-universe QLC+/OLA probe plus packet capture. |
| R009 | Standards-controlled protocols may need full-current specs. | Open | M07 records standards/vendor profile evidence before any adapter can pass; M12 records sACN/Art-Net evidence and keeps direct lighting output gated. | Standard version, clauses, and licensing notes recorded. |
| R010 | macOS permissions, signing, or notarization may block field tests. | Open | M13 records permission-readiness fields; M15 records signing, hardened-runtime, secure-timestamp, notarization, entitlement, purpose-string, Gatekeeper, and clean-Mac PASS gates. Q010 still needs the real identity and clean-Mac target. | Signed/notarized build, Gatekeeper assessment, and clean-Mac field report. |
| R011 | SOTA source drift may invalidate a milestone gate. | Open | Refresh primary sources before implementation and update the SOTA matrix first. | [open-questions.md](open-questions.md) row updated with dated source check. |

Resume here: before closing any milestone, check whether its implementation
changes this table or the SOTA matrix and update the affected row. Do not use
archived Mac-port companions as live risk status.

VERDICT: PARTIAL
