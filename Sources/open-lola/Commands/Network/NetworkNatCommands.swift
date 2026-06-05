import Foundation
import OpenLolaCore

func handleNetworkNatCommand(_ arguments: [String]) throws -> Bool {
    if try handleNetworkNatRuntimeCommand(arguments) {
        return true
    }
    if try handleNetworkNatLocalhostSmokeCommand(arguments) {
        return true
    }
    return false
}

private func handleNetworkNatRuntimeCommand(_ arguments: [String]) throws -> Bool {
    switch arguments {
    case let args where args.first == "nat-rendezvous-run":
        try runNatRendezvousCommand(args)
    case let args where args.first == "nat-relay-run":
        try runNatRelayCommand(args)
    case let args where args.first == "nat-rendezvous-forwarder-run":
        try runNatRendezvousForwarderCommand(args)
    case let args where args.first == "nat-friendly-route-run":
        try runNatFriendlyRouteCommand(args)
    default:
        return false
    }
    return true
}

private func handleNetworkNatLocalhostSmokeCommand(_ arguments: [String]) throws -> Bool {
    switch arguments {
    case ["nat-friendly-localhost-smoke"]:
        let report = try NatFriendlyRouteLocalhostSmoke.run()
        try report.validate()
        print(try report.prettyJSONString())
        printVerdict(report.verdict)
    case ["nat-rendezvous-localhost-smoke"]:
        let result = try NatRendezvousLocalhostSmoke.run()
        try result.serverReport.validate()
        for report in result.routeReports {
            try report.validate()
        }
        print(try result.prettyJSONString())
        printVerdict(.partial)
    case ["nat-rendezvous-forwarder-localhost-smoke"]:
        let report = try NatRendezvousForwarderLauncherLocalhostSmoke.run()
        try report.validate()
        print(try report.prettyJSONString())
        printVerdict(.partial)
    case ["nat-relay-fallback-localhost-smoke"]:
        let result = try NatRelayFallbackLocalhostSmoke.run()
        try result.rendezvousReport.validate()
        try result.relayReport.validate()
        for report in result.routeReports {
            try report.validate()
        }
        print(try result.prettyJSONString())
        printVerdict(.partial)
    default:
        return false
    }
    return true
}

private func runNatRendezvousCommand(_ args: [String]) throws {
    let configuration = try NatRendezvousRunConfiguration.parse(Array(args.dropFirst()))
    let report = try NatRendezvousRunner.run(configuration: configuration)
    try report.validate()
    try writeJSONData(try report.prettyJSONData(), to: configuration.outputPath)
    print("NAT rendezvous report written: \(configuration.outputPath)")
    print("session-id: \(configuration.sessionID)")
    print("registrations: \(report.registrations.count)")
    print("mode: \(configuration.mode.rawValue)")
    printVerdict(report.verdict)
}

private func runNatRelayCommand(_ args: [String]) throws {
    let configuration = try NatRelayRunConfiguration.parse(Array(args.dropFirst()))
    let report = try NatRelayRunner.run(configuration: configuration)
    try report.validate()
    try writeJSONData(try report.prettyJSONData(), to: configuration.outputPath)
    print("NAT relay report written: \(configuration.outputPath)")
    print("session-id: \(configuration.sessionID)")
    print("registrations: \(report.registrations.count)")
    print("forwarded-datagrams: \(report.forwardedDatagrams)")
    printVerdict(report.verdict)
}

private func runNatRendezvousForwarderCommand(_ args: [String]) throws {
    let configuration = try NatRendezvousForwarderLauncherConfiguration.parse(Array(args.dropFirst()))
    let report = try NatRendezvousForwarderLauncherRunner.run(configuration: configuration)
    try report.validate()
    try writeJSONData(try report.prettyJSONData(), to: configuration.outputPath)
    print(report.performanceWarning)
    print("NAT rendezvous/UDP forwarder launcher report written: \(configuration.outputPath)")
    print("session-id: \(configuration.sessionID)")
    print("rendezvous-port: \(configuration.rendezvousPort)")
    print("forwarder-port: \(configuration.forwarderPort)")
    printVerdict(report.verdict)
}

private func runNatFriendlyRouteCommand(_ args: [String]) throws {
    let configuration = try NatFriendlyRouteRunConfiguration.parse(Array(args.dropFirst()))
    let result = try NatFriendlyRouteRunner.run(configuration: configuration)
    try result.report.validate()
    try writeJSONData(try result.report.prettyJSONData(), to: configuration.outputPath)
    if let debugTrace = result.debugTrace,
       let debugOutputPath = configuration.debugOutputPath {
        try debugTrace.write(to: debugOutputPath)
    }
    print("NAT-friendly route report written: \(configuration.outputPath)")
    print("session-id: \(configuration.sessionID)")
    print("compatibility-mode: \(result.report.compatibilityMode.rawValue)")
    print("raw-p2p-preferred: \(result.report.rawP2PPreferred)")
    printVerdict(result.report.verdict)
}
