import Darwin
import Foundation
import Testing

@testable import OpenLolaCore

@Test
func lolaUdpMediaSocketReceiverBindsBeforeTransmitWindow() throws {
    let ports = try freeLocalUdpPorts(count: 2)
    let receiver = LoLaSocketUdpMediaReceiver(timeoutSeconds: 1)
    var transmittedAfterBind = false

    let datagrams = try receiver.receive(
        maxDatagrams: 1,
        localHost: "127.0.0.1",
        peer: "127.0.0.1",
        audioPort: ports[0],
        videoPort: ports[1]
    ) {
        transmittedAfterBind = true
        try sendLoLaUdpMediaTestPayload(port: ports[0], payload: Data([0x01, 0x02, 0x03]))
    }

    #expect(transmittedAfterBind)
    #expect(datagrams == [
        LoLaUdpMediaDatagram(
            stream: .audio,
            port: ports[0],
            sourceHost: "127.0.0.1",
            payload: Data([0x01, 0x02, 0x03])
        ),
    ])
}

@Test
func fileDescriptorSetGuardRejectsOutOfRangeDescriptors() {
    #expect(openLolaFileDescriptorFitsFDSet(Int32(FD_SETSIZE - 1)))
    #expect(!openLolaFileDescriptorFitsFDSet(Int32(FD_SETSIZE)))
    #expect(throws: ExternalConnectorSessionError.self) {
        try openLolaRequireFileDescriptorFitsFDSet(Int32(FD_SETSIZE), context: "test")
    }
    var set = fd_set()
    #expect(throws: ExternalConnectorSessionError.self) {
        try openLolaFDSet(Int32(FD_SETSIZE), set: &set)
    }
    #expect(throws: ExternalConnectorSessionError.self) {
        _ = try openLolaFDIsSet(Int32(FD_SETSIZE), set: &set)
    }
}

@Test
func lolaUdpMediaSocketClosesDescriptorOnBindFallbackFailure() throws {
    let source = try readLoLaUdpMediaSocketSource()

    #expect(source.contains("var shouldClose = true"))
    #expect(source.contains("if shouldClose"))
    #expect(source.contains("close(descriptor)"))
    #expect(source.contains("shouldClose = false"))
    #expect(source.contains("bindLoLaUdpMediaSocket(descriptor, host: \"0.0.0.0\", port: port)"))
}

private func sendLoLaUdpMediaTestPayload(port: UInt16, payload: Data) throws {
    let descriptor = Darwin.socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
    guard descriptor >= 0 else {
        throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
    }
    defer { Darwin.close(descriptor) }

    var address = sockaddr_in()
    address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
    address.sin_family = sa_family_t(AF_INET)
    address.sin_port = port.bigEndian
    address.sin_addr = in_addr(s_addr: inet_addr("127.0.0.1"))
    try payload.withUnsafeBytes { rawBuffer in
        guard let baseAddress = rawBuffer.baseAddress else {
            throw NSError(domain: NSPOSIXErrorDomain, code: Int(EINVAL))
        }
        let sent = withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { socketAddress in
                Darwin.sendto(
                    descriptor,
                    baseAddress,
                    rawBuffer.count,
                    0,
                    socketAddress,
                    socklen_t(MemoryLayout<sockaddr_in>.size)
                )
            }
        }
        guard sent == rawBuffer.count else {
            throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
        }
    }
}

private func readLoLaUdpMediaSocketSource() throws -> String {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    return try String(
        contentsOf: root.appendingPathComponent(
            "Sources/OpenLolaCore/Connectors/LoLa/LoLaCompatibilityUdpMediaSocket.swift"
        ),
        encoding: .utf8
    )
}
