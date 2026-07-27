// Shared open-lola CLI test helpers keep command-line test scenarios deterministic.
import Foundation

enum OpenLolaCLIExecutableProbeError: Error, Equatable {
    case missingExecutable(String)
    case staleExecutable(String)
    case missingModificationDate(String)
}

enum OpenLolaCLIOutputError: Error {
    case missingVerdictLine
    case sourceEnumerationFailed(String)
}

private let openLolaRouterCommandPatternSources = [
    #"RegisteredCommand\(name:\s*"([^"]+)""#,
    #"args\[0\]\s*==\s*"([^"]+)""#,
    #"args\.first\s*==\s*"([^"]+)""#,
    #"case\s*\[\s*"([^"]+)""#,
    #""([^"]+)"\s*:\s*\{\s*try\s+validateReport"#
]

func openLolaExecutableRouterCommandNames(repositoryRoot: URL) throws -> Set<String> {
    let sourceRoot = repositoryRoot.appendingPathComponent("Sources/open-lola")
    guard let enumerator = FileManager.default.enumerator(
        at: sourceRoot,
        includingPropertiesForKeys: nil
    ) else {
        throw OpenLolaCLIOutputError.sourceEnumerationFailed(sourceRoot.path)
    }
    let sourceURLs = enumerator
        .compactMap { $0 as? URL }
        .filter { $0.pathExtension == "swift" }
        .sorted { $0.path < $1.path }
    let patterns = try openLolaRouterCommandPatternSources.map {
        try NSRegularExpression(pattern: $0)
    }
    var names = Set<String>()

    for url in sourceURLs {
        let text = try String(contentsOf: url, encoding: .utf8)
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        for pattern in patterns {
            for match in pattern.matches(in: text, range: range) {
                guard let matchRange = Range(match.range(at: 1), in: text) else {
                    continue
                }
                names.insert(String(text[matchRange]))
            }
        }
    }
    return names
}

func runFreshOpenLolaCLI(
    arguments: [String],
    context: String,
    logPrefix: String
) throws -> (exitCode: Int32, output: String) {
    let process = Process()
    process.executableURL = try requiredFreshOpenLolaCLIURL(context: context)
    process.arguments = arguments
    let result = try runTestProcessCapturingCombinedOutput(process, logPrefix: logPrefix)
    return (result.status, result.output)
}

func executableJSONPayload(from output: String) throws -> Data {
    guard let verdictRange = output.range(of: "\nVERDICT: ", options: .backwards) else {
        throw OpenLolaCLIOutputError.missingVerdictLine
    }
    return Data(output[..<verdictRange.lowerBound].utf8)
}

func commandValue(_ command: [String], _ flag: String) -> String? {
    guard let index = command.firstIndex(of: flag), command.indices.contains(index + 1) else {
        return nil
    }
    return command[index + 1]
}

func repositoryRelativePaths(in command: String, trackedPrefixes: [String]) -> [String] {
    command.split(separator: " ").map(String.init).compactMap { token in
        let path = token.trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
        return trackedPrefixes.contains { path == $0 || path.hasPrefix($0) } ? path : nil
    }
}

func requiredFreshOpenLolaCLIURL(
    repositoryRoot: URL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath),
    environment: [String: String] = ProcessInfo.processInfo.environment,
    context: String
) throws -> URL {
    let buildPath = openLolaSwiftBuildPath(repositoryRoot: repositoryRoot, environment: environment)
    let candidates = openLolaCLIExecutableCandidates(
        repositoryRoot: repositoryRoot,
        environment: environment
    )

    guard let cliURL = candidates.first(where: { FileManager.default.isExecutableFile(atPath: $0.path) }) else {
        throw OpenLolaCLIExecutableProbeError.missingExecutable(
            "open-lola executable must be built before \(context); run " +
                openLolaCLIFreshBuildCommand(buildPath: buildPath)
        )
    }
    try requireFreshOpenLolaCLI(cliURL, repositoryRoot: repositoryRoot, buildPath: buildPath)
    return cliURL
}

func openLolaCLIExecutableCandidates(
    repositoryRoot: URL,
    environment: [String: String]
) -> [URL] {
    if let configuredPath = nonEmptyEnvironmentPath("OPEN_LOLA_TEST_OPEN_LOLA_CLI", environment: environment) {
        return [URL(fileURLWithPath: configuredPath)]
    }
    return [
        openLolaSwiftBuildPath(repositoryRoot: repositoryRoot, environment: environment)
            .appendingPathComponent("debug/open-lola")
    ]
}

func openLolaSwiftBuildPath(
    repositoryRoot: URL,
    environment: [String: String]
) -> URL {
    if let configuredPath = nonEmptyEnvironmentPath("OPEN_LOLA_SWIFT_BUILD_PATH", environment: environment) {
        return URL(fileURLWithPath: configuredPath)
    }
    return repositoryRoot.appendingPathComponent(".build")
}

func requireFreshOpenLolaCLI(
    _ cliURL: URL,
    repositoryRoot: URL,
    buildPath: URL? = nil
) throws {
    let executableDate = try openLolaCLIModificationDate(cliURL)
    let sourceDate = try newestOpenLolaProductSourceModificationDate(repositoryRoot: repositoryRoot)
    guard executableDate.addingTimeInterval(1) >= sourceDate else {
        throw OpenLolaCLIExecutableProbeError.staleExecutable(
            "\(cliURL.path) is older than product sources; run " +
                openLolaCLIFreshBuildCommand(
                    buildPath: buildPath ?? repositoryRoot.appendingPathComponent(".build")
                )
        )
    }
}

private func nonEmptyEnvironmentPath(_ key: String, environment: [String: String]) -> String? {
    let value = environment[key]?.trimmingCharacters(in: .whitespacesAndNewlines)
    return value?.isEmpty == false ? value : nil
}

private func openLolaCLIFreshBuildCommand(buildPath: URL) -> String {
    "swift build --product open-lola --build-path \(buildPath.path)"
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
            "swift"
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
