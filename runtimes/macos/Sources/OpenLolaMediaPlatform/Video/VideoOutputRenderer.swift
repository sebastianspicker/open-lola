// Paces reassembled video frames for preview or hardware output and records submission outcomes.
import Foundation

private let videoOutputLatencySampleLimit = 10_000

/// Defines `metricsOnly`, `localPreview`, `blackmagicDeckLink`, and `disabled` states used to make video output backend kind decisions in video capture and frame transport.
public enum VideoOutputBackendKind: String, Codable, Equatable, Sendable {
    case metricsOnly
    case localPreview
    case blackmagicDeckLink
    case disabled
}

/// Sets the frame-pacing rule used before a video output backend receives a frame.
public enum VideoFramePacingPolicy: String, Codable, Equatable, Sendable {
    case latestOnly
    case deadline
    case continuity
}

/// Associates `packet`, `receivedAtNanoseconds`, and `reassembledAtNanoseconds` with one frame as it moves through video transport.
public struct VideoOutputFrame: Equatable, Sendable {
    public var packet: VideoTransportPacket
    public var receivedAtNanoseconds: UInt64
    public var reassembledAtNanoseconds: UInt64

    public init(
        packet: VideoTransportPacket,
        receivedAtNanoseconds: UInt64,
        reassembledAtNanoseconds: UInt64
    ) {
        self.packet = packet
        self.receivedAtNanoseconds = receivedAtNanoseconds
        self.reassembledAtNanoseconds = reassembledAtNanoseconds
    }
}

/// Defines `accepted`, `acceptedWithBackpressureDrop`, and `rejected` states used to make video output submit result decisions in video capture and frame transport.
public enum VideoOutputSubmitResult: Equatable, Sendable {
    case accepted
    case acceptedWithBackpressureDrop
    case rejected
}

/// Tracks `backend`, `pacingPolicy`, `framesSubmitted`, and `framesRendered` to expose latency, pressure, and delivery outcomes in video capture and frame transport.
public struct VideoRenderOutputMetrics: Codable, Equatable, Sendable {
    public var backend: VideoOutputBackendKind
    public var pacingPolicy: VideoFramePacingPolicy
    public var framesSubmitted: Int
    public var framesRendered: Int
    public var framesOutput: Int
    public var framesDroppedLate: Int
    public var framesDroppedBackpressure: Int
    public var framesDroppedContinuity: Int
    public var observedQueueDepth: Int
    public var receiveToReassembly: UdpPcmPacketAgeMetrics
    public var reassemblyToRender: UdpPcmPacketAgeMetrics
    public var renderToOutput: UdpPcmPacketAgeMetrics

    /// Identifies the output backend and its frame-pacing policy.
    public struct Configuration: Equatable, Sendable {
        public var backend: VideoOutputBackendKind
        public var pacingPolicy: VideoFramePacingPolicy

        public init(
            backend: VideoOutputBackendKind,
            pacingPolicy: VideoFramePacingPolicy
        ) {
            self.backend = backend
            self.pacingPolicy = pacingPolicy
        }
    }

    /// Counts rendered, output, and dropped frames observed by the renderer.
    public struct FrameDelivery: Equatable, Sendable {
        public var framesSubmitted: Int
        public var framesRendered: Int
        public var framesOutput: Int
        public var framesDroppedLate: Int
        public var framesDroppedBackpressure: Int
        public var framesDroppedContinuity: Int
        public var observedQueueDepth: Int

        public init(
            framesSubmitted: Int,
            framesRendered: Int,
            framesOutput: Int,
            framesDroppedLate: Int,
            framesDroppedBackpressure: Int,
            framesDroppedContinuity: Int,
            observedQueueDepth: Int
        ) {
            self.framesSubmitted = framesSubmitted
            self.framesRendered = framesRendered
            self.framesOutput = framesOutput
            self.framesDroppedLate = framesDroppedLate
            self.framesDroppedBackpressure = framesDroppedBackpressure
            self.framesDroppedContinuity = framesDroppedContinuity
            self.observedQueueDepth = observedQueueDepth
        }
    }

