// Probes AtemReadOnlyControlProbe capability or availability, isolating environment inspection from policy decisions.
import Foundation
#if canImport(Darwin)
import Darwin
#endif

/// Probes an ATEM endpoint without arming commands and returns read-only health evidence.
public enum AtemReadOnlyControlProbe {
    public static func run(configuration: AtemReadOnlyProbeConfiguration) -> AtemReadOnlyControlReport {
        makeReport(
            configuration: configuration,
            observation: tcpReachabilityObservation(configuration: configuration),
            capturedAt: ISO8601DateFormatter().string(from: Date())
        )
    }

    public static func makeUnavailableReport(host: String, capturedAt: String? = nil) -> AtemReadOnlyControlReport {
        let configuration = AtemReadOnlyProbeConfiguration(
            host: host,
            outputPath: ""
        )
        return makeReport(
            configuration: configuration,
            observation: AtemReadOnlyNetworkObservation(
                health: .unavailable,
                durationMilliseconds: 0,
                errorMessage: "No live ATEM network probe was run."
            ),
            capturedAt: capturedAt ?? ISO8601DateFormatter().string(from: Date())
        )
    }

    public static func makeReport(
        configuration: AtemReadOnlyProbeConfiguration,
        observation: AtemReadOnlyNetworkObservation,
        capturedAt: String
    ) -> AtemReadOnlyControlReport {
        AtemReadOnlyControlReport(
            identity: AtemReadOnlyControlIdentity(
                id: "m11-atem-readonly-probe",
                title: "M11 ATEM read-only control probe",
                capturedAt: capturedAt
            ),
            device: AtemReadOnlyControlDeviceEvidence(
                ipAddress: configuration.host,
                model: "unknown",
                firmware: "unknown",
                controlPort: configuration.port,
                protocolName: "tcp-reachability",
                networkInterface: configuration.networkInterface,
                sameNetworkAsAudio: configuration.sameNetworkAsAudio
            ),
            switchState: AtemReadOnlyControlSwitchState(
                programSource: "unknown",
                previewSource: "unknown",
                tally: "unknown",
                audioMixerState: "unknown"
            ),
            probe: AtemReadOnlyControlProbeEvidence(
                health: observation.health,
                armedCommandsAllowed: false,
                pollIntervalMilliseconds: configuration.pollIntervalMilliseconds,
                connectionAttemptMilliseconds: observation.durationMilliseconds,
                errorMessage: observation.errorMessage
            ),
            verdict: .partial,
            notes: "Read-only ATEM reachability probe; .connected means TCP handshake completed, "
                + "not ATEM protocol verified. No switching commands are implemented or armed, "
                + "and model/firmware require a real read-only ATEM adapter or captured hardware evidence."
        )
    }

    private static func tcpReachabilityObservation(
        configuration: AtemReadOnlyProbeConfiguration
    ) -> AtemReadOnlyNetworkObservation {
        #if canImport(Darwin)
        let start = Date()
        let socketDescriptor = socket(AF_INET, SOCK_STREAM, 0)
        guard socketDescriptor >= 0 else {
            let socketErrno = errno
            return AtemReadOnlyNetworkObservation(
                health: .error,
                durationMilliseconds: elapsedMilliseconds(since: start),
                errorMessage: "socket creation failed: \(socketErrno)"
            )
        }
        defer {
            close(socketDescriptor)
        }

        guard configureNonblockingAtemSocket(socketDescriptor) else {
            return AtemReadOnlyNetworkObservation(
                health: .error,
                durationMilliseconds: elapsedMilliseconds(since: start),
                errorMessage: "failed to configure nonblocking socket: \(errno)"
            )
        }

        guard let address = sockaddrIn(host: configuration.host, port: configuration.port) else {
            return AtemReadOnlyNetworkObservation(
                health: .error,
                durationMilliseconds: elapsedMilliseconds(since: start),
                errorMessage: "invalid IPv4 host"
            )
        }

        var targetAddress = address
        return connectedAtemObservation(
            socketDescriptor: socketDescriptor,
            targetAddress: &targetAddress,
            timeoutMilliseconds: configuration.timeoutMilliseconds,
            start: start
        )
        #else
        return AtemReadOnlyNetworkObservation(
            health: .unavailable,
            durationMilliseconds: 0,
            errorMessage: "TCP reachability probe is unavailable on this platform."
        )
        #endif
    }

    #if canImport(Darwin)
    private static func configureNonblockingAtemSocket(_ socketDescriptor: Int32) -> Bool {
        let flags = fcntl(socketDescriptor, F_GETFL, 0)
        guard flags >= 0 else {
            return false
        }
        return fcntl(socketDescriptor, F_SETFL, flags | O_NONBLOCK) >= 0
    }

    private static func connectedAtemObservation(
        socketDescriptor: Int32,
        targetAddress: inout sockaddr_in,
        timeoutMilliseconds: Int,
        start: Date
    ) -> AtemReadOnlyNetworkObservation {
        let connectResult = withAtemSockaddrPointer(to: &targetAddress) { socketAddress, socketAddressLength in
            connect(socketDescriptor, socketAddress, socketAddressLength)
        }

        if connectResult == 0 {
            return AtemReadOnlyNetworkObservation(
                health: .connected,
                durationMilliseconds: elapsedMilliseconds(since: start),
                errorMessage: nil
            )
        }

        return pendingAtemConnectionObservation(
            socketDescriptor: socketDescriptor,
            timeoutMilliseconds: timeoutMilliseconds,
            start: start
        )
    }

