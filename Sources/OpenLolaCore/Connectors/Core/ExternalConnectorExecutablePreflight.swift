import Foundation

public enum ExternalConnectorExecutableIdentity: String, Codable, Equatable, Sendable {
    case internalLoLa
    case ultraGrid
    case jackTrip
    case pythonUv
    case missing
    case unknown
}

public enum ExternalConnectorExecutablePreflightError: Error, Equatable, Sendable {
    case unknownArgument(String)
    case duplicateArgument(String)
    case missingValue(String)
    case missingRequiredArgument(String)
    case emptyField(String)
    case emptyList(String)
    case passWithFailingProbe(String)
    case failWithoutFailingProbe
}

public struct ExternalConnectorExecutablePreflightConfiguration: Equatable, Sendable {
    public var outputPath: String
    public var connector: ExternalConnectorKind?
    public var ultraGridExecutable: String
    public var jackTripExecutable: String

    public init(
        outputPath: String,
        connector: ExternalConnectorKind? = nil,
        ultraGridExecutable: String = "uv",
        jackTripExecutable: String = "jacktrip"
    ) {
        self.outputPath = outputPath
        self.connector = connector
        self.ultraGridExecutable = ultraGridExecutable
        self.jackTripExecutable = jackTripExecutable
    }

    public static func parse(_ arguments: [String]) throws -> ExternalConnectorExecutablePreflightConfiguration {
        let allowed = [
            "--output",
            "--connector",
            "--ultragrid-executable",
            "--jacktrip-executable",
        ]
        var values: [String: String] = [:]
        var index = 0

        while index < arguments.count {
            let argument = arguments[index]
            guard allowed.contains(argument) else {
                throw ExternalConnectorExecutablePreflightError.unknownArgument(argument)
            }
            guard values[argument] == nil else {
                throw ExternalConnectorExecutablePreflightError.duplicateArgument(argument)
            }
            let valueIndex = index + 1
            guard valueIndex < arguments.count, !arguments[valueIndex].hasPrefix("--") else {
                throw ExternalConnectorExecutablePreflightError.missingValue(argument)
            }
            values[argument] = arguments[valueIndex]
            index += 2
        }

        return ExternalConnectorExecutablePreflightConfiguration(
            outputPath: try requiredExternalConnectorExecutablePreflightValue("--output", values),
            connector: try values["--connector"].map(parseExternalConnectorKind),
            ultraGridExecutable: values["--ultragrid-executable"] ?? "uv",
            jackTripExecutable: values["--jacktrip-executable"] ?? "jacktrip"
        )
    }
}

public struct ExternalConnectorExecutableProbe: Codable, Equatable, Sendable {
    public var id: String
    public var connector: ExternalConnectorKind
    public var label: String
    public var executable: String
    public var arguments: [String]
    public var requiredForAudioVideo: Bool
    public var launched: Bool
    public var exitStatus: Int32?
    public var standardOutputPrefix: String
    public var standardErrorPrefix: String
    public var detectedIdentity: ExternalConnectorExecutableIdentity
    public var verdict: MeasurementVerdict
    public var notes: String

    public init(
        id: String,
        connector: ExternalConnectorKind,
        label: String,
        executable: String,
        arguments: [String],
        requiredForAudioVideo: Bool,
        launched: Bool,
        exitStatus: Int32? = nil,
        standardOutputPrefix: String = "",
        standardErrorPrefix: String = "",
        detectedIdentity: ExternalConnectorExecutableIdentity,
        verdict: MeasurementVerdict,
        notes: String
    ) {
        self.id = id
        self.connector = connector
        self.label = label
        self.executable = executable
        self.arguments = arguments
        self.requiredForAudioVideo = requiredForAudioVideo
        self.launched = launched
        self.exitStatus = exitStatus
        self.standardOutputPrefix = standardOutputPrefix
        self.standardErrorPrefix = standardErrorPrefix
        self.detectedIdentity = detectedIdentity
        self.verdict = verdict
        self.notes = notes
    }
}

