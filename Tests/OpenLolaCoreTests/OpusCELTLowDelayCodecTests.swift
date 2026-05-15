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
func opusCELTLowDelayEncoderDoesNotForceUnwrapOutputBuffer() throws {
    let source = try readOpusCodecRepositoryText("Sources/OpenLolaCore/Audio/Codecs/OpusCELTLowDelayCodec.swift")

    #expect(source.contains("let outputBaseAddress = output.baseAddress"))
    #expect(!source.contains("output.baseAddress!"))
}

@Test
func opusCELTLowDelayCodecExposesScratchBufferHotPathAPIs() throws {
    let codecSource = try readOpusCodecRepositoryText("Sources/OpenLolaCore/Audio/Codecs/OpusCELTLowDelayCodec.swift")
    let loopSource = try readOpusCodecRepositoryText("Sources/OpenLolaCore/Network/P2P/DirectPeerSessionAVAudioLoops.swift")

    #expect(codecSource.contains("public func encode(\n        _ pcm: UnsafeRawBufferPointer,\n        into output: UnsafeMutableRawBufferPointer"))
    #expect(codecSource.contains("public func decode(\n        _ encoded: UnsafeRawBufferPointer,\n        into output: UnsafeMutableRawBufferPointer"))
    #expect(loopSource.contains("opusEncodeScratch"))
    #expect(loopSource.contains("opusDecodeScratch"))
    #expect(loopSource.contains("try opusEncoder.encode(payloadBytes, into: output)"))
    #expect(loopSource.contains("try opusDecoder.decode(input, into: output)"))
}

private func readOpusCodecRepositoryText(_ relativePath: String) throws -> String {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    return try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
}
