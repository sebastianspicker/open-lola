import OpenLolaEvidenceModels
import OpenLolaSessionDomain
import OpenLolaContracts
// Coordinates network diagnostics execution and its result lifecycle, keeping runtime side effects separate from protocol values and validation policy.
import Dispatch
import Foundation

/// Runs NetworkDiagnosticsRunner while keeping its stateful execution separate from report validation.
public enum NetworkDiagnosticsRunner {
    /// Runs ping and traceroute against `configuration.peer`; a peer that is neither an IP literal nor a hostname
    /// is refused before either tool starts, so it can never be read as an option.
    public static func run(configuration: NetworkDiagnosticsRunConfiguration) -> NetworkDiagnosticsReport {
        guard isValidPeer(configuration.peer) else {
            let refused = ProcessResult(
                output: "",
                exitCode: -1,
                timedOut: false,
                spawnError: "refused to run: peer \(configuration.peer.debugDescription) "
                    + "is not an IP address or hostname"
            )
            return makeReport(configuration: configuration, pingProcess: refused, tracerouteProcess: refused)
        }
        // Both tools parse options with getopt, so "--" ends option parsing before the peer.
        let pingProcess = runNetworkDiagnosticsProcess(
            executable: "/sbin/ping",
            arguments: ["-c", "\(configuration.pingCount)", "-n", "--", configuration.peer],
            timeoutSeconds: max(2, configuration.pingCount + 2)
        )
        let tracerouteProcess = runNetworkDiagnosticsProcess(
            executable: "/usr/sbin/traceroute",
            arguments: ["-n", "-m", "\(configuration.maxHops)", "--", configuration.peer],
            timeoutSeconds: max(2, configuration.maxHops + 2)
        )
        return makeReport(
            configuration: configuration,
            pingProcess: pingProcess,
            tracerouteProcess: tracerouteProcess
        )
    }

    /// True for an IPv4 or IPv6 literal, or an RFC 1123 hostname (letters, digits and inner hyphens per label, at
    /// most 253 characters); anything starting with "-" or holding spaces or other characters is rejected.
    public static func isValidPeer(_ peer: String) -> Bool {
        var ipv4 = in_addr()
        var ipv6 = in6_addr()
        if inet_pton(AF_INET, peer, &ipv4) == 1 || inet_pton(AF_INET6, peer, &ipv6) == 1 {
            return true
        }
        let name = peer.hasSuffix(".") ? String(peer.dropLast()) : peer
        guard !name.isEmpty, name.utf8.count <= 253 else {
            return false
        }
        return name.split(separator: ".", omittingEmptySubsequences: false).allSatisfy(isValidHostnameLabel)
    }

    private static func isValidHostnameLabel(_ label: Substring) -> Bool {
        guard (1...63).contains(label.utf8.count), label.first != "-", label.last != "-" else {
            return false
        }
        return label.unicodeScalars.allSatisfy { $0.isASCII && (CharacterSet.alphanumerics.contains($0) || $0 == "-") }
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