public struct ExternalConnectorExecutablePreflightReport: ReportValidatingArtifact, PrettyJSONCodable, Equatable, Sendable {
    public var id: String
    public var capturedAt: String
    public var probes: [ExternalConnectorExecutableProbe]
    public var verdict: MeasurementVerdict
    public var notes: String

    public init(
        id: String,
        capturedAt: String,
        probes: [ExternalConnectorExecutableProbe],
        verdict: MeasurementVerdict,
        notes: String
    ) {
        self.id = id
        self.capturedAt = capturedAt
        self.probes = probes
        self.verdict = verdict
        self.notes = notes
    }

    public func validate() throws {
        try requireExternalConnectorExecutablePreflightNonEmpty(id, "id")
        try requireExternalConnectorExecutablePreflightNonEmpty(capturedAt, "capturedAt")
        try requireExternalConnectorExecutablePreflightNonEmpty(notes, "notes")
        try requireExternalConnectorExecutablePreflightNonEmptyList(probes.map(\.id), "probes.id")
        for probe in probes {
            try requireExternalConnectorExecutablePreflightNonEmpty(probe.label, "probes.label")
            try requireExternalConnectorExecutablePreflightNonEmpty(probe.executable, "probes.executable")
            try requireExternalConnectorExecutablePreflightNonEmpty(probe.notes, "probes.notes")
            if probe.connector != .lola {
                try requireExternalConnectorExecutablePreflightNonEmptyList(probe.arguments, "probes.arguments")
            }
        }
        let failingProbeIDs = probes.filter { $0.verdict == .fail }.map(\.id)
        if verdict == .pass, let first = failingProbeIDs.first {
            throw ExternalConnectorExecutablePreflightError.passWithFailingProbe(first)
        }
        if verdict == .fail, failingProbeIDs.isEmpty {
            throw ExternalConnectorExecutablePreflightError.failWithoutFailingProbe
        }
    }
}

public enum ExternalConnectorExecutablePreflightRunner {
    public static func run(
        configuration: ExternalConnectorExecutablePreflightConfiguration
    ) -> ExternalConnectorExecutablePreflightReport {
        var probes: [ExternalConnectorExecutableProbe] = []
        if configuration.connector == nil || configuration.connector == .lola {
            probes.append(lolaInternalProbe())
        }
        if configuration.connector == nil || configuration.connector == .mvtpUltraGrid || configuration.connector == .jackTrip {
            probes.append(externalExecutableProbe(
                id: "external-connector-executable-ultragrid-uv",
                connector: .mvtpUltraGrid,
                label: "MVTP/UltraGrid uv",
                executable: configuration.ultraGridExecutable,
                arguments: ["-h"],
                expected: .ultraGrid
            ))
        }
        if configuration.connector == nil || configuration.connector == .jackTrip {
            probes.append(externalExecutableProbe(
                id: "external-connector-executable-jacktrip",
                connector: .jackTrip,
                label: "JackTrip audio",
                executable: configuration.jackTripExecutable,
                arguments: ["--version"],
                expected: .jackTrip
            ))
        }
        return ExternalConnectorExecutablePreflightReport(
            id: "external-connector-executable-preflight",
            capturedAt: ISO8601DateFormatter().string(from: Date()),
            probes: probes,
            verdict: aggregateExternalConnectorExecutablePreflightVerdict(probes),
            notes: "Checks local executable identity for external NMP connector launch plans. It catches PATH collisions such as Python uv versus UltraGrid uv, but it is not endpoint interoperability evidence."
        )
    }
}

