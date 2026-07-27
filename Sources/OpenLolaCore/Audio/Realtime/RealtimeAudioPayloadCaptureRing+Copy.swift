// Implements RealtimeAudioPayloadCaptureRing+Copy bounded buffering, isolating real-time ownership rules from audio and network loops.
import CoreAudio
import Darwin

private struct RealtimeAudioSelectedSampleEndpoint {
    var base: UnsafeRawPointer
    var channel: Int
    var channelCount: Int
}

private struct RealtimeAudioSelectedSampleDestination {
    var base: UnsafeMutableRawPointer
    var channel: Int
    var channelCount: Int
}

private struct RealtimeAudioSelectedSampleCopyRequest {
    var source: RealtimeAudioSelectedSampleEndpoint
    var destination: RealtimeAudioSelectedSampleDestination
    var frame: Int
    var bytesPerSample: Int
}

extension RealtimeAudioPayloadCaptureRing {
    static func copySelectedInterleavedChannels(
        sourceBase: UnsafeRawPointer,
        destinationBase: UnsafeMutableRawPointer,
        sourceChannelCount: Int,
        shape: RealtimeAudioPayloadShape,
        inputChannelMap: [Int]
    ) -> Bool {
        let bytesPerSample = shape.sampleFormat.bytesPerSample
        for frame in 0..<shape.frameCount {
            for (destinationChannel, sourceChannel) in inputChannelMap.enumerated() {
                guard copySelectedAudioSample(
                    request: RealtimeAudioSelectedSampleCopyRequest(
                        source: RealtimeAudioSelectedSampleEndpoint(
                            base: sourceBase,
                            channel: sourceChannel,
                            channelCount: sourceChannelCount
                        ),
                        destination: RealtimeAudioSelectedSampleDestination(
                            base: destinationBase,
                            channel: destinationChannel,
                            channelCount: shape.channelCount
                        ),
                        frame: frame,
                        bytesPerSample: bytesPerSample
                    )
                ) else {
                    return false
                }
            }
        }
        return true
    }

    static func copySelectedAudioBuffers(
        _ inputBuffers: RealtimeAudioBufferListReader,
        destinationBase: UnsafeMutableRawPointer,
        shape: RealtimeAudioPayloadShape,
        inputChannelMap: [Int]
    ) -> Bool {
        let bytesPerSample = shape.sampleFormat.bytesPerSample
        for (destinationChannel, sourceChannel) in inputChannelMap.enumerated() {
            guard let location = bufferLocation(forStableChannel: sourceChannel, in: inputBuffers),
                  let source = audioBufferForCopy(at: location.bufferIndex, in: inputBuffers, shape: shape),
                  let sourceBase = source.mData else {
                return false
            }
            let sourceChannelCount = Int(source.mNumberChannels)
            for frame in 0..<shape.frameCount {
                guard copySelectedAudioSample(
                    request: RealtimeAudioSelectedSampleCopyRequest(
                        source: RealtimeAudioSelectedSampleEndpoint(
                            base: sourceBase,
                            channel: location.localChannel,
                            channelCount: sourceChannelCount
                        ),
                        destination: RealtimeAudioSelectedSampleDestination(
                            base: destinationBase,
                            channel: destinationChannel,
                            channelCount: shape.channelCount
                        ),
                        frame: frame,
                        bytesPerSample: bytesPerSample
                    )
                ) else {
                    return false
                }
            }
        }
        return true
    }

    private static func copySelectedAudioSample(request: RealtimeAudioSelectedSampleCopyRequest) -> Bool {
        guard let sourceOffset = audioByteOffset(
            frame: request.frame,
            channel: request.source.channel,
            channelCount: request.source.channelCount,
            bytesPerSample: request.bytesPerSample
        ), let destinationOffset = audioByteOffset(
            frame: request.frame,
            channel: request.destination.channel,
            channelCount: request.destination.channelCount,
            bytesPerSample: request.bytesPerSample
        ) else {
            return false
        }
        memcpy(
            request.destination.base.advanced(by: destinationOffset),
            request.source.base.advanced(by: sourceOffset),
            request.bytesPerSample
        )
        return true
    }

    private static func audioBufferForCopy(
        at index: Int,
        in inputBuffers: RealtimeAudioBufferListReader,
        shape: RealtimeAudioPayloadShape
    ) -> AudioBuffer? {
        guard let buffer = inputBuffers[index] else {
            return nil
        }
        guard buffer.mData != nil else {
            return nil
        }
        let requiredBytes = shape.frameCount
            * Int(buffer.mNumberChannels)
            * shape.sampleFormat.bytesPerSample
        guard let availableBytes = Int(exactly: buffer.mDataByteSize),
              availableBytes >= requiredBytes else {
            return nil
        }
        return buffer
    }

    private static func bufferLocation(
        forStableChannel stableChannel: Int,
        in inputBuffers: RealtimeAudioBufferListReader
    ) -> (bufferIndex: Int, localChannel: Int)? {
        guard stableChannel >= 0 else {
            return nil
        }
        var baseChannel = 0
        for bufferIndex in 0..<inputBuffers.count {
            guard let buffer = inputBuffers[bufferIndex] else {
                return nil
            }
            let channelCount = Int(buffer.mNumberChannels)
            if stableChannel < baseChannel + channelCount {
                return (bufferIndex, stableChannel - baseChannel)
            }
            baseChannel += channelCount
        }
        return nil
    }
}
