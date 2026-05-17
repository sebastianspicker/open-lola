import Darwin
import Dispatch
import Foundation

public final class ManagedProcess: @unchecked Sendable {
    private let process: Process
    private let standardOutputHandle: FileHandle?
    private let standardErrorHandle: FileHandle?
    private let killProcess: @Sendable (pid_t) -> Int32
    private let closeHandle: @Sendable (FileHandle) throws -> Void
    private let cleanupLock = NSLock()
    private var standardOutputCloseAttempted = false
    private var standardErrorCloseAttempted = false

    init(
        process: Process,
        standardOutputHandle: FileHandle?,
        standardErrorHandle: FileHandle?,
        killProcess: @escaping @Sendable (pid_t) -> Int32 = { kill($0, SIGKILL) },
        closeHandle: @escaping @Sendable (FileHandle) throws -> Void = { try $0.close() }
    ) {
        self.process = process
        self.standardOutputHandle = standardOutputHandle
        self.standardErrorHandle = standardErrorHandle
        self.killProcess = killProcess
        self.closeHandle = closeHandle
    }

    public var isRunning: Bool {
        process.isRunning
    }

    public var processIdentifier: pid_t {
        process.processIdentifier
    }

    public var terminationStatus: Int32 {
        process.terminationStatus
    }

    public func terminate() {
        process.terminate()
    }

    @discardableResult
    public func killImmediately() -> ManagedProcessCleanupWarning? {
        let result = killProcess(process.processIdentifier)
        guard result != 0 else {
            return nil
        }
        return ManagedProcessCleanupWarning(
            operation: "kill",
            message: "SIGKILL process \(process.processIdentifier) failed errno \(errno)"
        )
    }

    @discardableResult
    public func waitUntilExit() -> [ManagedProcessCleanupWarning] {
        process.waitUntilExit()
        return closeOutputHandles()
    }

    @discardableResult
    public func closeOutputHandles() -> [ManagedProcessCleanupWarning] {
        var warnings: [ManagedProcessCleanupWarning] = []
        let handles = outputHandlesPendingClose()
        if let stdout = handles.stdout {
            do {
                try closeHandle(stdout)
            } catch {
                warnings.append(ManagedProcessCleanupWarning(
                    operation: "stdout-close",
                    message: "stdout close failed: \(error)"
                ))
            }
        }
        if let stderr = handles.stderr {
            do {
                try closeHandle(stderr)
            } catch {
                warnings.append(ManagedProcessCleanupWarning(
                    operation: "stderr-close",
                    message: "stderr close failed: \(error)"
                ))
            }
        }
        return warnings
    }

    private func outputHandlesPendingClose() -> (stdout: FileHandle?, stderr: FileHandle?) {
        cleanupLock.lock()
        defer { cleanupLock.unlock() }
        let stdout = standardOutputCloseAttempted ? nil : standardOutputHandle
        let stderr = standardErrorCloseAttempted ? nil : standardErrorHandle
        if standardOutputHandle != nil {
            standardOutputCloseAttempted = true
        }
        if standardErrorHandle != nil {
            standardErrorCloseAttempted = true
        }
        return (stdout, stderr)
    }
}

public struct ManagedProcessCleanupWarning: Equatable, Sendable {
    public var operation: String
    public var message: String

    public init(operation: String, message: String) {
        self.operation = operation
        self.message = message
    }
}

public struct ManagedProcessTerminationResult: Equatable, Sendable {
    public var processCount: Int
    public var exitedAfterTerminate: Bool
    public var forcedKillSent: Bool
    public var exitedAfterKill: Bool
    public var cleanupWarnings: [ManagedProcessCleanupWarning]

    public init(
        processCount: Int,
        exitedAfterTerminate: Bool,
        forcedKillSent: Bool,
        exitedAfterKill: Bool,
        cleanupWarnings: [ManagedProcessCleanupWarning] = []
    ) {
        self.processCount = processCount
        self.exitedAfterTerminate = exitedAfterTerminate
        self.forcedKillSent = forcedKillSent
        self.exitedAfterKill = exitedAfterKill
        self.cleanupWarnings = cleanupWarnings
    }

    public var allExited: Bool {
        exitedAfterTerminate || exitedAfterKill
    }
}

