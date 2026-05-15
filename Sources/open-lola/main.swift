import Darwin
import Foundation
import OpenLolaCore

private let outputFlag = "--" + "output"

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

    if try handleNetworkCommand(arguments) {
        return
    }
    if try handleMadiReceiveCommand(arguments) {
        return
    }
    if try handleMadiFullDuplexCommand(arguments) {
        return
    }
    if try handleLatencyProfileCommand(arguments) {
        return
    }
    if try handlePerformanceCommand(arguments) {
        return
    }
    if try handleE2EBenchmarkCommand(arguments) {
        return
    }
    if try handleMilestoneCommand(arguments) {
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
    [
        RegisteredCommand(name: "session-capabilities", argumentCount: 0) { _ in
            print(try OpenLolaCLI.sessionCapabilitiesJSONString())
            printVerdict(.pass)
        },
        RegisteredCommand(name: "fixture-smoke-matrix", argumentCount: 0) { _ in
            print(try OpenLolaCLI.fixtureSmokeMatrixJSONString())
            printVerdict(.partial)
        },
        RegisteredCommand(name: "command-inventory", argumentCount: 0) { _ in
            print(try OpenLolaCLI.commandInventoryJSONString())
            printVerdict(.partial)
        },
        RegisteredCommand(name: "report-schema-inventory", argumentCount: 0) { _ in
            print(try OpenLolaCLI.reportSchemaInventoryJSONString())
            printVerdict(.partial)
        },
        RegisteredCommand(name: "goal-codewise-closure", argumentCount: 0) { _ in
            let report = GoalCodewiseClosureReport.codewiseClosure()
            try printGoalCodewiseClosure(report)
        },
        RegisteredCommand(name: "goal-codewise-closure-run", argumentCount: 2) { args in
            try requireOutputFlag(args)
            let report = GoalCodewiseClosureReport.codewiseClosure()
            try report.validate()
            try writeJSONData(try report.prettyJSONData(), to: args[1])
            print("GOAL.md codewise closure report written: \(args[1])")
            print("real-world-verdict: \(report.realWorldVerdict.rawValue)")
            printVerdict(report.verdict)
        },
        RegisteredCommand(name: "goal-runtime-evidence-template", argumentCount: 0) { _ in
            let report = GoalRuntimeEvidenceTemplateReport.template()
            try report.validate()
            print(try report.prettyJSONString())
            print("real-world-verdict: \(report.realWorldVerdict.rawValue)")
            printVerdict(report.verdict)
        },
        RegisteredCommand(name: "goal-runtime-evidence-template-run", argumentCount: 2) { args in
            try requireOutputFlag(args)
            let report = GoalRuntimeEvidenceTemplateReport.template()
            try report.validate()
            try writeJSONData(try report.prettyJSONData(), to: args[1])
            print("GOAL.md runtime evidence template written: \(args[1])")
            print("real-world-verdict: \(report.realWorldVerdict.rawValue)")
            printVerdict(report.verdict)
        },
        RegisteredCommand(name: "goal-runtime-preflight", argumentCount: 0) { _ in
            let report = GoalRuntimePreflightRunner.run()
            try report.validate()
            print(try report.prettyJSONString())
            print("real-world-verdict: \(report.realWorldVerdict.rawValue)")
            printVerdict(report.verdict)
        },
        RegisteredCommand(name: "goal-runtime-preflight-run", argumentCount: 2) { args in
            try requireOutputFlag(args)
            let report = GoalRuntimePreflightRunner.run()
            try report.validate()
            try writeJSONData(try report.prettyJSONData(), to: args[1])
            print("GOAL.md runtime preflight report written: \(args[1])")
            print("real-world-verdict: \(report.realWorldVerdict.rawValue)")
            printVerdict(report.verdict)
        },
        RegisteredCommand(name: "goal-completion-audit", argumentCount: 0) { _ in
            let report = GoalCompletionAuditRunner.run()
            try printGoalCompletionAudit(report)
        },
        RegisteredCommand(name: "goal-completion-audit-run", argumentCount: 2) { args in
            try requireOutputFlag(args)
            let report = GoalCompletionAuditRunner.run()
            try report.validate()
            try writeJSONData(try report.prettyJSONData(), to: args[1])
            print("GOAL.md completion audit written: \(args[1])")
            print("real-world-verdict: \(report.realWorldVerdict.rawValue)")
            print("blockers: \(report.blockers.count)")
            print("next-actions: \(report.nextActions.count)")
            printVerdict(report.verdict)
        },
        RegisteredCommand(name: "current-evidence-status-matrix", argumentCount: 0) { _ in
            let report = CurrentEvidenceStatusMatrixReport.current()
            try printCurrentEvidenceStatusMatrix(report)
        },
        RegisteredCommand(name: "current-evidence-status-matrix-run", argumentCount: 2) { args in
            try requireOutputFlag(args)
            let report = CurrentEvidenceStatusMatrixReport.current()
            try report.validate()
            try writeJSONData(try report.prettyJSONData(), to: args[1])
            print("current evidence status matrix written: \(args[1])")
            print("source-matrix: \(report.sourceMatrixPath)")
            print("real-world-tasks: \(report.summary.realWorldTaskCount)")
            printVerdict(report.verdict)
        },
        RegisteredCommand(name: "realtime-audio-path-inventory", argumentCount: 0) { _ in
            print(try OpenLolaCLI.realtimeAudioPathInventoryJSONString())
            printVerdict(.partial)
        },
        RegisteredCommand(name: "network-route-command-matrix", argumentCount: 0) { _ in
            print(try OpenLolaCLI.networkRouteCommandMatrixJSONString())
            printVerdict(.partial)
        },
        RegisteredCommand(name: "video-control-degrade-matrix", argumentCount: 0) { _ in
            print(try OpenLolaCLI.videoControlDegradeMatrixJSONString())
            printVerdict(.partial)
        },
        RegisteredCommand(name: "source-ownership-inventory", argumentCount: 0) { _ in
            print(try OpenLolaCLI.sourceOwnershipInventoryJSONString())
            printVerdict(.partial)
        },
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
        },
    ]
}

