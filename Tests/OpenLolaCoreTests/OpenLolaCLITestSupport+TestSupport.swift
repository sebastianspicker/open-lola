import Foundation

enum OpenLolaCLIExecutableProbeError: Error, Equatable {
    case missingExecutable(String)
    case staleExecutable(String)
    case missingModificationDate(String)
}

func requiredFreshOpenLolaCLIURL(
    repositoryRoot: URL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath),
    environment: [String: String] = ProcessInfo.processInfo.environment,
    context: String
) throws -> URL {
    let configuredPath = environment["OPEN_LOLA_TEST_OPEN_LOLA_CLI"]?
        .trimmingCharacters(in: .whitespacesAndNewlines)
    let candidates = configuredPath?.isEmpty == false
        ? [URL(fileURLWithPath: configuredPath!)]
        : [
            URL(fileURLWithPath: "/private/tmp/open-lola2-swiftpm-build/debug/open-lola"),
            repositoryRoot.appendingPathComponent(".build/debug/open-lola"),
            repositoryRoot.appendingPathComponent(".build/arm64-apple-macosx/debug/open-lola"),
        ]

    guard let cliURL = candidates.first(where: { FileManager.default.isExecutableFile(atPath: $0.path) }) else {
        throw OpenLolaCLIExecutableProbeError.missingExecutable(
            "open-lola executable must be built before \(context); run swift build --product open-lola --build-path /private/tmp/open-lola2-swiftpm-build"
        )
    }
    try requireFreshOpenLolaCLI(cliURL, repositoryRoot: repositoryRoot)
    return cliURL
}

func requireFreshOpenLolaCLI(_ cliURL: URL, repositoryRoot: URL) throws {
    let executableDate = try openLolaCLIModificationDate(cliURL)
    let sourceDate = try newestOpenLolaProductSourceModificationDate(repositoryRoot: repositoryRoot)
    guard executableDate.addingTimeInterval(1) >= sourceDate else {
        throw OpenLolaCLIExecutableProbeError.staleExecutable(
            "\(cliURL.path) is older than product sources; run swift build --product open-lola --build-path /private/tmp/open-lola2-swiftpm-build"
        )
    }
}

private func newestOpenLolaProductSourceModificationDate(repositoryRoot: URL) throws -> Date {
    var newest = try openLolaCLIModificationDate(repositoryRoot.appendingPathComponent("Package.swift"))
    let sourceRoot = repositoryRoot.appendingPathComponent("Sources")
    guard let enumerator = FileManager.default.enumerator(
        at: sourceRoot,
        includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey],
        options: [.skipsHiddenFiles]
    ) else {
        return newest
    }
    for case let url as URL in enumerator where isOpenLolaProductSource(url) {
        newest = max(newest, try openLolaCLIModificationDate(url))
    }
    return newest
}

private func isOpenLolaProductSource(_ url: URL) -> Bool {
    let components = url.standardizedFileURL.pathComponents
    if let sourcesIndex = components.lastIndex(of: "Sources"),
       sourcesIndex + 1 < components.endIndex,
       ["open-lola-app", "open-lola-app-main"].contains(components[sourcesIndex + 1]) {
        return false
    }
    switch url.lastPathComponent {
    case "Package.swift":
        return true
    default:
        return [
            "c",
            "cc",
            "cpp",
            "cxx",
            "h",
            "hpp",
            "m",
            "mm",
            "modulemap",
            "swift",
        ].contains(url.pathExtension)
    }
}

private func openLolaCLIModificationDate(_ url: URL) throws -> Date {
    let values = try url.resourceValues(forKeys: [.contentModificationDateKey])
    guard let date = values.contentModificationDate else {
        throw OpenLolaCLIExecutableProbeError.missingModificationDate(url.path)
    }
    return date
}
