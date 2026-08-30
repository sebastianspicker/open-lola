// Defines console overview rows and summaries, keeping high-level presentation data together.
import OpenLolaCore

struct AppOverviewStatusItem: Equatable, Identifiable {
    let id: String
    let title: String
    let value: String
    let systemImage: String
}

struct AppOverviewNextAction: Equatable {
    let title: String
    let detail: String
    let targetSection: NativeAppShellSurfaceSectionID
    let systemImage: String
}

struct AppOverviewEvidenceSummary: Equatable {
    let sourceVerdict: String
    let runtimeEvidence: String
    let latestReportPath: String
    let freshness: String
}
