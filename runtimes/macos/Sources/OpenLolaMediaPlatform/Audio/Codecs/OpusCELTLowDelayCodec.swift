// Retains the source-alpha Opus wire vocabulary when the codec implementation is unavailable.
import Foundation

public enum OpusCELTLowDelayConstants {
    public static let sampleRateHertz = 48_000
    public static let frameCount = 120
    public static let bitrateBitsPerSecond = 64_000
    public static let frameDurationMilliseconds = 2.5
    public static let maxEncodedByteCount = 1_500
}

public enum OpusCELTLowDelayCodecError: Error, Equatable, Sendable {
    case unavailable
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

public enum OpusCELTLowDelayCodecValidation {
    public static func validate(
        sampleRateHertz: Int,
        frameCount: Int,
        sampleFormat: UdpPcmSampleFormat,
        channelCount: Int
    ) throws {
        throw OpusCELTLowDelayCodecError.unavailable
    }
}

public final class OpusCELTLowDelayEncoder {
    public init(channelCount: Int) throws {
        throw OpusCELTLowDelayCodecError.unavailable
    }

    public func encode(_ pcm: Data) throws -> Data {
        throw OpusCELTLowDelayCodecError.unavailable
    }

    public func encode(_ pcm: UnsafeRawBufferPointer) throws -> Data {
        throw OpusCELTLowDelayCodecError.unavailable
    }

    public func encode(
        _ pcm: UnsafeRawBufferPointer,
        into output: UnsafeMutableRawBufferPointer
    ) throws -> Int {
        throw OpusCELTLowDelayCodecError.unavailable
    }
}

public final class OpusCELTLowDelayDecoder {
    private let channelCount: Int

    public init(channelCount: Int) throws {
        self.channelCount = channelCount
        throw OpusCELTLowDelayCodecError.unavailable
    }

    public func decode(_ encoded: Data) throws -> Data {
        throw OpusCELTLowDelayCodecError.unavailable
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
        throw OpusCELTLowDelayCodecError.unavailable
    }
}
