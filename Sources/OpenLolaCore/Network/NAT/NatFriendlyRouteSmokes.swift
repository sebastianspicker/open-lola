// Runs deterministic and localhost NAT rendezvous scenarios while labeling their results as compatibility checks rather than Internet traversal proof.
import Darwin
import Dispatch
import Foundation

/// Provides deterministic NatFriendlyRouteSyntheticSmoke coverage without requiring external NAT traversal and relay setup infrastructure.
public enum NatFriendlyRouteSyntheticSmoke {
    public static func run() -> NatFriendlyRouteReport {
        var input = NatFriendlyRouteReportInput()
        input.id = "nat-friendly-synthetic"
        input.capturedAt = "2026-05-03T00:00:00Z"
        input.sessionID = "synthetic-session"
        input.peerID = "sender-a"
        input.role = .sender
        input.rendezvousEndpoint = NatEndpoint(host: "127.0.0.1", port: 7_000)
        input.localEndpoint = NatEndpoint(host: "127.0.0.1", port: 5_004)
        input.compatibilityMode = .directTraversal
        input.rawP2PPreferred = true
        input.traversal = NatTraversalEvidence(
            observedExternalEndpoint: NatEndpoint(host: "127.0.0.1", port: 5_004),
            peerEndpoint: NatEndpoint(host: "127.0.0.1", port: 5_004),
            directCandidateDiscovered: true,
            directTraversalSucceeded: true,
            relayUsed: false,
            keepaliveIntervalMilliseconds: 500,
            addedLatencyMicroseconds: 0
        )
        input.loopback = UdpPcmLoopbackSyntheticSmoke.run()
        input.verdict = .partial
        input.notes = "Synthetic NAT-friendly direct traversal report."
        return NatFriendlyRouteReport(input)
    }
}

/// Provides deterministic NatFriendlyRouteLocalhostSmoke coverage without requiring external NAT traversal and relay setup infrastructure.
public enum NatFriendlyRouteLocalhostSmoke {
    public static func run() throws -> NatFriendlyRouteReport {
        guard var report = try NatRendezvousLocalhostSmoke.run().routeReports.first else {
            throw NatRendezvousSmokeError.timedOut("localhost NAT smoke produced no route reports")
        }
        report.id = "nat-friendly-localhost-smoke-\(Int(Date().timeIntervalSince1970))"
        report.notes = "Localhost NAT-friendly smoke. This is compatibility evidence only."
        return report
    }
}

/// Represents the NatRendezvousLocalhostSmokeResult produced by NAT traversal and relay setup without exposing its execution state.
public struct NatRendezvousLocalhostSmokeResult: PrettyJSONCodable, Equatable, Sendable {
    public var serverReport: NatRendezvousReport
    public var routeReports: [NatFriendlyRouteReport]
}

/// Enumerates failures that callers must handle when working with NAT traversal and relay setup.
public enum NatRendezvousSmokeError: Error, Equatable, Sendable {
    case timedOut(String)
}

final class NatSmokeResultBox<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var result: Result<Value, Error>?

    func set(_ result: Result<Value, Error>) {
        lock.lock()
        defer { lock.unlock() }
        self.result = result
    }

    func get() -> Result<Value, Error>? {
        lock.lock()
        defer { lock.unlock() }
        let result = result
        return result
    }
}

struct NatSmokeWorker<Value> {
    let done: DispatchSemaphore
    let result: NatSmokeResultBox<Value>
}

struct NatReadySmokeWorker<Value> {
    let done: DispatchSemaphore
    let ready: DispatchSemaphore
    let result: NatSmokeResultBox<Value>
}

struct NatLocalhostRouteClientRequest: Sendable {
    let role: NatFriendlyRouteRole
    let peerID: String
    let rendezvousPort: UInt16
    let relayPort: UInt16
    let sessionID: String
    let durationSeconds: Int
}

func startNatSmokeWorker<Value>(
    _ operation: @escaping @Sendable () throws -> Value
) -> NatSmokeWorker<Value> {
    let done = DispatchSemaphore(value: 0)
    let result = NatSmokeResultBox<Value>()
    DispatchQueue.global(qos: .userInitiated).async {
        result.set(Result { try operation() })
        done.signal()
    }
    return NatSmokeWorker(done: done, result: result)
}

func startReadyNatSmokeWorker<Value>(
    _ operation: @escaping @Sendable (_ signalReady: @escaping @Sendable () -> Void) throws -> Value
) -> NatReadySmokeWorker<Value> {
    let done = DispatchSemaphore(value: 0)
    let ready = DispatchSemaphore(value: 0)
    let result = NatSmokeResultBox<Value>()
    DispatchQueue.global(qos: .userInitiated).async {
        result.set(Result { try operation { ready.signal() } })
        done.signal()
    }
    return NatReadySmokeWorker(done: done, ready: ready, result: result)
}

func requireNatSmokeReady<Value>(
    _ worker: NatReadySmokeWorker<Value>,
    timeoutLabel: String
) throws {
    guard worker.ready.wait(timeout: .now() + 2) == .success else {
        throw NatRendezvousSmokeError.timedOut(timeoutLabel)
    }
}

