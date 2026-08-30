// Defines shared console selection behavior, keeping navigation resolution separate from display models.
import OpenLolaCore

enum AppConsoleSectionSelection {
    static func activeSection(
        current: NativeAppShellSurfaceSectionID,
        visibleSections: [NativeAppShellSurfaceSection],
        sessionState: AppSessionState,
        captureReportAvailable: Bool
    ) -> NativeAppShellSurfaceSectionID? {
        let visibleIDs = Set(visibleSections.map(\.id))
        guard visibleIDs.contains(current),
              isAvailable(current, sessionState: sessionState, captureReportAvailable: captureReportAvailable) else {
            return nil
        }
        return current
    }

    static func resolvedSection(
        current: NativeAppShellSurfaceSectionID,
        visibleSections: [NativeAppShellSurfaceSection],
        sessionState: AppSessionState,
        captureReportAvailable: Bool
    ) -> NativeAppShellSurfaceSectionID? {
        activeSection(
            current: current,
            visibleSections: visibleSections,
            sessionState: sessionState,
            captureReportAvailable: captureReportAvailable
        )
            ?? replacementSection(
                visibleSections: visibleSections,
                sessionState: sessionState,
                captureReportAvailable: captureReportAvailable
            )
    }

    private static func replacementSection(
        visibleSections: [NativeAppShellSurfaceSection],
        sessionState: AppSessionState,
        captureReportAvailable: Bool
    ) -> NativeAppShellSurfaceSectionID? {
        visibleSections.first {
            isAvailable($0.id, sessionState: sessionState, captureReportAvailable: captureReportAvailable)
        }?.id
    }

    private static func isAvailable(
        _: NativeAppShellSurfaceSectionID,
        sessionState _: AppSessionState,
        captureReportAvailable _: Bool
    ) -> Bool {
        true
    }
}
