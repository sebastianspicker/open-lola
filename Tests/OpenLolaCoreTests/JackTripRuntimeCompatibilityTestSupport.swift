// Shared JackTrip runtime compatibility helpers keep multi-file test scenarios deterministic.
import Foundation

@testable import OpenLolaCore

final class JackTripStreamingOrderProbe {
    var emittedDatagramCount = 0
    var capturedAheadOfTransmit = false
    var requiresReceiverBound = false
    var receiverBound = false
    var transmitStartedBeforeReceiverBound = false
}

final class JackTripCallCountingAudioProvider: JackTripAudioFrameProviding {
    private(set) var callCount = 0

    func interleavedInt16PCM(sequenceNumber _: Int, channels: Int, frames: Int) throws -> Data {
        callCount += 1
        return Data(repeating: 0, count: channels * frames * MemoryLayout<Int16>.size)
    }
}

final class JackTripLegacyBlockingAudioProvider: JackTripAudioFrameProviding {
    private let lock = NSLock()
    private(set) var legacyCallCount = 0

    func interleavedInt16PCM(sequenceNumber _: Int, channels _: Int, frames _: Int) throws -> Data {
        lock.lock()
        legacyCallCount += 1
        lock.unlock()
        _ = DispatchSemaphore(value: 0).wait(timeout: .now() + .seconds(1))
        return Data()
    }
}

final class TestMonotonicClockState {
    private(set) var now: UInt64

    init(now: UInt64) { self.now = now }

    func advance(toAtLeast deadline: UInt64) { now = max(now, deadline) }

    func advance(by nanoseconds: UInt64) { now += nanoseconds }
}

final class JackTripTestMonotonicClock: JackTripMonotonicClock {
    private let state: TestMonotonicClockState

    init(now: UInt64 = 0) { state = TestMonotonicClockState(now: now) }

    var now: UInt64 { state.now }

    func nowNanoseconds() -> UInt64 { state.now }

    func sleep(untilNanoseconds: UInt64) throws { state.advance(toAtLeast: untilNanoseconds) }

    func advance(by nanoseconds: UInt64) { state.advance(by: nanoseconds) }
}

final class JackTripFirstCaptureOverrunProvider: JackTripAudioFrameProviding {
    let clock: JackTripTestMonotonicClock
    let overrunNanoseconds: UInt64

    init(clock: JackTripTestMonotonicClock, overrunNanoseconds: UInt64) {
        self.clock = clock
        self.overrunNanoseconds = overrunNanoseconds
    }

    func interleavedInt16PCM(sequenceNumber: Int, channels: Int, frames: Int) throws -> Data {
        if sequenceNumber == 0 { clock.advance(by: overrunNanoseconds) }
        return Data(repeating: 0, count: channels * frames * MemoryLayout<Int16>.size)
    }
}

final class JackTripLateTransmitProbe: @unchecked Sendable {
    var didFinish = false
}

struct JackTripStreamingOrderProvider: JackTripAudioFrameProviding {
    let probe: JackTripStreamingOrderProbe

    func interleavedInt16PCM(sequenceNumber: Int, channels: Int, frames: Int) throws -> Data {
        if probe.emittedDatagramCount < sequenceNumber {
            probe.capturedAheadOfTransmit = true
        }
        return Data(repeating: 0, count: channels * frames * MemoryLayout<Int16>.size)
    }

    func interleavedInt16PCM(
        sequenceNumber: Int,
        channels: Int,
        frames: Int,
        deadlineNanoseconds: UInt64?
    ) throws -> Data {
        guard deadlineNanoseconds.map({ DispatchTime.now().uptimeNanoseconds < $0 }) ?? true else {
            throw ExternalConnectorSessionError.socketFailed(
                "JackTrip exchange deadline expired before audio capture"
            )
        }
        return try interleavedInt16PCM(
            sequenceNumber: sequenceNumber,
            channels: channels,
            frames: frames
        )
    }
}

struct JackTripStreamingOrderTransmitter: JackTripCompatibilityMediaTransmitting {
    let probe: JackTripStreamingOrderProbe

    func transmit(
        _ datagrams: [JackTripCompatibilityDatagram],
        localHost _: String,
        peer _: String
    ) throws -> Int {
        probe.emittedDatagramCount += datagrams.count
        return datagrams.count
    }

    func transmitGenerated(
        localHost _: String,
        peer _: String,
        generate: (_ emit: (JackTripCompatibilityDatagram) throws -> Void) throws -> Void
    ) throws -> Int {
        if probe.requiresReceiverBound, !probe.receiverBound {
            probe.transmitStartedBeforeReceiverBound = true
        }
        try generate { _ in probe.emittedDatagramCount += 1 }
        return probe.emittedDatagramCount
    }
}

struct JackTripBoundOrderReceiver: JackTripCompatibilityMediaReceiving {
    let probe: JackTripStreamingOrderProbe

    func receive(_: JackTripMediaReceiveRequest) throws -> JackTripCompatibilityReceiveResult {
        JackTripCompatibilityReceiveResult(datagrams: [])
    }

    func receiveWhileBound(
        _ request: JackTripMediaReceiveRequest,
        transmit: @escaping () throws -> Int
    ) throws -> (transmitted: Int, received: JackTripCompatibilityReceiveResult) {
        probe.receiverBound = true
        let transmitted = try transmit()
        return (transmitted, JackTripCompatibilityReceiveResult(datagrams: []))
    }
}

final class JackTripIndependentDuplexReceiver: JackTripCompatibilityMediaReceiving {
    let inbound: [JackTripCompatibilityDatagram]
    private(set) var expectedReceiveCount: Int?

    init(inbound: [JackTripCompatibilityDatagram]) {
        self.inbound = inbound
    }

    func receive(_: JackTripMediaReceiveRequest) throws -> JackTripCompatibilityReceiveResult {
        JackTripCompatibilityReceiveResult(datagrams: inbound)
    }

    func receiveWhileBound(
        _ request: JackTripMediaReceiveRequest,
        transmit: @escaping () throws -> Int
    ) throws -> (transmitted: Int, received: JackTripCompatibilityReceiveResult) {
        expectedReceiveCount = request.expectedDatagrams
        return (try transmit(), JackTripCompatibilityReceiveResult(datagrams: inbound))
    }
}

struct JackTripZeroSuccessTransmitter: JackTripCompatibilityMediaTransmitting {
    func transmit(
        _: [JackTripCompatibilityDatagram],
        localHost _: String,
        peer _: String
    ) throws -> Int { 0 }

    func transmitGenerated(
        localHost _: String,
        peer _: String,
        generate: (_ emit: (JackTripCompatibilityDatagram) throws -> Void) throws -> Void
    ) throws -> Int {
        try generate { _ in }
        return 0
    }
}
