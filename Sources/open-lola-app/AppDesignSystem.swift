// Renders AppDesignSystem in the operator interface, keeping SwiftUI presentation distinct from execution and persistence state.
import Foundation
#if canImport(AppKit)
import AppKit
#endif
import SwiftUI

enum AppDesignSystem {
    private static let colorTheme = AppColorTheme()
    private static let appBackgroundComponents = colorTheme.components(
        for: .appBackground,
        scheme: .dark,
        contrast: .standard
    )
    private static let lightAppBackgroundComponents = colorTheme.components(
        for: .appBackground,
        scheme: .light,
        contrast: .standard
    )
    private static let contrastEnvironments: [(scheme: ColorScheme, contrast: ColorSchemeContrast)] = [
        (.light, .standard),
        (.light, .increased),
        (.dark, .standard),
        (.dark, .increased)
    ]
    private static let statusBadgeToneRoles: [AppColorRole] = [
        .stateUnconfigured,
        .stateReady,
        .stateArmed,
        .stateConnecting,
        .stateLive,
        .stateError,
        .stateWarning
    ]
    private static let lightWarningTextComponents = colorTheme.components(
        for: .stateWarning,
        scheme: .light,
        contrast: .standard
    )
    private static let lightStateArmedComponents = colorTheme.components(
        for: .stateArmed,
        scheme: .light,
        contrast: .standard
    )
    private static let lightStateReadyComponents = colorTheme.components(
        for: .stateReady,
        scheme: .light,
        contrast: .standard
    )
    private static let lightStateLiveComponents = colorTheme.components(
        for: .stateLive,
        scheme: .light,
        contrast: .standard
    )
    private static let lightStateErrorComponents = colorTheme.components(
        for: .stateError,
        scheme: .light,
        contrast: .standard
    )
    private static let lightStateUnconfiguredComponents = colorTheme.components(
        for: .stateUnconfigured,
        scheme: .light,
        contrast: .standard
    )
    private static let secondaryTextReferenceComponents = AppColorComponents(red: 0.64, green: 0.64, blue: 0.66)
    static let minimumNormalTextContrastRatio = 4.5
    static let appBackgroundSecondaryTextContrastRatio =
        secondaryTextReferenceComponents.contrastRatio(against: appBackgroundComponents)
    static let appBackgroundMeetsSecondaryTextContrast =
        appBackgroundSecondaryTextContrastRatio >= minimumNormalTextContrastRatio
    static let warningTextLightModeContrastRatio =
        lightWarningTextComponents.contrastRatio(against: lightAppBackgroundComponents)
    static let stateArmedLightModeContrastRatio =
        lightStateArmedComponents.contrastRatio(against: lightAppBackgroundComponents)
    static let stateReadyLightModeContrastRatio =
        lightStateReadyComponents.contrastRatio(against: lightAppBackgroundComponents)
    static let stateLiveLightModeContrastRatio =
        lightStateLiveComponents.contrastRatio(against: lightAppBackgroundComponents)
    static let stateErrorLightModeContrastRatio =
        lightStateErrorComponents.contrastRatio(against: lightAppBackgroundComponents)
    static let stateUnconfiguredLightModeContrastRatio =
        lightStateUnconfiguredComponents.contrastRatio(against: lightAppBackgroundComponents)
    static let statusBadgeMinimumTextContrastRatio =
        minimumContrastRatio(statusBadgeTextContrastRatios)
    static let warningBannerMinimumTextContrastRatio =
        minimumContrastRatio(warningBannerTextContrastRatios)
    static let onStateFillText = Color.black

    /// Near-black operator console background.
    static let appBackground = color(.appBackground)
    /// Panel surface, slightly lighter than the window background.
    static let panelBackground = color(.panelBackground)
    /// Elevated card surface for cards nested inside panels.
    static let elevatedBackground = color(.elevatedBackground)
    /// 1px separator / border color.
    static let panelBorder = color(.panelBorder)
    static let sidebarBackground = color(.sidebarBackground)
    static let searchFieldBackground = color(.searchFieldBackground)
    static let footerBackground = color(.footerBackground)
    /// Single interaction accent for selection, primary actions, and navigation focus.
    static let interactionAccent = Color(red: 0.251, green: 0.549, blue: 1.000)
    static let dividerOpacity = 0.4

    /// No configuration present.
    static let stateUnconfigured = color(.stateUnconfigured)
    /// All required fields filled; ready to arm.
    static let stateReady = color(.stateReady)
    /// Armed and awaiting explicit start.
    static let stateArmed = color(.stateArmed)
    /// In the process of establishing a P2P connection.
    static let stateConnecting = color(.stateConnecting)
    /// Session is live and passing media.
    static let stateLive = color(.stateLive)
    /// An unrecoverable error has occurred.
    static let stateError = color(.stateError)
    /// Warning text and icon color with a WCAG-compliant light-mode variant.
    static let stateWarning = color(.stateWarning)
    /// Warning banner background paired with `stateWarning`.
    static let stateWarningBackground = color(.stateWarningBackground)

    /// Safe level: −∞ to −12 dBFS.
    static let meterSafe = color(.meterSafe)
    /// Caution level: −12 to −3 dBFS.
    static let meterCaution = color(.meterCaution)
    /// Clip level: −3 to 0 dBFS.
    static let meterClip = color(.meterClip)

    static func color(
        _ role: AppColorRole,
        scheme: ColorScheme? = nil,
        contrast: ColorSchemeContrast? = nil
    ) -> Color {
        guard let scheme else {
            return dynamicColor(role)
        }
        let contrast = contrast ?? .standard
        return colorTheme.color(for: role, scheme: scheme, contrast: contrast)
    }

    private static func dynamicColor(_ role: AppColorRole) -> Color {
        #if canImport(AppKit)
        Color(nsColor: NSColor(name: nil) { appearance in
            let environment = AppColorEnvironment(appearance: appearance)
            return colorTheme.components(
                for: role,
                scheme: environment.scheme,
                contrast: environment.contrast
            ).nsColor
        })
        #else
        colorTheme.color(for: role, scheme: .dark, contrast: .standard)
        #endif
    }

    private static var statusBadgeTextContrastRatios: [Double] {
        contrastEnvironments.flatMap { environment in
            statusBadgeToneRoles.map { role in
                let tone = colorTheme.components(
                    for: role,
                    scheme: environment.scheme,
                    contrast: environment.contrast
                )
                let base = colorTheme.components(
                    for: .panelBackground,
                    scheme: environment.scheme,
                    contrast: environment.contrast
                )
                let fill = tone.withAlpha(0.14).composited(over: base)
                return tone.contrastRatio(against: fill)
            }
        }
    }

    private static var warningBannerTextContrastRatios: [Double] {
        contrastEnvironments.map { environment in
            let tone = colorTheme.components(
                for: .stateWarning,
                scheme: environment.scheme,
                contrast: environment.contrast
            )
            let base = colorTheme.components(
                for: .panelBackground,
                scheme: environment.scheme,
                contrast: environment.contrast
            )
            let fill = colorTheme.components(
                for: .stateWarningBackground,
                scheme: environment.scheme,
                contrast: environment.contrast
            ).composited(over: base)
            return tone.contrastRatio(against: fill)
        }
    }

    private static func minimumContrastRatio(_ ratios: [Double]) -> Double {
        ratios.min() ?? 0
    }
}
