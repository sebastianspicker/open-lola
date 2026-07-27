// Supports AppExecutionErrorGuidance launch and evidence handling, keeping process details out of the primary operator surface.
enum AppExecutionErrorGuidance {
    static func detail(for error: String) -> String {
        let lowercased = error.lowercased()
        if isReportPathError(lowercased) {
            return "Generate or load the report path shown in Report Paths before validating."
        }
        if isExecutablePathError(lowercased) {
            return "Check the executable path in Settings > Execution."
        }
        if isPlanError(lowercased) {
            return "Review the plan fields and generated command before launching again."
        }
        return "Review the log paths and error details shown in this section."
    }

    private static func isReportPathError(_ lowercased: String) -> Bool {
        containsAny(
            lowercased,
            keywords: ["missing report", "supervisor report", "external connector report"]
        )
    }

    private static func isExecutablePathError(_ lowercased: String) -> Bool {
        containsAny(lowercased, keywords: ["executable", "no such file", "posix"])
    }

    private static func isPlanError(_ lowercased: String) -> Bool {
        containsAny(lowercased, keywords: ["plan", "configuration"])
    }

    private static func containsAny(_ text: String, keywords: [String]) -> Bool {
        keywords.contains { text.contains($0) }
    }
}
