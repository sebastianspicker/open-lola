// Shared Reserved local UDP ports helpers keep multi-file test scenarios deterministic.
import Foundation

func freeLocalUdpPorts(count: Int) throws -> [UInt16] {
    try reservedLocalUdpPorts(count: count).closing().ports
}

final class ReservedLocalUdpPorts: @unchecked Sendable {
    let ports: [UInt16]
    private let lock = NSLock()
    private var descriptors: [Int32]

    init(ports: [UInt16], descriptors: [Int32]) {
        self.ports = ports
        self.descriptors = descriptors
    }

    deinit {
        close()
    }

    subscript(index: Int) -> UInt16 {
        ports[index]
    }

    func closing() -> ReservedLocalUdpPorts {
        close()
        return self
    }

    func close() {
        lock.lock()
        let descriptors = self.descriptors
        self.descriptors = []
        lock.unlock()
        for descriptor in descriptors {
            Darwin.close(descriptor)
        }
    }
}

func reservedLocalUdpPorts(count: Int) throws -> ReservedLocalUdpPorts {
    var ports: [UInt16] = []
    var descriptors: [Int32] = []
    do {
        while ports.count < count {
            let reservation = try reserveLocalUdpPort()
            if ports.contains(reservation.port) {
                Darwin.close(reservation.descriptor)
            } else {
                ports.append(reservation.port)
                descriptors.append(reservation.descriptor)
            }
        }
        return ReservedLocalUdpPorts(ports: ports, descriptors: descriptors)
    } catch {
        for descriptor in descriptors {
            Darwin.close(descriptor)
        }
        throw error
    }
}

private func reserveLocalUdpPort() throws -> (port: UInt16, descriptor: Int32) {
    let descriptor = Darwin.socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
    guard descriptor >= 0 else {
        throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
    }

    var address = sockaddr_in()
    address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
    address.sin_family = sa_family_t(AF_INET)
    address.sin_port = 0
    address.sin_addr = in_addr(s_addr: inet_addr("127.0.0.1"))
    let bindResult = withUnsafePointer(to: &address) { pointer in
        pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { rebound in
            Darwin.bind(descriptor, rebound, socklen_t(MemoryLayout<sockaddr_in>.size))
        }
    }
    guard bindResult == 0 else {
        Darwin.close(descriptor)
        throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
    }

    var bound = sockaddr_in()
    var length = socklen_t(MemoryLayout<sockaddr_in>.size)
    let nameResult = withUnsafeMutablePointer(to: &bound) { pointer in
        pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { rebound in
            Darwin.getsockname(descriptor, rebound, &length)
        }
    }
    guard nameResult == 0 else {
        Darwin.close(descriptor)
        throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
    }
    return (UInt16(bigEndian: bound.sin_port), descriptor)
}
