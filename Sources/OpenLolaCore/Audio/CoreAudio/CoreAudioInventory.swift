import CoreAudio
import Foundation

public struct AudioValueRangeSnapshot: Codable, Equatable, Sendable {
    public let minimum: Double
    public let maximum: Double

    public init(minimum: Double, maximum: Double) {
        self.minimum = minimum
        self.maximum = maximum
    }
}

public struct BufferFrameCandidates: Codable, Equatable, Sendable {
    public let inReportedRange: [Int]
    public let outsideReportedRange: [Int]
    public let note: String

    public init(
        candidates: [Int],
        reportedRange: AudioValueRangeSnapshot?,
        note: String = "reported-range-only"
    ) {
        guard let reportedRange else {
            self.inReportedRange = []
            self.outsideReportedRange = candidates
            self.note = "range-unavailable"
            return
        }

        self.inReportedRange = candidates.filter { candidate in
            Double(candidate) >= reportedRange.minimum
                && Double(candidate) <= reportedRange.maximum
        }
        self.outsideReportedRange = candidates.filter { candidate in
            Double(candidate) < reportedRange.minimum
                || Double(candidate) > reportedRange.maximum
        }
        self.note = note
    }

    public init(
        inReportedRange: [Int],
        outsideReportedRange: [Int],
        note: String
    ) {
        self.inReportedRange = inReportedRange
        self.outsideReportedRange = outsideReportedRange
        self.note = note
    }
}

public enum AudioChannelLayoutScope: String, Codable, Equatable, Sendable {
    case input
    case output
}

public struct AudioChannelLayoutSnapshot: Codable, Equatable, Sendable {
    public let scope: AudioChannelLayoutScope
    public let streamChannelCounts: [Int]
    public let totalChannelCount: Int
    public let channelLabels: [String]

    private enum CodingKeys: String, CodingKey {
        case scope
        case streamChannelCounts
        case totalChannelCount
        case channelLabels
    }

    public init(
        scope: AudioChannelLayoutScope,
        streamChannelCounts: [Int],
        channelLabels: [String]? = nil
    ) {
        self.scope = scope
        self.streamChannelCounts = streamChannelCounts
        self.totalChannelCount = streamChannelCounts.reduce(0, +)
        self.channelLabels = channelLabels ?? Self.defaultLabels(
            scope: scope,
            channelCount: totalChannelCount
        )
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let scope = try container.decode(AudioChannelLayoutScope.self, forKey: .scope)
        let streamChannelCounts = try container.decode(
            [Int].self,
            forKey: .streamChannelCounts
        )
        let totalChannelCount = try container.decodeIfPresent(
            Int.self,
            forKey: .totalChannelCount
        ) ?? streamChannelCounts.reduce(0, +)
        let channelLabels = try container.decodeIfPresent(
            [String].self,
            forKey: .channelLabels
        ) ?? Self.defaultLabels(scope: scope, channelCount: totalChannelCount)

        self.scope = scope
        self.streamChannelCounts = streamChannelCounts
        self.totalChannelCount = totalChannelCount
        self.channelLabels = channelLabels
    }

    private static func defaultLabels(
        scope: AudioChannelLayoutScope,
        channelCount: Int
    ) -> [String] {
        guard channelCount > 0 else {
            return []
        }
        return (1...channelCount).map { index in
            "\(scope.rawValue)-\(index)"
        }
    }
}

public struct CoreAudioDeviceInventory: Codable, Equatable, Sendable {
    public let id: UInt32
    public let name: String
    public let uid: String
    public let manufacturer: String?
    public let transportType: String?
    public let isAggregate: Bool
    public let inputChannelCount: Int
    public let outputChannelCount: Int
    public let inputStreamCount: Int
    public let outputStreamCount: Int
    public let inputChannelLayout: AudioChannelLayoutSnapshot
    public let outputChannelLayout: AudioChannelLayoutSnapshot
    public let nominalSampleRateHertz: Double?
    public let availableSampleRateRanges: [AudioValueRangeSnapshot]
    public let currentBufferFrameSize: UInt32?
    public let bufferFrameSizeRange: AudioValueRangeSnapshot?
    public let candidateBufferFrames: BufferFrameCandidates
    public let inputLatencyFrames: UInt32?
    public let outputLatencyFrames: UInt32?
    public let inputSafetyOffsetFrames: UInt32?
    public let outputSafetyOffsetFrames: UInt32?
    public let clockDomain: UInt32?
    public let diagnosticNotes: [String]

