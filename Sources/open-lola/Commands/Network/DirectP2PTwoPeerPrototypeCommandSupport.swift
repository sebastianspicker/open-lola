import Foundation
import OpenLolaCore

// Keep "prototype" in this aggregate report until a promoted non-prototype schema
// exists; the local supervisor and validator commands depend on this public name.
func runDirectP2PTwoPeerPrototypeReportCommand(_ arguments: [String]) throws {
    let values = try parseDirectP2PTwoPeerPrototypeArguments(arguments)
    let peerAReportPath = try directP2PTwoPeerPrototypeRequired("--peer-a-report", values)
    let peerBReportPath = try directP2PTwoPeerPrototypeRequired("--peer-b-report", values)
    let outputPath = try directP2PTwoPeerPrototypeRequired("--output", values)
    let peerARXProofPath = values["--peer-a-rx-proof"]
    let peerBRXProofPath = values["--peer-b-rx-proof"]
    let report = try DirectPeerTwoPeerPrototypeReportBuilder.makeReport(
        peerAReportPath: peerAReportPath,
        peerAReport: try directP2PReadSessionReport(peerAReportPath),
        peerARXProofPath: peerARXProofPath,
        peerARXProof: try directP2PReadRXProof(peerARXProofPath),
        peerBReportPath: peerBReportPath,
        peerBReport: try directP2PReadSessionReport(peerBReportPath),
        peerBRXProofPath: peerBRXProofPath,
        peerBRXProof: try directP2PReadRXProof(peerBRXProofPath)
    )
    try writeJSONData(try report.prettyJSONData(), to: outputPath)
    print("direct P2P two-peer prototype report written: \(outputPath)")
    print("peer-reports: \(report.peerEvidence.count)")
    print("rx-proof-artifacts: \(report.peerEvidence.filter { $0.rxProofPath != nil }.count)")
    printVerdict(report.verdict)
}

private func parseDirectP2PTwoPeerPrototypeArguments(_ arguments: [String]) throws -> [String: String] {
    let allowed = Set(["--peer-a-report", "--peer-b-report", "--peer-a-rx-proof", "--peer-b-rx-proof", "--output"])
    var values: [String: String] = [:]
    var index = 0
    while index < arguments.count {
        let key = arguments[index]
        guard allowed.contains(key) else {
            throw CommandError.invalidArgument("unknown \(key)")
        }
        guard values[key] == nil else {
            throw CommandError.invalidArgument("duplicate \(key)")
        }
        guard index + 1 < arguments.count, !arguments[index + 1].hasPrefix("--") else {
            throw CommandError.invalidArgument("missing value for \(key)")
        }
        values[key] = arguments[index + 1]
        index += 2
    }
    _ = try directP2PTwoPeerPrototypeRequired("--peer-a-report", values)
    _ = try directP2PTwoPeerPrototypeRequired("--peer-b-report", values)
    _ = try directP2PTwoPeerPrototypeRequired("--output", values)
    return values
}

private func directP2PTwoPeerPrototypeRequired(
    _ argument: String,
    _ values: [String: String]
) throws -> String {
    guard let value = values[argument], !value.isEmpty else {
        throw CommandError.invalidArgument("missing \(argument)")
    }
    return value
}

private func directP2PReadSessionReport(_ path: String) throws -> DirectPeerSessionReport {
    try loadJSON(DirectPeerSessionReport.self, from: path)
}

private func directP2PReadRXProof(_ path: String?) throws -> DirectPeerSessionReceiveProofArtifact? {
    guard let path else {
        return nil
    }
    return try loadJSON(DirectPeerSessionReceiveProofArtifact.self, from: path)
}