    private static func pendingAtemConnectionObservation(
        socketDescriptor: Int32,
        timeoutMilliseconds: Int,
        start: Date
    ) -> AtemReadOnlyNetworkObservation {
        guard errno == EINPROGRESS else {
            return AtemReadOnlyNetworkObservation(
                health: .unavailable,
                durationMilliseconds: elapsedMilliseconds(since: start),
                errorMessage: "connect failed: \(errno)"
            )
        }

        guard var writeSet = atemWritableSocketSet(for: socketDescriptor) else {
            return AtemReadOnlyNetworkObservation(
                health: .error,
                durationMilliseconds: elapsedMilliseconds(since: start),
                errorMessage: "socket descriptor exceeds fd_set capacity"
            )
        }

        var timeout = atemConnectTimeout(from: timeoutMilliseconds)
        let ready = select(socketDescriptor + 1, nil, &writeSet, nil, &timeout)
        if ready == 0 {
            return AtemReadOnlyNetworkObservation(
                health: .timeout,
                durationMilliseconds: elapsedMilliseconds(since: start),
                errorMessage: "connect timed out"
            )
        }
        guard ready > 0 else {
            return AtemReadOnlyNetworkObservation(
                health: .error,
                durationMilliseconds: elapsedMilliseconds(since: start),
                errorMessage: "select failed: \(errno)"
            )
        }

        return completedAtemConnectionObservation(socketDescriptor: socketDescriptor, start: start)
    }

    private static func completedAtemConnectionObservation(
        socketDescriptor: Int32,
        start: Date
    ) -> AtemReadOnlyNetworkObservation {
        var socketError: Int32 = 0
        var socketErrorLength = socklen_t(MemoryLayout<Int32>.size)
        let optionResult = getsockopt(
            socketDescriptor,
            SOL_SOCKET,
            SO_ERROR,
            &socketError,
            &socketErrorLength
        )
        guard optionResult == 0 else {
            return AtemReadOnlyNetworkObservation(
                health: .error,
                durationMilliseconds: elapsedMilliseconds(since: start),
                errorMessage: "getsockopt failed: \(errno)"
            )
        }
        guard socketError == 0 else {
            return AtemReadOnlyNetworkObservation(
                health: .unavailable,
                durationMilliseconds: elapsedMilliseconds(since: start),
                errorMessage: "connect failed: \(socketError)"
            )
        }

        return AtemReadOnlyNetworkObservation(
            health: .connected,
            durationMilliseconds: elapsedMilliseconds(since: start),
            errorMessage: nil
        )
    }

    private static func atemWritableSocketSet(for socketDescriptor: Int32) -> fd_set? {
        var writeSet = fd_set()
        openLolaFDZero(&writeSet)
        guard atemSocketDescriptorFitsFDSet(socketDescriptor) else {
            return nil
        }
        guard (try? openLolaFDSet(socketDescriptor, set: &writeSet)) != nil else {
            return nil
        }
        return writeSet
    }

    private static func atemConnectTimeout(from timeoutMilliseconds: Int) -> timeval {
        let boundedTimeoutMilliseconds = min(
            max(1, timeoutMilliseconds),
            atemProbeMaximumTimeoutMilliseconds
        )
        return timeval(
            tv_sec: boundedTimeoutMilliseconds / 1_000,
            tv_usec: Int32((boundedTimeoutMilliseconds % 1_000) * 1_000)
        )
    }
    #endif
}

#if canImport(Darwin)
// ATEM TCP reachability is a local macOS operator probe. These helpers stay
// Darwin-only because they depend on Darwin socket layout and fd_set storage.
private func sockaddrIn(host: String, port: UInt16) -> sockaddr_in? {
    var address = sockaddr_in()
    address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
    address.sin_family = sa_family_t(AF_INET)
    address.sin_port = port.bigEndian

    guard inet_pton(AF_INET, host, &address.sin_addr) == 1 else {
        return nil
    }
    return address
}

private func elapsedMilliseconds(since start: Date) -> Double {
    Date().timeIntervalSince(start) * 1_000
}

private func atemSocketDescriptorFitsFDSet(_ descriptor: Int32) -> Bool {
    openLolaFileDescriptorFitsFDSet(descriptor)
}

private func withAtemSockaddrPointer<Result>(
    to address: inout sockaddr_in,
    _ body: (UnsafePointer<sockaddr>, socklen_t) -> Result
) -> Result {
    precondition(MemoryLayout<sockaddr_in>.size >= MemoryLayout<sockaddr>.size)
    precondition(MemoryLayout<sockaddr_in>.alignment >= MemoryLayout<sockaddr>.alignment)
    return withUnsafePointer(to: &address) { pointer in
        pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
            body($0, socklen_t(MemoryLayout<sockaddr_in>.size))
        }
    }
}
#endif
