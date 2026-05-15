import Darwin
import Dispatch
import Foundation

public enum NatFriendlyRouteSyntheticSmoke {
    public static func run() -> NatFriendlyRouteReport {
        NatFriendlyRouteReport(
            id: "nat-friendly-synthetic",
            capturedAt: "2026-05-03T00:00:00Z",
            sessionID: "synthetic-session",
            peerID: "sender-a",
            role: .sender,
            rendezvousEndpoint: NatEndpoint(host: "127.0.0.1", port: 7_000),
            localEndpoint: NatEndpoint(host: "127.0.0.1", port: 5_004),
            compatibilityMode: .directTraversal,
            rawP2PPreferred: true,
            traversal: NatTraversalEvidence(
                observedExternalEndpoint: NatEndpoint(host: "127.0.0.1", port: 5_004),
                peerEndpoint: NatEndpoint(host: "127.0.0.1", port: 5_004),
                directCandidateDiscovered: true,
                directTraversalSucceeded: true,
                relayUsed: false,
                keepaliveIntervalMilliseconds: 500,
                addedLatencyMicroseconds: 0
            ),
            loopback: UdpPcmLoopbackSyntheticSmoke.run(),
            verdict: .partial,
            notes: "Synthetic NAT-friendly direct traversal report."
        )
    }
}

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

public struct NatRendezvousLocalhostSmokeResult: PrettyJSONCodable, Equatable, Sendable {
    public var serverReport: NatRendezvousReport
    public var routeReports: [NatFriendlyRouteReport]
}

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

public enum NatRendezvousLocalhostSmoke {
    public static func run() throws -> NatRendezvousLocalhostSmokeResult {
        let rendezvousPort = try availableNatRendezvousPort()
        let unusedRelayPort = try availableNatRendezvousPort()
        let sessionID = "localhost-rendezvous-smoke"
        let serverConfiguration = NatRendezvousRunConfiguration(
            bindHost: "127.0.0.1",
            port: rendezvousPort,
            sessionID: sessionID,
            mode: .rendezvousOnly,
            expectedPeerCount: 2,
            timeoutSeconds: 5,
            outputPath: "stdout"
        )

        let serverDone = DispatchSemaphore(value: 0)
        let serverReady = DispatchSemaphore(value: 0)
        let serverResult = NatSmokeResultBox<NatRendezvousReport>()
        DispatchQueue.global(qos: .userInitiated).async {
            let result = Result {
                try NatRendezvousRunner.run(
                    configuration: serverConfiguration,
                    onReady: { serverReady.signal() }
                )
            }
            serverResult.set(result)
            serverDone.signal()
        }
        guard serverReady.wait(timeout: .now() + 2) == .success else {
            throw NatRendezvousSmokeError.timedOut("rendezvous listener readiness")
        }

        let senderDone = DispatchSemaphore(value: 0)
        let looperDone = DispatchSemaphore(value: 0)
        let senderResult = NatSmokeResultBox<NatFriendlyRouteReport>()
        let looperResult = NatSmokeResultBox<NatFriendlyRouteReport>()

        DispatchQueue.global(qos: .userInitiated).async {
            let result = Result {
                try NatFriendlyRouteRunner.run(
                    configuration: NatFriendlyRouteRunConfiguration(
                        role: .sender,
                        bindHost: "127.0.0.1",
                        peerID: "sender-a",
                        rendezvousHost: "127.0.0.1",
                        rendezvousPort: rendezvousPort,
                        relayHost: "127.0.0.1",
                        relayPort: unusedRelayPort,
                        sessionID: sessionID,
                        localUdpPort: 0,
                        durationSeconds: 2,
                        rawRouteRttMicroseconds: 0,
                        outputPath: "stdout",
                        debugOutputPath: nil
                    )
                ).report
            }
            senderResult.set(result)
            senderDone.signal()
        }

        DispatchQueue.global(qos: .userInitiated).async {
            let result = Result {
                try NatFriendlyRouteRunner.run(
                    configuration: NatFriendlyRouteRunConfiguration(
                        role: .looper,
                        bindHost: "127.0.0.1",
                        peerID: "looper-b",
                        rendezvousHost: "127.0.0.1",
                        rendezvousPort: rendezvousPort,
                        relayHost: "127.0.0.1",
                        relayPort: unusedRelayPort,
                        sessionID: sessionID,
                        localUdpPort: 0,
                        durationSeconds: 2,
                        rawRouteRttMicroseconds: 0,
                        outputPath: "stdout",
                        debugOutputPath: nil
                    )
                ).report
            }
            looperResult.set(result)
            looperDone.signal()
        }

        guard senderDone.wait(timeout: .now() + 8) == .success else {
            throw NatRendezvousSmokeError.timedOut("sender client")
        }
        guard looperDone.wait(timeout: .now() + 8) == .success else {
            throw NatRendezvousSmokeError.timedOut("looper client")
        }
        guard serverDone.wait(timeout: .now() + 8) == .success else {
            throw NatRendezvousSmokeError.timedOut("rendezvous listener")
        }

        guard let server = serverResult.get() else {
            throw NatRendezvousSmokeError.timedOut("server result")
        }
        guard let sender = senderResult.get() else {
            throw NatRendezvousSmokeError.timedOut("sender result")
        }
        guard let looper = looperResult.get() else {
            throw NatRendezvousSmokeError.timedOut("looper result")
        }

        return NatRendezvousLocalhostSmokeResult(
            serverReport: try server.get(),
            routeReports: [
                try sender.get(),
                try looper.get()
            ]
        )
    }
}

