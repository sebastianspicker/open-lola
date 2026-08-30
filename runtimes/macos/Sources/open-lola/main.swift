// Boots the OpenLola executable and keeps process-level setup outside the command implementations.
import Darwin
import Foundation
import OpenLolaCore
import OpenLolaApplication

let arguments = Array(CommandLine.arguments.dropFirst())
do {
    try runOpenLolaCommand(arguments)
} catch {
    writeError("error: \(commandErrorDescription(error))")
    exit(1)
}

func runOpenLolaCommand(_ arguments: [String]) throws {
    switch arguments {
    case [], ["help"], ["--help"], ["-h"]:
        printTopLevelUsage()
        return
    default:
        break
    }

    let delegatedCommandHandlers: [([String]) throws -> Bool] = [
        handleNetworkCommand,
        handleMadiReceiveCommand,
        handleMadiFullDuplexCommand,
        handleLatencyProfileCommand,
        handlePerformanceCommand,
        handleE2EBenchmarkCommand,
        handleMilestoneCommand
    ]
    if try delegatedCommandHandlers.contains(where: { try $0(arguments) }) {
        return
    }

    let registry = openLolaCommandRegistry()
    guard let commandName = arguments.first,
          let command = registry[commandName] else {
        printTopLevelUsage()
        throw CommandError.invalidArgument(arguments.joined(separator: " "))
    }
    try command.run(args: Array(arguments.dropFirst()))
}

protocol Command {
    var name: String { get }
    var argumentCount: Int { get }

    func run(args: [String]) throws
}

struct RegisteredCommand: Command {
    let name: String
    let argumentCount: Int
    let body: ([String]) throws -> Void

    func run(args: [String]) throws {
        guard args.count == argumentCount else {
            throw CommandError.invalidArgument("\(name) expected \(argumentCount) argument(s), got \(args.count)")
        }
        try body(args)
    }
}

func openLolaCommandRegistry() -> [String: any Command] {
    Dictionary(uniqueKeysWithValues: openLolaCommands().map { ($0.name, $0) })
}

func openLolaCommands() -> [any Command] {
    baseOpenLolaCommands() + udpPcmOneShotCommands()
}

private func baseOpenLolaCommands() -> [any Command] {
    [
        RegisteredCommand(name: "session-capabilities", argumentCount: 0) { _ in
            let report = OpenLolaCLI.localCapabilitySet()
            try report.validate()
            print(try report.prettyJSONString())
            printVerdict(.pass)
        }
    ]
}

private func udpPcmOneShotCommands() -> [any Command] {
    [
        RegisteredCommand(name: "udp-pcm-send-once", argumentCount: 2) { args in
            guard let port = UInt16(args[1]) else {
                throw CommandError.invalidPort(args[1])
            }
            let packet = try UdpPcmOneShotSender.send(host: args[0], port: port)
            print("udp-pcm sent once: host=\(args[0]) port=\(port) seq=\(packet.header.sequenceNumber)")
            printVerdict(.pass)
        },
        RegisteredCommand(name: "udp-pcm-receive-once", argumentCount: 1) { args in
            guard let port = UInt16(args[0]) else {
                throw CommandError.invalidPort(args[0])
            }
            let packet = try UdpPcmOneShotReceiver.receive(port: port)
            print("udp-pcm received once: seq=\(packet.header.sequenceNumber) bytes=\(packet.header.payloadByteCount)")
            printVerdict(.pass)
        }
    ]
}

func printVerdict(_ verdict: MeasurementVerdict) {
    print("VERDICT: \(verdict.rawValue.uppercased())")
}

func printSummary() {
    let summary = CapabilitySummary.current

    print(summary.description)
    for capability in summary.capabilities {
        print("- \(capability)")
    }
}

func printTopLevelUsage() {
    print("Usage: open-lola <command> [...]")
    print("")
    print("Commands:")
    for command in openLolaCommands().map(\.name).sorted() {
        print("  \(command)")
    }
    print("")
    print("Use '<command> --help' for command-specific arguments where available.")
    print("udp-pcm-route-run physical evidence flags include --route-label --route-topology --sender-label " +
        "--sender-host --sender-ip --receiver-label --receiver-host --receiver-ip --link-rate-mbps --vlan " +
        "--multicast-policy --capture-notes --dscp-not-tested-reason --report-id --title --notes.")
}

func writeError(_ message: String) {
    FileHandle.standardError.write(Data((message + "\n").utf8))
}

func readPacketData(from url: URL) throws -> Data {
    let data = try BoundedFileReader.data(at: url)
    if url.pathExtension.lowercased() == "hex" {
        return try UdpPcmHexFixture.decode(data)
    }
    return data
}

func loadJSON<T: Decodable>(_ type: T.Type, from path: String) throws -> T {
    try BoundedFileReader.decodeJSON(type, fromPath: path)
}

func writeJSONData(_ data: Data, to path: String) throws {
    let outputURL = URL(fileURLWithPath: path)
    try FileManager.default.createDirectory(
        at: outputURL.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    try data.write(to: outputURL, options: [.atomic])
}

func requiredArgument(_ name: String, in args: [String]) throws -> String {
    guard let index = args.firstIndex(of: name),
          index + 1 < args.count else {
        throw CommandError.invalidArgument("missing \(name)")
    }
    return args[index + 1]
}

enum CommandError: Error, Equatable {
    case invalidPort(String)
    case invalidArgument(String)
    case loopbackRunFailed(String)
}

func commandErrorDescription(_ error: Error) -> String {
    switch error {
    case let command as CommandError:
        switch command {
        case .invalidPort(let value):
            return "invalid port \(value)"
        case .invalidArgument(let value):
            return "invalid argument: \(value)"
        case .loopbackRunFailed(let value):
            return "loopback run failed: \(value)"
        }
    default:
        return String(describing: error)
    }
}
