import Darwin
import Foundation

@testable import OpenLolaCore

func freeLoopbackUdpPort() throws -> UInt16 {
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

    var bound = sockaddr_in()
    var length = socklen_t(MemoryLayout<sockaddr_in>.size)
    let nameResult = withUnsafeMutablePointer(to: &bound) { pointer in
        pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { socketAddress in
            Darwin.getsockname(descriptor, socketAddress, &length)
        }
    }
    guard nameResult == 0 else {
        throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
    }

    return UInt16(bigEndian: bound.sin_port)
}

func runExternalConnectorSessionInBackground(
    _ configuration: ExternalConnectorSessionConfiguration,
    onLoLaControlReady: (@Sendable () -> Void)? = nil
) -> @Sendable () throws -> ExternalConnectorSessionReport {
    let semaphore = DispatchSemaphore(value: 0)
    let box = ExternalConnectorSessionResultBox()
    DispatchQueue.global(qos: .userInitiated).async {
        box.store(Result {
            try ExternalConnectorSessionRunner.run(
                configuration: configuration,
                processRunner: RealExternalConnectorProcessRunner(),
                loLaControlReady: onLoLaControlReady
            )
        })
        semaphore.signal()
    }
    return {
        semaphore.wait()
        return try box.load()
    }
}

private final class ExternalConnectorSessionResultBox: @unchecked Sendable {
    private let lock = NSLock()
    private var result: Result<ExternalConnectorSessionReport, Error>?

    func store(_ result: Result<ExternalConnectorSessionReport, Error>) {
        lock.lock()
        self.result = result
        lock.unlock()
    }

    func load() throws -> ExternalConnectorSessionReport {
        lock.lock()
        let result = self.result
        lock.unlock()
        switch result {
        case let .success(report):
            return report
        case let .failure(error):
            throw error
        case nil:
            throw ExternalConnectorSessionError.emptyField("backgroundSessionResult")
        }
    }
}
