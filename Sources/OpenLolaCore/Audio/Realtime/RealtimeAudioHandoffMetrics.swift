// Defines callback handoff metrics separately from engine configuration so the runtime model stays cohesive and inspectable.
import Foundation
import OpenLolaContracts

/// Tracks `inputBlocks`, `outputBlocks`, `networkSendBlocks`, and `networkReceiveBlocks` to expose latency, pressure, and delivery outcomes in the callback-driven audio path.
public struct RealtimeAudioHandoffMetrics: Codable, Equatable, Sendable {
    public struct Counters: Equatable, Sendable {
        public var inputBlocks: Int
        public var outputBlocks: Int
        public var networkSendBlocks: Int
        public var networkReceiveBlocks: Int
        public var droppedInputBlocks: Int
        public var droppedNetworkBlocks: Int
        public var outputUnderrunBlocks: Int
        public var callbackOverrunBlocks: Int

        public init(inputBlocks: Int, outputBlocks: Int, networkSendBlocks: Int, networkReceiveBlocks: Int, droppedInputBlocks: Int, droppedNetworkBlocks: Int, outputUnderrunBlocks: Int, callbackOverrunBlocks: Int) {
            self.inputBlocks = inputBlocks
            self.outputBlocks = outputBlocks
            self.networkSendBlocks = networkSendBlocks
            self.networkReceiveBlocks = networkReceiveBlocks
            self.droppedInputBlocks = droppedInputBlocks
            self.droppedNetworkBlocks = droppedNetworkBlocks
            self.outputUnderrunBlocks = outputUnderrunBlocks
            self.callbackOverrunBlocks = callbackOverrunBlocks
        }
    }

    public struct Buffering: Equatable, Sendable {
        public var latePackets: Int
        public var maximumBufferedBlocks: Int
        public var ringCapacityBlocks: Int
        public var fullCaptureRingBlocks: Int
        public var invalidInputBlocks: Int
        public var directInputBlocks: Int
        public var remappedInputBlocks: Int
        public var packetFragmentCount: Int

        public init(latePackets: Int, maximumBufferedBlocks: Int, ringCapacityBlocks: Int, fullCaptureRingBlocks: Int, invalidInputBlocks: Int, directInputBlocks: Int, remappedInputBlocks: Int, packetFragmentCount: Int) {
            self.latePackets = latePackets
            self.maximumBufferedBlocks = maximumBufferedBlocks
            self.ringCapacityBlocks = ringCapacityBlocks
            self.fullCaptureRingBlocks = fullCaptureRingBlocks
            self.invalidInputBlocks = invalidInputBlocks
            self.directInputBlocks = directInputBlocks
            self.remappedInputBlocks = remappedInputBlocks
            self.packetFragmentCount = packetFragmentCount
        }
    }

    public struct Observability: Equatable, Sendable {
        public var allocationWarnings: Int
        public var maximumCaptureRingOccupancyBlocks: Int
        public var maximumPlayoutQueueDepthBlocks: Int
        public var packetizationDuration: PerformanceCounterSummary
        public var depacketizationDuration: PerformanceCounterSummary

        public init(allocationWarnings: Int, maximumCaptureRingOccupancyBlocks: Int, maximumPlayoutQueueDepthBlocks: Int, packetizationDuration: PerformanceCounterSummary, depacketizationDuration: PerformanceCounterSummary) {
            self.allocationWarnings = allocationWarnings
            self.maximumCaptureRingOccupancyBlocks = maximumCaptureRingOccupancyBlocks
            self.maximumPlayoutQueueDepthBlocks = maximumPlayoutQueueDepthBlocks
            self.packetizationDuration = packetizationDuration
            self.depacketizationDuration = depacketizationDuration
        }
    }

    public struct Completion: Equatable, Sendable {
        public var hiddenPlayoutGrowthDetected: Bool
        public var shutdownCompleted: Bool
        public var rxBuffer: RxBufferRuntimeSnapshot?

        public init(hiddenPlayoutGrowthDetected: Bool, shutdownCompleted: Bool, rxBuffer: RxBufferRuntimeSnapshot? = nil) {
            self.hiddenPlayoutGrowthDetected = hiddenPlayoutGrowthDetected
            self.shutdownCompleted = shutdownCompleted
            self.rxBuffer = rxBuffer
        }
    }

    public var inputBlocks: Int
    public var outputBlocks: Int
    public var networkSendBlocks: Int
    public var networkReceiveBlocks: Int
    public var droppedInputBlocks: Int
    public var droppedNetworkBlocks: Int
    public var outputUnderrunBlocks: Int
    public var callbackOverrunBlocks: Int
    public var latePackets: Int
    public var maximumBufferedBlocks: Int
    public var ringCapacityBlocks: Int
    public var fullCaptureRingBlocks: Int
    public var invalidInputBlocks: Int
    public var directInputBlocks: Int
    public var remappedInputBlocks: Int
    public var packetFragmentCount: Int
    public var allocationWarnings: Int
    public var maximumCaptureRingOccupancyBlocks: Int
    public var maximumPlayoutQueueDepthBlocks: Int
    public var packetizationDuration: PerformanceCounterSummary
    public var depacketizationDuration: PerformanceCounterSummary
    public var hiddenPlayoutGrowthDetected: Bool
    public var shutdownCompleted: Bool
    public var rxBuffer: RxBufferRuntimeSnapshot?

    public init(counters: Counters, buffering: Buffering, observability: Observability, completion: Completion) {
        inputBlocks = counters.inputBlocks
        outputBlocks = counters.outputBlocks
        networkSendBlocks = counters.networkSendBlocks
        networkReceiveBlocks = counters.networkReceiveBlocks
        droppedInputBlocks = counters.droppedInputBlocks
        droppedNetworkBlocks = counters.droppedNetworkBlocks
        outputUnderrunBlocks = counters.outputUnderrunBlocks
        callbackOverrunBlocks = counters.callbackOverrunBlocks
        latePackets = buffering.latePackets
        maximumBufferedBlocks = buffering.maximumBufferedBlocks
        ringCapacityBlocks = buffering.ringCapacityBlocks
        fullCaptureRingBlocks = buffering.fullCaptureRingBlocks
        invalidInputBlocks = buffering.invalidInputBlocks
        directInputBlocks = buffering.directInputBlocks
        remappedInputBlocks = buffering.remappedInputBlocks
        packetFragmentCount = buffering.packetFragmentCount
        allocationWarnings = observability.allocationWarnings
        maximumCaptureRingOccupancyBlocks = observability.maximumCaptureRingOccupancyBlocks
        maximumPlayoutQueueDepthBlocks = observability.maximumPlayoutQueueDepthBlocks
        packetizationDuration = observability.packetizationDuration
        depacketizationDuration = observability.depacketizationDuration
        hiddenPlayoutGrowthDetected = completion.hiddenPlayoutGrowthDetected
        shutdownCompleted = completion.shutdownCompleted
        rxBuffer = completion.rxBuffer
    }
}