func requireNatSmokeDone<Value>(
    _ worker: NatSmokeWorker<Value>,
    timeoutLabel: String
) throws {
    guard worker.done.wait(timeout: .now() + 8) == .success else {
        throw NatRendezvousSmokeError.timedOut(timeoutLabel)
    }
}

func requireNatSmokeDone<Value>(
    _ worker: NatReadySmokeWorker<Value>,
    timeoutLabel: String
) throws {
    guard worker.done.wait(timeout: .now() + 8) == .success else {
        throw NatRendezvousSmokeError.timedOut(timeoutLabel)
    }
}

func requireNatSmokeResult<Value>(
    _ worker: NatSmokeWorker<Value>,
    timeoutLabel: String
) throws -> Result<Value, Error> {
    guard let result = worker.result.get() else {
        throw NatRendezvousSmokeError.timedOut(timeoutLabel)
    }
    return result
}

func requireNatSmokeResult<Value>(
    _ worker: NatReadySmokeWorker<Value>,
    timeoutLabel: String
) throws -> Result<Value, Error> {
    guard let result = worker.result.get() else {
        throw NatRendezvousSmokeError.timedOut(timeoutLabel)
    }
    return result
}

func natLocalhostRouteClientConfiguration(
    _ request: NatLocalhostRouteClientRequest
) -> NatFriendlyRouteRunConfiguration {
    let identity = NatFriendlyRouteRunConfiguration.Identity(
        role: request.role,
        bindHost: "127.0.0.1",
        peerID: request.peerID,
        sessionID: request.sessionID
    )
    let traversal = NatFriendlyRouteRunConfiguration.Traversal(
        rendezvousHost: "127.0.0.1",
        rendezvousPort: request.rendezvousPort,
        relayHost: "127.0.0.1",
        relayPort: request.relayPort
    )
    let runtime = NatFriendlyRouteRunConfiguration.Runtime(
        localUdpPort: 0,
        durationSeconds: request.durationSeconds,
        rawRouteRttMicroseconds: 0
    )
    let output = NatFriendlyRouteRunConfiguration.Output(reportPath: "stdout", debugPath: nil)
    let input = NatFriendlyRouteRunConfiguration.Input(
        identity: identity,
        traversal: traversal,
        runtime: runtime,
        output: output
    )
    return NatFriendlyRouteRunConfiguration(input)
}

func startNatLocalhostRouteClient(
    _ request: NatLocalhostRouteClientRequest
) -> NatSmokeWorker<NatFriendlyRouteReport> {
    startNatSmokeWorker {
        try NatFriendlyRouteRunner.run(
            configuration: natLocalhostRouteClientConfiguration(request)
        ).report
    }
}

/// Provides deterministic NatRendezvousLocalhostSmoke coverage without requiring external NAT traversal and relay setup infrastructure.
public enum NatRendezvousLocalhostSmoke {
    public static func run() throws -> NatRendezvousLocalhostSmokeResult {
        let rendezvousPort = try availableNatRendezvousPort()
        let unusedRelayPort = try availableNatRendezvousPort()
        let sessionID = "localhost-rendezvous-smoke"
        let server = startRendezvousLocalhostServer(port: rendezvousPort, sessionID: sessionID)
        try requireNatSmokeReady(server, timeoutLabel: "rendezvous listener readiness")

        let sender = startNatLocalhostRouteClient(.init(
            role: .sender,
            peerID: "sender-a",
            rendezvousPort: rendezvousPort,
            relayPort: unusedRelayPort,
            sessionID: sessionID,
            durationSeconds: 2
        ))
        let looper = startNatLocalhostRouteClient(.init(
            role: .looper,
            peerID: "looper-b",
            rendezvousPort: rendezvousPort,
            relayPort: unusedRelayPort,
            sessionID: sessionID,
            durationSeconds: 2
        ))

        try requireNatSmokeDone(sender, timeoutLabel: "sender client")
        try requireNatSmokeDone(looper, timeoutLabel: "looper client")
        try requireNatSmokeDone(server, timeoutLabel: "rendezvous listener")

        return NatRendezvousLocalhostSmokeResult(
            serverReport: try requireNatSmokeResult(server, timeoutLabel: "server result").get(),
            routeReports: [
                try requireNatSmokeResult(sender, timeoutLabel: "sender result").get(),
                try requireNatSmokeResult(looper, timeoutLabel: "looper result").get()
            ]
        )
    }

    private static func startRendezvousLocalhostServer(
        port: UInt16,
        sessionID: String
    ) -> NatReadySmokeWorker<NatRendezvousReport> {
        let configuration = NatRendezvousRunConfiguration(
            bindHost: "127.0.0.1",
            port: port,
            sessionID: sessionID,
            mode: .rendezvousOnly,
            expectedPeerCount: 2,
            timeoutSeconds: 5,
            outputPath: "stdout"
        )
        return startReadyNatSmokeWorker { signalReady in
            try NatRendezvousRunner.run(configuration: configuration, onReady: signalReady)
        }
    }
}
