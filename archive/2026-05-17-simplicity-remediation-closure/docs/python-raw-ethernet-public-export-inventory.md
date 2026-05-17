# Python Raw Ethernet Public Export Inventory

Date: 2026-05-17

Remediation slice: `SRP-028`

Source finding: `STC-MC-008`

## Decision

The Python raw Ethernet frame builder is an active public helper surface, not
dead code. It is not used by the normal UDP runtime path, but it is explicitly
exported from `linux_connector.lola_connector`, documented as an optional
AF_PACKET/libpcap fallback, and covered by focused codec tests.

Do not remove or privatize the exported raw packet helpers as cleanup-only work.
Any later simplification should first add an import/export regression test for
the intended public surface, then narrow only the internal helpers that are not
exported.

## Evidence Sources

- `linux_connector/lola_connector/ethernet.py` defines the raw
  Ethernet/IPv4/UDP builder and its local validation helpers.
- `linux_connector/lola_connector/__init__.py` imports and lists
  `build_ethernet_ipv4_udp_frame`, `build_ipv4_udp_packet`,
  `internet_checksum`, and `parse_mac` in `__all__`.
- `linux_connector/tests/test_codec.py` imports the module directly and covers
  packet layout, Ethernet header layout, MAC parsing, port validation, IP
  validation, and the IPv4/UDP maximum payload boundary.
- `linux_connector/docs/architecture.md` lists `lola_connector/ethernet.py` as
  optional raw Ethernet/IPv4/UDP frame construction.
- `linux_connector/docs/roadmap.md` keeps AF_PACKET/libpcap TX as an advanced
  fallback if exact pcap-visible outer headers are required.
- Normal CLI/runtime code in `linux_connector/lola_connector/cli.py`,
  `connector.py`, and `runtime.py` does not import the raw Ethernet module.

## Public Export Classification

| Symbol | Classification | Evidence | Notes |
|---|---|---|---|
| `linux_connector.lola_connector.ethernet` | Active public module | Documented in architecture and roadmap; imported by tests | Optional frame construction module, not normal runtime transport. |
| `build_ethernet_ipv4_udp_frame` | Active public API | Exported from package `__init__`; direct test coverage | Builds complete Ethernet + IPv4 + UDP frame bytes for optional raw transmitters. |
| `build_ipv4_udp_packet` | Active public API | Exported from package `__init__`; direct test coverage | Builds IPv4 + UDP packet bytes; used by the Ethernet frame builder. |
| `internet_checksum` | Active public API by export | Exported from package `__init__`; used by `build_ipv4_udp_packet` | No standalone public import test exists; add one before changing export status. |
| `parse_mac` | Active public API | Exported from package `__init__`; direct test coverage | Accepts colon or dash separated MAC text and returns six bytes. |

## Internal Helper Classification

| Symbol | Classification | Evidence | Notes |
|---|---|---|---|
| `ipv4_bytes` | Internal helper | Only referenced inside `ethernet.py` | Safe future candidate for underscore/private naming if public import coverage is first added for retained exports. |
| `validate_udp_port` | Internal helper | Only referenced inside `ethernet.py` | Behavior is covered through `build_ipv4_udp_packet` rejection tests. |
| `validate_ipv4_udp_payload` | Internal helper | Only referenced inside `ethernet.py` | Behavior is covered through maximum-payload tests. |
| `ETHERTYPE_IPV4` | Internal constant | Only referenced inside `ethernet.py` | Public behavior is asserted through frame bytes. |
| `IP_ID` | Internal constant | Only referenced inside `ethernet.py` | Packet layout detail, not exported. |
| `IP_TTL` | Internal constant | Only referenced inside `ethernet.py` | Public behavior is asserted through packet bytes. |
| `IP_PROTO_UDP` | Internal constant | Only referenced inside `ethernet.py` | Public behavior is asserted through packet bytes. |
| `MAX_IPV4_UDP_PAYLOAD_BYTES` | Internal constant | Only referenced inside `ethernet.py` | Public behavior is asserted through payload-boundary tests. |

## Runtime Classification

| Area | Classification | Evidence | Notes |
|---|---|---|---|
| Normal UDP connector runtime | Not active runtime use | CLI/runtime/connector imports do not reference `ethernet.py` | Current runtime sends normal UDP payloads through sockets. |
| Optional AF_PACKET/libpcap fallback | Active documented future/advanced contract | Roadmap names `lola_connector/ethernet.py` for exact outer-header fallback | This is enough to avoid deletion, but not proof of an implemented raw socket path. |
| Raw socket send/receive API | Unused/not implemented | No `RawEthernet`, `open_raw_socket`, `send_raw_frame`, or `receive_raw_frame` surface exists | Do not document a runtime raw socket path until one is implemented and tested. |

## Docs-Only Boundary

`docs/mac-port/sota-open-question-matrix.md` notes that custom Ethernet on macOS
requires entitlement and is not the default. That is a macOS architecture
constraint, not evidence that the Python helper is unused.

## Unused Or Stale Surface

No exported raw Ethernet helper was classified as unused.

The only simplification candidates found are internal names inside
`ethernet.py`. Renaming or underscoring them is optional and should not happen
inside this investigation slice because it does not improve runtime behavior.

## Follow-Up Guardrails

Before any implementation slice removes, renames, or stops exporting raw
Ethernet helpers:

- Add a package-boundary test importing the retained public names from
  `linux_connector.lola_connector`, not only from
  `linux_connector.lola_connector.ethernet`.
- Keep direct layout tests for Ethernet destination/source MACs, EtherType,
  IPv4 TTL/protocol, UDP ports, payload bytes, and maximum payload rejection.
- If the AF_PACKET/libpcap fallback is abandoned, update the roadmap and
  architecture docs in the same slice so docs no longer advertise the module as
  an advanced fallback.
- Do not add a raw socket runtime claim without a real send/receive API and
  tests that exercise it.

## Verification

Run before marking this investigation complete:

```bash
rg -n "ethernet|RawEthernet|lola_connector\\.ethernet|from linux_connector\\.lola_connector import" linux_connector docs scripts Tests Sources
PYTHONDONTWRITEBYTECODE=1 python -m pytest -p no:cacheprovider linux_connector
ruff check linux_connector scripts/verify_docs scripts/lib/*.py
```
