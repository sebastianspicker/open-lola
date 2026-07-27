// Implements UdpPcmLoopbackSocketDatagrams socket I/O and resource lifetime, isolating Darwin calls from protocol decisions.
import Darwin
import Dispatch
import Foundation

func connectedEchoTimeoutMicroseconds(packetIntervalNanoseconds: UInt64) -> UInt64 {
    max((packetIntervalNanoseconds / 1_000) * 3, 50_000)
}

func isFatalConnectedUdpReceiveError(_ error: Int32) -> Bool {
    error == ECONNREFUSED || error == EHOSTUNREACH || error == ENETUNREACH
}

struct ReceivedDatagram {
    let data: Data
    let address: sockaddr_in
}

func receiveDatagramFromIfAvailable(
    socket: Int32,
    byteCount: Int
) throws -> ReceivedDatagram? {
    var buffer = [UInt8](repeating: 0, count: byteCount)
    var address = sockaddr_in()
    var addressLength = socklen_t(MemoryLayout<sockaddr_in>.size)
    let (received, savedErrno) = receiveUdpDatagramFrom(
        UdpDatagramReceiveRequest(socket: socket, byteCount: byteCount, flags: 0),
        buffer: &buffer,
        address: &address,
        addressLength: &addressLength
    )
    if received < 0 {
        if savedErrno == EAGAIN || savedErrno == EWOULDBLOCK {
            return nil
        }
        throw UdpPcmRouteProbeError.receiveFailed(savedErrno)
    }
    guard addressLength == socklen_t(MemoryLayout<sockaddr_in>.size) else {
        throw UdpPcmRouteProbeError.receiveFailed(EINVAL)
    }
    return ReceivedDatagram(data: Data(buffer.prefix(received)), address: address)
}

func sendDatagram(_ data: Data, socket: Int32, address: sockaddr_in) throws {
    let (sent, savedErrno) = sendUdpDatagram(data, socket: socket, destination: address)
    if sent < 0 {
        throw UdpPcmRouteProbeError.sendFailed(savedErrno)
    }
    if sent != data.count {
        throw UdpPcmRouteProbeError.shortSend(expected: data.count, actual: sent)
    }
}
