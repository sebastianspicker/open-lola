// Defines versioned keepalive and relay-registration magic strings so every NAT participant identifies control datagrams identically.
import Foundation

enum NatProtocolMagic {
    static let keepalive = "open-lola-nat-keepalive-v1"
    static let relayRegistration = "open-lola-nat-relay-register-v1"
}
