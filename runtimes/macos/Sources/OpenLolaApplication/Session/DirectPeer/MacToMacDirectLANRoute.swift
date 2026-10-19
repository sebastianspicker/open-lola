// Decides whether a peer sits directly on one of this Mac's LAN subnets so a preflight can pass without NAT traversal evidence.
import Darwin
import Foundation
import OpenLolaTransport

/// One IPv4 address of this Mac, held as host-order address and netmask values.
public struct LocalIPv4Interface: Equatable, Sendable {
    public var name: String
    public var address: UInt32
    public var netmask: UInt32
    /// False for loopback, down or not-running, and point-to-point (utun/VPN) interfaces; their address still
    /// counts as this Mac's own, but their subnet never counts as a directly connected link.
    public var isDirectLinkCandidate: Bool

    public init(name: String, address: UInt32, netmask: UInt32, isDirectLinkCandidate: Bool = true) {
        self.name = name
        self.address = address
        self.netmask = netmask
        self.isDirectLinkCandidate = isDirectLinkCandidate
    }
}

/// Records why a direct LAN route was accepted, so a PASS without NAT route evidence stays auditable.
public struct DirectLANRouteBasis: Codable, Equatable, Sendable {
    public var peerAddress: String
    public var interfaceName: String
    public var localAddress: String
    public var prefixLength: Int
    public var tracerouteBasis: String

    public init(
        peerAddress: String,
        interfaceName: String,
        localAddress: String,
        prefixLength: Int,
        tracerouteBasis: String
    ) {
        self.peerAddress = peerAddress
        self.interfaceName = interfaceName
        self.localAddress = localAddress
        self.prefixLength = prefixLength
        self.tracerouteBasis = tracerouteBasis
    }
}

/// Pure IPv4 on-link rules plus the getifaddrs reader that feeds them.
public enum DirectLANRoute {
    /// Parses a dotted-quad IPv4 literal into a host-order value; hostnames and IPv6 return nil.
    public static func parseIPv4(_ text: String) -> UInt32? {
        var address = in_addr()
        guard inet_pton(AF_INET, text, &address) == 1 else {
            return nil
        }
        return UInt32(bigEndian: address.s_addr)
    }

    /// Renders a host-order IPv4 value as a dotted quad.
    public static func format(_ address: UInt32) -> String {
        (0..<4).map { String((address >> UInt32(24 - 8 * $0)) & 0xFF) }.joined(separator: ".")
    }

    /// True when `peer` is a different, non-loopback host inside the subnet of `address`/`netmask`.
    ///
    /// A /32 (or /0) netmask never describes a shared link, so it never matches.
    public static func isOnLinkSubnet(peer: UInt32, address: UInt32, netmask: UInt32) -> Bool {
        guard (peer >> 24) != 127, peer != address, netmask != UInt32.max, netmask != 0 else {
            return false
        }
        return (peer & netmask) == (address & netmask)
    }

    /// True when `peer` is any address of this Mac, on any interface, or a loopback address.
    public static func isLocalAddress(_ peer: UInt32, in interfaces: [LocalIPv4Interface]) -> Bool {
        (peer >> 24) == 127 || interfaces.contains { $0.address == peer }
    }

    /// Returns the first direct-link candidate whose subnet contains `peer`; nil when `peer` is this Mac itself.
    public static func onLinkInterface(
        for peer: UInt32,
        in interfaces: [LocalIPv4Interface]
    ) -> LocalIPv4Interface? {
        guard !isLocalAddress(peer, in: interfaces) else {
            return nil
        }
        return interfaces.first {
            $0.isDirectLinkCandidate && isOnLinkSubnet(peer: peer, address: $0.address, netmask: $0.netmask)
        }
    }

    /// Number of leading one bits in a contiguous netmask.
    public static func prefixLength(of netmask: UInt32) -> Int {
        netmask.nonzeroBitCount
    }

    /// True for interface flags that can describe a directly connected link: up and running, not loopback,
    /// and not point-to-point, so utun/VPN tunnels never count as a shared LAN.
    public static func isDirectLinkCandidate(flags: Int32) -> Bool {
        flags & IFF_UP != 0 && flags & IFF_RUNNING != 0
            && flags & IFF_LOOPBACK == 0 && flags & IFF_POINTOPOINT == 0
    }

    /// Reads every IPv4 address of this Mac with getifaddrs, marking which ones may count as a direct link.
    public static func localInterfaces() -> [LocalIPv4Interface] {
        var head: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&head) == 0, let first = head else {
            return []
        }
        defer { freeifaddrs(head) }
        var interfaces: [LocalIPv4Interface] = []
        var cursor: UnsafeMutablePointer<ifaddrs>? = first
        while let entry = cursor {
            if let interface = interface(from: entry.pointee) {
                interfaces.append(interface)
            }
            cursor = entry.pointee.ifa_next
        }
        return interfaces
    }

    private static func interface(from entry: ifaddrs) -> LocalIPv4Interface? {
        guard let addr = entry.ifa_addr, let mask = entry.ifa_netmask,
              addr.pointee.sa_family == sa_family_t(AF_INET) else {
            return nil
        }
        let address = addr.withMemoryRebound(to: sockaddr_in.self, capacity: 1) {
            UInt32(bigEndian: $0.pointee.sin_addr.s_addr)
        }
        let netmask = mask.withMemoryRebound(to: sockaddr_in.self, capacity: 1) {
            UInt32(bigEndian: $0.pointee.sin_addr.s_addr)
        }
        return LocalIPv4Interface(
            name: String(cString: entry.ifa_name),
            address: address,
            netmask: netmask,
            isDirectLinkCandidate: isDirectLinkCandidate(flags: Int32(bitPattern: entry.ifa_flags))
        )
    }
}

