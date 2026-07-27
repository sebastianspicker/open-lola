// Verifies that LoLa transmit binds configured control port for remote peers.
import Darwin
import Foundation
import Testing

@testable import OpenLolaCore

@Test
func lolaTransmitBindsConfiguredControlPortForRemotePeers() throws {
    let configuration = ExternalConnectorSessionConfiguration(.init(
  connector: .lola,
  role: .tx,
  peer: "198.51.100.20",
  outputPath: "/tmp/lola-remote-tx.json"
) { input in
  input.localHost = "0.0.0.0"
  input.dryRun = false
  input.controlPort = 7000
})

    #expect(shouldBindLoLaTransmitControlPort(configuration))
}

@Test
func lolaTransmitUsesEphemeralSourceForSameHostLoopbackTests() throws {
    let explicitLoopback = ExternalConnectorSessionConfiguration(.init(
  connector: .lola,
  role: .tx,
  peer: "127.0.0.1",
  outputPath: "/tmp/lola-loopback-tx.json"
) { input in
  input.localHost = "127.0.0.1"
  input.dryRun = false
})
    let wildcardLoopback = ExternalConnectorSessionConfiguration(.init(
  connector: .lola,
  role: .tx,
  peer: "127.0.0.1",
  outputPath: "/tmp/lola-loopback-wildcard-tx.json"
) { input in
  input.localHost = "0.0.0.0"
  input.dryRun = false
})

    #expect(!shouldBindLoLaTransmitControlPort(explicitLoopback))
    #expect(!shouldBindLoLaTransmitControlPort(wildcardLoopback))
}

@Test
func lolaTransmitUsesEphemeralSourceForSameHostNonLoopbackTests() throws {
    let sameHost = ExternalConnectorSessionConfiguration(.init(
  connector: .lola,
  role: .txRx,
  peer: "192.0.2.175",
  outputPath: "/tmp/lola-same-host-tx-rx.json"
) { input in
  input.localHost = "192.0.2.175"
  input.dryRun = false
})

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
    let configuration = ExternalConnectorSessionConfiguration(.init(
  connector: .lola,
  role: .tx,
  peer: "198.51.100.20",
  outputPath: "/tmp/lola-nat-tx.json"
) { input in
  input.localHost = "198.51.100.10"
  input.dryRun = false
  input.controlPort = controlPort
})

    try bindLoLaTransmitControlPort(socket: descriptor, configuration: configuration)
    let bound = try boundLoLaControlSocketTestUdpAddress(socket: descriptor)

    #expect(bound.port == controlPort)
    #expect(bound.host == "0.0.0.0")
}

@Test
func lolaTransmitControlBindErrnoKeepsSuccessAndFailureDistinct() throws {
    let descriptor = Darwin.socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
    guard descriptor >= 0 else {
        throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
    }
    defer { Darwin.close(descriptor) }

    errno = EBUSY
    #expect(try externalConnectorUdpBindErrno(socket: descriptor, host: "127.0.0.1", port: 0) == 0)

    errno = 0
    #expect(try externalConnectorUdpBindErrno(socket: -1, host: "127.0.0.1", port: 0) == EBADF)
}

@Test
func lolaWildcardLocalHostAdvertisesOutboundLoopbackAddress() throws {
    let controlPort = try freeLoLaControlSocketTestUdpPort()
    let configuration = ExternalConnectorSessionConfiguration(.init(
  connector: .lola,
  role: .tx,
  peer: "127.0.0.1",
  outputPath: "/tmp/lola-loopback-advertised-source.json"
) { input in
  input.localHost = "0.0.0.0"
  input.dryRun = false
  input.controlPort = controlPort
})

    #expect(try lolaControlAdvertisedSourceIP(configuration) == "127.0.0.1")
}

private func freeLoLaControlSocketTestUdpPort() throws -> UInt16 {
    try freeLoLaTestPort(.udp)
}

private func boundLoLaControlSocketTestUdpAddress(socket: Int32) throws -> (host: String, port: UInt16) {
    try boundLoLaTestSocketAddress(socket: socket)
}
