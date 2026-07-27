// Defines generated native-shell artifacts and validates timestamped file and clipboard handoff results.
import AppKit
import Foundation

/// Defines the supported choices for native app shell artifact kind.
public enum NativeAppShellArtifactKind: String, Codable, Equatable, Sendable {
    case localMediaInventory
    case remoteMediaInventory
    case twoPeerRunPlan
    case twoPeerSupervisorCommand
}

/// Defines failures reported when native app shell artifact error cannot continue.
public enum NativeAppShellArtifactError: Error, Equatable, Sendable {
    case emptyClipboardText
}

/// Enumerates the supported operating modes for native app shell artifact write.
public enum NativeAppShellArtifactWriteMode: Equatable, Sendable {
    case overwrite
    case writeTimestampedIfExists
}

/// Defines the validated fields for native app shell generated artifact state.
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

/// Defines the validated fields for native app shell artifact write result.
public struct NativeAppShellArtifactWriteResult: Equatable, Sendable {
    public var artifact: NativeAppShellGeneratedArtifactState
    public var requestedPath: String
    public var writtenPath: String
    public var writtenCount: Int
    public var skippedCount: Int
    public var failedCount: Int

    public init(
        artifact: NativeAppShellGeneratedArtifactState,
        requestedPath: String,
        writtenPath: String,
        writtenCount: Int,
        skippedCount: Int,
        failedCount: Int
    ) {
        self.artifact = artifact
        self.requestedPath = requestedPath
        self.writtenPath = writtenPath
        self.writtenCount = writtenCount
        self.skippedCount = skippedCount
        self.failedCount = failedCount
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
        try writeTwoPeerRunPlanArtifactResult(
            to: url,
            runDirectory: runDirectory,
            mode: .overwrite
        ).artifact
    }

    func writeTwoPeerRunPlanArtifactResult(
        to url: URL,
        runDirectory: String = NativeAppShellExecutionPaths.defaultRunDirectory(),
        mode: NativeAppShellArtifactWriteMode = .overwrite,
        generatedAt: String = ISO8601DateFormatter().string(from: Date())
    ) throws -> NativeAppShellArtifactWriteResult {
        let requestedURL = url
        let targetURL = Self.twoPeerRunPlanArtifactTargetURL(
            requestedURL: requestedURL,
            mode: mode,
            generatedAt: generatedAt
        )
        let report = try twoPeerRunPlanReport(outputPath: targetURL.path, runDirectory: runDirectory)
        try FileManager.default.createDirectory(
            at: targetURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try report.prettyJSONData().write(to: targetURL, options: [.atomic])
        let artifact = NativeAppShellGeneratedArtifactState(
            kind: .twoPeerRunPlan,
            generatedAt: report.capturedAt,
            path: targetURL.path,
            clipboardText: try report.prettyJSONString(),
            validationSummary: "\(report.id): \(report.verdict.rawValue)"
        )
        let skippedCount = targetURL.path == requestedURL.path ? 0 : 1
        return NativeAppShellArtifactWriteResult(
            artifact: artifact,
            requestedPath: requestedURL.path,
            writtenPath: targetURL.path,
            writtenCount: 1,
            skippedCount: skippedCount,
            failedCount: 0
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
            "--require-preflight", "true"
        ].joined(separator: " ")
        return NativeAppShellGeneratedArtifactState(
            kind: .twoPeerSupervisorCommand,
            generatedAt: generatedAt,
            path: outputPath,
            clipboardText: command,
            validationSummary: "direct-p2p-two-peer-local-run ssh command"
        )
    }

    private static func twoPeerRunPlanArtifactTargetURL(
        requestedURL: URL,
        mode: NativeAppShellArtifactWriteMode,
        generatedAt: String
    ) -> URL {
        guard mode == .writeTimestampedIfExists,
              FileManager.default.fileExists(atPath: requestedURL.path)
        else {
            return requestedURL
        }

        var candidate = timestampedSiblingURL(for: requestedURL, generatedAt: generatedAt)
        if FileManager.default.fileExists(atPath: candidate.path) {
            candidate = timestampedSiblingURL(
                for: requestedURL,
                generatedAt: "\(generatedAt)-\(UUID().uuidString)"
            )
        }
        return candidate
    }

    private static func timestampedSiblingURL(for requestedURL: URL, generatedAt: String) -> URL {
        let timestamp = generatedAt.map { character in
            character.isLetter || character.isNumber ? character : "-"
        }.reduce(into: "") { partialResult, character in
            partialResult.append(character)
        }
        let baseName = requestedURL.deletingPathExtension().lastPathComponent
        let pathExtension = requestedURL.pathExtension
        let fileName = pathExtension.isEmpty
            ? "\(baseName)-\(timestamp)"
            : "\(baseName)-\(timestamp).\(pathExtension)"
        return requestedURL.deletingLastPathComponent().appendingPathComponent(fileName)
    }
}
