import OpenLolaContracts
import OpenLolaSessionDomain
import OpenLolaEvidenceModels
import OpenLolaTransport
import OpenLolaMediaPlatform
// Coordinates runtime execution and its result lifecycle, keeping runtime side effects separate from protocol values and validation policy.
import Darwin
import Dispatch
import Foundation

private let managedProcessLogByteLimit = 1_048_576

private final class ManagedProcessLogCapture: @unchecked Sendable {
    let pipe = Pipe()
    private let logHandle: FileHandle
    private let limit: Int
    private let lock = NSLock()
    private var bytesWritten = 0
    private var finished = false
    private var isClosing = false

    init(logHandle: FileHandle, limit: Int = managedProcessLogByteLimit) {
        self.logHandle = logHandle
        self.limit = limit
        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            self?.consume(handle.availableData)
        }
    }

    func close() throws {
        lock.lock()
        let shouldClose = !isClosing
        isClosing = true
        lock.unlock()
        guard shouldClose else { return }

        let readHandle = pipe.fileHandleForReading
        readHandle.readabilityHandler = nil
        while let data = try readHandle.read(upToCount: 64 * 1_024), !data.isEmpty {
            consume(data, whileClosing: true)
        }
        try readHandle.close()
        try pipe.fileHandleForWriting.close()
        try logHandle.close()
        lock.lock()
        finished = true
        lock.unlock()
    }

    private func consume(_ data: Data, whileClosing: Bool = false) {
        guard !data.isEmpty else { return }
        lock.lock()
        defer { lock.unlock() }
        guard !finished, (!isClosing || whileClosing), bytesWritten < limit else { return }
        let prefix = data.prefix(limit - bytesWritten)
        do {
            try logHandle.write(contentsOf: prefix)
            bytesWritten += prefix.count
        } catch {
            // Keep draining the pipe even if the optional log cannot be written.
            bytesWritten = limit
        }
    }
}

/// Captures structured result required to validate, interpret, and reproduce a managed-process runtime result.
public final class ManagedProcess: @unchecked Sendable {
    private let process: Process
    private let standardOutputCapture: ManagedProcessLogCapture?
    private let standardErrorCapture: ManagedProcessLogCapture?
    private let killProcess: @Sendable (pid_t) -> Int32
    private let cleanupLock = NSLock()
    private var standardOutputCloseAttempted = false
    private var standardErrorCloseAttempted = false

    fileprivate init(
        process: Process,
        standardOutputCapture: ManagedProcessLogCapture?,
        standardErrorCapture: ManagedProcessLogCapture?,
        killProcess: @escaping @Sendable (pid_t) -> Int32 = { kill($0, SIGKILL) }
    ) {
        self.process = process
        self.standardOutputCapture = standardOutputCapture
        self.standardErrorCapture = standardErrorCapture
        self.killProcess = killProcess
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
        let captures = outputCapturesPendingClose()
        if let stdout = captures.stdout {
            do {
                try stdout.close()
            } catch {
                warnings.append(ManagedProcessCleanupWarning(
                    operation: "stdout-close",
                    message: "stdout close failed: \(error)"
                ))
            }
        }
        if let stderr = captures.stderr {
            do {
                try stderr.close()
            } catch {
                warnings.append(ManagedProcessCleanupWarning(
                    operation: "stderr-close",
                    message: "stderr close failed: \(error)"
                ))
            }
        }
        return warnings
    }

    private func outputCapturesPendingClose() -> (stdout: ManagedProcessLogCapture?, stderr: ManagedProcessLogCapture?) {
        cleanupLock.lock()
        defer { cleanupLock.unlock() }
        let stdout = standardOutputCloseAttempted ? nil : standardOutputCapture
        let stderr = standardErrorCloseAttempted ? nil : standardErrorCapture
        if standardOutputCapture != nil {
            standardOutputCloseAttempted = true
        }
        if standardErrorCapture != nil {
            standardErrorCloseAttempted = true
        }
        return (stdout, stderr)
    }
}

/// Captures reported warning required to validate, interpret, and reproduce a managed-process runtime result.
public struct ManagedProcessCleanupWarning: Equatable, Sendable {
    public var operation: String
    public var message: String

    public init(operation: String, message: String) {
        self.operation = operation
        self.message = message
    }
}

/// Captures operation result required to validate, interpret, and reproduce a managed-process runtime result.
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

/// Indicates that a synchronous managed process exceeded its caller-provided deadline.
public struct ManagedProcessTimeoutError: Error, Equatable, Sendable {
    public let executable: String
    public let timeoutSeconds: TimeInterval

    public init(executable: String, timeoutSeconds: TimeInterval) {
        self.executable = executable
        self.timeoutSeconds = timeoutSeconds
    }
}

/// Runs the managed-process runtime evaluation from supplied artifacts while retaining their measurement provenance in the resulting report.
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

        let standardOutputCapture = try standardOutputPath.map {
            ManagedProcessLogCapture(logHandle: try openLogHandle(atPath: $0))
        }
        let standardErrorCapture: ManagedProcessLogCapture?
        do {
            standardErrorCapture = try standardErrorPath.map {
                ManagedProcessLogCapture(logHandle: try openLogHandle(atPath: $0))
            }
        } catch {
            try? standardOutputCapture?.close()
            throw error
        }
        process.standardOutput = standardOutputCapture?.pipe
        process.standardError = standardErrorCapture?.pipe

        let managed = ManagedProcess(
            process: process,
            standardOutputCapture: standardOutputCapture,
            standardErrorCapture: standardErrorCapture
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
        standardErrorPath: String? = nil,
        timeoutSeconds: TimeInterval? = nil
    ) throws -> Int32 {
        let process = try start(
            executable: executable,
            arguments: arguments,
            standardOutputPath: standardOutputPath,
            standardErrorPath: standardErrorPath
        )
        guard let timeoutSeconds else {
            process.waitUntilExit()
            return process.terminationStatus
        }
        guard timeoutSeconds.isFinite, timeoutSeconds > 0 else {
            throw ManagedProcessTimeoutError(executable: executable, timeoutSeconds: timeoutSeconds)
        }
        let deadline = deadline(afterSeconds: timeoutSeconds)
        guard waitUntilExit([process], deadline: deadline) else {
            _ = terminate([process], graceSeconds: min(1, timeoutSeconds))
            throw ManagedProcessTimeoutError(executable: executable, timeoutSeconds: timeoutSeconds)
        }
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
        let descriptor = Darwin.open(path, O_WRONLY | O_CREAT | O_APPEND | O_NOFOLLOW | O_CLOEXEC, 0o600)
        guard descriptor >= 0 else {
            throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
        }
        var metadata = stat()
        guard fstat(descriptor, &metadata) == 0, metadata.st_mode & S_IFMT == S_IFREG else {
            let error = errno
            Darwin.close(descriptor)
            throw POSIXError(POSIXErrorCode(rawValue: error) ?? .EIO)
        }
        guard fchmod(descriptor, 0o600) == 0 else {
            let error = errno
            Darwin.close(descriptor)
            throw POSIXError(POSIXErrorCode(rawValue: error) ?? .EIO)
        }
        return FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
    }
}
