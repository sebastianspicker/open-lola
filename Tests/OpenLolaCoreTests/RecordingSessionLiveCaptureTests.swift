import Foundation
import Testing

@testable import OpenLolaCore

#if canImport(CoreAudio)
import CoreAudio

@Test
func coreAudioRawInputStateCopiesSelectedInterleavedChannels() throws {
    let state = try CoreAudioRawInputState(
        framesPerBuffer: 2,
        channelCount: 1,
        inputChannels: [1],
        sampleFormat: .float32LittleEndian,
        durationSeconds: 1,
        sampleRateHertz: 2
    )
    var samples: [Float32] = [1, 10, 2, 20]

    try withAudioBufferList(samples: &samples, channelCount: 2) { input in
        state.record(input: input)
    }

    let captured = state.capturedAudio()
    let values = captured.data.withUnsafeBytes { rawBuffer in
        Array(rawBuffer.bindMemory(to: Float32.self))
    }
    #expect(values == [10, 20])
    #expect(captured.underruns == 0)
    #expect(captured.callbackMaxMicroseconds != nil)
}

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

@Test
func recordingAudioInputIOProcSkipsInvalidatedState() throws {
    let state = try CoreAudioRawInputState(
        framesPerBuffer: 1,
        channelCount: 1,
        inputChannels: [0],
        sampleFormat: .int16LittleEndian,
        durationSeconds: 1,
        sampleRateHertz: 1
    )
    state.invalidateCallbacks()
    var inputSamples = [Int16(7)]
    var outputSamples = [Int16(9)]
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

    #expect(outputSamples == [0])
    #expect(state.capturedAudio().data.isEmpty)
}

@Test
func coreAudioRawInputStateRejectsOverflowingBufferSizing() {
    #expect(throws: RecordingLiveCaptureError.audioBufferSizingOverflow) {
        _ = try CoreAudioRawInputState(
            framesPerBuffer: Int.max / 2,
            channelCount: 4,
            inputChannels: [0],
            sampleFormat: .float32LittleEndian,
            durationSeconds: 1,
            sampleRateHertz: 48_000
        )
    }
}

@Test
func coreAudioRawInputRecorderStopsStartedDeviceOnExit() throws {
    let sourceURL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("Sources/OpenLolaCore/Release/RecordingSessionLiveCapture.swift")
    let source = try String(contentsOf: sourceURL, encoding: .utf8)
    let destroyRange = try #require(source.range(of: "AudioDeviceDestroyIOProcID(deviceID, ioProcID)"))
    let guardRange = try #require(source.range(of: "var didStartDevice = false"))
    let deferredStopRange = try #require(source.range(of: "_ = AudioDeviceStop(deviceID, ioProcID)"))
    let startRange = try #require(source.range(of: "status = AudioDeviceStart(deviceID, ioProcID)"))
    let startedRange = try #require(source.range(of: "didStartDevice = true"))
    let stopRange = try #require(source.range(
        of: "status = AudioDeviceStop(deviceID, ioProcID)",
        range: startedRange.upperBound..<source.endIndex
    ))
    let stoppedRange = try #require(source.range(
        of: "didStartDevice = false",
        range: stopRange.upperBound..<source.endIndex
    ))

    #expect(source.contains("if didStartDevice"))
    #expect(destroyRange.upperBound <= guardRange.lowerBound)
    #expect(guardRange.upperBound <= deferredStopRange.lowerBound)
    #expect(deferredStopRange.upperBound <= startRange.lowerBound)
    #expect(startRange.upperBound <= startedRange.lowerBound)
    #expect(startedRange.upperBound <= stopRange.lowerBound)
    #expect(stopRange.upperBound <= stoppedRange.lowerBound)
}

@Test
func coreAudioRawInputStateUsesOwningBuffersForRawAllocations() throws {
    let sourceURL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("Sources/OpenLolaCore/Release/RecordingSessionLiveCapture.swift")
    let source = try String(contentsOf: sourceURL, encoding: .utf8)
    let stateRange = try #require(source.range(of: "final class CoreAudioRawInputState"))
    let rawBufferRange = try #require(source.range(of: "private final class RecordingRawByteBuffer"))
    let uint64BufferRange = try #require(source.range(of: "private final class RecordingUInt64Buffer"))
    let stateSource = String(source[stateRange.lowerBound..<rawBufferRange.lowerBound])

    #expect(stateSource.contains("private let bufferStorage: RecordingRawByteBuffer"))
    #expect(stateSource.contains("private let callbackDurationsStorage: RecordingUInt64Buffer"))
    #expect(!stateSource.contains("UnsafeMutableRawPointer.allocate"))
    #expect(!stateSource.contains("UnsafeMutablePointer<UInt64>.allocate"))
    #expect(rawBufferRange.upperBound <= uint64BufferRange.lowerBound)
    #expect(source.contains("pointer.deinitialize(count: capacity)"))
}