    /// Captures the elapsed times between receive, reassembly, render, and output.
    public struct Latency: Equatable, Sendable {
        public var receiveToReassembly: UdpPcmPacketAgeMetrics
        public var reassemblyToRender: UdpPcmPacketAgeMetrics
        public var renderToOutput: UdpPcmPacketAgeMetrics

        public init(
            receiveToReassembly: UdpPcmPacketAgeMetrics,
            reassemblyToRender: UdpPcmPacketAgeMetrics,
            renderToOutput: UdpPcmPacketAgeMetrics
        ) {
            self.receiveToReassembly = receiveToReassembly
            self.reassemblyToRender = reassemblyToRender
            self.renderToOutput = renderToOutput
        }
    }

    public init(
        configuration: Configuration,
        frameDelivery: FrameDelivery,
        latency: Latency
    ) {
        backend = configuration.backend
        pacingPolicy = configuration.pacingPolicy
        framesSubmitted = frameDelivery.framesSubmitted
        framesRendered = frameDelivery.framesRendered
        framesOutput = frameDelivery.framesOutput
        framesDroppedLate = frameDelivery.framesDroppedLate
        framesDroppedBackpressure = frameDelivery.framesDroppedBackpressure
        framesDroppedContinuity = frameDelivery.framesDroppedContinuity
        observedQueueDepth = frameDelivery.observedQueueDepth
        receiveToReassembly = latency.receiveToReassembly
        reassemblyToRender = latency.reassemblyToRender
        renderToOutput = latency.renderToOutput
    }
}

/// Schedules `backend`, `pacingPolicy`, `maxQueueDepth`, and `deadlineNanoseconds` for output while retaining the pacing results of video capture and frame transport.
public struct VideoOutputRenderer: Equatable, Sendable {
    public var backend: VideoOutputBackendKind
    public var pacingPolicy: VideoFramePacingPolicy
    public var maxQueueDepth: Int
    public var deadlineNanoseconds: UInt64?
    private var queue: [VideoOutputFrame]
    private var framesSubmitted: Int
    private var framesRendered: Int
    private var framesOutput: Int
    private var framesDroppedLate: Int
    private var framesDroppedBackpressure: Int
    private var framesDroppedContinuity: Int
    private var observedQueueDepth: Int
    private var lastOutputSequenceNumberByStreamID: [UInt32: UInt64]
    private var receiveToReassemblyMicroseconds: BoundedDoubleSamples
    private var reassemblyToRenderMicroseconds: BoundedDoubleSamples
    private var renderToOutputMicroseconds: BoundedDoubleSamples

    public init(
        backend: VideoOutputBackendKind,
        pacingPolicy: VideoFramePacingPolicy,
        maxQueueDepth: Int,
        deadlineNanoseconds: UInt64? = nil
    ) {
        self.backend = backend
        self.pacingPolicy = pacingPolicy
        self.maxQueueDepth = max(0, maxQueueDepth)
        self.deadlineNanoseconds = deadlineNanoseconds
        queue = []
        queue.reserveCapacity(max(0, maxQueueDepth))
        framesSubmitted = 0
        framesRendered = 0
        framesOutput = 0
        framesDroppedLate = 0
        framesDroppedBackpressure = 0
        framesDroppedContinuity = 0
        observedQueueDepth = 0
        lastOutputSequenceNumberByStreamID = [:]
        receiveToReassemblyMicroseconds = BoundedDoubleSamples(capacity: videoOutputLatencySampleLimit)
        reassemblyToRenderMicroseconds = BoundedDoubleSamples(capacity: videoOutputLatencySampleLimit)
        renderToOutputMicroseconds = BoundedDoubleSamples(capacity: videoOutputLatencySampleLimit)
    }

