import Foundation

@testable import OpenLolaCore

struct JackTripStaticReceiveResultReceiver: JackTripCompatibilityMediaReceiving {
    var result: JackTripCompatibilityReceiveResult

    func receive(
        expectedDatagrams _: Int,
        localHost _: String,
        peer _: String,
        audioPort _: UInt16,
        headerMode _: JackTripPacketHeaderMode,
        emptyHeaderTemplate _: JackTripDefaultHeader?,
        timeoutSeconds _: Int
    ) throws -> JackTripCompatibilityReceiveResult {
        result
    }
}

struct JackTripFixedAudioProvider: JackTripAudioFrameProviding {
    var interleaved: Data

    func interleavedInt16PCM(sequenceNumber _: Int, channels _: Int, frames _: Int) throws -> Data {
        interleaved
    }
}

final class JackTripReceiveResultBox: @unchecked Sendable {
    private let semaphore = DispatchSemaphore(value: 0)
    private let lock = NSLock()
    private var result: Result<JackTripCompatibilityReceiveResult, Error>?

    func store(_ result: Result<JackTripCompatibilityReceiveResult, Error>) {
        lock.lock()
        self.result = result
        lock.unlock()
        semaphore.signal()
    }

    func load() throws -> JackTripCompatibilityReceiveResult {
        semaphore.wait()
        lock.lock()
        let result = self.result
        lock.unlock()
        switch result {
        case let .success(value):
            return value
        case let .failure(error):
            throw error
        case nil:
            throw ExternalConnectorSessionError.emptyField("jackTripReceiveResult")
        }
    }
}

func jackTripTestPacket(sequenceNumber: UInt16, payloadByte: UInt8) throws -> JackTripAudioPacket {
    try JackTripAudioPacket(
        header: JackTripDefaultHeader(
            timestampMicroseconds: UInt64(1_700_000_000_000_000 + Int(sequenceNumber)),
            sequenceNumber: sequenceNumber,
            bufferSizeSamples: 2,
            sampleRate: .hz48000,
            bitResolution: .bit16,
            incomingChannelsFromNetwork: 2,
            outgoingChannelsToNetwork: JackTripCompatibility.matchingOutgoingChannelSentinel
        ),
        planarAudioPayload: Data(repeating: payloadByte, count: 8)
    )
}
