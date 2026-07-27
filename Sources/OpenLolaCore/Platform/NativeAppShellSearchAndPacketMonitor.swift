// Defines native-app shell packet, frame, or monitor values and conversion helpers so producers and consumers agree on their exchanged representation.
import Foundation

/// Defines the supported choices for native app packet stream filter.
public enum NativeAppPacketStreamFilter: String, CaseIterable, Codable, Equatable, Identifiable, Sendable {
    case all = "All"
    case audio = "Audio"
    case video = "Video"

    public var id: String { rawValue }
}

/// Defines the validated fields for native app packet monitor row.
public struct NativeAppPacketMonitorRow: Equatable, Identifiable, Sendable {
    public let id: Int
    public let streamType: LoLaCompatibilityCaptureStream
    public let stream: String
    public let source: String
    public let destination: String
    public let payload: String
    public let candidate: String
    public let accessibilityLabel: String

    public init(packet: LoLaCompatibilityCapturePacketReport) {
        id = packet.index
        streamType = packet.stream
        stream = packet.stream.rawValue
        source = Self.endpoint(packet.sourceIP, packet.sourcePort)
        destination = Self.endpoint(packet.destinationIP, packet.destinationPort)
        payload = packet.payloadLength.map { "\($0) B" } ?? "n/a"
        candidate = packet.mediaPayloadCandidate?.rawValue ?? packet.controlMessageName ?? "n/a"
        accessibilityLabel = [
            "Packet \(packet.index)",
            "stream \(stream)",
            "from \(source) to \(destination)",
            "payload \(payload)",
            "candidate \(candidate)"
        ].joined(separator: ", ")
    }

    private static func endpoint(_ host: String?, _ port: UInt16?) -> String {
        guard let host, let port else {
            return "n/a"
        }
        return "\(host):\(port)"
    }
}

/// Defines failures reported when native app packet monitor rows error cannot continue.
public enum NativeAppPacketMonitorRowsError: Error, Equatable, Sendable {
    case negativeLimit(Int)
}

/// Defines the values accepted for native app packet monitor rows.
public enum NativeAppPacketMonitorRows {
    public static func rows(
        report: LoLaCompatibilityCaptureReport,
        streamFilter: NativeAppPacketStreamFilter = .all,
        searchText: String = "",
        limit: Int
    ) throws -> [NativeAppPacketMonitorRow] {
        guard limit >= 0 else {
            throw NativeAppPacketMonitorRowsError.negativeLimit(limit)
        }
        var rows = report.packets.prefix(limit).map(NativeAppPacketMonitorRow.init(packet:))

        switch streamFilter {
        case .audio:
            rows = rows.filter { $0.streamType == .audio }
        case .video:
            rows = rows.filter { $0.streamType == .video }
        case .all:
            break
        }

        let query = normalized(searchText.trimmingCharacters(in: .whitespacesAndNewlines))
        guard !query.isEmpty else {
            return Array(rows)
        }

        return rows.filter {
            normalizedContains($0.stream, query) ||
                normalizedContains($0.source, query) ||
                normalizedContains($0.destination, query) ||
                normalizedContains($0.candidate, query)
        }
    }
}

/// Filters native shell sections and actions by normalized operator search text.
public enum NativeAppShellSectionSearch {
    public static func visibleSections(
        _ sections: [NativeAppShellSurfaceSection],
        query: String
    ) -> [NativeAppShellSurfaceSection] {
        let normalizedQuery = normalized(query.trimmingCharacters(in: .whitespacesAndNewlines))
        guard !normalizedQuery.isEmpty else {
            return sections
        }
        return sections.filter {
            normalizedContains($0.title, normalizedQuery) ||
                normalizedContains($0.id.rawValue, normalizedQuery)
        }
    }
}

private func normalized(_ value: String) -> String {
    value.precomposedStringWithCanonicalMapping
}

private func normalizedContains(_ value: String, _ query: String) -> Bool {
    normalized(value).localizedCaseInsensitiveContains(query)
}
