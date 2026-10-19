// Describes the machine that wrote a direct-peer session report, using model, chip and OS version only.
import Darwin
import Foundation

/// Records the hardware class a peer ran on so benchmark aggregates can name its machine.
///
/// It deliberately carries no host name, user name, serial number or address. An empty value was not available.
public struct DirectPeerSessionHostIdentity: Codable, Equatable, Sendable {
    /// Model identifier from `sysctl hw.model`, for example `Mac14,6`.
    public var machineModel: String
    /// CPU brand from `sysctl machdep.cpu.brand_string`, for example `Apple M2 Max`.
    public var chipName: String
    /// macOS version from `ProcessInfo`, for example `macOS 14.5.0`.
    public var osVersion: String

    /// Creates a host block from already read values.
    public init(machineModel: String, chipName: String, osVersion: String) {
        self.machineModel = machineModel
        self.chipName = chipName
        self.osVersion = osVersion
    }

    /// Reads the identity of the machine this process runs on.
    public static func current() -> DirectPeerSessionHostIdentity {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        return DirectPeerSessionHostIdentity(
            machineModel: sysctlString("hw.model") ?? "",
            chipName: sysctlString("machdep.cpu.brand_string") ?? "",
            osVersion: "macOS \(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
        )
    }

    private static func sysctlString(_ name: String) -> String? {
        var size = 0
        guard sysctlbyname(name, nil, &size, nil, 0) == 0, size > 1 else {
            return nil
        }
        var buffer = [UInt8](repeating: 0, count: size)
        guard sysctlbyname(name, &buffer, &size, nil, 0) == 0 else {
            return nil
        }
        let text = String(decoding: buffer.prefix(while: { $0 != 0 }), as: UTF8.self)
        return text.isEmpty ? nil : text
    }
}