    public init(
        id: UInt32,
        name: String,
        uid: String,
        manufacturer: String?,
        transportType: String?,
        isAggregate: Bool,
        inputChannelCount: Int,
        outputChannelCount: Int,
        inputStreamCount: Int,
        outputStreamCount: Int,
        inputChannelLayout: AudioChannelLayoutSnapshot? = nil,
        outputChannelLayout: AudioChannelLayoutSnapshot? = nil,
        nominalSampleRateHertz: Double?,
        availableSampleRateRanges: [AudioValueRangeSnapshot],
        currentBufferFrameSize: UInt32?,
        bufferFrameSizeRange: AudioValueRangeSnapshot?,
        candidateBufferFrames: BufferFrameCandidates,
        inputLatencyFrames: UInt32?,
        outputLatencyFrames: UInt32?,
        inputSafetyOffsetFrames: UInt32?,
        outputSafetyOffsetFrames: UInt32?,
        clockDomain: UInt32?,
        diagnosticNotes: [String]
    ) {
        self.id = id
        self.name = name
        self.uid = uid
        self.manufacturer = manufacturer
        self.transportType = transportType
        self.isAggregate = isAggregate
        self.inputChannelCount = inputChannelCount
        self.outputChannelCount = outputChannelCount
        self.inputStreamCount = inputStreamCount
        self.outputStreamCount = outputStreamCount
        self.inputChannelLayout = inputChannelLayout ?? AudioChannelLayoutSnapshot(
            scope: .input,
            streamChannelCounts: inputChannelCount > 0 ? [inputChannelCount] : []
        )
        self.outputChannelLayout = outputChannelLayout ?? AudioChannelLayoutSnapshot(
            scope: .output,
            streamChannelCounts: outputChannelCount > 0 ? [outputChannelCount] : []
        )
        self.nominalSampleRateHertz = nominalSampleRateHertz
        self.availableSampleRateRanges = availableSampleRateRanges
        self.currentBufferFrameSize = currentBufferFrameSize
        self.bufferFrameSizeRange = bufferFrameSizeRange
        self.candidateBufferFrames = candidateBufferFrames
        self.inputLatencyFrames = inputLatencyFrames
        self.outputLatencyFrames = outputLatencyFrames
        self.inputSafetyOffsetFrames = inputSafetyOffsetFrames
        self.outputSafetyOffsetFrames = outputSafetyOffsetFrames
        self.clockDomain = clockDomain
        self.diagnosticNotes = diagnosticNotes
    }

    public func channelSet(
        scope: AudioChannelLayoutScope,
        sourceKind: AudioChannelSourceKind = .coreAudio
    ) -> AudioChannelSet {
        let layout: AudioChannelLayoutSnapshot
        switch scope {
        case .input:
            layout = inputChannelLayout
        case .output:
            layout = outputChannelLayout
        }

        return AudioChannelSet(
            channels: layout.channelLabels.enumerated().map { index, label in
                AudioChannelDescriptor(
                    stableSourceIndex: index,
                    label: label,
                    sourceKind: sourceKind
                )
            }
        )
    }

    public func selectedChannelSet(
        scope: AudioChannelLayoutScope,
        stableSourceIndices: [Int],
        sourceKind: AudioChannelSourceKind = .coreAudio
    ) throws -> AudioChannelSet {
        let available = channelSet(scope: scope, sourceKind: sourceKind)
            .sortedByStableSourceIndex
        let availableIndices = Set(available.map(\.stableSourceIndex))
        let requestedIndices = Set(stableSourceIndices)
        guard requestedIndices.count == stableSourceIndices.count else {
            throw CoreAudioChannelSelectionError.duplicateChannelIndex
        }
        for index in stableSourceIndices where !availableIndices.contains(index) {
            throw CoreAudioChannelSelectionError.channelIndexOutOfRange(
                index: index,
                available: available.count
            )
        }
        return AudioChannelSet(
            channels: available.filter { requestedIndices.contains($0.stableSourceIndex) }
        )
    }
}

