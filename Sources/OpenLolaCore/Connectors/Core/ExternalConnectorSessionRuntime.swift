import Darwin
import Foundation
#if canImport(Darwin)
import Darwin
#endif

func runExternalProcess(
    plan: ExternalConnectorLaunchPlan,
    durationSeconds: Int
) -> ExternalConnectorProcessResult {
    guard let executable = plan.executable else {
        return ExternalConnectorProcessResult(
            launched: false,
            error: ExternalConnectorSessionError.externalConnectorRequiresExecutable(plan.connector).localizedDescription
        )
    }
    return RealExternalConnectorProcessRunner().run(
        invocations:
        [
            ExternalConnectorProcessInvocation(
                executable: executable,
                arguments: plan.arguments,
                connector: plan.connector,
                role: plan.role
            ),
        ],
        durationSeconds: durationSeconds
    )[0]
}

func runExternalProcessGroup(
    plan: ExternalConnectorLaunchPlan,
    durationSeconds: Int,
    processRunner: any ExternalConnectorProcessRunning = RealExternalConnectorProcessRunner()
) -> (primary: ExternalConnectorProcessResult, auxiliaries: [ExternalConnectorProcessResult]) {
    guard let executable = plan.executable else {
        return (
            ExternalConnectorProcessResult(
                launched: false,
                error: ExternalConnectorSessionError.externalConnectorRequiresExecutable(plan.connector).localizedDescription
            ),
            []
        )
    }
    let invocations = [
        ExternalConnectorProcessInvocation(
            executable: executable,
            arguments: plan.arguments,
            connector: plan.connector,
            role: plan.role
        ),
    ] + plan.auxiliaryProcesses.map {
        ExternalConnectorProcessInvocation(
            executable: $0.executable,
            arguments: $0.arguments,
            connector: plan.connector,
            role: plan.role
        )
    }
    let results = processRunner.run(invocations: invocations, durationSeconds: durationSeconds)
    return (results[0], Array(results.dropFirst()))
}

func runExternalAuxiliaryProcessGroup(
    plan: ExternalConnectorLaunchPlan,
    durationSeconds: Int,
    processRunner: any ExternalConnectorProcessRunning = RealExternalConnectorProcessRunner()
) -> [ExternalConnectorProcessResult] {
    let invocations = plan.auxiliaryProcesses.map {
        ExternalConnectorProcessInvocation(
            executable: $0.executable,
            arguments: $0.arguments,
            connector: plan.connector,
            role: plan.role
        )
    }
    guard !invocations.isEmpty else {
        return []
    }
    return processRunner.run(invocations: invocations, durationSeconds: durationSeconds)
}

struct ExternalConnectorProcessInvocation: Equatable, Sendable {
    var executable: String
    var arguments: [String]
    var connector: ExternalConnectorKind
    var role: ExternalConnectorSessionRole
}

// Single production conformer by design; tests inject this seam to exercise
// process-group result, cleanup, and auxiliary-process failure paths without
// launching external connector binaries.
protocol ExternalConnectorProcessRunning: Sendable {
    func run(
        invocations: [ExternalConnectorProcessInvocation],
        durationSeconds: Int
    ) -> [ExternalConnectorProcessResult]
}

private struct ExternalConnectorProcessSlot {
    var running: RunningExternalConnectorProcess?
    var result: ExternalConnectorProcessResult?
}

struct RealExternalConnectorProcessRunner: ExternalConnectorProcessRunning {
    func run(
        invocations: [ExternalConnectorProcessInvocation],
        durationSeconds: Int
    ) -> [ExternalConnectorProcessResult] {
        var slots = invocations.map { _ in ExternalConnectorProcessSlot() }

        for (index, invocation) in invocations.enumerated() {
            do {
                try validateExternalConnectorInvocationPreflight(invocation)
                slots[index].running = try startExternalConnectorProcess(
                    ExternalConnectorProcessRunConfiguration(
                        executable: invocation.executable,
                        arguments: invocation.arguments,
                        environment: [
                            "OPEN_LOLA_EXTERNAL_CONNECTOR": invocation.connector.rawValue,
                            "OPEN_LOLA_EXTERNAL_CONNECTOR_ROLE": invocation.role.rawValue,
                        ]
                    )
                )
            } catch {
                slots[index].result = ExternalConnectorProcessResult(
                    launched: false,
                    error: "failed to launch \(invocation.executable) for \(invocation.connector.rawValue): \(error)"
                )
            }
        }

        externalConnectorWaitForProcessesOrTimeout(&slots, timeout: TimeInterval(max(1, durationSeconds)))

        for index in slots.indices {
            guard var launched = slots[index].running else {
                continue
            }
            let stillRunningAtDeadline = launched.reapAndCheckRunning()
            if stillRunningAtDeadline {
                terminateExternalConnectorProcessGroup(&launched)
            }
            launched.waitUntilExitStatus()
            let cleanupStatus = cleanupExternalConnectorProcessGroup(&launched)
            slots[index].result = ExternalConnectorProcessResult(
                launched: true,
                processIdentifier: launched.processIdentifier,
                exitStatus: launched.terminationStatus,
                terminatedAfterDuration: stillRunningAtDeadline,
                standardOutputPrefix: externalConnectorPipePrefix(launched.stdout),
                standardErrorPrefix: externalConnectorPipePrefix(launched.stderr),
                waitStatusKnown: launched.waitStatusKnown,
                cleanupStatus: cleanupStatus,
                error: nil
            )
        }

        return slots.map { slot in
            slot.result ?? ExternalConnectorProcessResult(launched: false, error: "process result missing")
        }
    }
}

