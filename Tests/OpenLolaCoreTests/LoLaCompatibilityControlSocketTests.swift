import Darwin
import Foundation
import Testing

@testable import OpenLolaCore

@Test
func lolaTransmitBindsConfiguredControlPortForRemotePeers() throws {
    let configuration = ExternalConnectorSessionConfiguration(
        connector: .lola,
        role: .tx,
        peer: "198.51.100.20",
        localHost: "0.0.0.0",
        outputPath: "/tmp/lola-remote-tx.json",
        dryRun: false,
        controlPort: 7000
    )

    #expect(shouldBindLoLaTransmitControlPort(configuration))
}

@Test
func lolaTransmitUsesEphemeralSourceForSameHostLoopbackTests() throws {
    let explicitLoopback = ExternalConnectorSessionConfiguration(
        connector: .lola,
        role: .tx,
        peer: "127.0.0.1",
        localHost: "127.0.0.1",
        outputPath: "/tmp/lola-loopback-tx.json",
        dryRun: false
    )
    let wildcardLoopback = ExternalConnectorSessionConfiguration(
        connector: .lola,
        role: .tx,
        peer: "127.0.0.1",
        localHost: "0.0.0.0",
        outputPath: "/tmp/lola-loopback-wildcard-tx.json",
        dryRun: false
    )

    #expect(!shouldBindLoLaTransmitControlPort(explicitLoopback))
    #expect(!shouldBindLoLaTransmitControlPort(wildcardLoopback))
}

@Test
func lolaTransmitUsesEphemeralSourceForSameHostNonLoopbackTests() throws {
    let sameHost = ExternalConnectorSessionConfiguration(
        connector: .lola,
        role: .txRx,
        peer: "10.230.61.175",
        localHost: "10.230.61.175",
        outputPath: "/tmp/lola-same-host-tx-rx.json",
        dryRun: false
    )

    #expect(!shouldBindLoLaTransmitControlPort(sameHost))
}

@Test
func lolaTransmitControlBindFallsBackWhenAdvertisedSourceIPIsNotLocal() throws {
    let descriptor = Darwin.socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
    guard descriptor >= 0 else {
        throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
    }
    defer { Darwin.close(descriptor) }

    let controlPort = try freeLoLaControlSocketTestUdpPort()
    let configuration = ExternalConnectorSessionConfiguration(
        connector: .lola,
        role: .tx,
        peer: "198.51.100.20",
        localHost: "198.51.100.10",
        outputPath: "/tmp/lola-nat-tx.json",
        dryRun: false,
        controlPort: controlPort
    )

    try bindLoLaTransmitControlPort(socket: descriptor, configuration: configuration)
    let bound = try boundLoLaControlSocketTestUdpAddress(socket: descriptor)

    #expect(bound.port == controlPort)
    #expect(bound.host == "0.0.0.0")
}

@Test
func lolaTransmitControlBindErrnoKeepsSuccessAndFailureDistinct() throws {
    let source = try readLoLaCompatibilityControlSocketSource()

    #expect(source.contains("let status = withUnsafePointer(to: &address)"))
    #expect(source.contains("return status == 0 ? 0 : errno"))
    #expect(!source.contains("return errno"))
}

@Test
func lolaWildcardLocalHostAdvertisesOutboundLoopbackAddress() throws {
    let configuration = ExternalConnectorSessionConfiguration(
        connector: .lola,
        role: .tx,
        peer: "127.0.0.1",
        localHost: "0.0.0.0",
        outputPath: "/tmp/lola-loopback-advertised-source.json",
        dryRun: false,
        controlPort: try freeLoLaControlSocketTestUdpPort()
    )

    #expect(try lolaControlAdvertisedSourceIP(configuration) == "127.0.0.1")
}

private func readLoLaCompatibilityControlSocketSource() throws -> String {
    let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    let source = root.appendingPathComponent(
        "Sources/OpenLolaCore/Connectors/LoLa/LoLaCompatibilityControlSocket.swift"
    )
    return try String(contentsOf: source, encoding: .utf8)
}

private func freeLoLaControlSocketTestUdpPort() throws -> UInt16 {
    let descriptor = Darwin.socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
    guard descriptor >= 0 else {
        throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
    }
    defer { Darwin.close(descriptor) }

    var address = sockaddr_in()
    address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
    address.sin_family = sa_family_t(AF_INET)
    address.sin_port = 0
    address.sin_addr = in_addr(s_addr: inet_addr("127.0.0.1"))
    let bindResult = withUnsafePointer(to: &address) { pointer in
        pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { socketAddress in
            Darwin.bind(descriptor, socketAddress, socklen_t(MemoryLayout<sockaddr_in>.size))
        }
    }
    guard bindResult == 0 else {
        throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
    }

    return try boundLoLaControlSocketTestUdpAddress(socket: descriptor).port
}

private func boundLoLaControlSocketTestUdpAddress(socket: Int32) throws -> (host: String, port: UInt16) {
    var bound = sockaddr_in()
    var length = socklen_t(MemoryLayout<sockaddr_in>.size)
    let nameResult = withUnsafeMutablePointer(to: &bound) { pointer in
        pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { socketAddress in
            Darwin.getsockname(socket, socketAddress, &length)
        }
    }
    guard nameResult == 0 else {
        throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
    }

    var address = bound.sin_addr
    var buffer = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
    guard inet_ntop(AF_INET, &address, &buffer, socklen_t(buffer.count)) != nil else {
        throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
    }
    let endIndex = buffer.firstIndex(of: 0) ?? buffer.endIndex
    return (
        host: String(decoding: buffer[..<endIndex].map(UInt8.init), as: UTF8.self),
        port: UInt16(bigEndian: bound.sin_port)
    )
}
