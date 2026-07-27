// Coordinates network diagnostics execution and its result lifecycle, keeping runtime side effects separate from protocol values and validation policy.
import Dispatch
import Foundation

/// Runs NetworkDiagnosticsRunner while keeping its stateful execution separate from report validation.
public enum NetworkDiagnosticsRunner {
    public static func run(configuration: NetworkDiagnosticsRunConfiguration) -> NetworkDiagnosticsReport {
        let pingProcess = runNetworkDiagnosticsProcess(
            executable: "/sbin/ping",
            arguments: ["-c", "\(configuration.pingCount)", "-n", configuration.peer],
            timeoutSeconds: max(2, configuration.pingCount + 2)
        )
        let tracerouteProcess = runNetworkDiagnosticsProcess(
            executable: "/usr/sbin/traceroute",
            arguments: ["-n", "-m", "\(configuration.maxHops)", configuration.peer],
            timeoutSeconds: max(2, configuration.maxHops + 2)
        )
        return makeReport(
            configuration: configuration,
            pingProcess: pingProcess,
            tracerouteProcess: tracerouteProcess
        )
    }

    static func makeReport(
        configuration: NetworkDiagnosticsRunConfiguration,
        pingProcess: ProcessResult,
        tracerouteProcess: ProcessResult
    ) -> NetworkDiagnosticsReport {
        let pingOutcome = parsePingResult(pingProcess)
        let tracerouteOutcome = parseTracerouteResult(tracerouteProcess)
        let verdict = pingOutcome.error == nil && tracerouteOutcome.error == nil
            ? networkDiagnosticsVerdict(ping: pingOutcome.result, traceroute: tracerouteOutcome.result)
            : .partial
        return NetworkDiagnosticsReport(
            identity: NetworkDiagnosticsReport.Identity(
                id: "network-diagnostics-\(Int(Date().timeIntervalSince1970))",
                capturedAt: ISO8601DateFormatter().string(from: Date()),
                peer: configuration.peer
            ),
            ping: NetworkDiagnosticsReport.PingEvidence(
                result: pingOutcome.result,
                error: pingOutcome.error
            ),
            traceroute: NetworkDiagnosticsReport.TracerouteEvidence(
                result: tracerouteOutcome.result,
                error: tracerouteOutcome.error
            ),
            verdict: verdict,
            notes: "ICMP ping and traceroute are diagnostic comparisons only; they do not prove audio latency."
        )
    }

    private static func parsePingResult(
        _ processResult: ProcessResult
    ) -> NetworkDiagnosticsPingOutcome {
        if let spawnError = processResult.spawnError {
            return NetworkDiagnosticsPingOutcome(
                result: nil,
                error: "ping process failed: \(spawnError)"
            )
        }
        if processResult.timedOut {
            return NetworkDiagnosticsPingOutcome(result: nil, error: "ping timed out")
        }
        do {
            let ping = try NetworkDiagnosticsParser.parsePing(processResult.output)
            let error = processResult.exitCode == 0 ? nil : "ping exited with status \(processResult.exitCode)"
            return NetworkDiagnosticsPingOutcome(result: ping, error: error)
        } catch {
            var reason = "ping parse failed: \(error)"
            if processResult.exitCode != 0 {
                reason += "; ping exited with status \(processResult.exitCode)"
            }
            return NetworkDiagnosticsPingOutcome(result: nil, error: reason)
        }
    }

    private static func parseTracerouteResult(
        _ processResult: ProcessResult
    ) -> NetworkDiagnosticsTracerouteOutcome {
        if let spawnError = processResult.spawnError {
            let traceroute = NetworkTracerouteResult(
                hops: [],
                blocked: true,
                blockedReason: "traceroute process failed: \(spawnError)"
            )
            return NetworkDiagnosticsTracerouteOutcome(
                result: traceroute,
                error: traceroute.blockedReason
            )
        }
        let parsed: NetworkTracerouteResult
        do {
            parsed = try NetworkDiagnosticsParser.parseTraceroute(processResult.output)
        } catch {
            let reason = "traceroute parse failed: \(error)"
            let traceroute = NetworkTracerouteResult(hops: [], blocked: true, blockedReason: reason)
            return NetworkDiagnosticsTracerouteOutcome(result: traceroute, error: reason)
        }
        if processResult.timedOut {
            let traceroute = NetworkTracerouteResult(
                hops: parsed.hops,
                blocked: true,
                blockedReason: "traceroute timed out"
            )
            return NetworkDiagnosticsTracerouteOutcome(
                result: traceroute,
                error: traceroute.blockedReason
            )
        }
        let error = processResult.exitCode == 0 ? nil : "traceroute exited with status \(processResult.exitCode)"
        return NetworkDiagnosticsTracerouteOutcome(result: parsed, error: error)
    }
}

private struct NetworkDiagnosticsPingOutcome {
    let result: NetworkPingResult?
    let error: String?
}

private struct NetworkDiagnosticsTracerouteOutcome {
    let result: NetworkTracerouteResult
    let error: String?
}

func networkDiagnosticsVerdict(
    ping: NetworkPingResult?,
    traceroute: NetworkTracerouteResult
) -> MeasurementVerdict {
    guard let ping,
          ping.received > 0,
          ping.packetLossPercent == 0,
          networkDiagnosticsPingMeetsPassThresholds(ping),
          !traceroute.blocked else {
        return .partial
    }
    return .pass
}

struct ProcessResult {
    let output: String
    let exitCode: Int32
    let timedOut: Bool
    let spawnError: String?
}

func runNetworkDiagnosticsProcess(
    executable: String,
    arguments: [String],
    timeoutSeconds: Int
) -> ProcessResult {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: executable)
    process.arguments = arguments
    let outputPipe = Pipe()
    let outputCapture = BoundedPipeCapture(pipe: outputPipe)
    process.standardOutput = outputPipe
    process.standardError = outputPipe
    let terminated = DispatchSemaphore(value: 0)
    process.terminationHandler = { _ in
        terminated.signal()
    }
    do {
        try process.run()
        outputCapture.closeWriteHandle()
    } catch {
        outputCapture.closeWriteHandle()
        return ProcessResult(
            output: "",
            exitCode: -1,
            timedOut: false,
            spawnError: "\(error)"
        )
    }

    let timedOut = terminated.wait(timeout: .now() + .seconds(timeoutSeconds)) == .timedOut
    if timedOut {
        process.terminate()
        let exitedAfterTerminate = terminated.wait(timeout: .now() + .milliseconds(500)) == .success
        if !exitedAfterTerminate, process.isRunning {
            _ = kill(process.processIdentifier, SIGKILL)
            _ = terminated.wait(timeout: .now() + .seconds(2))
        }
    }
    let didExit = !process.isRunning
    return ProcessResult(
        output: outputCapture.prefix(drainToEnd: didExit),
        exitCode: didExit ? process.terminationStatus : -1,
        timedOut: timedOut,
        spawnError: nil
    )
}