private func validateExternalConnectorInvocationPreflight(
    _ invocation: ExternalConnectorProcessInvocation
) throws {
    guard invocation.connector == .mvtpUltraGrid,
          let portMapIndex = invocation.arguments.firstIndex(of: "-P"),
          invocation.arguments.indices.contains(portMapIndex + 1) else {
        return
    }
    let ports = Set(invocation.arguments[portMapIndex + 1].split(separator: ":").compactMap { UInt16(String($0)) })
    for port in ports {
        try validateExternalConnectorPortAvailable(port)
    }
}

private func validateExternalConnectorPortAvailable(_ port: UInt16) throws {
#if canImport(Darwin)
    let descriptor = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
    guard descriptor >= 0 else {
        throw ExternalConnectorSessionError.socketFailed("socket")
    }
    defer { close(descriptor) }
    var address = sockaddr_in()
    address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
    address.sin_family = sa_family_t(AF_INET)
    address.sin_port = port.bigEndian
    address.sin_addr = in_addr(s_addr: INADDR_ANY.bigEndian)
    let status = withUnsafePointer(to: &address) { pointer in
        pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPointer in
            bind(descriptor, sockaddrPointer, socklen_t(MemoryLayout<sockaddr_in>.size))
        }
    }
    guard status == 0 else {
        throw ExternalConnectorSessionError.invalidPort("ultragrid.port", String(port))
    }
#else
    _ = port
#endif
}

private func externalConnectorWaitForProcessesOrTimeout(
    _ slots: inout [ExternalConnectorProcessSlot],
    timeout: TimeInterval
) {
    let deadline = MonotonicDeadline(seconds: timeout)
    while deadline.hasTimeRemaining {
        let activeProcessIdentifiers = slots.indices.compactMap { index -> pid_t? in
            guard var launched = slots[index].running else {
                return nil
            }
            let isRunning = launched.reapAndCheckRunning()
            slots[index].running = launched
            return isRunning ? launched.processIdentifier : nil
        }
        guard !activeProcessIdentifiers.isEmpty else {
            return
        }
        _ = externalConnectorWaitForAnyProcessExit(
            processIdentifiers: activeProcessIdentifiers,
            timeout: deadline.remainingSeconds
        )
    }
}

private func externalConnectorWaitForAnyProcessExit(
    processIdentifiers: [pid_t],
    timeout: TimeInterval
) -> Bool {
    let queue = kqueue()
    guard queue >= 0 else {
        return false
    }
    defer { close(queue) }

    var events = processIdentifiers.map { processIdentifier in
        return kevent(
            ident: UInt(processIdentifier),
            filter: Int16(EVFILT_PROC),
            flags: UInt16(EV_ADD | EV_ENABLE | EV_ONESHOT),
            fflags: UInt32(NOTE_EXIT),
            data: 0,
            udata: nil
        )
    }
    guard !events.isEmpty else {
        return false
    }
    guard kevent(queue, &events, Int32(events.count), nil, 0, nil) == 0 else {
        return false
    }

    let deadline = MonotonicDeadline(seconds: max(0, timeout))
    var event = kevent()
    var wait = externalConnectorRuntimeTimeSpec(seconds: deadline.remainingSeconds)
    var received = kevent(queue, nil, 0, &event, 1, &wait)
    while received == -1, errno == EINTR {
        wait = externalConnectorRuntimeTimeSpec(seconds: deadline.remainingSeconds)
        received = kevent(queue, nil, 0, &event, 1, &wait)
    }
    return received > 0
}

private func externalConnectorRuntimeTimeSpec(seconds: TimeInterval) -> timespec {
    let boundedSeconds = max(0, seconds)
    return timespec(
        tv_sec: Int(boundedSeconds),
        tv_nsec: Int((boundedSeconds - floor(boundedSeconds)) * 1_000_000_000)
    )
}
