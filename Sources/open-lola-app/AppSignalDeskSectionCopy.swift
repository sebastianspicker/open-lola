// Section titles and detail copy for Signal Desk navigation chrome.
import OpenLolaCore

enum AppSignalDeskSectionCopy {
    private static let values: [NativeAppShellSurfaceSectionID: AppSignalDeskSectionCopyValue] = [
        .overview: .init(
            title: "Session",
            detail: "Establish the route, run audio first, and keep measured proof distinct from configuration."
        ),
        .session: .init(
            title: "Session",
            detail: "Establish the route, run audio first, and keep measured proof distinct from configuration."
        ),
        .devices: .init(
            title: "Devices",
            detail: "Choose the workflow, local media devices, and remote peer."
        ),
        .routing: .init(
            title: "Routing",
            detail: "Review the route, network fields, and generated artifacts."
        ),
        .streams: .init(
            title: "Streams",
            detail: "Inspect local preview and remote media evidence."
        ),
        .packetMonitor: .init(
            title: "Packet Monitor",
            detail: "Inspect decoded packet evidence or learn how to capture it."
        ),
        .validation: .init(
            title: "Validation",
            detail: "Validate the latest measured report and resolve evidence gaps."
        ),
        .diagnostics: .init(
            title: "Diagnostics",
            detail: "Inspect permissions, boundaries, execution, and raw diagnostics."
        ),
        .settings: .init(
            title: "Settings",
            detail: "Open durable application preferences."
        )
    ]

    static func title(for section: NativeAppShellSurfaceSectionID) -> String {
        value(for: section).title
    }

    static func detail(for section: NativeAppShellSurfaceSectionID) -> String {
        value(for: section).detail
    }

    private static func value(
        for section: NativeAppShellSurfaceSectionID
    ) -> AppSignalDeskSectionCopyValue {
        guard let value = values[section] else {
            preconditionFailure("Missing signal desk copy for \(section.rawValue)")
        }
        return value
    }
}

private struct AppSignalDeskSectionCopyValue {
    var title: String
    var detail: String
}