public enum CoreAudioChannelSelectionError: Error, Equatable, Sendable {
    case duplicateChannelIndex
    case channelIndexOutOfRange(index: Int, available: Int)
}

public enum CoreAudioInventoryValidationError: Error, Equatable, Sendable {
    case noDevices
    case missingDeviceIdentity(UInt32)
    case missingDeviceCapabilities(UInt32)
    case channelLayoutScopeMismatch(
        deviceID: UInt32,
        expected: AudioChannelLayoutScope,
        actual: AudioChannelLayoutScope
    )
    case channelLayoutChannelCountMismatch(
        deviceID: UInt32,
        scope: AudioChannelLayoutScope,
        expected: Int,
        actual: Int
    )
    case channelLayoutLabelCountMismatch(
        deviceID: UInt32,
        scope: AudioChannelLayoutScope,
        expected: Int,
        actual: Int
    )
    case negativeChannelLayoutStreamCount(
        deviceID: UInt32,
        scope: AudioChannelLayoutScope,
        value: Int
    )
}

public struct CoreAudioInventoryReport: PrettyJSONCodable, Equatable, Sendable {
    public let capturedAt: String
    public let hostName: String
    public let devices: [CoreAudioDeviceInventory]

    public init(
        capturedAt: String,
        hostName: String,
        devices: [CoreAudioDeviceInventory]
    ) {
        self.capturedAt = capturedAt
        self.hostName = hostName
        self.devices = devices
    }


    public func validate() throws {
        guard !devices.isEmpty else {
            throw CoreAudioInventoryValidationError.noDevices
        }

        for device in devices {
            guard !device.name.isEmpty,
                  !device.uid.isEmpty,
                  !device.uid.hasPrefix("unknown-") else {
                throw CoreAudioInventoryValidationError.missingDeviceIdentity(device.id)
            }
            guard device.nominalSampleRateHertz != nil
                || !device.availableSampleRateRanges.isEmpty
                || device.currentBufferFrameSize != nil
                || device.bufferFrameSizeRange != nil else {
                throw CoreAudioInventoryValidationError.missingDeviceCapabilities(device.id)
            }
            try validateChannelLayout(
                device.inputChannelLayout,
                expectedScope: .input,
                expectedChannelCount: device.inputChannelCount,
                deviceID: device.id
            )
            try validateChannelLayout(
                device.outputChannelLayout,
                expectedScope: .output,
                expectedChannelCount: device.outputChannelCount,
                deviceID: device.id
            )
        }
    }

    private func validateChannelLayout(
        _ layout: AudioChannelLayoutSnapshot,
        expectedScope: AudioChannelLayoutScope,
        expectedChannelCount: Int,
        deviceID: UInt32
    ) throws {
        guard layout.scope == expectedScope else {
            throw CoreAudioInventoryValidationError.channelLayoutScopeMismatch(
                deviceID: deviceID,
                expected: expectedScope,
                actual: layout.scope
            )
        }
        if let negativeCount = layout.streamChannelCounts.first(where: { $0 < 0 }) {
            throw CoreAudioInventoryValidationError.negativeChannelLayoutStreamCount(
                deviceID: deviceID,
                scope: expectedScope,
                value: negativeCount
            )
        }
        guard layout.totalChannelCount == expectedChannelCount else {
            throw CoreAudioInventoryValidationError.channelLayoutChannelCountMismatch(
                deviceID: deviceID,
                scope: expectedScope,
                expected: expectedChannelCount,
                actual: layout.totalChannelCount
            )
        }
        guard layout.channelLabels.count == expectedChannelCount else {
            throw CoreAudioInventoryValidationError.channelLayoutLabelCountMismatch(
                deviceID: deviceID,
                scope: expectedScope,
                expected: expectedChannelCount,
                actual: layout.channelLabels.count
            )
        }
    }

}

public enum CoreAudioInventoryError: Error, Sendable {
    case coreAudioStatus(OSStatus, String)
    case noDevices
}
