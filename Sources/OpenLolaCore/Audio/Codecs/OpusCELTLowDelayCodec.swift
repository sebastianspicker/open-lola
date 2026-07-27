// Implements OpusCELTLowDelayCodec encoding and decoding, keeping wire representation apart from transport lifetime.
import COpus
import Foundation

/// Fixes the sample, frame, and packet limits that keep the fixed-shape low-delay Opus path wire-compatible.
public enum OpusCELTLowDelayConstants {
    public static let sampleRateHertz = Int(OPEN_LOLA_OPUS_SAMPLE_RATE_HZ)
    public static let frameCount = Int(OPEN_LOLA_OPUS_FRAME_COUNT)
    public static let bitrateBitsPerSecond = Int(OPEN_LOLA_OPUS_BITRATE_BPS)
    public static let frameDurationMilliseconds = 2.5
    public static let maxEncodedByteCount = Int(OPEN_LOLA_OPUS_MAX_PACKET_BYTES)
}

/// Reports unsupported sample, frame, format, and channel shapes before Opus packets reach the live path.
public enum OpusCELTLowDelayCodecError: Error, Equatable, Sendable {
    case invalidSampleRate(Int)
    case invalidFrameCount(Int)
    case invalidSampleFormat(UdpPcmSampleFormat)
    case invalidChannelCount(Int)
    case invalidPCMByteCount(expected: Int, actual: Int)
    case createEncoderFailed(Int32)
    case createDecoderFailed(Int32)
    case encodeFailed(Int32)
    case decodeFailed(Int32)
    case invalidEncodedByteCapacity(expectedAtLeast: Int, actual: Int)
    case invalidDecodedPCMByteCount(expected: Int, actual: Int)
}

/// Enforces the fixed 48 kHz, 2.5 ms, float-PCM contract required by the low-delay codec.
public enum OpusCELTLowDelayCodecValidation {
    public static func validate(
        sampleRateHertz: Int,
        frameCount: Int,
        sampleFormat: UdpPcmSampleFormat,
        channelCount: Int
    ) throws {
        guard sampleRateHertz == OpusCELTLowDelayConstants.sampleRateHertz else {
            throw OpusCELTLowDelayCodecError.invalidSampleRate(sampleRateHertz)
        }
        guard frameCount == OpusCELTLowDelayConstants.frameCount else {
            throw OpusCELTLowDelayCodecError.invalidFrameCount(frameCount)
        }
        guard sampleFormat == .float32LittleEndian else {
            throw OpusCELTLowDelayCodecError.invalidSampleFormat(sampleFormat)
        }
        guard (1...2).contains(channelCount) else {
            throw OpusCELTLowDelayCodecError.invalidChannelCount(channelCount)
        }
    }
}

private func validateOpusCELTLowDelayChannelCount(_ channelCount: Int) throws {
    try OpusCELTLowDelayCodecValidation.validate(
        sampleRateHertz: OpusCELTLowDelayConstants.sampleRateHertz,
        frameCount: OpusCELTLowDelayConstants.frameCount,
        sampleFormat: .float32LittleEndian,
        channelCount: channelCount
    )
}

/// Owns the native encoder handle that turns PCM callback blocks into low-delay packets.
public final class OpusCELTLowDelayEncoder {
    private let handle: OpaquePointer
    private let channelCount: Int

    public init(channelCount: Int) throws {
        try validateOpusCELTLowDelayChannelCount(channelCount)
        var rawHandle: OpaquePointer?
        let result = open_lola_opus_create_encoder(Int32(channelCount), &rawHandle)
        guard result == 0, let rawHandle else {
            throw OpusCELTLowDelayCodecError.createEncoderFailed(result)
        }
        self.handle = rawHandle
        self.channelCount = channelCount
    }

    deinit {
        open_lola_opus_destroy_encoder(handle)
    }

    public func encode(_ pcm: Data) throws -> Data {
        try pcm.withUnsafeBytes { bytes in
            try encode(bytes)
        }
    }

    public func encode(_ pcm: UnsafeRawBufferPointer) throws -> Data {
        var encoded = Data(count: OpusCELTLowDelayConstants.maxEncodedByteCount)
        let encodedByteCount = try encoded.withUnsafeMutableBytes { output in
            try encode(pcm, into: output)
        }
        encoded.removeSubrange(Int(encodedByteCount)..<encoded.count)
        return encoded
    }

