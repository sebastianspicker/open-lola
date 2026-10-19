# Packet capture

Capture on the native Linux interface or Windows Npcap adapter the station uses.
Store captures outside the checkout and sanitize them before sharing.

| Question | Capture filter | What to look for |
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

On Windows, list adapters with `tshark -D`, then capture on the one you need:

```powershell
& 'C:\Program Files\Wireshark\tshark.exe' -i 1 -a duration:10 `
  -f 'udp port 7000 or udp port 19788 or udp port 19798' `
  -w "$env:TEMP\lola.pcapng"
```

## Offline decoder

`decode-pcap` reads classic PCAP (either endianness, microsecond or nanosecond
magic) and PCAPNG. It understands Ethernet/VLAN, raw IPv4, Linux cooked, and
cooked-v2 link headers. It reports endpoints and frame occurrences, preludes,
fragment counts, unique and duplicate bytes, flags, conflicts, malformed drops,
and completeness.

Each new prelude starts a new occurrence, so fragments from different frames
that reuse a wire ID are never merged into one complete frame. Input is capped
at 256 MiB, one million packets, 4096 frame occurrences, and 256 PCAPNG
interfaces.

- A corrupt capture file fails the command.
- Malformed media inside a readable capture is counted, and later valid traffic
  is still decoded.
- Unsupported link-layer records, non-UDP packets, and fragmented IP packets are
  ignored.
- Checksums are not validated, because transmit-side captures are taken before
  NIC checksum offload fills them in.

A complete frame in a capture shows the packets were well formed. It does not
show playback, physical timing, peer identity, or original LoLa behavior.

## Packet sizes

Audio UDP payloads are exactly 1066 bytes, with a 33-byte fragment header and an
eight-byte serialized-body header. For stereo 16-bit PCM with 64 frames, the PCM
payload is 256 bytes and the fragment length is 264. Senders use frame ID
`sequence + 1`, while receive freshness compares the serialized sequence
independently. Video sends a 64-byte prelude followed by normal fragments. The
versioned [corpus](../interop/lola2/README.md) has synthetic regression
examples.
