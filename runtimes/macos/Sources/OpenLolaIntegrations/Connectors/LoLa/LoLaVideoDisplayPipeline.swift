// Turns received LoLa video datagrams into displayed BGRA frames off the receive thread and counts each stage.
import Dispatch
import Foundation
import OpenLolaMediaPlatform
import OpenLolaSessionDomain
import OpenLolaTransport

/// Counts for the RX video display path: reassembled, decoded and displayed frames.
public struct LoLaVideoDisplayReport: Codable, Equatable, Sendable {
    /// The negotiated payload interpretation, or nil when the RX side cannot display it.
    public var payloadFormat: LoLaReceivedVideoFormat?
    public var reassembledFrameCount: Int
    public var incompleteFrameCount: Int
    public var discardedPacketCount: Int
    public var decodedFrameCount: Int
    public var decodeFailureCount: Int
    /// Frames the display surface reported as rendered.
    public var displayedFrameCount: Int
    /// Frames skipped because a newer one arrived before decode, plus sink drops.
    public var droppedFrameCount: Int
    public var lastDecodeError: String?
    public var notes: String
}

/// True when this session should reassemble, decode and display received LoLa video.
func lolaVideoDisplayEnabled(_ configuration: ExternalConnectorSessionConfiguration) -> Bool {
    !configuration.dryRun
        && configuration.role.receives
        && configuration.mediaMode.hasVideo
        && configuration.videoDisplay == "appkit"
}

/// Receives video datagrams on the media receive thread, reassembles them there,
/// and hands the newest complete frame to a serial queue that converts it and
/// submits it to the sink. A frame that arrives while one is pending replaces it.
final class LoLaVideoDisplayPipeline: @unchecked Sendable {
    private let format: LoLaReceivedVideoFormat?
    private let negotiatedTuple: String
    private let width: Int
    private let height: Int
    private let frameRate: Int
    private let sink: any RawBGRAPreviewSink
    private let queue = DispatchQueue(label: "open-lola.lola.video-display", qos: .userInitiated)
    private let lock = NSLock()
    private var assembler: LoLaVideoFrameAssembler
    private var reassembled = 0
    private var pending: (sequence: UInt32, payload: Data)?
    private var drainScheduled = false
    private var replaced = 0
    private var decoded = 0
    private var decodeFailures = 0
    private var lastDecodeError: String?

    init(configuration: ExternalConnectorSessionConfiguration, sink: any RawBGRAPreviewSink) {
        format = LoLaReceivedVideoFormat.negotiated(
            compression: configuration.videoCompression,
            bitsPerPixel: configuration.videoBitsPerPixel,
            bayer: configuration.videoBayer
        )
        negotiatedTuple = "COMP \(configuration.videoCompression) BPP \(configuration.videoBitsPerPixel)"
        width = configuration.videoWidth
        height = configuration.videoHeight
        frameRate = configuration.videoFrameRate
        // A prelude larger than the negotiated frame could pin memory; the assembler drops it.
        assembler = LoLaVideoFrameAssembler(maximumSerializedSize: LoLaVideoFrameAssembler.maximumSerializedSize(
            compression: configuration.videoCompression,
            width: configuration.videoWidth,
            height: configuration.videoHeight,
            bitsPerPixel: configuration.videoBitsPerPixel
        ))
        self.sink = sink
    }

    /// Builds the pipeline when the display gate is on; `sink` replaces the AppKit window in tests.
    static func makeIfRequested(
        configuration: ExternalConnectorSessionConfiguration,
        sink: (any RawBGRAPreviewSink)? = nil
    ) -> LoLaVideoDisplayPipeline? {
        guard lolaVideoDisplayEnabled(configuration) else { return nil }
        return LoLaVideoDisplayPipeline(configuration: configuration, sink: sink ?? RawBGRAAppKitPreviewWindow())
    }

    /// Accepts one received datagram; audio datagrams are ignored. Never throws,
    /// so a bad video packet cannot count as an audio playout rejection.
    func consume(_ datagram: LoLaUdpMediaDatagram) {
        guard datagram.stream == .video, let frame = assembler.accept(datagram.payload) else { return }
        lock.lock()
        reassembled += 1
        guard let format else {
            lock.unlock()
            return
        }
        if pending != nil { replaced += 1 }
        pending = frame
        let schedule = !drainScheduled
        drainScheduled = true
        lock.unlock()
        if schedule { queue.async { self.drain(format) } }
    }

    /// Closes the sink; safe to call after `finish` and on error paths.
    func close() {
        sink.close()
    }

    /// Waits for queued frames, closes the sink and returns the counts.
    func finish() -> LoLaVideoDisplayReport {
        queue.sync {}
        close()
        lock.lock()
        defer { lock.unlock() }
        let unshown = pending == nil ? 0 : 1
        return LoLaVideoDisplayReport(
            payloadFormat: format,
            reassembledFrameCount: reassembled,
            incompleteFrameCount: assembler.incompleteFrameCount,
            discardedPacketCount: assembler.discardedPacketCount,
            decodedFrameCount: decoded,
            decodeFailureCount: decodeFailures,
            displayedFrameCount: sink.renderedFrameCount,
            droppedFrameCount: replaced + unshown + sink.droppedFrameCount,
            lastDecodeError: lastDecodeError,
            notes: format.map { "Received video was reassembled, decoded as \($0.rawValue) and submitted to the preview." }
                ?? "Received video was reassembled but not displayed: \(negotiatedTuple) is not a displayable LoLa payload."
        )
    }

    private func drain(_ format: LoLaReceivedVideoFormat) {
        while let frame = takePending() {
            do {
                let bgra = try LoLaReceivedVideoConverter.bgra(
                    frame.payload, format: format, width: width, height: height
                )
                try sink.submit(frame: makeFrame(sequence: frame.sequence, bgra: bgra))
                record(error: nil)
            } catch {
                record(error: error)
            }
        }
    }

    private func takePending() -> (sequence: UInt32, payload: Data)? {
        lock.lock()
        defer { lock.unlock() }
        guard let frame = pending else {
            drainScheduled = false
            return nil
        }
        pending = nil
        return frame
    }

    private func record(error: Error?) {
        lock.lock()
        defer { lock.unlock() }
        guard let error else {
            decoded += 1
            return
        }
        decodeFailures += 1
        lastDecodeError = String(describing: error)
    }

    private func makeFrame(sequence: UInt32, bgra: Data) -> RawCapturedVideoFrame {
        RawCapturedVideoFrame(
            metadata: CapturedVideoFrame(
                streamID: 0,
                sequenceNumber: UInt64(sequence),
                timestampNanoseconds: DispatchTime.now().uptimeNanoseconds,
                timestampBasis: .hostUptimeNanoseconds,
                sourceRole: .remotePeer,
                width: width,
                height: height,
                pixelFormat: "bgra8",
                frameRate: VideoFrameRate(numerator: max(1, frameRate), denominator: 1),
                fingerprint: "lola-rx-\(sequence)"
            ),
            payload: bgra
        )
    }
}
