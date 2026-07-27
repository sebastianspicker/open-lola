// Copies channel-mapped samples between Core Audio buffer layouts and aligned scratch memory with bounds checks kept off the callback declarations.
import CoreAudio
import Darwin
import Foundation

extension DirectPeerRealtimeAudioGraph {
    func copyMappedInput(from buffers: ReadOnlyAudioBufferListPointer) -> DirectPeerInputCopyResult {
        memset(inputScratch, 0, configuration.payloadByteCount)
        if buffers.count == 1 {
            return copyMappedInputFromSingleBuffer(buffers)
        }
        return copyMappedInputFromSplitBuffers(buffers)
    }

    func copyMappedInputFromSingleBuffer(
        _ buffers: ReadOnlyAudioBufferListPointer
    ) -> DirectPeerInputCopyResult {
        guard let sourceBuffer = buffers[0], let source = sourceBuffer.mData else {
            return .inputBufferUnavailable
        }
        let sourceChannels = Int(sourceBuffer.mNumberChannels)
        guard sourceChannels > 0 else { return .invalidSourceChannelCount }
        for (outputChannel, inputChannel) in configuration.inputChannelMap.enumerated() {
            guard outputChannel < configuration.channelCount else {
                return .destinationChannelOutOfRange
            }
            guard inputChannel >= 0, inputChannel < sourceChannels else {
                return .inputChannelOutOfRange
            }
            let result = copyMappedInputChannel(
                source: UnsafeRawPointer(source),
                sourceChannel: inputChannel,
                sourceChannelCount: sourceChannels,
                sourceByteCount: Int(sourceBuffer.mDataByteSize),
                destinationChannel: outputChannel
            )
            guard result == .copied else { return result }
        }
        return .copied
    }

    func copyMappedInputFromSplitBuffers(
        _ buffers: ReadOnlyAudioBufferListPointer
    ) -> DirectPeerInputCopyResult {
        for (outputChannel, inputChannel) in configuration.inputChannelMap.enumerated() {
            guard outputChannel < configuration.channelCount else {
                return .destinationChannelOutOfRange
            }
            guard inputChannel >= 0 else { return .inputChannelOutOfRange }
            guard let sourceLocation = readOnlyBufferLocation(
                forStableChannel: inputChannel,
                in: buffers
            ) else {
                return totalChannelCount(in: buffers) > 0
                    ? .inputChannelOutOfRange
                    : .invalidSourceChannelCount
            }
            guard let source = sourceLocation.buffer.mData else {
                return .inputBufferUnavailable
            }
            let result = copyMappedInputChannel(
                source: UnsafeRawPointer(source),
                sourceChannel: sourceLocation.channelIndex,
                sourceChannelCount: sourceLocation.channelCount,
                sourceByteCount: Int(sourceLocation.buffer.mDataByteSize),
                destinationChannel: outputChannel
            )
            guard result == .copied else { return result }
        }
        return .copied
    }

    func copyMappedInputChannel(
        source: UnsafeRawPointer,
        sourceChannel: Int,
        sourceChannelCount: Int,
        sourceByteCount: Int,
        destinationChannel: Int
    ) -> DirectPeerInputCopyResult {
        let bytesPerSample = configuration.sampleFormat.bytesPerSample
        switch audioChannelCopyPlan(
            request: DirectPeerAudioChannelCopyPlanRequest(
                source: DirectPeerAudioChannelCopyEndpoint(
                    channel: sourceChannel,
                    channelCount: sourceChannelCount,
                    byteCount: sourceByteCount
                ),
                destination: DirectPeerAudioChannelCopyEndpoint(
                    channel: destinationChannel,
                    channelCount: configuration.channelCount,
                    byteCount: configuration.payloadByteCount
                ),
                bytesPerSample: bytesPerSample,
                frameCount: configuration.framesPerBuffer
            )
        ) {
        case let .valid(plan):
            copyAudioChannelBytes(
                source: source,
                destination: inputScratch,
                plan: plan,
                bytesPerSample: bytesPerSample,
                frameCount: configuration.framesPerBuffer
            )
            return .copied
        case .invalidByteOffset:
            return .invalidByteOffset
        case .sourceBufferTooSmall:
            return .inputBufferTooSmall
        case .destinationBufferTooSmall:
            return .destinationBufferTooSmall
        }
    }

    func clearOutput(_ buffers: UnsafeMutableAudioBufferListPointer) {
        for buffer in buffers where buffer.mData != nil {
            memset(buffer.mData, 0, Int(buffer.mDataByteSize))
        }
    }

    func copyMappedOutput(to buffers: UnsafeMutableAudioBufferListPointer) -> Bool {
        if buffers.count == 1, let destination = buffers[0].mData {
            return copyMappedOutputToSingleBuffer(destination, buffer: buffers[0])
        }
        return copyMappedOutputToSplitBuffers(buffers)
    }