    public func encode(
        _ pcm: UnsafeRawBufferPointer,
        into output: UnsafeMutableRawBufferPointer
    ) throws -> Int {
        let expectedByteCount = OpusCELTLowDelayConstants.frameCount
            * channelCount
            * UdpPcmSampleFormat.float32LittleEndian.bytesPerSample
        guard pcm.count == expectedByteCount else {
            throw OpusCELTLowDelayCodecError.invalidPCMByteCount(
                expected: expectedByteCount,
                actual: pcm.count
            )
        }
        guard let baseAddress = pcm.baseAddress else {
            throw OpusCELTLowDelayCodecError.invalidPCMByteCount(
                expected: expectedByteCount,
                actual: pcm.count
            )
        }
        guard output.count >= OpusCELTLowDelayConstants.maxEncodedByteCount,
              let outputBaseAddress = output.baseAddress else {
            throw OpusCELTLowDelayCodecError.invalidEncodedByteCapacity(
                expectedAtLeast: OpusCELTLowDelayConstants.maxEncodedByteCount,
                actual: output.count
            )
        }

        let encodedByteCount = open_lola_opus_encode_float(
            handle,
            baseAddress.assumingMemoryBound(to: Float.self),
            Int32(OpusCELTLowDelayConstants.frameCount),
            outputBaseAddress.assumingMemoryBound(to: UInt8.self),
            Int32(output.count)
        )
        guard encodedByteCount > 0 else {
            throw OpusCELTLowDelayCodecError.encodeFailed(encodedByteCount)
        }
        return Int(encodedByteCount)
    }
}

/// Owns the native decoder handle that restores low-delay packets into PCM callback blocks.
public final class OpusCELTLowDelayDecoder {
    private let handle: OpaquePointer
    private let channelCount: Int

    public init(channelCount: Int) throws {
        try validateOpusCELTLowDelayChannelCount(channelCount)
        var rawHandle: OpaquePointer?
        let result = open_lola_opus_create_decoder(Int32(channelCount), &rawHandle)
        guard result == 0, let rawHandle else {
            throw OpusCELTLowDelayCodecError.createDecoderFailed(result)
        }
        self.handle = rawHandle
        self.channelCount = channelCount
    }

    deinit {
        open_lola_opus_destroy_decoder(handle)
    }

    public func decode(_ encoded: Data) throws -> Data {
        var pcm = Data(count: outputPCMByteCount)
        _ = try encoded.withUnsafeBytes { input in
            try pcm.withUnsafeMutableBytes { output in
                try decode(input, into: output)
            }
        }
        return pcm
    }

    public var outputPCMByteCount: Int {
        OpusCELTLowDelayConstants.frameCount
            * channelCount
            * UdpPcmSampleFormat.float32LittleEndian.bytesPerSample
    }

    public func decode(
        _ encoded: UnsafeRawBufferPointer,
        into output: UnsafeMutableRawBufferPointer
    ) throws -> Int {
        guard !encoded.isEmpty else {
            throw OpusCELTLowDelayCodecError.decodeFailed(-1)
        }
        guard output.count >= outputPCMByteCount else {
            throw OpusCELTLowDelayCodecError.invalidDecodedPCMByteCount(
                expected: outputPCMByteCount,
                actual: output.count
            )
        }
        guard let inputBaseAddress = encoded.baseAddress,
              let outputBaseAddress = output.baseAddress else {
            throw OpusCELTLowDelayCodecError.decodeFailed(-1)
        }
        let decodedFrameCount = open_lola_opus_decode_float(
            handle,
            inputBaseAddress.assumingMemoryBound(to: UInt8.self),
            Int32(encoded.count),
            outputBaseAddress.assumingMemoryBound(to: Float.self),
            Int32(OpusCELTLowDelayConstants.frameCount)
        )
        guard decodedFrameCount == Int32(OpusCELTLowDelayConstants.frameCount) else {
            throw OpusCELTLowDelayCodecError.decodeFailed(decodedFrameCount)
        }
        return outputPCMByteCount
    }
}
