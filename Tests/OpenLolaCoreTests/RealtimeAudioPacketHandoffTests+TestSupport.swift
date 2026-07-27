// Shared realtime audio packet handoff tests helpers keep related tests deterministic and focused on their contract.
import Dispatch
import Foundation
import Testing

@testable import OpenLolaCore

final class PacketHandoffIntCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var storedValue = 0

    var value: Int {
        lock.lock()
        defer { lock.unlock() }
        return storedValue
    }

    func increment() {
        lock.lock()
        storedValue += 1
        lock.unlock()
    }
}

var realtimeAudioPacketHandoffRepositoryRoot: URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
}

func realtimeAudioPacketHandoffSwiftSourceFiles(under root: URL) throws -> [URL] {
    try testSwiftSourceFiles(under: root)
}

final class PacketHandoffUInt64PayloadRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var values: [UInt64]

    init(capacity: Int) {
        values = []
        values.reserveCapacity(capacity)
    }

    var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return values.count
    }

    func append(_ value: UInt64) {
        lock.lock()
        values.append(value)
        lock.unlock()
    }

    func snapshot() -> [UInt64] {
        lock.lock()
        defer { lock.unlock() }
        return values
    }
}

func packetHandoffConfiguration(
    preallocatedBlockCount: Int = 4,
    playoutTargetFrames: Int = 32,
    rxBufferPolicy: RxBufferPolicy? = nil
) -> RealtimeAudioEngineConfiguration {
    standardRealtimeAudioEngineConfiguration(
        playoutTargetFrames: playoutTargetFrames,
        preallocatedBlockCount: preallocatedBlockCount,
        rxBufferPolicy: rxBufferPolicy
    )
}

func packet(sequence: UInt64, senderFrameIndex: UInt64) -> UdpPcmPacket {
    UdpPcmPacket(
        header: UdpPcmPacketHeader(
            transport: .init(sequenceNumber: sequence, senderFrameIndex: senderFrameIndex, senderHostTimeNanoseconds: sequence),
            format: .init(sampleRateHertz: 48_000, framesPerPacket: 32, channelCount: 2, sampleFormat: .int16LittleEndian)
        ),
        payload: Data(repeating: UInt8(sequence), count: 128)
    )
}

func mismatchedV2Mode() throws -> AudioTransportMode {
    try plannedV2TestAudioTransportMode(
        .init(
            streamID: 1,
            channelCount: 2,
            sampleFormat: .float32LittleEndian,
            metadataRevision: 0
        )
    )
}

func incompleteV2Mode() -> AudioTransportMode {
    v2TestAudioTransportMode(
        .init(
            streamID: 1,
            channelCount: 2,
            sampleFormat: .int16LittleEndian,
            metadataRevision: 0
        ),
        fragments: [
            UdpPcmV2ChannelFragmentPlan(
                .init(
                    streamID: 1,
                    audio: .init(
                        totalChannelCount: 2,
                        framesPerPacket: 32,
                        sampleRateHertz: 48_000,
                        sampleFormat: .int16LittleEndian
                    ),
                    metadata: .init(
                        metadataRevision: 0,
                        packingMode: .interleavedChannelRange
                    ),
                    channelRange: .init(
                        offset: 0,
                        count: 1
                    ),
                    position: .init(
                        index: 0,
                        count: 1
                    ),
                    byteCounts: .init(
                        payload: 64,
                        packet: 144
                    )
                )
            )
        ]
    )
}