    func copyMappedOutputToSingleBuffer(
        _ destination: UnsafeMutableRawPointer,
        buffer: AudioBuffer
    ) -> Bool {
        let destinationChannels = Int(buffer.mNumberChannels)
        guard destinationChannels > 0 else { return false }
        for (inputChannel, outputChannel) in configuration.outputChannelMap.enumerated() {
            guard inputChannel < configuration.channelCount,
                  outputChannel >= 0,
                  outputChannel < destinationChannels else {
                return false
            }
            guard copyMappedOutputChannel(
                destination: destination,
                destinationChannel: outputChannel,
                destinationChannelCount: destinationChannels,
                destinationByteCount: Int(buffer.mDataByteSize),
                inputChannel: inputChannel
            ) else {
                return false
            }
        }
        return true
    }

    func copyMappedOutputToSplitBuffers(
        _ buffers: UnsafeMutableAudioBufferListPointer
    ) -> Bool {
        for (inputChannel, outputChannel) in configuration.outputChannelMap.enumerated() {
            guard inputChannel < configuration.channelCount,
                  outputChannel >= 0,
                  let destinationLocation = mutableBufferLocation(
                    forStableChannel: outputChannel,
                    in: buffers
                  ) else {
                return false
            }
            guard copyMappedOutputChannel(
                destination: destinationLocation.data,
                destinationChannel: destinationLocation.channelIndex,
                destinationChannelCount: destinationLocation.channelCount,
                destinationByteCount: destinationLocation.byteCount,
                inputChannel: inputChannel
            ) else {
                return false
            }
        }
        return true
    }

    func copyMappedOutputChannel(
        destination: UnsafeMutableRawPointer,
        destinationChannel: Int,
        destinationChannelCount: Int,
        destinationByteCount: Int,
        inputChannel: Int
    ) -> Bool {
        let bytesPerSample = configuration.sampleFormat.bytesPerSample
        guard case let .valid(plan) = audioChannelCopyPlan(
            request: DirectPeerAudioChannelCopyPlanRequest(
                source: DirectPeerAudioChannelCopyEndpoint(
                    channel: inputChannel,
                    channelCount: configuration.channelCount,
                    byteCount: configuration.payloadByteCount
                ),
                destination: DirectPeerAudioChannelCopyEndpoint(
                    channel: destinationChannel,
                    channelCount: destinationChannelCount,
                    byteCount: destinationByteCount
                ),
                bytesPerSample: bytesPerSample,
                frameCount: configuration.framesPerBuffer
            )
        ) else {
            return false
        }
        copyAudioChannelBytes(
            source: UnsafeRawPointer(outputScratch),
            destination: destination,
            plan: plan,
            bytesPerSample: bytesPerSample,
            frameCount: configuration.framesPerBuffer
        )
        return true
    }

    func readOnlyBufferLocation(
        forStableChannel stableChannel: Int,
        in buffers: ReadOnlyAudioBufferListPointer
    ) -> DirectPeerReadOnlyAudioBufferLocation? {
        var baseChannel = 0
        for bufferIndex in 0..<buffers.count {
            guard let buffer = buffers[bufferIndex] else {
                continue
            }
            let channelCount = Int(buffer.mNumberChannels)
            guard channelCount > 0 else {
                continue
            }
            let upperBound = baseChannel + channelCount
            if stableChannel < upperBound {
                return DirectPeerReadOnlyAudioBufferLocation(
                    buffer: buffer,
                    channelIndex: stableChannel - baseChannel,
                    channelCount: channelCount
                )
            }
            baseChannel = upperBound
        }
        return nil
    }

    func mutableBufferLocation(
        forStableChannel stableChannel: Int,
        in buffers: UnsafeMutableAudioBufferListPointer
    ) -> DirectPeerMutableAudioBufferLocation? {
        var baseChannel = 0
        for bufferIndex in 0..<buffers.count {
            let buffer = buffers[bufferIndex]
            let channelCount = Int(buffer.mNumberChannels)
            guard channelCount > 0 else {
                continue
            }
            let upperBound = baseChannel + channelCount
            if stableChannel < upperBound {
                guard let data = buffer.mData else {
                    return nil
                }
                return DirectPeerMutableAudioBufferLocation(
                    data: data,
                    byteCount: Int(buffer.mDataByteSize),
                    channelIndex: stableChannel - baseChannel,
                    channelCount: channelCount
                )
            }
            baseChannel = upperBound
        }
        return nil
    }

    func totalChannelCount(in buffers: ReadOnlyAudioBufferListPointer) -> Int {
        var total = 0
        for bufferIndex in 0..<buffers.count {
            guard let buffer = buffers[bufferIndex] else {
                continue
            }
            total += max(0, Int(buffer.mNumberChannels))
        }
        return total
    }

}
