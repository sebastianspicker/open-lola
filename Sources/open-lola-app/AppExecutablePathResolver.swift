import Foundation
import OSLog

enum AppExecutablePathResolver {
    private static let packagedCLIDefault = ".build/debug/open-lola"
    private static let logger = Logger(subsystem: "open-lola.app", category: "ExecutablePathResolver")

    static func resolve(_ path: String) -> AppExecutablePathResolution {
        let trimmedPath = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPath.isEmpty else {
            return .unavailable(path: "unset", reason: "path is empty")
        }
        if trimmedPath.hasPrefix("/") {
            return resolveAbsolutePath(trimmedPath)
        }
        if trimmedPath == packagedCLIDefault, let packagedCLI = bundledSibling(named: "open-lola") {
            return .verified(path: packagedCLI)
        }
        let candidate = URL(fileURLWithPath: trimmedPath)
        if FileManager.default.isExecutableFile(atPath: candidate.path) {
            return .verified(path: candidate.path)
        }
        if let sibling = bundledSibling(named: candidate.lastPathComponent) {
            return .verified(path: sibling)
        }
        return unresolvedPath(candidate.path)
    }

    static func verifiedPath(_ path: String) throws -> String {
        let resolution = resolve(path)
        if let path = resolution.verifiedPath {
            return path
        }
        logger.warning("Executable path could not be verified: \(resolution.displayPath, privacy: .public)")
        throw AppExecutablePathResolutionError(resolution: resolution)
    }

    private static func resolveAbsolutePath(_ path: String) -> AppExecutablePathResolution {
        if FileManager.default.isExecutableFile(atPath: path) {
            return .verified(path: path)
        }
        return unresolvedPath(path)
    }

    private static func unresolvedPath(_ path: String) -> AppExecutablePathResolution {
        if FileManager.default.fileExists(atPath: path) {
            return .unverified(path: path, reason: "file is not executable")
        }
        return .unavailable(path: path, reason: "file does not exist")
    }

    private static func bundledSibling(named name: String) -> String? {
        guard let sibling = Bundle.main.executableURL?
            .deletingLastPathComponent()
            .appendingPathComponent(name),
            FileManager.default.isExecutableFile(atPath: sibling.path) else {
            return nil
        }
        return sibling.path
    }
}

enum AppExecutablePathResolution: Equatable {
    case verified(path: String)
    case unverified(path: String, reason: String)
    case unavailable(path: String, reason: String)

    var verifiedPath: String? {
        switch self {
        case .verified(let path):
            return path
        case .unverified, .unavailable:
            return nil
        }
    }

    var displayPath: String {
        switch self {
        case .verified(let path):
            return path
        case .unverified(let path, let reason):
            return "Unverified: \(path) (\(reason))"
        case .unavailable(let path, let reason):
            return "Unavailable: \(path) (\(reason))"
        }
    }

    var failureDescription: String? {
        switch self {
        case .verified:
            return nil
        case .unverified(let path, let reason):
            return "Executable path unverified: \(path) (\(reason))"
        case .unavailable(let path, let reason):
            return "Executable path unavailable: \(path) (\(reason))"
        }
    }
}

struct AppExecutablePathResolutionError: Error, CustomStringConvertible, LocalizedError, Equatable {
    let resolution: AppExecutablePathResolution

    var description: String {
        resolution.failureDescription ?? "Executable path verification failed."
    }

    var errorDescription: String? {
        description
    }
}
