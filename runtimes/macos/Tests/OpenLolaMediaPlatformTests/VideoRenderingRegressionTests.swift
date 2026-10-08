// Protects geometry validation and per-stream frame pacing at the macOS renderer boundary.
import Foundation
import XCTest
@testable import OpenLolaMediaPlatform

final class VideoRenderingRegressionTests: XCTestCase {
    func testPreviewRejectsInvalidAndOverflowingGeometry() {
        for width in [0, -1, Int.max] {
            let source = TestPatternCameraSource(width: 1, height: 1, frameIntervalNanoseconds: 1, pixelFormat: "bgra8")
            var metadata = source.nextFrame()!
            metadata.width = width
            XCTAssertThrowsError(try RawBGRAImageFactory.validate(frame: .init(metadata: metadata, payload: Data())))
        }
        XCTAssertThrowsError(try MediaGeometrySizing.rawFrameByteCountForBitsPerPixel(width: -1, height: -1, bitsPerPixel: 24))
        XCTAssertThrowsError(try MediaGeometrySizing.rawFrameByteCountForBitsPerPixel(width: 0, height: 2, bitsPerPixel: 24))
        XCTAssertEqual(try MediaGeometrySizing.rawFrameByteCountForBitsPerPixel(width: 3, height: 1, bitsPerPixel: 1), 1)
    }

    func testLatestOnlyKeepsNewestFrameForEachStream() {
        var renderer = VideoOutputRenderer(backend: .localPreview, pacingPolicy: .latestOnly, maxQueueDepth: 4)
        XCTAssertEqual(renderer.submit(frame(stream: 1, sequence: 1), renderAtNanoseconds: 0), .accepted)
        XCTAssertEqual(renderer.submit(frame(stream: 2, sequence: 1), renderAtNanoseconds: 0), .accepted)
        XCTAssertEqual(renderer.submit(frame(stream: 1, sequence: 2), renderAtNanoseconds: 0), .acceptedWithBackpressureDrop)
        XCTAssertEqual(renderer.renderNext(renderAtNanoseconds: 1, outputAtNanoseconds: 1)?.streamID, 2)
        XCTAssertEqual(renderer.renderNext(renderAtNanoseconds: 1, outputAtNanoseconds: 1)?.sequenceNumber, 2)
        XCTAssertNil(renderer.renderNext(renderAtNanoseconds: 1, outputAtNanoseconds: 1))
        XCTAssertEqual(renderer.metrics.framesDroppedBackpressure, 1)
        XCTAssertEqual(renderer.submit(frame(stream: 1, sequence: 1), renderAtNanoseconds: 1), .rejected)
    }

    func testLatestOnlySupportsSequenceRollover() {
        var renderer = VideoOutputRenderer(backend: .metricsOnly, pacingPolicy: .latestOnly, maxQueueDepth: 2)
        renderer.submit(frame(stream: 1, sequence: UInt64.max), renderAtNanoseconds: 0)
        XCTAssertEqual(renderer.submit(frame(stream: 1, sequence: 0), renderAtNanoseconds: 0), .acceptedWithBackpressureDrop)
        XCTAssertEqual(renderer.renderNext(renderAtNanoseconds: 0, outputAtNanoseconds: 0)?.sequenceNumber, 0)
    }

    func testDeadlineUsesLocalReceiveClockAndRechecksAtRender() {
        var renderer = VideoOutputRenderer(backend: .localPreview, pacingPolicy: .deadline, maxQueueDepth: 2, deadlineNanoseconds: 10)
        var fresh = frame(stream: 1, sequence: 1)
        fresh.receivedAtNanoseconds = 1_000
        fresh.packet.timestampNanoseconds = 1
        XCTAssertEqual(renderer.submit(fresh, renderAtNanoseconds: 1_005), .accepted)
        XCTAssertNil(renderer.renderNext(renderAtNanoseconds: 1_011, outputAtNanoseconds: 1_011))
        XCTAssertEqual(renderer.metrics.framesDroppedLate, 1)
        XCTAssertEqual(renderer.metrics.framesRendered, 0)
    }

    func testContinuityConsidersFramesAlreadyQueued() {
        var renderer = VideoOutputRenderer(backend: .localPreview, pacingPolicy: .continuity, maxQueueDepth: 4)
        renderer.submit(frame(stream: 1, sequence: 10), renderAtNanoseconds: 0)
        _ = renderer.renderNext(renderAtNanoseconds: 0, outputAtNanoseconds: 0)
        XCTAssertEqual(renderer.submit(frame(stream: 1, sequence: 11), renderAtNanoseconds: 0), .accepted)
        XCTAssertEqual(renderer.submit(frame(stream: 1, sequence: 12), renderAtNanoseconds: 0), .accepted)
        XCTAssertEqual(renderer.submit(frame(stream: 1, sequence: 14), renderAtNanoseconds: 0), .rejected)
        XCTAssertEqual(renderer.renderNext(renderAtNanoseconds: 0, outputAtNanoseconds: 0)?.sequenceNumber, 11)
        XCTAssertEqual(renderer.renderNext(renderAtNanoseconds: 0, outputAtNanoseconds: 0)?.sequenceNumber, 12)
    }

    private func frame(stream: UInt32, sequence: UInt64) -> VideoOutputFrame {
        var fields = VideoTransportPacketFields()
        fields.streamID = stream
        fields.sequenceNumber = sequence
        return .init(packet: VideoTransportPacket(fields), receivedAtNanoseconds: 0, reassembledAtNanoseconds: 0)
    }
}
