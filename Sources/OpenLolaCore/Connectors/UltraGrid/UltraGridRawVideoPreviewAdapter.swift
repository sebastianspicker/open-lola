// Adapts explicitly understood UltraGrid raw frames to the native BGRA preview sink.
import Foundation

enum UltraGridRawVideoPreviewError: Error, Equatable, Sendable {
    case unsupportedFourCC(UInt32)
    case payloadSizeMismatch(expected: Int, actual: Int)
    case arithmeticOverflow
    case closed
}

final class UltraGridRawVideoPreviewAdapter: @unchecked Sendable {
    private static let rgbaFourCC: UInt32 = 0x5247_4241
    private static let rgb3FourCC: UInt32 = 0x5247_4233

    private let sink: any RawBGRAPreviewSink
    private let lock = NSLock()
    private var closed = false
    private(set) var deliveredFrameCount = 0
    private(set) var droppedFrameCount = 0

    init(sink: any RawBGRAPreviewSink) {
        self.sink = sink
    }

    @discardableResult
    func submit(_ frame: UltraGridReassembledRawVideoFrame) -> Bool {
        do {
            try submitValidated(frame)
            lock.lock()
            deliveredFrameCount += 1
            lock.unlock()
            return true
        } catch {
            lock.lock()
            droppedFrameCount += 1
            lock.unlock()
            return false
        }
    }

    func close() {
        lock.lock()
        let shouldClose = !closed
        closed = true
        lock.unlock()
        if shouldClose { sink.close() }
    }

    private func submitValidated(_ frame: UltraGridReassembledRawVideoFrame) throws {
        lock.lock()
        let isClosed = closed
        lock.unlock()
        guard !isClosed else { throw UltraGridRawVideoPreviewError.closed }

        let pixelCount = try checkedProduct(Int(frame.header.width), Int(frame.header.height))
        let bgra: Data
        switch frame.header.fourCC.rawValue {
        case Self.rgbaFourCC:
            try validatePayload(frame.payload, expected: try checkedProduct(pixelCount, 4))
            bgra = swizzleRGBAtoBGRA(frame.payload)
        case Self.rgb3FourCC:
            try validatePayload(frame.payload, expected: try checkedProduct(pixelCount, 3))
            bgra = expandRGB3toBGRA(
                frame.payload,
                byteCount: try checkedProduct(pixelCount, 4)
            )
        default:
            throw UltraGridRawVideoPreviewError.unsupportedFourCC(frame.header.fourCC.rawValue)
        }
        try sink.submit(frame: RawCapturedVideoFrame(
            metadata: CapturedVideoFrame(
                streamID: UInt32(frame.header.substreamID),
                sequenceNumber: UInt64(frame.sequenceNumber),
                timestampNanoseconds: try timestampNanoseconds(fromRTP90k: frame.timestamp),
                timestampBasis: .remoteRTP90kNanoseconds,
                sourceRole: .remotePeer,
                width: Int(frame.header.width),
                height: Int(frame.header.height),
                pixelFormat: "bgra8",
                frameRate: VideoFrameRate(
                    numerator: Int(frame.header.frameRateNumerator),
                    denominator: max(1, Int(frame.header.frameRateDenominator))
                ),
                fingerprint: "ultragrid-rx-\(frame.header.bufferNumber)-\(frame.sequenceNumber)"
            ),
            payload: bgra
        ))
    }

    private func checkedProduct(_ lhs: Int, _ rhs: Int) throws -> Int {
        let result = lhs.multipliedReportingOverflow(by: rhs)
        guard !result.overflow else { throw UltraGridRawVideoPreviewError.arithmeticOverflow }
        return result.partialValue
    }

    private func timestampNanoseconds(fromRTP90k timestamp: UInt32) throws -> UInt64 {
        let scaled = UInt64(timestamp).multipliedReportingOverflow(by: 1_000_000_000)
        guard !scaled.overflow else { throw UltraGridRawVideoPreviewError.arithmeticOverflow }
        return scaled.partialValue / UInt64(UltraGridCompatibility.videoClockRateHertz)
    }

    private func validatePayload(_ payload: Data, expected: Int) throws {
        guard payload.count == expected else {
            throw UltraGridRawVideoPreviewError.payloadSizeMismatch(expected: expected, actual: payload.count)
        }
    }

    private func swizzleRGBAtoBGRA(_ rgba: Data) -> Data {
        var bgra = rgba
        for offset in stride(from: 0, to: bgra.count, by: 4) { bgra.swapAt(offset, offset + 2) }
        return bgra
    }

    private func expandRGB3toBGRA(_ rgb: Data, byteCount: Int) -> Data {
        var bgra = Data(capacity: byteCount)
        for offset in stride(from: 0, to: rgb.count, by: 3) {
            bgra.append(rgb[offset + 2])
            bgra.append(rgb[offset + 1])
            bgra.append(rgb[offset])
            bgra.append(255)
        }
        return bgra
    }
}
