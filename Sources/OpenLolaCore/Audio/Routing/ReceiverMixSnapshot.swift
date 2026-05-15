import Foundation

public struct ReceiverMixRoute: Codable, Equatable, Sendable {
    public var sourceChannelIndex: Int
    public var destinationChannelIndex: Int
    public var gainDb: Double
    public var muted: Bool
    public var pan: Double

    public init(
        sourceChannelIndex: Int,
        destinationChannelIndex: Int,
        gainDb: Double,
        muted: Bool,
        pan: Double
    ) {
        self.sourceChannelIndex = sourceChannelIndex
        self.destinationChannelIndex = destinationChannelIndex
        self.gainDb = gainDb
        self.muted = muted
        self.pan = pan
    }
}

public struct ReceiverMixSnapshot: Codable, Equatable, Sendable {
    public var routes: [ReceiverMixRoute]
    public var requiresDestructiveDownmix: Bool

    public init(
        routes: [ReceiverMixRoute],
        requiresDestructiveDownmix: Bool
    ) {
        self.routes = routes
        self.requiresDestructiveDownmix = requiresDestructiveDownmix
    }

    public static func identity(
        inputChannels: AudioChannelSet,
        outputChannels: AudioChannelSet
    ) -> ReceiverMixSnapshot {
        let input = inputChannels.sortedByStableSourceIndex
        let output = outputChannels.sortedByStableSourceIndex
        let routeCount = min(input.count, output.count)
        let routes = (0..<routeCount).map { index in
            ReceiverMixRoute(
                sourceChannelIndex: input[index].stableSourceIndex,
                destinationChannelIndex: output[index].stableSourceIndex,
                gainDb: 0,
                muted: false,
                pan: 0
            )
        }

        return ReceiverMixSnapshot(
            routes: routes,
            requiresDestructiveDownmix: input.count > output.count
        )
    }

    public func prepared(
        inputChannelCount: Int,
        outputChannelCount: Int,
        allowDestructiveDownmix: Bool = false
    ) throws -> PreparedReceiverMixSnapshot {
        guard inputChannelCount > 0 else {
            throw ReceiverMixSnapshotError.nonPositiveChannelCount("inputChannelCount")
        }
        guard outputChannelCount > 0 else {
            throw ReceiverMixSnapshotError.nonPositiveChannelCount("outputChannelCount")
        }
        guard allowDestructiveDownmix || !requiresDestructiveDownmix else {
            throw ReceiverMixSnapshotError.destructiveDownmixRequiresExplicitPolicy
        }

        return PreparedReceiverMixSnapshot(
            routes: try routes.map { route in
                try PreparedReceiverMixRoute(
                    route: route,
                    inputChannelCount: inputChannelCount,
                    outputChannelCount: outputChannelCount
                )
            },
            requiresDestructiveDownmix: requiresDestructiveDownmix
        )
    }
}

public enum ReceiverMixSnapshotError: Error, Equatable, Sendable {
    case nonPositiveChannelCount(String)
    case sourceChannelOutOfRange(index: Int, channelCount: Int)
    case destinationChannelOutOfRange(index: Int, channelCount: Int)
    case nonFiniteGain(Double)
    case panOutOfRange(Double)
    case destructiveDownmixRequiresExplicitPolicy
}

let receiverMixPanTolerance = 1e-10

public struct PreparedReceiverMixRoute: Equatable, Sendable {
    public var sourceChannelIndex: Int
    public var destinationChannelIndex: Int
    public var linearGain: Double
    public var leftGain: Double
    public var rightGain: Double
    public var pan: Double
    public var muted: Bool

    public init(
        route: ReceiverMixRoute,
        inputChannelCount: Int,
        outputChannelCount: Int
    ) throws {
        guard route.sourceChannelIndex >= 0,
              route.sourceChannelIndex < inputChannelCount else {
            throw ReceiverMixSnapshotError.sourceChannelOutOfRange(
                index: route.sourceChannelIndex,
                channelCount: inputChannelCount
            )
        }
        guard route.destinationChannelIndex >= 0,
              route.destinationChannelIndex < outputChannelCount else {
            throw ReceiverMixSnapshotError.destinationChannelOutOfRange(
                index: route.destinationChannelIndex,
                channelCount: outputChannelCount
            )
        }
        guard route.gainDb.isFinite else {
            throw ReceiverMixSnapshotError.nonFiniteGain(route.gainDb)
        }
        guard route.pan >= -1.0 - receiverMixPanTolerance,
              route.pan <= 1.0 + receiverMixPanTolerance else {
            throw ReceiverMixSnapshotError.panOutOfRange(route.pan)
        }

        let linearGain = route.muted ? 0 : pow(10, route.gainDb / 20)
        let leftPan = sqrt((1 - route.pan) / 2)
        let rightPan = sqrt((1 + route.pan) / 2)
        self.sourceChannelIndex = route.sourceChannelIndex
        self.destinationChannelIndex = route.destinationChannelIndex
        self.linearGain = linearGain
        self.leftGain = linearGain * leftPan
        self.rightGain = linearGain * rightPan
        self.pan = route.pan
        self.muted = route.muted
    }
}

public struct PreparedReceiverMixSnapshot: Equatable, Sendable {
    public var routes: [PreparedReceiverMixRoute]
    public var requiresDestructiveDownmix: Bool

    public init(routes: [PreparedReceiverMixRoute], requiresDestructiveDownmix: Bool) {
        self.routes = routes
        self.requiresDestructiveDownmix = requiresDestructiveDownmix
    }
}

public struct ReceiverMixSnapshotStore: Sendable {
    public private(set) var snapshot: ReceiverMixSnapshot
    public private(set) var prepared: PreparedReceiverMixSnapshot
    public private(set) var revision: UInt64

    public init(
        initial: ReceiverMixSnapshot,
        inputChannelCount: Int,
        outputChannelCount: Int
    ) throws {
        self.snapshot = initial
        self.prepared = try initial.prepared(
            inputChannelCount: inputChannelCount,
            outputChannelCount: outputChannelCount
        )
        self.revision = 1
    }

    public mutating func replace(
        with replacement: ReceiverMixSnapshot,
        inputChannelCount: Int,
        outputChannelCount: Int
    ) throws {
        let prepared = try replacement.prepared(
            inputChannelCount: inputChannelCount,
            outputChannelCount: outputChannelCount
        )
        self.snapshot = replacement
        self.prepared = prepared
        self.revision &+= 1
    }
}
