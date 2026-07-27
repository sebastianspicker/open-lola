// Coordinates DirectPeerCaptureReadinessSignal signaling, separating readiness notifications from real-time payload ownership.
import Darwin

final class DirectPeerCaptureReadinessSignal: @unchecked Sendable {
    let readDescriptor: Int32
    private let writeDescriptor: Int32

    init?() {
        var descriptors: [Int32] = [-1, -1]
        guard pipe(&descriptors) == 0 else {
            return nil
        }
        guard Self.makeNonBlocking(descriptors[0]), Self.makeNonBlocking(descriptors[1]) else {
            close(descriptors[0])
            close(descriptors[1])
            return nil
        }
        readDescriptor = descriptors[0]
        writeDescriptor = descriptors[1]
    }

    deinit {
        close(readDescriptor)
        close(writeDescriptor)
    }

    func signal() {
        var byte: UInt8 = 1
        let result = Darwin.write(writeDescriptor, &byte, 1)
        if result < 0, errno != EAGAIN, errno != EWOULDBLOCK {
            return
        }
    }

    func drain() {
        var buffer = (UInt64(0), UInt64(0), UInt64(0), UInt64(0))
        withUnsafeMutableBytes(of: &buffer) { bytes in
            while Darwin.read(readDescriptor, bytes.baseAddress, bytes.count) > 0 {}
        }
    }

    private static func makeNonBlocking(_ descriptor: Int32) -> Bool {
        let flags = fcntl(descriptor, F_GETFL)
        return flags >= 0 && fcntl(descriptor, F_SETFL, flags | O_NONBLOCK) == 0
    }
}
