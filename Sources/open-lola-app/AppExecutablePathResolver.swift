import Foundation
import OSLog

enum AppExecutablePathResolver {
    private static let packagedCLIDefault = ".build/debug/open-lola"
    private static let logger = Logger(subsystem: "open-lola.app", category: "ExecutablePathResolver")

    static func resolve(_ path: String) -> String {
        if path.hasPrefix("/") {
            return path
        }
        if path == packagedCLIDefault, let packagedCLI = bundledSibling(named: "open-lola") {
            return packagedCLI
        }
        let candidate = URL(fileURLWithPath: path)
        if FileManager.default.isExecutableFile(atPath: candidate.path) {
            return candidate.path
        }
        if let sibling = bundledSibling(named: candidate.lastPathComponent) {
            return sibling
        }
        logger.warning("Executable path could not be verified: \(candidate.path, privacy: .public)")
        return candidate.path
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
