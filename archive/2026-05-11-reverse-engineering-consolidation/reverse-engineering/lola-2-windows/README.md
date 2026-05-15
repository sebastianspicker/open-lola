# LoLa 2.0 Windows Legacy Compatibility RE Harness

Date: 2026-05-03  
Status: Mac-only reverse-engineering roadmap  
Verdict: PARTIAL
Verdict target: `PARTIAL`

## Scope

This harness records the deepest defensible Windows LoLa 2.0 compatibility
reconstruction that can be done on this Mac from static and offline evidence.
It does not require, assume, or replace a Windows host, live Windows execution,
ASIO runtime behavior, XIMEA/PtGrey camera runtime behavior, WinPcap driver
timing, or packet capture from a real Windows LoLa peer.

Primary corpus:

- `../../archive/2026-05-11-win-compiled/win-compiled/2-0`

Comparison corpus:

- `../../archive/2026-05-11-win-compiled/win-compiled/1-5`

Existing canonical reverse-engineering set:

- [../README.md](../README.md)
- [../REVERSE_ENGINEERING_COMPANION_2026.md](../REVERSE_ENGINEERING_COMPANION_2026.md)
- [../REVERSE_ENGINEERING_EVIDENCE_MATRIX_2026.md](../REVERSE_ENGINEERING_EVIDENCE_MATRIX_2026.md)
- [../REVERSE_ENGINEERING_LOLA_E2E_WORKFLOW_2026.md](../REVERSE_ENGINEERING_LOLA_E2E_WORKFLOW_2026.md)

## Reading Order

1. [static-analysis.md](static-analysis.md) for artifact inventory, PE
   metadata, dependency ownership, static tools, call-graph clusters, and codec
   evidence.
2. [runtime-analysis.md](runtime-analysis.md) for Mac-only runtime limitations
   and the runtime-equivalent reconstruction from static evidence.
3. [validation-checklist.md](validation-checklist.md) for Mac-confirmable
   checks versus future Windows/hardware validation.
4. [legacy-compatibility-roadmap.md](legacy-compatibility-roadmap.md) for the
   milestone-driven compatibility architecture and implementation fences.

## Evidence Boundary

Static facts come from inventory, hashes, PE metadata, imports, exports,
strings, resources, existing Ghidra/radare2 notes, and current `rabin2`/`r2`
probes. Inferences are labeled. Any claim that needs real device timing, real
packet bytes, ASIO buffers, WinPcap driver behavior, XIMEA/PtGrey runtime
behavior, 48 kHz interop, packet loss, reconnect behavior, or a Windows peer is
kept as future validation.

No licensing or authentication bypass, credential extraction, exploit code,
binary patching, or activation reconstruction is in scope.
