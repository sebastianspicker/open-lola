// Verifies close-race accounting at the raw BGRA AppKit preview boundary.
import AppKit
import Foundation
import Testing

@testable import OpenLolaCore

@Suite(.serialized)
struct RawBGRAAppKitPreviewWindowTests {
    @Test
    @MainActor
    func dropsDequeuedFrameClosedBeforeMainActorDelivery() async throws {
        let deliveryGate = RawBGRAPreviewDeliveryGate()
        let preview = RawBGRAAppKitPreviewWindow(beforeMainActorDelivery: {
            deliveryGate.markDequeuedAndWaitForDelivery()
        })
        let frame = RawCapturedVideoFrame(
            metadata: CapturedVideoFrame(
                streamID: 1,
                sequenceNumber: 1,
                timestampNanoseconds: 1,
                timestampBasis: .hostUptimeNanoseconds,
                sourceRole: .testPattern,
                width: 1,
                height: 1,
                pixelFormat: "bgra8",
                frameRate: VideoFrameRate(numerator: 30, denominator: 1),
                fingerprint: "close-race-frame"
            ),
            payload: Data([0, 0, 0, 255])
        )

        try preview.submit(frame: frame)
        #expect(await deliveryGate.waitUntilDequeued())
        preview.close()
        deliveryGate.allowDelivery()

        for _ in 0 ..< 100 where preview.droppedFrameCount == 0 {
            await Task.yield()
        }
        #expect(preview.droppedFrameCount == 1)
        #expect(preview.renderedFrameCount == 0)
    }

    @Test
    @MainActor
    func reopensAfterOperatorClosesWindow() async throws {
        let preview = RawBGRAAppKitPreviewWindow()
        try preview.submit(frame: makePreviewFrame(sequenceNumber: 1))
        #expect(await preview.waitUntilRenderedFrameCount(reaches: 1))
        #expect(preview.hasPreviewWindowForTesting)
        #expect(preview.previewWindowIsReleasedWhenClosedForTesting == false)

        preview.performCloseForTesting()
        #expect(!preview.hasPreviewWindowForTesting)

        try preview.submit(frame: makePreviewFrame(sequenceNumber: 2))
        #expect(await preview.waitUntilRenderedFrameCount(reaches: 2))
        #expect(preview.hasPreviewWindowForTesting)
        #expect(preview.previewWindowIsReleasedWhenClosedForTesting == false)
        preview.close()
    }
}

@MainActor
private func makePreviewFrame(sequenceNumber: UInt64) -> RawCapturedVideoFrame {
    RawCapturedVideoFrame(
        metadata: CapturedVideoFrame(
            streamID: 1,
            sequenceNumber: sequenceNumber,
            timestampNanoseconds: sequenceNumber,
            timestampBasis: .hostUptimeNanoseconds,
            sourceRole: .testPattern,
            width: 1,
            height: 1,
            pixelFormat: "bgra8",
            frameRate: VideoFrameRate(numerator: 30, denominator: 1),
            fingerprint: "operator-close-\(sequenceNumber)"
        ),
        payload: Data([0, 0, 0, 255])
    )
}

@MainActor
private extension RawBGRAAppKitPreviewWindow {
    func waitUntilRenderedFrameCount(reaches target: Int) async -> Bool {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: .seconds(1))
        while clock.now < deadline {
            if renderedFrameCount >= target {
                return true
            }
            await Task.yield()
        }
        return false
    }
}

private final class RawBGRAPreviewDeliveryGate: @unchecked Sendable {
    private let condition = NSCondition()
    private var dequeued = false
    private var deliveryAllowed = false

    func markDequeuedAndWaitForDelivery() {
        condition.lock()
        dequeued = true
        condition.broadcast()
        while !deliveryAllowed {
            condition.wait()
        }
        condition.unlock()
    }

    func waitUntilDequeued() async -> Bool {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: .seconds(1))
        while clock.now < deadline {
            let wasDequeued = condition.withLock { dequeued }
            if wasDequeued {
                return true
            }
            await Task.yield()
        }
        return false
    }

    func allowDelivery() {
        condition.lock()
        deliveryAllowed = true
        condition.broadcast()
        condition.unlock()
    }
}
