import Foundation
import OpenLolaCore

func parseDirectP2PMeshTopologyArguments(_ arguments: [String]) throws -> [String: String] {
    try parseDirectP2PMeshValues(arguments, allowed: ["--output", "--peers"])
}

func directP2PMeshTopologyOutputPath(_ values: [String: String]) throws -> String {
    guard let outputPath = values["--output"], !outputPath.isEmpty else {
        throw CommandError.invalidArgument("missing --output")
    }
    return outputPath
}

func directP2PMeshTopologyPeerCount(_ values: [String: String]) throws -> Int {
    guard let value = values["--peers"] else {
        return 3
    }
    guard let peerCount = Int(value), peerCount >= 3 else {
        throw CommandError.invalidArgument("invalid --peers")
    }
    return peerCount
}

func parseDirectP2PMeshRuntimeArguments(_ arguments: [String]) throws -> [String: String] {
    try parseDirectP2PMeshValues(arguments, allowed: ["--output", "--peers", "--packets"])
}

private func parseDirectP2PMeshValues(_ arguments: [String], allowed: Set<String>) throws -> [String: String] {
    try KeyValueArgumentParser.parseValues(
        arguments,
        allowed: allowed,
        allowsDashPrefixedValues: false,
        unknown: { CommandError.invalidArgument("unknown \($0)") },
        duplicate: { CommandError.invalidArgument("duplicate \($0)") },
        missingValue: { CommandError.invalidArgument("missing value for \($0)") }
    )
}

func directP2PMeshRuntimeOutputPath(_ values: [String: String]) throws -> String {
    guard let outputPath = values["--output"], !outputPath.isEmpty else {
        throw CommandError.invalidArgument("missing --output")
    }
    return outputPath
}

func directP2PMeshRuntimePeerCount(_ values: [String: String]) throws -> Int {
    guard let value = values["--peers"] else {
        return 3
    }
    guard let peerCount = Int(value), peerCount >= 3 else {
        throw CommandError.invalidArgument("invalid --peers")
    }
    return peerCount
}

func directP2PMeshRuntimePacketCount(_ values: [String: String]) throws -> Int {
    guard let value = values["--packets"] else {
        return 1
    }
    guard let packetCount = Int(value), packetCount > 0 else {
        throw CommandError.invalidArgument("invalid --packets")
    }
    return packetCount
}
