# Packet capture

Capture traffic on the selected native Linux interface or Windows Npcap adapter.
Store captures outside the checkout and sanitize them before sharing. The table
below maps a question to the filter and observation that answers it.

| Question | Capture filter | Required observation |
|---|---|---|
| Is control reachable? | `udp port 7000` | Matching status request and ACK. |
| Was media negotiated? | `udp port 7000` | QuickConn and matching ACK or rejection. |
| Is audio arriving? | `udp port 19788` | Correct endpoints, packet shape, and sequence progression. |
| Is video complete? | `udp port 19798` | A prelude and contiguous fragments for the same frame occurrence. |

For a bounded capture on Linux:

```bash
timeout 10 tcpdump -i eth0 -n -w /tmp/lola.pcap \
  'udp and (port 7000 or port 19788 or port 19798)'
cargo run -p rusty-lola --no-default-features -- decode-pcap /tmp/lola.pcap
```

On Windows, list adapters with `tshark -D`, then use the selected interface:

```powershell
& 'C:\Program Files\Wireshark\tshark.exe' -i 1 -a duration:10 `
  -f 'udp port 7000 or udp port 19788 or udp port 19798' `
  -w "$env:TEMP\lola.pcapng"
```

The offline decoder reads classic PCAP (either endianness, with microsecond or
nanosecond magic) and PCAPNG, including Ethernet/VLAN, raw IPv4, Linux cooked,
and cooked-v2 link headers. It reports endpoint and frame occurrences, preludes,
fragment counts, unique and duplicate bytes, flags, conflicts, malformed drops,
and completeness. Each new prelude starts a new occurrence, so repeated wire IDs
cannot combine partial occurrences into complete evidence. It caps input at
256 MiB, one million packets, 4096 frame occurrences, and 256 PCAPNG interfaces.

Container corruption fails the command. Malformed media inside a readable capture
is counted, and later valid traffic remains visible. Unsupported link-layer
records and non-UDP or fragmented-IP packets are ignored. The decoder does not
validate packet checksums, because transmit captures can precede NIC checksum
offload. A complete frame is a structural capture observation, not proof of
playback, physical timing, peer identity, or original LoLa behavior.

Audio UDP payloads are exactly 1066 bytes, with a 33-byte fragment header and an
eight-byte serialized-body header. For stereo 16-bit PCM with 64 frames, the PCM
payload is 256 bytes and the fragment length is 264. Senders use frame ID
`sequence + 1`, while receive freshness compares the serialized sequence
independently. Video carries a 64-byte prelude followed by normal fragments. The
packet examples in this document describe the expected shape.
