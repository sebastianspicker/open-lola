# Transport Error Handling

Transport code uses these conventions for UDP, NAT, RTP, and direct peer paths:

- Configuration, socket setup, protocol validation, and malformed packet handling throw typed errors.
- Nonblocking receive helpers may return `nil` only when no packet is currently available.
- Socket, decode, validation, and background task failures must propagate to the caller.
- Debug logging can add context, but it must not replace thrown errors.
- Partial reports represent missing external evidence or environmental limitations, not swallowed runtime failures.
