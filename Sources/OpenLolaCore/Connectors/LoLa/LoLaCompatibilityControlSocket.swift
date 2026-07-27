// Implements LoLaCompatibilityControlSocket socket I/O and resource lifetime, isolating Darwin calls from protocol decisions.
import Darwin

func shouldBindLoLaTransmitControlPort(_ configuration: ExternalConnectorSessionConfiguration) -> Bool {
    guard configuration.connector == .lola, configuration.role.transmits, !configuration.peer.isEmpty else {
        return false
    }
    if configuration.localHost != "0.0.0.0", configuration.localHost == configuration.peer {
        return false
    }
    return !isLoLaSameHostLoopback(localHost: configuration.localHost, peer: configuration.peer)
}

func bindLoLaTransmitControlPort(
    socket: Int32,
    configuration: ExternalConnectorSessionConfiguration
) throws {
    let bindErrno = try externalConnectorUdpBindErrno(
        socket: socket,
        host: configuration.localHost,
        port: configuration.controlPort
    )
    if bindErrno == 0 {
        return
    }
    guard configuration.localHost != "0.0.0.0", bindErrno == EADDRNOTAVAIL else {
        throw ExternalConnectorSessionError.socketFailed(
            "bind \(configuration.localHost):\(configuration.controlPort) errno \(bindErrno)"
        )
    }

    let wildcardErrno = try externalConnectorUdpBindErrno(
        socket: socket,
        host: "0.0.0.0",
        port: configuration.controlPort
    )
    guard wildcardErrno == 0 else {
        throw ExternalConnectorSessionError.socketFailed(
            "bind 0.0.0.0:\(configuration.controlPort) errno \(wildcardErrno)"
        )
    }
}

func externalConnectorUdpBindErrno(
    socket: Int32,
    host: String,
    port: UInt16
) throws -> Int32 {
    var address = sockaddr_in()
    address.sin_family = sa_family_t(AF_INET)
    address.sin_port = port.bigEndian
    guard inet_pton(AF_INET, host, &address.sin_addr) == 1 else {
        throw ExternalConnectorSessionError.socketFailed("inet_pton \(host)")
    }
    let status = withUnsafePointer(to: &address) { pointer in
        pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { socketAddress in
            Darwin.bind(socket, socketAddress, socklen_t(MemoryLayout<sockaddr_in>.size))
        }
    }
    return status == 0 ? 0 : errno
}

private func isLoLaSameHostLoopback(localHost: String, peer: String) -> Bool {
    guard isLoLaLoopbackHost(peer) else {
        return false
    }
    return localHost == "0.0.0.0" || isLoLaLoopbackHost(localHost)
}

private func isLoLaLoopbackHost(_ host: String) -> Bool {
    var address = in_addr()
    guard inet_pton(AF_INET, host, &address) == 1 else {
        return false
    }
    let octets = withUnsafeBytes(of: address.s_addr) { rawBuffer in
        Array(rawBuffer)
    }
    return octets.first == 127
}
