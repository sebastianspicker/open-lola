import Foundation

enum VideoTransportValidator: ReportPrimitiveValidating {
    typealias ValidationError = VideoTransportValidationError
}

func isRawOrIntraFrameTransportMode(_ mode: VideoTransportMode) -> Bool {
    mode == .raw || mode == .intraFrame
}

func normalizedVideoPixelFormat(_ pixelFormat: String) -> String {
    switch pixelFormat.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
    case "bgra", "bgra8", "32bgra", "kcvpixelformattype_32bgra":
        return "bgra8"
    case "rgba", "rgba8", "32rgba":
        return "rgba8"
    case "rgb", "rgb24", "synthetic-rgb":
        return "rgb24"
    case "2vuy", "yuvs", "yuv422":
        return "yuv422"
    default:
        return pixelFormat.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}

func videoBytesPerPixel(for pixelFormat: String) -> Int {
    switch normalizedVideoPixelFormat(pixelFormat) {
    case "rgb24":
        return 3
    case "bgra8", "rgba8":
        return 4
    case "yuv422":
        return 2
    default:
        return 1
    }
}

func requiredVideoTransportRunString(
    _ argument: String,
    _ values: [String: String]
) throws -> String {
    guard let value = values[argument], !value.isEmpty else {
        throw VideoTransportRunConfigurationError.missingRequiredArgument(argument)
    }
    return value
}

func requiredVideoTransportRunPositiveInteger(
    _ argument: String,
    _ values: [String: String]
) throws -> Int {
    let value = try requiredVideoTransportRunString(argument, values)
    guard let integer = Int(value) else {
        throw VideoTransportRunConfigurationError.invalidInteger(argument: argument, value: value)
    }
    guard integer > 0 else {
        throw VideoTransportRunConfigurationError.nonPositiveArgument(argument)
    }
    return integer
}

func optionalVideoTransportRunPositiveInteger(
    _ argument: String,
    _ values: [String: String],
    defaultValue: Int
) throws -> Int {
    guard values[argument] != nil else {
        return defaultValue
    }
    return try requiredVideoTransportRunPositiveInteger(argument, values)
}

func optionalVideoTransportRunPositiveUInt32(
    _ argument: String,
    _ values: [String: String],
    defaultValue: UInt32
) throws -> UInt32 {
    guard let value = values[argument] else {
        return defaultValue
    }
    guard let integer = UInt32(value) else {
        throw VideoTransportRunConfigurationError.invalidInteger(argument: argument, value: value)
    }
    guard integer > 0 else {
        throw VideoTransportRunConfigurationError.nonPositiveArgument(argument)
    }
    return integer
}

func optionalVideoTransportRunPositiveDouble(
    _ argument: String,
    _ values: [String: String],
    defaultValue: Double
) throws -> Double {
    guard let value = values[argument] else {
        return defaultValue
    }
    guard let double = Double(value) else {
        throw VideoTransportRunConfigurationError.invalidDouble(argument: argument, value: value)
    }
    guard double > 0 else {
        throw VideoTransportRunConfigurationError.nonPositiveArgument(argument)
    }
    return double
}

func requiredVideoTransportRunPort(_ values: [String: String]) throws -> UInt16 {
    let rawPort = try requiredVideoTransportRunPositiveInteger("--port", values)
    guard rawPort <= Int(UInt16.max) else {
        throw VideoTransportRunConfigurationError.invalidPort(rawPort)
    }
    return UInt16(rawPort)
}

func optionalVideoTransportRunSourceRole(
    _ argument: String,
    _ values: [String: String],
    defaultValue: VideoStreamRole
) throws -> VideoStreamRole {
    guard let value = values[argument] else {
        return defaultValue
    }
    guard let role = VideoStreamRole(rawValue: value), role != .disabled else {
        throw VideoTransportRunConfigurationError.invalidSourceRole(value)
    }
    return role
}

func videoTransportPacketAgeMetrics(for values: [Double]) -> UdpPcmPacketAgeMetrics {
    UdpPcmPacketAgeMetrics(
        p50Microseconds: videoTransportPercentile(values, rank: 0.50),
        p95Microseconds: videoTransportPercentile(values, rank: 0.95),
        p99Microseconds: videoTransportPercentile(values, rank: 0.99),
        maxMicroseconds: values.max() ?? 0
    )
}

func videoTransportPercentile(_ values: [Double], rank: Double) -> Double {
    guard !values.isEmpty else {
        return 0
    }
    let sorted = values.sorted()
    let boundedRank = min(max(rank, 0), 1)
    let position = Double(sorted.count - 1) * boundedRank
    let lowerIndex = Int(position.rounded(.down))
    let upperIndex = Int(position.rounded(.up))
    if lowerIndex == upperIndex {
        return sorted[lowerIndex]
    }
    let weight = position - Double(lowerIndex)
    return sorted[lowerIndex] + (sorted[upperIndex] - sorted[lowerIndex]) * weight
}
