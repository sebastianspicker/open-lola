// Translates MilestoneExternalConnectorCommands command syntax into core API calls, keeping CLI parsing independent from domain services.
import Foundation
import OpenLolaCore

func handleMilestoneExternalConnectorCommand(_ arguments: [String]) throws -> Bool {
    if try handleMilestoneExternalConnectorCoreCommand(arguments) { return true }
    if try handleMilestoneExternalConnectorNmpCommand(arguments) { return true }
    return false
}

private func handleMilestoneExternalConnectorCoreCommand(_ arguments: [String]) throws -> Bool {
    switch arguments {
    case ["external-connector-synthetic-smoke"]:
        let report = ExternalConnectorSyntheticSmoke.run()
        try report.validate()
        print(try report.prettyJSONString())
        print("source-level-verdict: \(report.sourceLevelVerdict.rawValue)")
        print("real-world-verdict: \(report.realWorldVerdict.rawValue)")
        printVerdict(report.verdict)
    case let args where args.count == 3 && args[0] == "external-connector-report-run" && args[1] == "--output":
        let report = ExternalConnectorSyntheticSmoke.run()
        try writeValidatedReport(report, to: args[2])
        print("external connector report written: \(args[2])")
        print("connectors: \(report.connectors.count)")
        print("source-level-verdict: \(report.sourceLevelVerdict.rawValue)")
        print("real-world-verdict: \(report.realWorldVerdict.rawValue)")
        printVerdict(report.verdict)
    case let args where args.first == "external-connector-session-run":
        try runExternalConnectorSessionCommand(args)
    case let args where args.first == "external-connector-connection-plan-run":
        try runExternalConnectorConnectionPlanCommand(args)
    case let args where args.first == "external-connector-executable-preflight-run":
        try runExternalConnectorExecutablePreflightCommand(args)
    default:
        return false
    }
    return true
}

private func handleMilestoneExternalConnectorNmpCommand(_ arguments: [String]) throws -> Bool {
    switch arguments {
    case let args where args.first == "external-connector-nmp-plan-run":
        try runExternalConnectorNmpPlanCommand(args)
    case let args where args.first == "external-connector-nmp-preflight-run":
        try runExternalConnectorNmpPreflightCommand(args)
    case let args where args.first == "external-connector-nmp-endpoint-run":
        try runExternalConnectorNmpEndpointCommand(args)
    case let args where args.first == "external-connector-nmp-workflow-run":
        try runExternalConnectorNmpWorkflowCommand(args)
    default:
        return false
    }
    return true
}

private func runExternalConnectorSessionCommand(_ args: [String]) throws {
    let configuration = try ExternalConnectorSessionConfiguration.parse(Array(args.dropFirst()))
    let report = try ExternalConnectorSessionRunner.run(configuration: configuration)
    try writeValidatedReport(report, to: configuration.outputPath)
    print("external connector session report written: \(configuration.outputPath)")
    print("connector: \(report.connector.rawValue)")
    print("role: \(report.role.rawValue)")
    print("dry-run: \(report.dryRun)")
    printVerdict(report.verdict)
}

private func runExternalConnectorConnectionPlanCommand(_ args: [String]) throws {
    let configuration = try ExternalConnectorConnectionPlanConfiguration.parse(Array(args.dropFirst()))
    let report = try ExternalConnectorConnectionPlanRunner.run(configuration: configuration)
    try writeValidatedReport(report, to: configuration.outputPath)
    print("external connector connection plan written: \(configuration.outputPath)")
    print("connector: \(report.connector.rawValue)")
    print("endpoints: \(report.endpoints.count)")
    printVerdict(report.verdict)
}

private func runExternalConnectorExecutablePreflightCommand(_ args: [String]) throws {
    let configuration = try ExternalConnectorExecutablePreflightConfiguration.parse(Array(args.dropFirst()))
    let report = ExternalConnectorExecutablePreflightRunner.run(configuration: configuration)
    try writeValidatedReport(report, to: configuration.outputPath)
    print("external connector executable preflight written: \(configuration.outputPath)")
    print("probes: \(report.probes.count)")
    print("failing-probes: \(report.probes.filter { $0.verdict == .fail }.count)")
    printVerdict(report.verdict)
}

private func runExternalConnectorNmpPlanCommand(_ args: [String]) throws {
    let configuration = try ExternalConnectorNmpPlanConfiguration.parse(Array(args.dropFirst()))
    let report = try ExternalConnectorNmpPlanRunner.run(configuration: configuration)
    try writeValidatedReport(report, to: configuration.outputPath)
    print("external connector NMP plan written: \(configuration.outputPath)")
    print("connectors: \(report.connectors.count)")
    print("plans: \(report.plans.count)")
    printVerdict(report.verdict)
}

private func runExternalConnectorNmpPreflightCommand(_ args: [String]) throws {
    let configuration = try ExternalConnectorNmpPreflightConfiguration.parse(Array(args.dropFirst()))
    let plan = try ExternalConnectorNmpPlanReport.readValidated(fromPath: configuration.planPath)
    let report = try ExternalConnectorNmpPreflightRunner.run(configuration: configuration, plan: plan)
    try writeValidatedReport(report, to: configuration.outputPath)
    print("external connector NMP preflight written: \(configuration.outputPath)")
    print("plan: \(report.planID)")
    print("results: \(report.results.count)")
    printVerdict(report.verdict)
}

private func runExternalConnectorNmpEndpointCommand(_ args: [String]) throws {
    let configuration = try ExternalConnectorNmpEndpointRunConfiguration.parse(Array(args.dropFirst()))
    let plan = try ExternalConnectorNmpPlanReport.readValidated(fromPath: configuration.planPath)
    let preflight = try configuration.preflightPath.map {
        try ExternalConnectorNmpPreflightReport.readValidated(fromPath: $0)
    }
    let report = try ExternalConnectorNmpEndpointRunRunner.run(
        configuration: configuration,
        plan: plan,
        preflight: preflight
    )
    try writeValidatedReport(report, to: configuration.outputPath)
    print("external connector NMP endpoint run written: \(configuration.outputPath)")
    print("plan: \(report.planID)")
    print("side: \(report.side.rawValue)")
    print("results: \(report.results.count)")
    printVerdict(report.verdict)
}

private func runExternalConnectorNmpWorkflowCommand(_ args: [String]) throws {
    let configuration = try ExternalConnectorNmpWorkflowConfiguration.parse(Array(args.dropFirst()))
    let report = try ExternalConnectorNmpWorkflowRunner.run(configuration: configuration)
    try report.validate()
    try writeJSONData(try report.plan.prettyJSONData(), to: report.planPath)
    try writeJSONData(try report.preflight.prettyJSONData(), to: report.preflightPath)
    try writeJSONData(try report.endpointRun.prettyJSONData(), to: report.endpointRunPath)
    try writeJSONData(try report.prettyJSONData(), to: configuration.outputPath)
    print("external connector NMP workflow written: \(configuration.outputPath)")
    print("plan: \(report.planPath)")
    print("preflight: \(report.preflightPath)")
    print("endpoint-run: \(report.endpointRunPath)")
    print("side: \(report.side.rawValue)")
    printVerdict(report.verdict)
}