private func lolaInternalProbe() -> ExternalConnectorExecutableProbe {
    ExternalConnectorExecutableProbe(
        id: "external-connector-executable-lola-internal",
        connector: .lola,
        label: "LoLa internal control/media source path",
        executable: "open-lola",
        arguments: [],
        requiredForAudioVideo: true,
        launched: false,
        detectedIdentity: .internalLoLa,
        verdict: .pass,
        notes: "LoLa compatibility is implemented inside open-lola; no external LoLa executable is required for the connector path."
    )
}

private func externalExecutableProbe(
    id: String,
    connector: ExternalConnectorKind,
    label: String,
    executable: String,
    arguments: [String],
    expected: ExternalConnectorExecutableIdentity
) -> ExternalConnectorExecutableProbe {
    let attempts = externalConnectorExecutableCandidates(primary: executable, expected: expected).map { candidate in
        let result = runExternalConnectorExecutableProbe(executable: candidate, arguments: arguments)
        let text = "\(result.standardOutputPrefix)\n\(result.standardErrorPrefix)"
        let identity = result.launched && result.exitStatus != 127
            ? detectExternalConnectorExecutableIdentity(text)
            : .missing
        let verdict: MeasurementVerdict = result.launched && result.exitStatus == 0 && identity == expected
            ? .pass
            : .fail
        return ExternalConnectorExecutableProbeAttempt(
            executable: candidate,
            result: result,
            detectedIdentity: identity,
            verdict: verdict
        )
    }
    guard let selected = attempts.first(where: { $0.verdict == .pass }) ?? attempts.first else {
        return ExternalConnectorExecutableProbe(
            id: id,
            connector: connector,
            label: label,
            executable: executable,
            arguments: arguments,
            requiredForAudioVideo: true,
            launched: false,
            detectedIdentity: .missing,
            verdict: .fail,
            notes: "No executable candidates were available for probing."
        )
    }
    return ExternalConnectorExecutableProbe(
        id: id,
        connector: connector,
        label: label,
        executable: selected.executable,
        arguments: arguments,
        requiredForAudioVideo: true,
        launched: selected.result.launched,
        exitStatus: selected.result.exitStatus,
        standardOutputPrefix: selected.result.standardOutputPrefix,
        standardErrorPrefix: selected.result.standardErrorPrefix,
        detectedIdentity: selected.detectedIdentity,
        verdict: selected.verdict,
        notes: externalConnectorExecutableProbeNotes(
            requestedExecutable: executable,
            selectedExecutable: selected.executable,
            attemptedExecutables: attempts.map(\.executable),
            expected: expected,
            detected: selected.detectedIdentity,
            result: selected.result
        )
    )
}

private struct ExternalConnectorExecutableProbeAttempt {
    var executable: String
    var result: ExternalConnectorProcessResult
    var detectedIdentity: ExternalConnectorExecutableIdentity
    var verdict: MeasurementVerdict
}

private func externalConnectorExecutableCandidates(
    primary: String,
    expected: ExternalConnectorExecutableIdentity
) -> [String] {
    var candidates = [primary]
    if primary.contains("/") {
        let directory = URL(fileURLWithPath: primary).deletingLastPathComponent().path
        switch expected {
        case .ultraGrid:
            candidates += ["uv-ug", "ultragrid"].map { "\(directory)/\($0)" }
        case .jackTrip:
            candidates += ["jacktrip"].map { "\(directory)/\($0)" }
        default:
            break
        }
    }
    switch expected {
    case .ultraGrid:
        candidates += [
            "uv",
            "uv-ug",
            "ultragrid",
            "/opt/homebrew/bin/uv",
            "/opt/homebrew/bin/uv-ug",
            "/opt/homebrew/bin/ultragrid",
            "/usr/local/bin/uv",
            "/usr/local/bin/uv-ug",
            "/usr/local/bin/ultragrid",
            "/opt/local/bin/uv",
            "/opt/local/bin/uv-ug",
            "/opt/local/bin/ultragrid",
            "/Applications/UltraGrid.app/Contents/MacOS/uv",
        ]
    case .jackTrip:
        candidates += [
            "jacktrip",
            "/opt/homebrew/bin/jacktrip",
            "/usr/local/bin/jacktrip",
            "/opt/local/bin/jacktrip",
            "/Applications/JackTrip.app/Contents/MacOS/jacktrip",
        ]
    default:
        break
    }
    return uniqueExternalConnectorExecutableCandidates(candidates)
}