func requireOutputFlag(_ args: [String]) throws {
    guard args[0] == outputFlag else {
        throw CommandError.invalidArgument("missing --output")
    }
}

func printGoalCodewiseClosure(_ report: GoalCodewiseClosureReport) throws {
    try report.validate()
    print(try report.prettyJSONString())
    print("real-world-verdict: \(report.realWorldVerdict.rawValue)")
    printVerdict(report.verdict)
}

func printGoalCompletionAudit(_ report: GoalCompletionAuditReport) throws {
    try report.validate()
    print(try report.prettyJSONString())
    print("real-world-verdict: \(report.realWorldVerdict.rawValue)")
    print("blockers: \(report.blockers.count)")
    print("next-actions: \(report.nextActions.count)")
    printVerdict(report.verdict)
}

func printCurrentEvidenceStatusMatrix(_ report: CurrentEvidenceStatusMatrixReport) throws {
    try report.validate()
    print(try report.prettyJSONString())
    print("source-matrix: \(report.sourceMatrixPath)")
    print("real-world-tasks: \(report.summary.realWorldTaskCount)")
    printVerdict(report.verdict)
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
    for entry in CLICommandInventory.entries.sorted(by: { $0.command < $1.command }) {
        print("  \(entry.command)")
    }
    print("")
    print("Use '<command> --help' for command-specific arguments where available.")
    print("udp-pcm-route-run physical evidence flags include --route-label --route-topology --sender-label --sender-host --sender-ip --receiver-label --receiver-host --receiver-ip --link-rate-mbps --vlan --multicast-policy --capture-notes --dscp-not-tested-reason --report-id --title --notes.")
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