    public var metrics: VideoRenderOutputMetrics {
        VideoRenderOutputMetrics(
            configuration: .init(
                backend: backend,
                pacingPolicy: pacingPolicy
            ),
            frameDelivery: .init(
                framesSubmitted: framesSubmitted,
                framesRendered: framesRendered,
                framesOutput: framesOutput,
                framesDroppedLate: framesDroppedLate,
                framesDroppedBackpressure: framesDroppedBackpressure,
                framesDroppedContinuity: framesDroppedContinuity,
                observedQueueDepth: observedQueueDepth
            ),
            latency: .init(
                receiveToReassembly: videoTransportPacketAgeMetrics(for: receiveToReassemblyMicroseconds.samples),
                reassemblyToRender: videoTransportPacketAgeMetrics(for: reassemblyToRenderMicroseconds.samples),
                renderToOutput: videoTransportPacketAgeMetrics(for: renderToOutputMicroseconds.samples)
            )
        )
    }

    @discardableResult
    public mutating func submit(
        _ frame: VideoOutputFrame,
        renderAtNanoseconds: UInt64
    ) -> VideoOutputSubmitResult {
        framesSubmitted += 1
        guard backend != .disabled, maxQueueDepth > 0 else {
            framesDroppedBackpressure += 1
            return .rejected
        }
        guard !isLate(frame.packet, renderAtNanoseconds: renderAtNanoseconds) else {
            framesDroppedLate += 1
            return .rejected
        }
        guard keepsContinuity(frame.packet) else {
            framesDroppedContinuity += 1
            return .rejected
        }

        queue.append(frame)
        if queue.count > maxQueueDepth {
            let dropCount = queue.count - maxQueueDepth
            queue.removeFirst(dropCount)
            framesDroppedBackpressure += dropCount
            observedQueueDepth = max(observedQueueDepth, queue.count)
            return queue.contains(frame) ? .acceptedWithBackpressureDrop : .rejected
        }
        observedQueueDepth = max(observedQueueDepth, queue.count)
        return .accepted
    }

    public mutating func renderNext(
        renderAtNanoseconds: UInt64,
        outputAtNanoseconds: UInt64
    ) -> VideoTransportPacket? {
        guard !queue.isEmpty else {
            return nil
        }
        let frame = queue.removeFirst()
        framesRendered += 1
        receiveToReassemblyMicroseconds.append(
            videoOutputMicroseconds(from: frame.receivedAtNanoseconds, to: frame.reassembledAtNanoseconds)
        )
        reassemblyToRenderMicroseconds.append(
            videoOutputMicroseconds(from: frame.reassembledAtNanoseconds, to: renderAtNanoseconds)
        )
        lastOutputSequenceNumberByStreamID[frame.packet.streamID] = frame.packet.sequenceNumber
        if backend != .metricsOnly {
            framesOutput += 1
            renderToOutputMicroseconds.append(
                videoOutputMicroseconds(from: renderAtNanoseconds, to: outputAtNanoseconds)
            )
        }
        return frame.packet
    }

    private func isLate(
        _ packet: VideoTransportPacket,
        renderAtNanoseconds: UInt64
    ) -> Bool {
        guard pacingPolicy == .deadline,
              let deadlineNanoseconds else {
            return false
        }
        return renderAtNanoseconds > packet.timestampNanoseconds
            && renderAtNanoseconds - packet.timestampNanoseconds > deadlineNanoseconds
    }

    private func keepsContinuity(_ packet: VideoTransportPacket) -> Bool {
        guard pacingPolicy == .continuity,
              let previous = lastOutputSequenceNumberByStreamID[packet.streamID] else {
            return true
        }
        return packet.sequenceNumber == previous &+ 1
    }
}

private func videoOutputMicroseconds(from start: UInt64, to end: UInt64) -> Double {
    guard end >= start else {
        return 0
    }
    return Double(end - start) / 1_000
}

private struct BoundedDoubleSamples: Equatable, Sendable {
    private let capacity: Int
    private var storage: [Double]
    private var startIndex: Int

    init(capacity: Int) {
        self.capacity = max(1, capacity)
        storage = []
        storage.reserveCapacity(self.capacity)
        startIndex = 0
    }

    mutating func append(_ value: Double) {
        guard storage.count == capacity else {
            storage.append(value)
            return
        }
        storage[startIndex] = value
        startIndex = (startIndex + 1) % capacity
    }

    var samples: [Double] {
        guard storage.count == capacity, startIndex > 0 else {
            return storage
        }
        return Array(storage[startIndex..<storage.count]) + Array(storage[0..<startIndex])
    }
}
