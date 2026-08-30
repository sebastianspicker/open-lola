// Supplies DirectP2PSessionRunManualConfigurationSupport helpers, keeping command assembly details out of the primary CLI flow.
import Foundation
import OpenLolaCore

func directP2PSessionManualConfiguration(
    _ values: [String: String],
    packetCount: Int
) throws -> DirectPeerSessionManualRunConfiguration {
    let roleText = try directP2PRequiredString("--role", values)
    guard let role = DirectPeerSessionManualRole(rawValue: roleText) else {
        throw CommandError.invalidArgument("invalid --role")
    }
    return DirectPeerSessionManualRunConfiguration(identity: .init(role: role, localPeerID: try directP2PRequiredString("--local-peer", values), remotePeerID: try directP2PRequiredString("--remote-peer", values)), network: .init(localHost: try directP2PRequiredString("--local-host", values), remoteHost: try directP2PRequiredString("--remote-host", values), ports: .init(controlPort: try directP2PRequiredPort("--control-port", values), remoteControlPort: try directP2PRequiredPort("--remote-control-port", values), audioPort: try directP2PRequiredPort("--audio-port", values), videoPort: try directP2PRequiredPort("--video-port", values), metricsPort: try directP2PRequiredPort("--metrics-port", values))), tuning: .init(packetCount: packetCount, audioChannelCount: try directP2POptionalPositiveInt("--channels", values) ?? 2, timeoutSeconds: try directP2POptionalPositiveInt("--timeout-seconds", values) ?? 5, dscp: try directP2POptionalDscp(values)))
}

func directP2PRequiredString(
    _ key: String,
    _ values: [String: String]
) throws -> String {
    guard let value = values[key], !value.isEmpty else {
        throw CommandError.invalidArgument("missing \(key)")
    }
    return value
}

func directP2PRequiredPort(
    _ key: String,
    _ values: [String: String]
) throws -> UInt16 {
    let value = try directP2PRequiredString(key, values)
    guard let port = UInt16(value), port > 0 else {
        throw CommandError.invalidArgument("invalid \(key)")
    }
    return port
}

func directP2POptionalPositiveInt(
    _ key: String,
    _ values: [String: String]
) throws -> Int? {
    guard let value = values[key] else {
        return nil
    }
    guard let number = Int(value), number > 0 else {
        throw CommandError.invalidArgument("invalid \(key)")
    }
    let maximum = directP2PMaximumPositiveInteger(for: key)
    guard number <= maximum else {
        throw CommandError.invalidArgument("invalid \(key)")
    }
    return number
}

func directP2PMaximumPositiveInteger(for key: String) -> Int {
    directP2PPositiveIntegerBounds[key] ?? 1_000_000
}

func directP2POptionalDscp(_ values: [String: String]) throws -> Int? {
    guard let value = values["--dscp"] else {
        return nil
    }
    guard let dscp = Int(value), dscp >= 0, dscp <= 63 else {
        throw CommandError.invalidArgument("invalid --dscp")
    }
    return dscp
}

func directP2PRequiredPositiveInt(
    _ key: String,
    _ values: [String: String]
) throws -> Int {
    guard let number = try directP2POptionalPositiveInt(key, values) else {
        throw CommandError.invalidArgument("missing \(key)")
    }
    return number
}

func directP2PSampleFormat(_ value: String) throws -> UdpPcmSampleFormat {
    do {
        return try DirectPeerSessionAVMediaShape.sampleFormat(from: value)
    } catch {
        throw CommandError.invalidArgument("invalid --sample-format")
    }
}

func directP2PVideoPixelFormat(_ value: String) throws -> String {
    do {
        return try DirectPeerSessionAVMediaShape.normalizedVideoPixelFormat(from: value)
    } catch {
        throw CommandError.invalidArgument("invalid --video-pixel-format")
    }
}

func directP2POptionalChannelCSV(
    _ key: String,
    _ values: [String: String],
    expectedCount: Int
) throws -> [Int]? {
    guard let value = values[key] else {
        return nil
    }
    let channels = value.split(separator: ",").map(String.init)
    guard !channels.isEmpty else {
        throw CommandError.invalidArgument("invalid \(key)")
    }
    guard channels.count == expectedCount else {
        throw CommandError.invalidArgument("\(key) must contain \(expectedCount) entries")
    }
    return try channels.map { channel in
        guard let number = Int(channel), number >= 0 else {
            throw CommandError.invalidArgument("invalid \(key)")
        }
        return number
    }
}