public enum ManagedProcessRunner {
    public static func start(
        executable: String,
        arguments: [String],
        standardOutputPath: String? = nil,
        standardErrorPath: String? = nil,
        onPrepared: ((ManagedProcess) -> Void)? = nil,
        terminationHandler: (@Sendable (ManagedProcess) -> Void)? = nil
    ) throws -> ManagedProcess {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments

        let standardOutputHandle = try standardOutputPath.map { try openLogHandle(atPath: $0) }
        let standardErrorHandle: FileHandle?
        do {
            standardErrorHandle = try standardErrorPath.map { try openLogHandle(atPath: $0) }
        } catch {
            try? standardOutputHandle?.close()
            throw error
        }
        process.standardOutput = standardOutputHandle
        process.standardError = standardErrorHandle

        let managed = ManagedProcess(
            process: process,
            standardOutputHandle: standardOutputHandle,
            standardErrorHandle: standardErrorHandle
        )
        if let terminationHandler {
            process.terminationHandler = { _ in
                terminationHandler(managed)
            }
        }
        onPrepared?(managed)
        do {
            try process.run()
        } catch {
            managed.closeOutputHandles()
            throw error
        }
        return managed
    }

    public static func runToExit(
        executable: String,
        arguments: [String],
        standardOutputPath: String? = nil,
        standardErrorPath: String? = nil
    ) throws -> Int32 {
        let process = try start(
            executable: executable,
            arguments: arguments,
            standardOutputPath: standardOutputPath,
            standardErrorPath: standardErrorPath
        )
        process.waitUntilExit()
        return process.terminationStatus
    }

    public static func waitUntilExit(
        _ processes: [ManagedProcess],
        deadline: DispatchTime,
        pollIntervalSeconds: TimeInterval = 0.05
    ) -> Bool {
        waitUntilExitAndClose(
            processes,
            deadline: deadline,
            pollIntervalSeconds: pollIntervalSeconds
        ).exited
    }

    private static func waitUntilExitAndClose(
        _ processes: [ManagedProcess],
        deadline: DispatchTime,
        pollIntervalSeconds: TimeInterval = 0.05
    ) -> (exited: Bool, cleanupWarnings: [ManagedProcessCleanupWarning]) {
        while DispatchTime.now() < deadline {
            if processes.allSatisfy({ !$0.isRunning }) {
                return (true, processes.flatMap { $0.closeOutputHandles() })
            }
            Thread.sleep(forTimeInterval: pollIntervalSeconds)
        }
        let allExited = processes.allSatisfy { !$0.isRunning }
        if allExited {
            return (true, processes.flatMap { $0.closeOutputHandles() })
        }
        return (false, [])
    }

    @discardableResult
    public static func terminate(
        _ processes: [ManagedProcess],
        graceSeconds: TimeInterval
    ) -> ManagedProcessTerminationResult {
        for process in processes where process.isRunning {
            process.terminate()
        }
        let graceDeadline = deadline(afterSeconds: graceSeconds)
        var cleanupWarnings: [ManagedProcessCleanupWarning] = []
        let terminateWait = waitUntilExitAndClose(processes, deadline: graceDeadline)
        cleanupWarnings.append(contentsOf: terminateWait.cleanupWarnings)
        if terminateWait.exited {
            return ManagedProcessTerminationResult(
                processCount: processes.count,
                exitedAfterTerminate: true,
                forcedKillSent: false,
                exitedAfterKill: true,
                cleanupWarnings: cleanupWarnings
            )
        }
        for process in processes where process.isRunning {
            if let warning = process.killImmediately() {
                cleanupWarnings.append(warning)
            }
        }
        let killWait = waitUntilExitAndClose(
            processes,
            deadline: deadline(afterSeconds: graceSeconds)
        )
        cleanupWarnings.append(contentsOf: killWait.cleanupWarnings)
        return ManagedProcessTerminationResult(
            processCount: processes.count,
            exitedAfterTerminate: false,
            forcedKillSent: true,
            exitedAfterKill: killWait.exited,
            cleanupWarnings: cleanupWarnings
        )
    }

    private static func deadline(afterSeconds seconds: TimeInterval) -> DispatchTime {
        let milliseconds = max(0, Int((seconds * 1_000).rounded(.up)))
        return .now() + .milliseconds(milliseconds)
    }

    private static func openLogHandle(atPath path: String) throws -> FileHandle {
        let url = URL(fileURLWithPath: path)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        _ = FileManager.default.createFile(atPath: path, contents: nil)
        return try FileHandle(forWritingTo: url)
    }
}
