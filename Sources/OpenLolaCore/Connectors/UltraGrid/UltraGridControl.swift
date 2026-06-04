import Foundation

public enum UltraGridControlCommand: Codable, Equatable, Sendable {
    case noop
    case stats(Bool)
    case mute
    case muteReceiver(Bool)
    case muteSender(Bool)
    case volume(UltraGridControlVolumeDirection)
    case avDelayMilliseconds(Int)
    case compress(String)
    case module(path: String, message: String)

    private static let literalCommands: [String: UltraGridControlCommand] = [
        "noop": .noop,
        "stats on": .stats(true),
        "stats off": .stats(false),
        "mute": .mute,
        "mute-receiver": .muteReceiver(true),
        "unmute-receiver": .muteReceiver(false),
        "mute-sender": .muteSender(true),
        "unmute-sender": .muteSender(false),
        "volume up": .volume(.up),
        "volume down": .volume(.down),
    ]

    public static func parse(_ value: String) throws -> UltraGridControlCommand {
        let command = try validateExternalConnectorProcessArgument(
            value,
            field: "ultraGrid.controlCommand",
            argumentClass: .ultraGridControlCommand
        )
        if let literal = literalCommands[command] {
            return literal
        }
        if let avDelay = try parseAvDelay(command) {
            return avDelay
        }
        if let compress = try parseCompress(command) {
            return compress
        }
        return try parseModule(command, originalValue: value)
    }

    private static func parseAvDelay(_ command: String) throws -> UltraGridControlCommand? {
        guard command.hasPrefix("av-delay ") else {
            return nil
        }
        let value = String(command.dropFirst("av-delay ".count))
        guard let milliseconds = Int(value), milliseconds >= 0 else {
            throw UltraGridCompatibilityError.invalidField("control.avDelayMilliseconds", -1)
        }
        return .avDelayMilliseconds(milliseconds)
    }

    private static func parseCompress(_ command: String) throws -> UltraGridControlCommand? {
        guard command.hasPrefix("compress ") else {
            return nil
        }
        let value = String(command.dropFirst("compress ".count))
        guard !value.isEmpty else {
            throw UltraGridCompatibilityError.invalidField("control.compress", 0)
        }
        return .compress(value)
    }

    private static func parseModule(_ command: String, originalValue: String) throws -> UltraGridControlCommand {
        let parts = command.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
        guard parts.count == 2 else {
            throw ExternalConnectorSessionError.unknownArgument("--ultragrid-control-command \(originalValue)")
        }
        return .module(path: String(parts[0]), message: String(parts[1]))
    }

    public func encodedLine() throws -> String {
        let command = switch self {
        case .noop:
            "noop"
        case let .stats(enabled):
            enabled ? "stats on" : "stats off"
        case .mute:
            "mute"
        case let .muteReceiver(muted):
            muted ? "mute-receiver" : "unmute-receiver"
        case let .muteSender(muted):
            muted ? "mute-sender" : "unmute-sender"
        case let .volume(direction):
            "volume \(direction.rawValue)"
        case let .avDelayMilliseconds(milliseconds):
            "av-delay \(milliseconds)"
        case let .compress(value):
            "compress \(value)"
        case let .module(path, message):
            "\(path) \(message)"
        }
        return try UltraGridControlCodec.encode(command)
    }
}

public enum UltraGridControlVolumeDirection: String, Codable, Equatable, Sendable {
    case up
    case down
}

public enum UltraGridControlState: String, Codable, Equatable, Sendable {
    case disabled
    case modeled
}

public struct UltraGridControlReport: Codable, Equatable, Sendable {
    public var mode: UltraGridControlMode
    public var port: UInt16
    public var state: UltraGridControlState
    public var commands: [String]
    public var encodedCommandCount: Int
    public var sourceReference: String
    public var notes: String

    public init(
        mode: UltraGridControlMode,
        port: UInt16,
        state: UltraGridControlState,
        commands: [String],
        sourceReference: String = "https://raw.githubusercontent.com/CESNET/UltraGrid/master/src/control_socket.cpp",
        notes: String
    ) {
        self.mode = mode
        self.port = port
        self.state = state
        self.commands = commands
        self.encodedCommandCount = commands.count
        self.sourceReference = sourceReference
        self.notes = notes
    }

    public func validate(fieldPrefix: String) throws {
        try requireExternalConnectorSessionNonEmpty(sourceReference, "\(fieldPrefix).sourceReference")
        try requireExternalConnectorSessionNonEmpty(notes, "\(fieldPrefix).notes")
        guard encodedCommandCount == commands.count else {
            throw ExternalConnectorSessionError.invalidPositiveInteger(
                "\(fieldPrefix).encodedCommandCount",
                String(encodedCommandCount)
            )
        }
        if mode == .disabled {
            guard state == .disabled else {
                throw ExternalConnectorSessionError.unsupportedRuntimeMode("ultragrid-control-disabled-state")
            }
            guard commands.isEmpty else {
                throw ExternalConnectorSessionError.unsupportedRuntimeMode("ultragrid-control-disabled-commands")
            }
        } else {
            guard port > 0 else {
                throw ExternalConnectorSessionError.invalidPort("\(fieldPrefix).port", String(port))
            }
            guard state == .modeled else {
                throw ExternalConnectorSessionError.unsupportedRuntimeMode("ultragrid-control-enabled-state")
            }
        }
    }
}

public enum UltraGridControlCodec {
    public static func encode(_ command: String) throws -> String {
        guard !command.isEmpty else {
            throw ExternalConnectorSessionError.unknownArgument("--ultragrid-control-command")
        }
        guard !command.contains("\r"), !command.contains("\n"), !command.contains("\0") else {
            throw ExternalConnectorSessionError.invalidProcessArgument("ultraGrid.controlCommand", command)
        }
        return "\(command)\r\n"
    }
}

enum UltraGridControlReportBuilder {
    static let defaultControlPort: UInt16 = 5054

    static func report(_ configuration: ExternalConnectorSessionConfiguration) throws -> UltraGridControlReport {
        let encoded = try configuration.ultraGridControlCommands.map { try $0.encodedLine() }
        let port = configuration.controlPort == 0 && configuration.ultraGridControlMode != .disabled
            ? defaultControlPort
            : configuration.controlPort
        if configuration.ultraGridControlMode == .disabled {
            return UltraGridControlReport(
                mode: .disabled,
                port: port,
                state: .disabled,
                commands: [],
                notes: "UltraGrid control socket modeling is disabled for this run."
            )
        }
        return UltraGridControlReport(
            mode: configuration.ultraGridControlMode,
            port: port,
            state: .modeled,
            commands: encoded,
            notes: "Swift-native UltraGrid control command framing is modeled from the public control socket source. No reference peer control-plane response is claimed."
        )
    }
}