public struct NatRelayFallbackLocalhostSmokeResult: PrettyJSONCodable, Equatable, Sendable {
    public var rendezvousReport: NatRendezvousReport
    public var relayReport: NatRelayReport
    public var routeReports: [NatFriendlyRouteReport]
}

public enum NatRelayFallbackLocalhostSmoke {
    public static func run() throws -> NatRelayFallbackLocalhostSmokeResult {
        let ports = try availableNatRendezvousPorts(count: 3)
        let rendezvousPort = ports[0]
        let relayPort = ports[1]
        let failedDirectPort = ports[2]
        let sessionID = "localhost-relay-fallback-smoke"
        let failedDirectEndpoint = NatEndpoint(host: "127.0.0.1", port: failedDirectPort)

        let rendezvousDone = DispatchSemaphore(value: 0)
        let rendezvousReady = DispatchSemaphore(value: 0)
        let rendezvousResult = NatSmokeResultBox<NatRendezvousReport>()
        DispatchQueue.global(qos: .userInitiated).async {
            let result = Result {
                try NatFailedDirectRendezvousRunner.run(
                    bindHost: "127.0.0.1",
                    port: rendezvousPort,
                    sessionID: sessionID,
                    peerEndpoint: failedDirectEndpoint,
                    expectedPeerCount: 2,
                    timeoutSeconds: 5,
                    onReady: { rendezvousReady.signal() }
                )
            }
            rendezvousResult.set(result)
            rendezvousDone.signal()
        }

        let relayDone = DispatchSemaphore(value: 0)
        let relayReady = DispatchSemaphore(value: 0)
        let relayResult = NatSmokeResultBox<NatRelayReport>()
        DispatchQueue.global(qos: .userInitiated).async {
            let result = Result {
                try NatRelayRunner.run(
                    configuration: NatRelayRunConfiguration(
                        bindHost: "127.0.0.1",
                        port: relayPort,
                        sessionID: sessionID,
                        expectedPeerCount: 2,
                        timeoutSeconds: 4,
                        outputPath: "stdout"
                    ),
                    onReady: { relayReady.signal() }
                )
            }
            relayResult.set(result)
            relayDone.signal()
        }
        guard rendezvousReady.wait(timeout: .now() + 2) == .success else {
            throw NatRendezvousSmokeError.timedOut("failed-direct rendezvous readiness")
        }
        guard relayReady.wait(timeout: .now() + 2) == .success else {
            throw NatRendezvousSmokeError.timedOut("relay listener readiness")
        }

        let senderDone = DispatchSemaphore(value: 0)
        let looperDone = DispatchSemaphore(value: 0)
        let senderResult = NatSmokeResultBox<NatFriendlyRouteReport>()
        let looperResult = NatSmokeResultBox<NatFriendlyRouteReport>()

        DispatchQueue.global(qos: .userInitiated).async {
            let result = Result {
                try NatFriendlyRouteRunner.run(
                    configuration: NatFriendlyRouteRunConfiguration(
                        role: .sender,
                        bindHost: "127.0.0.1",
                        peerID: "sender-relay",
                        rendezvousHost: "127.0.0.1",
                        rendezvousPort: rendezvousPort,
                        relayHost: "127.0.0.1",
                        relayPort: relayPort,
                        sessionID: sessionID,
                        localUdpPort: 0,
                        durationSeconds: 1,
                        rawRouteRttMicroseconds: 0,
                        outputPath: "stdout",
                        debugOutputPath: nil
                    )
                ).report
            }
            senderResult.set(result)
            senderDone.signal()
        }

        DispatchQueue.global(qos: .userInitiated).async {
            let result = Result {
                try NatFriendlyRouteRunner.run(
                    configuration: NatFriendlyRouteRunConfiguration(
                        role: .looper,
                        bindHost: "127.0.0.1",
                        peerID: "looper-relay",
                        rendezvousHost: "127.0.0.1",
                        rendezvousPort: rendezvousPort,
                        relayHost: "127.0.0.1",
                        relayPort: relayPort,
                        sessionID: sessionID,
                        localUdpPort: 0,
                        durationSeconds: 1,
                        rawRouteRttMicroseconds: 0,
                        outputPath: "stdout",
                        debugOutputPath: nil
                    )
                ).report
            }
            looperResult.set(result)
            looperDone.signal()
        }

        guard senderDone.wait(timeout: .now() + 8) == .success else {
            throw NatRendezvousSmokeError.timedOut("relay fallback sender client")
        }
        guard looperDone.wait(timeout: .now() + 8) == .success else {
            throw NatRendezvousSmokeError.timedOut("relay fallback looper client")
        }
        guard rendezvousDone.wait(timeout: .now() + 8) == .success else {
            throw NatRendezvousSmokeError.timedOut("failed-direct rendezvous listener")
        }
        guard relayDone.wait(timeout: .now() + 8) == .success else {
            throw NatRendezvousSmokeError.timedOut("relay listener")
        }

        guard let rendezvous = rendezvousResult.get() else {
            throw NatRendezvousSmokeError.timedOut("failed-direct rendezvous result")
        }
        guard let relay = relayResult.get() else {
            throw NatRendezvousSmokeError.timedOut("relay result")
        }
        guard let sender = senderResult.get() else {
            throw NatRendezvousSmokeError.timedOut("relay fallback sender result")
        }
        guard let looper = looperResult.get() else {
            throw NatRendezvousSmokeError.timedOut("relay fallback looper result")
        }

        return NatRelayFallbackLocalhostSmokeResult(
            rendezvousReport: try rendezvous.get(),
            relayReport: try relay.get(),
            routeReports: [
                try sender.get(),
                try looper.get()
            ]
        )
    }
}