private func uniqueExternalConnectorExecutableCandidates(_ candidates: [String]) -> [String] {
    var seen: Set<String> = []
    var unique: [String] = []
    for candidate in candidates where !candidate.isEmpty && seen.insert(candidate).inserted {
        unique.append(candidate)
    }
    return unique
}

private func runExternalConnectorExecutableProbe(
    executable: String,
    arguments: [String]
) -> ExternalConnectorProcessResult {
    runExternalConnectorProcess(
        ExternalConnectorProcessRunConfiguration(executable: executable, arguments: arguments)
    )
}

private func detectExternalConnectorExecutableIdentity(_ text: String) -> ExternalConnectorExecutableIdentity {
    let lowered = text.lowercased()
    if lowered.contains("an extremely fast python package manager")
        || (lowered.contains("python package") && lowered.contains("uv")) {
        return .pythonUv
    }
    if lowered.contains("ultragrid")
        || (lowered.contains("capture") && lowered.contains("display") && lowered.contains("-t") && lowered.contains("-d")) {
        return .ultraGrid
    }
    if lowered.contains("jacktrip") {
        return .jackTrip
    }
    return .unknown
}

private func externalConnectorExecutableProbeNotes(
    requestedExecutable: String,
    selectedExecutable: String,
    attemptedExecutables: [String],
    expected: ExternalConnectorExecutableIdentity,
    detected: ExternalConnectorExecutableIdentity,
    result: ExternalConnectorProcessResult
) -> String {
    let discoverySuffix = selectedExecutable == requestedExecutable
        ? ""
        : " Selected \(selectedExecutable) after trying \(attemptedExecutables.joined(separator: ", "))."
    if !result.launched {
        return "\(requestedExecutable) could not be launched through PATH, common macOS install locations, or the supplied path."
    }
    if result.exitStatus != 0 {
        return "\(selectedExecutable) launched but exited with status \(result.exitStatus ?? -1).\(discoverySuffix)"
    }
    if expected != detected {
        return "\(selectedExecutable) launched, but identity \(detected.rawValue) does not match expected \(expected.rawValue).\(discoverySuffix)"
    }
    return "\(selectedExecutable) launched and matched expected \(expected.rawValue) identity.\(discoverySuffix)"
}

private func aggregateExternalConnectorExecutablePreflightVerdict(
    _ probes: [ExternalConnectorExecutableProbe]
) -> MeasurementVerdict {
    if probes.contains(where: { $0.verdict == .fail }) {
        return .fail
    }
    if probes.contains(where: { $0.verdict == .partial }) {
        return .partial
    }
    return .pass
}

private func requiredExternalConnectorExecutablePreflightValue(
    _ key: String,
    _ values: [String: String]
) throws -> String {
    guard let value = values[key], !value.isEmpty else {
        throw ExternalConnectorExecutablePreflightError.missingRequiredArgument(key)
    }
    return value
}

private func requireExternalConnectorExecutablePreflightNonEmpty(
    _ value: String,
    _ field: String
) throws {
    try ValidationPrimitives.requireNonEmpty(
        value,
        field: field,
        empty: ExternalConnectorExecutablePreflightError.emptyField
    )
}

private func requireExternalConnectorExecutablePreflightNonEmptyList(
    _ values: [String],
    _ field: String
) throws {
    try ValidationPrimitives.requireNonEmptyStrings(
        values,
        field: field,
        emptyField: ExternalConnectorExecutablePreflightError.emptyField,
        emptyList: ExternalConnectorExecutablePreflightError.emptyList
    )
}