/// Outcome of the direct-LAN rule: a basis when every condition held, otherwise the blockers that failed.
struct DirectLANRouteEvaluation: Equatable {
    var basis: DirectLANRouteBasis?
    var blockers: [String]
}

extension DirectLANRoute {
    /// Applies the LAN rule: (a) peer is another host's on-link IPv4 address, (b) ping had 0% loss, (c) traceroute
    /// shows one hop, or was unavailable on a /24 or narrower subnet.
    static func evaluate(
        peer: String,
        diagnostics: NetworkDiagnosticsReport,
        interfaces: [LocalIPv4Interface]
    ) -> DirectLANRouteEvaluation {
        guard let peerAddress = parseIPv4(peer) else {
            return DirectLANRouteEvaluation(
                basis: nil,
                blockers: ["peer \(peer) is not an IPv4 address; a direct LAN route needs one"]
            )
        }
        if isLocalAddress(peerAddress, in: interfaces) {
            return DirectLANRouteEvaluation(
                basis: nil,
                blockers: ["peer \(peer) is an address of this Mac, not a second machine"]
            )
        }
        guard let interface = onLinkInterface(for: peerAddress, in: interfaces) else {
            return DirectLANRouteEvaluation(
                basis: nil,
                blockers: ["peer \(peer) is not on a subnet directly connected to this Mac"]
            )
        }
        var blockers: [String] = []
        let pingSucceeded = diagnostics.ping.map { $0.received > 0 && $0.packetLossPercent == 0 } ?? false
        if !pingSucceeded {
            blockers.append("direct LAN route needs a ping with 0% loss")
        }
        let prefix = prefixLength(of: interface.netmask)
        let traceroute = tracerouteDecision(peer: peer, diagnostics: diagnostics, prefixLength: prefix)
        guard case .accepted(let tracerouteBasis) = traceroute else {
            if case .blocked(let blocker) = traceroute {
                blockers.append(blocker)
            }
            return DirectLANRouteEvaluation(basis: nil, blockers: blockers)
        }
        guard blockers.isEmpty else {
            return DirectLANRouteEvaluation(basis: nil, blockers: blockers)
        }
        let basis = DirectLANRouteBasis(
            peerAddress: peer,
            interfaceName: interface.name,
            localAddress: format(interface.address),
            prefixLength: prefix,
            tracerouteBasis: tracerouteBasis
        )
        return DirectLANRouteEvaluation(basis: basis, blockers: [])
    }

    /// Widest subnet (smallest prefix) on which an unavailable traceroute is still accepted as a direct route.
    static let minimumPrefixLengthWithoutTraceroute = 24

    /// Whether the traceroute evidence supports a direct route to `peer` on a subnet of `prefixLength` bits.
    ///
    /// A one-hop trace is accepted on any subnet. A blocked or failed traceroute is accepted only on a /24 or
    /// narrower subnet: a wide subnet can hide routers, so without traceroute it cannot prove a direct route.
    /// Report validation recomputes this decision, so a recorded basis must match the recorded diagnostics.
    static func tracerouteDecision(
        peer: String,
        diagnostics: NetworkDiagnosticsReport,
        prefixLength: Int
    ) -> DirectLANTracerouteDecision {
        let traceroute = diagnostics.traceroute
        if traceroute.blocked || diagnostics.tracerouteError != nil {
            let reason = traceroute.blockedReason ?? diagnostics.tracerouteError ?? "unavailable"
            guard prefixLength >= minimumPrefixLengthWithoutTraceroute else {
                return .blocked(
                    "traceroute unavailable (\(reason)) and the /\(prefixLength) subnet is wider than "
                        + "/\(minimumPrefixLengthWithoutTraceroute); a wide subnet cannot prove a direct route "
                        + "without traceroute"
                )
            }
            return .accepted(
                "traceroute unavailable (\(reason)); accepted because the peer is on-link and ping succeeded"
            )
        }
        guard traceroute.hops.count == 1, traceroute.hops.first?.address == peer else {
            return .blocked(
                "traceroute did not reach \(peer) in exactly one hop (\(traceroute.hops.count) hops seen)"
            )
        }
        return .accepted("traceroute reached the peer in one hop")
    }
}

/// The traceroute part of the direct-LAN rule: the recorded basis text, or the blocker that failed.
enum DirectLANTracerouteDecision: Equatable {
    case accepted(String)
    case blocked(String)
}