private func withAudioBufferList<Sample>(
    samples: inout [Sample],
    channelCount: UInt32,
    _ body: (UnsafePointer<AudioBufferList>) throws -> Void
) throws {
    try samples.withUnsafeMutableBytes { bytes in
        let baseAddress = try #require(bytes.baseAddress)
        let buffer = AudioBuffer(
            mNumberChannels: channelCount,
            mDataByteSize: UInt32(bytes.count),
            mData: baseAddress
        )
        var list = AudioBufferList(mNumberBuffers: 1, mBuffers: buffer)
        try withUnsafePointer(to: &list, body)
    }
}
#endif

#if canImport(AVFoundation)
@preconcurrency import AVFoundation
import CoreMedia
import CoreVideo

@Test
func avFoundationSampleBufferCollectorEnqueuesMockVideoFrames() throws {
    let collector = AVFoundationSampleBufferCollector(
        queueDepth: 2,
        streamID: 7,
        frameRate: VideoFrameRate(numerator: 30, denominator: 1),
        captureRawFrames: true
    )

    collector.record(sampleBuffer: try makeTestSampleBuffer(width: 2, height: 2))

    let frame = try #require(collector.latestRawFrame())
    let artifact = try #require(collector.rawVideoArtifact())
    #expect(frame.metadata.streamID == 7)
    #expect(frame.metadata.width == 2)
    #expect(frame.metadata.height == 2)
    #expect(artifact.frameIndex.count == 1)
    #expect(!artifact.rawFrameData.isEmpty)
}

private func makeTestSampleBuffer(width: Int, height: Int) throws -> CMSampleBuffer {
    let attributes = [
        kCVPixelBufferCGImageCompatibilityKey: true,
        kCVPixelBufferCGBitmapContextCompatibilityKey: true,
    ] as CFDictionary
    var pixelBuffer: CVPixelBuffer?
    let pixelStatus = CVPixelBufferCreate(
        kCFAllocatorDefault,
        width,
        height,
        kCVPixelFormatType_32BGRA,
        attributes,
        &pixelBuffer
    )
    guard pixelStatus == kCVReturnSuccess, let pixelBuffer else {
        throw NSError(domain: "RecordingSessionLiveCaptureTests", code: Int(pixelStatus))
    }

    CVPixelBufferLockBaseAddress(pixelBuffer, [])
    if let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) {
        memset(baseAddress, 0x7f, CVPixelBufferGetDataSize(pixelBuffer))
    }
    CVPixelBufferUnlockBaseAddress(pixelBuffer, [])

    var formatDescription: CMVideoFormatDescription?
    let formatStatus = CMVideoFormatDescriptionCreateForImageBuffer(
        allocator: kCFAllocatorDefault,
        imageBuffer: pixelBuffer,
        formatDescriptionOut: &formatDescription
    )
    guard formatStatus == noErr, let formatDescription else {
        throw NSError(domain: "RecordingSessionLiveCaptureTests", code: Int(formatStatus))
    }

    var timing = CMSampleTimingInfo(
        duration: CMTime(value: 1, timescale: 30),
        presentationTimeStamp: CMTime(value: 1, timescale: 30),
        decodeTimeStamp: .invalid
    )
    var sampleBuffer: CMSampleBuffer?
    let sampleStatus = CMSampleBufferCreateReadyWithImageBuffer(
        allocator: kCFAllocatorDefault,
        imageBuffer: pixelBuffer,
        formatDescription: formatDescription,
        sampleTiming: &timing,
        sampleBufferOut: &sampleBuffer
    )
    guard sampleStatus == noErr, let sampleBuffer else {
        throw NSError(domain: "RecordingSessionLiveCaptureTests", code: Int(sampleStatus))
    }
    return sampleBuffer
}
#endif
