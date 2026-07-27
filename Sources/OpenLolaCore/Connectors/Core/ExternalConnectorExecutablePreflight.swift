// Performs ExternalConnectorExecutablePreflight readiness checks before a run, keeping start-blocking conditions out of the runtime loop.
import Foundation

/// Defines the supported choices for external connector executable identity.
public enum ExternalConnectorExecutableIdentity: String, Codable, Equatable, Sendable {
    case internalLoLa
    case ultraGrid
    case jackTrip
    case pythonUv
    case missing
    case unknown
}

// swiftlint:disable:next type_name
/// Defines failures reported when external connector executable preflight error cannot continue.
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

// swiftlint:disable:next type_name
/// Defines the validated fields for external connector executable preflight configuration.
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
            "--jacktrip-executable"
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

/// Defines the validated fields for external connector executable probe fields.
public struct ExternalConnectorExecutableProbeFields: Equatable, Sendable {
    public var id = ""
    public var connector: ExternalConnectorKind = .lola
    public var label = ""
    public var executable = ""
    public var arguments: [String] = []
    public var requiredForAudioVideo = true
    public var launched = false
    public var exitStatus: Int32?
    public var standardOutputPrefix = ""
    public var standardErrorPrefix = ""
    public var detectedIdentity: ExternalConnectorExecutableIdentity = .unknown
    public var evidenceStatus: String?
    public var verdict: MeasurementVerdict = .fail
    public var notes = ""

    public init() {}
}

/// Defines the validated fields for external connector executable probe.
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
    public var evidenceStatus: String?
    public var verdict: MeasurementVerdict
    public var notes: String

    public init(_ fields: ExternalConnectorExecutableProbeFields) {
        self.id = fields.id
        self.connector = fields.connector
        self.label = fields.label
        self.executable = fields.executable
        self.arguments = fields.arguments
        self.requiredForAudioVideo = fields.requiredForAudioVideo
        self.launched = fields.launched
        self.exitStatus = fields.exitStatus
        self.standardOutputPrefix = fields.standardOutputPrefix
        self.standardErrorPrefix = fields.standardErrorPrefix
        self.detectedIdentity = fields.detectedIdentity
        self.evidenceStatus = fields.evidenceStatus
        self.verdict = fields.verdict
        self.notes = fields.notes
    }
}

// swiftlint:disable:next type_name
/// Records the evidence and outcome for external connector executable preflight report.
public struct ExternalConnectorExecutablePreflightReport:
    ReportValidatingArtifact,
    PrettyJSONCodable,
    Equatable,
    Sendable {
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
            if probe.connector == .lola, !probe.launched, probe.verdict == .pass {
                guard probe.evidenceStatus == "internal-not-required" else {
                    throw ExternalConnectorExecutablePreflightError.emptyField("probes.evidenceStatus")
                }
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

// swiftlint:disable:next type_name
/// Parses preflight arguments, probes required executables, and writes the validated result.
public enum ExternalConnectorExecutablePreflightRunner {
    public static func run(
        configuration: ExternalConnectorExecutablePreflightConfiguration
    ) -> ExternalConnectorExecutablePreflightReport {
        var probes: [ExternalConnectorExecutableProbe] = []
        if configuration.connector == nil || configuration.connector == .lola {
            probes.append(lolaInternalProbe())
        }
        if externalConnectorPreflightShouldProbeUltraGrid(configuration.connector) {
            probes.append(externalExecutableProbe(ExternalConnectorExecutableProbeRequest(
                id: "external-connector-executable-ultragrid-uv",
                connector: .mvtpUltraGrid,
                label: "MVTP/UltraGrid uv",
                executable: configuration.ultraGridExecutable,
                arguments: ["-h"],
                expected: .ultraGrid
            )))
        }
        if configuration.connector == nil || configuration.connector == .jackTrip {
            probes.append(externalExecutableProbe(ExternalConnectorExecutableProbeRequest(
                id: "external-connector-executable-jacktrip",
                connector: .jackTrip,
                label: "JackTrip audio",
                executable: configuration.jackTripExecutable,
                arguments: ["--version"],
                expected: .jackTrip
            )))
        }
        return ExternalConnectorExecutablePreflightReport(
            id: "external-connector-executable-preflight",
            capturedAt: ISO8601DateFormatter().string(from: Date()),
            probes: probes,
            verdict: aggregateExternalConnectorExecutablePreflightVerdict(probes),
            notes: [
                "Checks local executable identity for external NMP connector launch plans.",
                "It catches PATH collisions such as Python uv versus UltraGrid uv,",
                "but it is not endpoint interoperability evidence."
            ].joined(separator: " ")
        )
    }
}

private func externalConnectorPreflightShouldProbeUltraGrid(_ connector: ExternalConnectorKind?) -> Bool {
    connector == nil || connector == .mvtpUltraGrid || connector == .jackTrip
}

private func lolaInternalProbe() -> ExternalConnectorExecutableProbe {
    var fields = ExternalConnectorExecutableProbeFields()
    fields.id = "external-connector-executable-lola-internal"
    fields.connector = .lola
    fields.label = "LoLa internal control/media source path"
    fields.executable = "open-lola"
    fields.detectedIdentity = .internalLoLa
    fields.evidenceStatus = "internal-not-required"
    fields.verdict = .pass
    fields.notes = [
        "LoLa compatibility is implemented inside open-lola;",
        "no external LoLa executable is required for the connector path."
    ].joined(separator: " ")
    return ExternalConnectorExecutableProbe(fields)
}

func externalConnectorExecutableCandidates(
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
            "/Applications/UltraGrid.app/Contents/MacOS/uv"
        ]
    case .jackTrip:
        candidates += [
            "jacktrip",
            "/opt/homebrew/bin/jacktrip",
            "/usr/local/bin/jacktrip",
            "/opt/local/bin/jacktrip",
            "/Applications/JackTrip.app/Contents/MacOS/jacktrip"
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

func runExternalConnectorExecutableProbe(
    executable: String,
    arguments: [String]
) -> ExternalConnectorProcessResult {
    runExternalConnectorProcess(
        ExternalConnectorProcessRunConfiguration(executable: executable, arguments: arguments)
    )
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
