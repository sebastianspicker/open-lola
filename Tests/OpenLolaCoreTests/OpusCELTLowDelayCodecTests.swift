// Covers the Opus CELT low-delay codec contract required by real-time media sessions.
import Foundation
import Testing

@testable import OpenLolaCore

@Test
func opusCELTLowDelayRoundTripsStereoFloat32Frame() throws {
    let channelCount = 2
    let samples = (0..<(OpusCELTLowDelayConstants.frameCount * channelCount)).map { index in
        Float(sin(Double(index) / 12.0) * 0.2)
    }
    let pcm = samples.withUnsafeBufferPointer { Data(buffer: $0) }
    let encoder = try OpusCELTLowDelayEncoder(channelCount: channelCount)
    let decoder = try OpusCELTLowDelayDecoder(channelCount: channelCount)

    let encoded = try encoder.encode(pcm)
    let decoded = try decoder.decode(encoded)
    let decodedSamples = decoded.withUnsafeBytes { Array($0.bindMemory(to: Float.self)) }

    #expect(!encoded.isEmpty)
    #expect(encoded.count < pcm.count)
    #expect(decoded.count == pcm.count)
    #expect(decodedSamples.count == samples.count)
    #expect(decodedSamples.allSatisfy { $0.isFinite })
    #expect((decodedSamples.map { abs($0) }.max() ?? 0) > 0)
}

@Test
func opusCELTLowDelayEncodesAndDecodesWithCallerOwnedScratchBuffers() throws {
    let channelCount = 2
    let samples = (0..<(OpusCELTLowDelayConstants.frameCount * channelCount)).map { index in
        Float(sin(Double(index) / 10.0) * 0.1)
    }
    let pcm = samples.withUnsafeBufferPointer { Data(buffer: $0) }
    let encoder = try OpusCELTLowDelayEncoder(channelCount: channelCount)
    let decoder = try OpusCELTLowDelayDecoder(channelCount: channelCount)
    var encodedScratch = Data(count: OpusCELTLowDelayConstants.maxEncodedByteCount)
    let encodedByteCount = try pcm.withUnsafeBytes { input in
        try encodedScratch.withUnsafeMutableBytes { output in
            try encoder.encode(input, into: output)
        }
    }
    let encoded = Data(encodedScratch.prefix(encodedByteCount))
    var decodedScratch = Data(count: decoder.outputPCMByteCount)
    let decodedByteCount = try encoded.withUnsafeBytes { input in
        try decodedScratch.withUnsafeMutableBytes { output in
            try decoder.decode(input, into: output)
        }
    }

    #expect(encodedByteCount > 0)
    #expect(encodedByteCount < pcm.count)
    #expect(decodedByteCount == pcm.count)
}

@Test
func opusCELTLowDelayRejectsUnsupportedShapes() {
    #expect(throws: OpusCELTLowDelayCodecError.invalidSampleRate(44_100)) {
        try OpusCELTLowDelayCodecValidation.validate(
            sampleRateHertz: 44_100,
            frameCount: 120,
            sampleFormat: .float32LittleEndian,
            channelCount: 2
        )
    }
    #expect(throws: OpusCELTLowDelayCodecError.invalidFrameCount(32)) {
        try OpusCELTLowDelayCodecValidation.validate(
            sampleRateHertz: 48_000,
            frameCount: 32,
            sampleFormat: .float32LittleEndian,
            channelCount: 2
        )
    }
    #expect(throws: OpusCELTLowDelayCodecError.invalidSampleFormat(.int16LittleEndian)) {
        try OpusCELTLowDelayCodecValidation.validate(
            sampleRateHertz: 48_000,
            frameCount: 120,
            sampleFormat: .int16LittleEndian,
            channelCount: 2
        )
    }
    #expect(throws: OpusCELTLowDelayCodecError.invalidChannelCount(64)) {
        try OpusCELTLowDelayCodecValidation.validate(
            sampleRateHertz: 48_000,
            frameCount: 120,
            sampleFormat: .float32LittleEndian,
            channelCount: 64
        )
    }
}

@Test
func opusCELTLowDelayCallerOwnedScratchBuffersRejectInvalidCapacity() throws {
    let channelCount = 2
    let samples = (0..<(OpusCELTLowDelayConstants.frameCount * channelCount)).map { index in
        Float(sin(Double(index) / 8.0) * 0.15)
    }
    let pcm = samples.withUnsafeBufferPointer { Data(buffer: $0) }
    let encoder = try OpusCELTLowDelayEncoder(channelCount: channelCount)
    let decoder = try OpusCELTLowDelayDecoder(channelCount: channelCount)
    var shortEncodedScratch = Data(count: OpusCELTLowDelayConstants.maxEncodedByteCount - 1)

    #expect(
        throws: OpusCELTLowDelayCodecError.invalidEncodedByteCapacity(
            expectedAtLeast: OpusCELTLowDelayConstants.maxEncodedByteCount,
            actual: shortEncodedScratch.count
        )
    ) {
        try pcm.withUnsafeBytes { input in
            try shortEncodedScratch.withUnsafeMutableBytes { output in
                try encoder.encode(input, into: output)
            }
        }
    }

    let encoded = try encoder.encode(pcm)
    var shortDecodedScratch = Data(count: decoder.outputPCMByteCount - 1)
    #expect(
        throws: OpusCELTLowDelayCodecError.invalidDecodedPCMByteCount(
            expected: decoder.outputPCMByteCount,
            actual: shortDecodedScratch.count
        )
    ) {
        try encoded.withUnsafeBytes { input in
            try shortDecodedScratch.withUnsafeMutableBytes { output in
                try decoder.decode(input, into: output)
            }
        }
    }
}
