import AppKit
import Foundation

public enum NativeAppShellArtifactKind: String, Codable, Equatable, Sendable {
    case localMediaInventory
    case remoteMediaInventory
    case twoPeerRunPlan
    case twoPeerSupervisorCommand
}

public enum NativeAppShellArtifactError: Error, Equatable, Sendable {
    case emptyClipboardText
}

public struct NativeAppShellGeneratedArtifactState: PrettyJSONCodable, Equatable, Sendable {
    public var kind: NativeAppShellArtifactKind
    public var generatedAt: String
    public var path: String?
    public var clipboardText: String
    public var validationSummary: String

    public init(
        kind: NativeAppShellArtifactKind,
        generatedAt: String,
        path: String?,
        clipboardText: String,
        validationSummary: String
    ) {
        self.kind = kind
        self.generatedAt = generatedAt
        self.path = path
        self.clipboardText = clipboardText
        self.validationSummary = validationSummary
    }
}

public extension NativeAppShellLocalMediaInventory {
    static func decodeJSON(from data: Data) throws -> NativeAppShellLocalMediaInventory {
        try JSONDecoder().decode(NativeAppShellLocalMediaInventory.self, from: data)
    }

    static func decodeJSON(from string: String) throws -> NativeAppShellLocalMediaInventory {
        try decodeJSON(from: Data(string.utf8))
    }

    static func readJSON(from url: URL) throws -> NativeAppShellLocalMediaInventory {
        try decodeJSON(from: BoundedFileReader.data(at: url))
    }

    static func readClipboardString(_ string: String) throws -> NativeAppShellLocalMediaInventory {
        guard !string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw NativeAppShellArtifactError.emptyClipboardText
        }
        return try decodeJSON(from: string)
    }

    func writeJSON(to url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try prettyJSONData().write(to: url, options: [.atomic])
    }

    func clipboardString() throws -> String {
        try prettyJSONString()
    }

    func writeToGeneralPasteboard() throws {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(try clipboardString(), forType: .string)
    }
}

public extension NativeAppShellOperatorPrototypeState {
    mutating func importRemoteInventoryJSON(from data: Data) throws {
        try importValidatedRemoteInventory(try NativeAppShellLocalMediaInventory.decodeJSON(from: data))
    }

    mutating func importRemoteInventoryJSON(from string: String) throws {
        try importRemoteInventoryJSON(from: Data(string.utf8))
    }

    mutating func importRemoteInventoryJSON(from url: URL) throws {
        try importValidatedRemoteInventory(try NativeAppShellLocalMediaInventory.readJSON(from: url))
    }

    private mutating func importValidatedRemoteInventory(_ candidate: NativeAppShellLocalMediaInventory) throws {
        var nextState = self
        nextState.remoteInventory = candidate
        try nextState.validate()
        self = nextState
    }

    func localInventoryArtifactState(
        generatedAt: String = ISO8601DateFormatter().string(from: Date()),
        path: String? = nil
    ) throws -> NativeAppShellGeneratedArtifactState {
        NativeAppShellGeneratedArtifactState(
            kind: .localMediaInventory,
            generatedAt: generatedAt,
            path: path,
            clipboardText: try inventory.clipboardString(),
            validationSummary: "local inventory JSON export"
        )
    }

    func twoPeerRunPlanReport(
        outputPath: String = NativeAppShellExecutionPaths.defaultPlanPath(),
        runDirectory: String = NativeAppShellExecutionPaths.defaultRunDirectory()
    ) throws -> DirectPeerTwoPeerRunPlanReport {
        let configuration = try twoPeerRunPlanConfiguration(
            outputPath: outputPath,
            runDirectory: runDirectory
        )
        let report = try DirectPeerTwoPeerRunPlanner.makeReport(configuration: configuration)
        try report.validate()
        return report
    }

    func twoPeerRunPlanArtifactState(
        outputPath: String = NativeAppShellExecutionPaths.defaultPlanPath(),
        runDirectory: String = NativeAppShellExecutionPaths.defaultRunDirectory(),
        generatedAt: String = ISO8601DateFormatter().string(from: Date())
    ) throws -> NativeAppShellGeneratedArtifactState {
        let report = try twoPeerRunPlanReport(outputPath: outputPath, runDirectory: runDirectory)
        return NativeAppShellGeneratedArtifactState(
            kind: .twoPeerRunPlan,
            generatedAt: generatedAt,
            path: outputPath,
            clipboardText: try report.prettyJSONString(),
            validationSummary: "\(report.id): \(report.verdict.rawValue)"
        )
    }

    func writeTwoPeerRunPlanArtifact(
        to url: URL,
        runDirectory: String = NativeAppShellExecutionPaths.defaultRunDirectory()
    ) throws -> NativeAppShellGeneratedArtifactState {
        let report = try twoPeerRunPlanReport(outputPath: url.path, runDirectory: runDirectory)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try report.prettyJSONData().write(to: url, options: [.atomic])
        return NativeAppShellGeneratedArtifactState(
            kind: .twoPeerRunPlan,
            generatedAt: report.capturedAt,
            path: url.path,
            clipboardText: try report.prettyJSONString(),
            validationSummary: "\(report.id): \(report.verdict.rawValue)"
        )
    }

    static func readTwoPeerRunPlanArtifact(from url: URL) throws -> DirectPeerTwoPeerRunPlanReport {
        try DirectPeerTwoPeerRunPlanReport.readValidated(from: url)
    }

    func twoPeerSupervisorCommandArtifactState(
        planPath: String = NativeAppShellExecutionPaths.defaultPlanPath(),
        outputPath: String = NativeAppShellExecutionPaths.defaultSupervisorReportPath(),
        executablePath: String = NativeAppShellExecutionPaths.installedCLIPlaceholder,
        macASSH: String,
        macBSSH: String,
        generatedAt: String = ISO8601DateFormatter().string(from: Date())
    ) throws -> NativeAppShellGeneratedArtifactState {
        try validate()
        let command = [
            executablePath,
            "direct-p2p-two-peer-local-run",
            "--plan", planPath,
            "--output", outputPath,
            "--execution-mode", "ssh",
            "--mac-a-ssh", macASSH,
            "--mac-b-ssh", macBSSH,
            "--execute", "true",
            "--require-preflight", "true",
        ].joined(separator: " ")
        return NativeAppShellGeneratedArtifactState(
            kind: .twoPeerSupervisorCommand,
            generatedAt: generatedAt,
            path: outputPath,
            clipboardText: command,
            validationSummary: "direct-p2p-two-peer-local-run ssh command"
        )
    }
}
