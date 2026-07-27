// Provides DebugTrace diagnostic tracing, keeping optional observability out of normal control flow.
import Foundation

/// Records one timestamped Open LoLa diagnostic event after field-policy sanitization.
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

/// Defines DebugTraceFieldPolicy acceptance rules so callers receive deterministic pass or failure evidence.
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
            "succeeded"
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
            "token"
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

/// Accumulates a bounded, sanitized Open LoLa event trace and renders it as JSON Lines.
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
                capturedAt: Date.ISO8601FormatStyle().format(Date()),
                event: event,
                fields: sanitized(fields, policy: fieldPolicy)
            )
        )
    }

    public func jsonLines() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return events.map { event in
            do {
                let data = try encoder.encode(event)
                return debugTraceJSONLine(from: data)
            } catch {
                let failure: [String: Any] = [
                    "capturedAt": Date.ISO8601FormatStyle().format(Date()),
                    "event": "debug-trace-encoding-failed",
                    "fields": [
                        "error": String(describing: error),
                        "sourceEvent": event.event
                    ]
                ]
                guard let data = try? JSONSerialization.data(withJSONObject: failure, options: [.sortedKeys]) else {
                    return #"{"event":"debug-trace-encoding-failed"}"#
                }
                return debugTraceJSONLine(from: data)
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

/// Couples a run failure description with the diagnostic trace captured before termination.
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

private func debugTraceJSONLine(from data: Data) -> String {
    String(data: data, encoding: .utf8) ?? #"{"event":"debug-trace-invalid-utf8"}"#
}
