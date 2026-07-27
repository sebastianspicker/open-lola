// Verifies that Core Audio raw input state tracks overflow without growing buffer.
import Foundation
import Testing

@testable import OpenLolaCore

#if canImport(CoreAudio)
import CoreAudio

@Test
func coreAudioRawInputStateTracksOverflowWithoutGrowingBuffer() throws {
    let state = try CoreAudioRawInputState(
        framesPerBuffer: 1,
        channelCount: 1,
        inputChannels: [0],
        sampleFormat: .int16LittleEndian,
        durationSeconds: 1,
        sampleRateHertz: 1
    )

    for value in [Int16(1), Int16(2), Int16(3), Int16(4)] {
        var samples = [value]
        try withAudioBufferList(samples: &samples, channelCount: 1) { input in
            state.record(input: input)
        }
    }

    let captured = state.capturedAudio()
    let values = captured.data.withUnsafeBytes { rawBuffer in
        Array(rawBuffer.bindMemory(to: Int16.self))
    }
    #expect(values == [1, 2, 3])
    #expect(captured.underruns == 1)
}

@Test
func recordingAudioInputIOProcZerosOutputBuffers() throws {
    let state = try CoreAudioRawInputState(
        framesPerBuffer: 1,
        channelCount: 1,
        inputChannels: [0],
        sampleFormat: .int16LittleEndian,
        durationSeconds: 1,
        sampleRateHertz: 1
    )
    var inputSamples = [Int16(7)]
    var outputSamples = [Int16(9), Int16(9)]
    var timestamp = AudioTimeStamp()

    try withAudioBufferList(samples: &inputSamples, channelCount: 1) { input in
        try outputSamples.withUnsafeMutableBytes { outputBytes in
            let outputBase = try #require(outputBytes.baseAddress)
            let outputBuffer = AudioBuffer(
                mNumberChannels: 1,
                mDataByteSize: UInt32(outputBytes.count),
                mData: outputBase
            )
            var outputList = AudioBufferList(mNumberBuffers: 1, mBuffers: outputBuffer)
            let status = recordingAudioInputIOProc(
                0,
                &timestamp,
                input,
                &timestamp,
                &outputList,
                &timestamp,
                Unmanaged.passUnretained(state).toOpaque()
            )
            #expect(status == noErr)
        }
    }

    #expect(outputSamples == [0, 0])
}

private func withAudioBufferList<Sample>(
    samples: inout [Sample],
    channelCount: UInt32,
    _ body: (UnsafePointer<AudioBufferList>) throws -> Void
) throws {
    try withMutableAudioBufferList(samples: &samples, channelCount: channelCount) { list in
        try body(UnsafePointer(list))
    }
}
#endif

#if canImport(AVFoundation)
@preconcurrency import AVFoundation
import CoreMedia
import CoreVideo

private func makeTestSampleBuffer(width: Int, height: Int) throws -> CMSampleBuffer {
    try makeVideoCaptureTestSampleBuffer(width: width, height: height)
}
#endif