public enum NatRendezvousForwarderLauncherLocalhostSmoke {
    public static func run() throws -> NatRendezvousForwarderLauncherReport {
        let ports = try availableNatRendezvousPorts(count: 2)
        return try NatRendezvousForwarderLauncherRunner.run(
            configuration: NatRendezvousForwarderLauncherConfiguration(
                bindHost: "127.0.0.1",
                rendezvousPort: ports[0],
                forwarderPort: ports[1],
                sessionID: "localhost-forwarder-launcher-smoke",
                expectedPeerCount: 2,
                timeoutSeconds: 1,
                outputPath: "stdout"
            )
        )
    }
}

private enum NatFailedDirectRendezvousRunner {
    static func run(
        bindHost: String,
        port: UInt16,
        sessionID: String,
        peerEndpoint: NatEndpoint,
        expectedPeerCount: Int,
        timeoutSeconds: Int,
        onReady: (() -> Void)? = nil
    ) throws -> NatRendezvousReport {
        let socket = try makeUdpSocket(receiveTimeoutSeconds: 1)
        defer { close(socket) }
        try bindIPv4(socket, host: bindHost, port: port.bigEndian)
        onReady?()

        var registrations: [String: NatRendezvousRegistration] = [:]
        let deadline = Date().addingTimeInterval(Double(timeoutSeconds))

        while Date() < deadline && registrations.count < expectedPeerCount {
            guard let datagram = try receiveRendezvousDatagram(socket: socket) else {
                continue
            }
            guard let request = try? JSONDecoder().decode(
                NatRendezvousRegistrationRequest.self,
                from: datagram.data
            ), request.sessionID == sessionID else {
                continue
            }

            let observedEndpoint = endpoint(from: datagram.source)
            registrations[request.peerID] = NatRendezvousRegistration(
                peerID: request.peerID,
                localEndpoint: request.localEndpoint,
                observedExternalEndpoint: observedEndpoint,
                registeredAt: currentNatTimestamp()
            )
            let response = NatRendezvousRegistrationResponse(
                sessionID: request.sessionID,
                peerID: request.peerID,
                observedExternalEndpoint: observedEndpoint,
                peerEndpoint: peerEndpoint,
                registeredPeerCount: registrations.count,
                sessionComplete: registrations.count >= expectedPeerCount
            )
            try sendRendezvousDatagram(
                try JSONEncoder().encode(response),
                socket: socket,
                destination: datagram.source
            )
        }

        return NatRendezvousReport(
            id: "nat-failed-direct-rendezvous-\(Int(Date().timeIntervalSince1970))",
            capturedAt: currentNatTimestamp(),
            endpoint: NatEndpoint(host: bindHost, port: port),
            sessionID: sessionID,
            mode: .relayFallback,
            expectedPeerCount: expectedPeerCount,
            registrations: registrations.values.sorted { $0.peerID < $1.peerID },
            completedPeerResponses: registrations.count,
            verdict: .partial,
            notes: "Localhost relay fallback smoke forced direct traversal to a closed UDP endpoint before relay use."
        )
    }
}
