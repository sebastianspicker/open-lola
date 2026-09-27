import Foundation
import Darwin

/// Validates the SSH/SCP destination before it becomes a process argument.
public enum RemoteProcessTarget {
    public static func validate(_ target: String) throws {
        guard !target.isEmpty, target.utf8.count <= 320,
              target.unicodeScalars.allSatisfy({ $0.isASCII && $0.value > 32 && $0.value < 127 }) else {
            throw invalidTarget()
        }
        let parts = target.split(separator: "@", omittingEmptySubsequences: false)
        guard parts.count <= 2 else { throw invalidTarget() }
        if parts.count == 2 {
            let user = String(parts[0])
            guard validName(user), !user.hasPrefix("-") else { throw invalidTarget() }
        }
        let host = String(parts[parts.count - 1])
        if host.hasPrefix("["), host.hasSuffix("]") {
            let address = String(host.dropFirst().dropLast())
            var parsed = in6_addr()
            guard address.withCString({ inet_pton(AF_INET6, $0, &parsed) }) == 1 else { throw invalidTarget() }
        } else {
            guard validName(host), !host.hasPrefix("-"), !host.hasPrefix("."), !host.contains("..") else {
                throw invalidTarget()
            }
        }
    }

    private static func validName(_ value: String) -> Bool {
        !value.isEmpty && value.utf8.allSatisfy {
            (65...90).contains($0) || (97...122).contains($0) || (48...57).contains($0) || [45, 46, 95].contains($0)
        }
    }

    private static func invalidTarget() -> NSError {
        NSError(domain: "OpenLola.RemoteProcessTarget", code: 1,
                userInfo: [NSLocalizedDescriptionKey: "SSH/SCP target must be host, user@host, or a bracketed IPv6 address."])
    }
}
