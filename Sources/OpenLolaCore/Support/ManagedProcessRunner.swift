import Darwin
import Foundation

public final class ManagedProcess: @unchecked Sendable {
    private let process: Process
    private let standardOutputHandle: FileHandle?
    private let standardErrorHandle: FileHandle?

    init(
        process: Process,
        standardOutputHandle: FileHandle?,
        standardErrorHandle: FileHandle?
    ) {
        self.process = process
        self.standardOutputHandle = standardOutputHandle
        self.standardErrorHandle = standardErrorHandle
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

    public func killImmediately() {
        _ = kill(process.processIdentifier, SIGKILL)
    }

    public func waitUntilExit() {
        process.waitUntilExit()
        closeOutputHandles()
    }

    public func closeOutputHandles() {
        try? standardOutputHandle?.close()
        try? standardErrorHandle?.close()
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
        deadline: Date,
        pollIntervalSeconds: TimeInterval = 0.05
    ) -> Bool {
        while Date() < deadline {
            if processes.allSatisfy({ !$0.isRunning }) {
                processes.forEach { $0.closeOutputHandles() }
                return true
            }
            Thread.sleep(forTimeInterval: pollIntervalSeconds)
        }
        let allExited = processes.allSatisfy { !$0.isRunning }
        if allExited {
            processes.forEach { $0.closeOutputHandles() }
        }
        return allExited
    }

    public static func terminate(
        _ processes: [ManagedProcess],
        graceSeconds: TimeInterval
    ) {
        for process in processes where process.isRunning {
            process.terminate()
        }
        let graceDeadline = Date().addingTimeInterval(graceSeconds)
        guard !waitUntilExit(processes, deadline: graceDeadline) else {
            return
        }
        for process in processes where process.isRunning {
            process.killImmediately()
        }
        _ = waitUntilExit(
            processes,
            deadline: Date().addingTimeInterval(graceSeconds)
        )
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
