import Foundation

public struct DebugTraceEvent: Codable, Equatable, Sendable {
    public let capturedAt: String
    public let event: String
    public let fields: [String: String]

    public init(capturedAt: String, event: String, fields: [String: String]) {
        self.capturedAt = capturedAt
        self.event = event
        self.fields = fields
    }
}

public struct DebugTraceFieldPolicy: Equatable, Sendable {
    public static let `default` = DebugTraceFieldPolicy(
        allowedFieldKeys: [
            "attempt",
            "attempts",
            "bindhost",
            "bindport",
            "bytes",
            "channelcount",
            "count",
            "debugoutputpath",
            "diagnostics",
            "dscp",
            "durationseconds",
            "error",
            "framesperpacket",
            "host",
            "observedexternalendpoint",
            "outputpath",
            "peer",
            "peerendpoint",
            "peerid",
            "peerport",
            "port",
            "receivetimeoutseconds",
            "relayendpoint",
            "role",
            "rttmicroseconds",
            "sampleformat",
            "sampleratehertz",
            "sequence",
            "sessionid",
            "sourceevent",
            "succeeded",
        ],
        alwaysAllowedFieldKeys: ["payloadhash"],
        unsafeFieldKeyFragments: [
            "credential",
            "key",
            "payload",
            "payloaddata",
            "payloadsample",
            "rawpayload",
            "secret",
            "token",
        ]
    )

    public var allowedFieldKeys: Set<String>
    public var alwaysAllowedFieldKeys: Set<String>
    public var unsafeFieldKeyFragments: [String]

    public init(
        allowedFieldKeys: Set<String>,
        alwaysAllowedFieldKeys: Set<String> = [],
        unsafeFieldKeyFragments: [String] = []
    ) {
        self.allowedFieldKeys = Set(allowedFieldKeys.map { $0.lowercased() })
        self.alwaysAllowedFieldKeys = Set(alwaysAllowedFieldKeys.map { $0.lowercased() })
        self.unsafeFieldKeyFragments = unsafeFieldKeyFragments.map { $0.lowercased() }
    }

    public func allowing(_ fieldKeys: [String]) -> DebugTraceFieldPolicy {
        var copy = self
        copy.allowedFieldKeys.formUnion(fieldKeys.map { $0.lowercased() })
        return copy
    }

    func allows(_ fieldKey: String) -> Bool {
        let normalized = fieldKey.lowercased()
        if alwaysAllowedFieldKeys.contains(normalized) {
            return true
        }
        return !unsafeFieldKeyFragments.contains { normalized.contains($0) }
            && allowedFieldKeys.contains(normalized)
    }
}

public struct DebugTrace: Equatable, Sendable {
    public private(set) var events: [DebugTraceEvent]
    public private(set) var droppedEvents: Int
    public let limit: Int
    public let fieldPolicy: DebugTraceFieldPolicy

    public init(limit: Int = 2_048, fieldPolicy: DebugTraceFieldPolicy = .default) {
        self.events = []
        self.droppedEvents = 0
        self.limit = max(0, limit)
        self.fieldPolicy = fieldPolicy
    }

    public mutating func record(event: String, fields: [String: String] = [:]) {
        guard events.count < limit else {
            droppedEvents += 1
            return
        }

        events.append(
            DebugTraceEvent(
                capturedAt: DebugTraceTimestampFormatter.string(from: Date()),
                event: event,
                fields: sanitized(fields, policy: fieldPolicy)
            )
        )
    }

    public func jsonLines() -> String {
        return events.map { event in
            do {
                let data = try DebugTraceJSONEncoder.encode(event)
                return String(decoding: data, as: UTF8.self)
            } catch {
                return DebugTraceEncodingFailureLine.make(event: event.event, error: error)
            }
        }.joined(separator: "\n")
    }

    public func write(to path: String) throws {
        let outputURL = URL(fileURLWithPath: path)
        try FileManager.default.createDirectory(
            at: outputURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try (jsonLines() + "\n").write(to: outputURL, atomically: true, encoding: .utf8)
    }
}

public struct DebugTracedRunFailure: Error, Equatable, Sendable {
    public let failureDescription: String
    public let debugTrace: DebugTrace

    public init(failureDescription: String, debugTrace: DebugTrace) {
        self.failureDescription = failureDescription
        self.debugTrace = debugTrace
    }
}

private func sanitized(_ fields: [String: String], policy: DebugTraceFieldPolicy) -> [String: String] {
    fields.filter { key, _ in
        policy.allows(key)
    }
}

private enum DebugTraceTimestampFormatter {
    private static let style = Date.ISO8601FormatStyle()

    static func string(from date: Date) -> String {
        style.format(date)
    }
}

private enum DebugTraceEncodingFailureLine {
    static func make(event: String, error: Error) -> String {
        let fields = [
            "\"capturedAt\":\"\(jsonEscaped(DebugTraceTimestampFormatter.string(from: Date())))\"",
            "\"event\":\"debug-trace-encoding-failed\"",
            "\"fields\":{"
                + "\"error\":\"\(jsonEscaped(String(describing: error)))\","
                + "\"sourceEvent\":\"\(jsonEscaped(event))\""
                + "}",
        ]
        return "{\(fields.joined(separator: ","))}"
    }

    private static func jsonEscaped(_ value: String) -> String {
        var escaped = ""
        escaped.reserveCapacity(value.count)
        for scalar in value.unicodeScalars {
            switch scalar.value {
            case 0x08:
                escaped += "\\b"
            case 0x09:
                escaped += "\\t"
            case 0x0A:
                escaped += "\\n"
            case 0x0C:
                escaped += "\\f"
            case 0x0D:
                escaped += "\\r"
            case 0x22:
                escaped += "\\\""
            case 0x5C:
                escaped += "\\\\"
            case 0x00...0x1F:
                escaped += String(format: "\\u%04X", scalar.value)
            default:
                escaped.unicodeScalars.append(scalar)
            }
        }
        return escaped
    }
}

private enum DebugTraceJSONEncoder {
    static func encode<Event: Encodable>(_ event: Event) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(event)
    }
}
