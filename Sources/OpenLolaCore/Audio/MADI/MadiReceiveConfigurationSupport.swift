// Resolves MADI receive buffer policy, output channels, and mixer state during engine initialization from one checked configuration path.
import Foundation

extension MadiReceiveEngine {
    static func initializationState(
        configuration: MadiReceiveConfiguration
    ) throws -> MadiReceiveInitializationState {
        guard configuration.mode.protocolVersion == .udpPcmV2 else {
            throw MadiReceiveError.invalidTransportMode
        }
        guard configuration.preallocatedBlockCount > 0 else {
            throw MadiReceiveError.nonPositiveField("preallocatedBlockCount")
        }
        let rxBufferPolicy = try resolvedRxBufferPolicy(configuration: configuration)
        let outputChannelCount = try resolvedOutputChannelCount(configuration: configuration)
        let mixStore = try resolvedReceiverMixStore(
            configuration: configuration,
            outputChannelCount: outputChannelCount
        )
        return MadiReceiveInitializationState(
            rxBufferPolicy: rxBufferPolicy,
            mixStore: mixStore,
            outputChannelCount: outputChannelCount
        )
    }

    static func resolvedRxBufferPolicy(
        configuration: MadiReceiveConfiguration
    ) throws -> RxBufferPolicy {
        let rxBufferPolicy = try configuration.rxBufferPolicy
            ?? MadiReceiveEngine.defaultRxBufferPolicy(for: configuration.mode)
        guard rxBufferPolicy.framesPerPacket == configuration.mode.framesPerPacket else {
            throw MadiReceiveError.transportModeMismatch("framesPerPacket")
        }
        guard rxBufferPolicy.sampleRateHertz == configuration.mode.sampleRateHertz else {
            throw MadiReceiveError.transportModeMismatch("sampleRateHertz")
        }
        return rxBufferPolicy
    }

    static func resolvedOutputChannelCount(
        configuration: MadiReceiveConfiguration
    ) throws -> Int {
        let outputChannelCount = configuration.outputChannelCount ?? configuration.mode.channelCount
        guard outputChannelCount > 0 else {
            throw MadiReceiveError.nonPositiveField("outputChannelCount")
        }
        return outputChannelCount
    }

    static func resolvedReceiverMixStore(
        configuration: MadiReceiveConfiguration,
        outputChannelCount: Int
    ) throws -> ReceiverMixSnapshotStore {
        let receiverMix = configuration.receiverMix
            ?? ReceiverMixSnapshot.identity(
                inputChannels: AudioChannelSet.defaultInput(count: configuration.mode.channelCount),
                outputChannels: AudioChannelSet.defaultOutput(count: outputChannelCount)
            )
        do {
            return try ReceiverMixSnapshotStore(
                initial: receiverMix,
                inputChannelCount: configuration.mode.channelCount,
                outputChannelCount: outputChannelCount
            )
        } catch let error as ReceiverMixSnapshotError {
            throw MadiReceiveError.receiverMix(error)
        }
    }

}
