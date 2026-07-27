// Shares bounded payload collection state across AVFoundation video collectors.
import Foundation

final class LoLaAVFoundationPayloadCollectionState: @unchecked Sendable {
    let expectedWidth: Int
    let expectedHeight: Int
    private let targetFrameCount: Int
    private let condition = NSCondition()
    private var payloads: [Data] = []
    private var failure: LoLaVideoPayloadError?

    init(expectedWidth: Int, expectedHeight: Int, targetFrameCount: Int) {
        self.expectedWidth = expectedWidth
        self.expectedHeight = expectedHeight
        self.targetFrameCount = targetFrameCount
    }

    var payloadCount: Int {
        condition.lock()
        defer { condition.unlock() }
        return payloads.count
    }

    func waitForPayloads(until deadline: Date) {
        condition.lock()
        defer { condition.unlock() }
        while payloads.count < targetFrameCount, failure == nil, Date() < deadline {
            condition.wait(until: deadline)
        }
    }

    func append(_ payload: Data) {
        condition.lock()
        defer { condition.unlock() }
        guard payloads.count < targetFrameCount else { return }
        payloads.append(payload)
        condition.signal()
    }

    func record(_ error: LoLaVideoPayloadError) {
        condition.lock()
        defer { condition.unlock() }
        failure = error
        condition.signal()
    }

    func result() throws -> [Data] {
        condition.lock()
        defer { condition.unlock() }
        if let failure { throw failure }
        guard payloads.count >= targetFrameCount else {
            throw LoLaVideoPayloadError.captureUnavailable
        }
        return Array(payloads.prefix(targetFrameCount))
    }

    func dimensionMismatchError(actualWidth: Int, actualHeight: Int) -> LoLaVideoPayloadError? {
        guard actualWidth != expectedWidth || actualHeight != expectedHeight else { return nil }
        return .frameDimensionMismatch(
            expectedWidth: expectedWidth,
            expectedHeight: expectedHeight,
            actualWidth: actualWidth,
            actualHeight: actualHeight
        )
    }
}
