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
        (.dark, .increased),
    ]
    private static let statusBadgeToneRoles: [AppColorRole] = [
        .stateUnconfigured,
        .stateReady,
        .stateArmed,
        .stateConnecting,
        .stateLive,
        .stateError,
        .stateWarning,
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
    /// Panel surface — slightly lighter than the window background.
    static let panelBackground = color(.panelBackground)
    /// Elevated card surface — for cards nested inside panels.
    static let elevatedBackground = color(.elevatedBackground)
    /// 1px separator / border color.
    static let panelBorder = color(.panelBorder)
    static let sidebarBackground = color(.sidebarBackground)
    static let searchFieldBackground = color(.searchFieldBackground)
    static let footerBackground = color(.footerBackground)
    static let dividerOpacity = 0.4

    /// No configuration present.
    static let stateUnconfigured = color(.stateUnconfigured)
    /// All required fields filled; ready to arm.
    static let stateReady = color(.stateReady)
    /// Armed — awaiting explicit start.
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

enum AppColorRole: Sendable {
    case appBackground
    case panelBackground
    case elevatedBackground
    case panelBorder
    case sidebarBackground
    case searchFieldBackground
    case footerBackground
    case stateUnconfigured
    case stateReady
    case stateArmed
    case stateConnecting
    case stateLive
    case stateError
    case stateWarning
    case stateWarningBackground
    case meterSafe
    case meterCaution
    case meterClip
}

private struct AppColorTheme: Sendable {
    private let palettes: [AppColorRole: AppColorPalette] = [
        .appBackground: AppColorPalette(
            lightStandard: AppColorComponents(red: 0.950, green: 0.960, blue: 0.970),
            lightIncreased: AppColorComponents(red: 0.980, green: 0.984, blue: 0.988),
            darkStandard: AppColorComponents(red: 0.045, green: 0.052, blue: 0.064),
            darkIncreased: AppColorComponents(red: 0.020, green: 0.024, blue: 0.030)
        ),
        .panelBackground: AppColorPalette(
            lightStandard: AppColorComponents(red: 0.985, green: 0.990, blue: 0.995),
            lightIncreased: AppColorComponents(red: 1.000, green: 1.000, blue: 1.000),
            darkStandard: AppColorComponents(red: 0.078, green: 0.088, blue: 0.104),
            darkIncreased: AppColorComponents(red: 0.055, green: 0.064, blue: 0.078)
        ),
        .elevatedBackground: AppColorPalette(
            lightStandard: AppColorComponents(red: 0.935, green: 0.945, blue: 0.958),
            lightIncreased: AppColorComponents(red: 0.965, green: 0.972, blue: 0.980),
            darkStandard: AppColorComponents(red: 0.110, green: 0.125, blue: 0.148),
            darkIncreased: AppColorComponents(red: 0.090, green: 0.104, blue: 0.124)
        ),
        .meterSafe: AppColorPalette(
            lightStandard: AppColorComponents(red: 0.200, green: 0.780, blue: 0.420),
            lightIncreased: AppColorComponents(red: 0.060, green: 0.680, blue: 0.260),
            darkStandard: AppColorComponents(red: 0.200, green: 0.780, blue: 0.420),
            darkIncreased: AppColorComponents(red: 0.060, green: 0.680, blue: 0.260)
        ),
        .meterCaution: AppColorPalette(
            lightStandard: AppColorComponents(red: 0.950, green: 0.780, blue: 0.100),
            lightIncreased: AppColorComponents(red: 1.000, green: 0.640, blue: 0.000),
            darkStandard: AppColorComponents(red: 0.950, green: 0.780, blue: 0.100),
            darkIncreased: AppColorComponents(red: 1.000, green: 0.640, blue: 0.000)
        ),
        .panelBorder: AppColorPalette(
            lightStandard: AppColorComponents(red: 0.000, green: 0.000, blue: 0.000, alpha: 0.14),
            lightIncreased: AppColorComponents(red: 0.000, green: 0.000, blue: 0.000, alpha: 0.22),
            darkStandard: AppColorComponents(red: 1.000, green: 1.000, blue: 1.000, alpha: 0.09),
            darkIncreased: AppColorComponents(red: 1.000, green: 1.000, blue: 1.000, alpha: 0.22)
        ),
        .sidebarBackground: AppColorPalette(
            lightStandard: AppColorComponents(red: 0.000, green: 0.000, blue: 0.000, alpha: 0.04),
            darkStandard: AppColorComponents(red: 0.000, green: 0.000, blue: 0.000, alpha: 0.28)
        ),
        .searchFieldBackground: AppColorPalette(
            lightStandard: AppColorComponents(red: 0.000, green: 0.000, blue: 0.000, alpha: 0.06),
            darkStandard: AppColorComponents(red: 1.000, green: 1.000, blue: 1.000, alpha: 0.12)
        ),
        .footerBackground: AppColorPalette(
            lightStandard: AppColorComponents(red: 0.000, green: 0.000, blue: 0.000, alpha: 0.03),
            darkStandard: AppColorComponents(red: 0.000, green: 0.000, blue: 0.000, alpha: 0.18)
        ),
        .stateUnconfigured: AppColorPalette(
            lightStandard: AppColorComponents(red: 0.380, green: 0.390, blue: 0.420),
            darkStandard: AppColorComponents(red: 0.640, green: 0.640, blue: 0.660)
        ),
        .stateReady: AppColorPalette(
            lightStandard: AppColorComponents(red: 0.620, green: 0.310, blue: 0.000),
            lightIncreased: AppColorComponents(red: 0.500, green: 0.240, blue: 0.000),
            darkStandard: AppColorComponents(red: 1.000, green: 0.820, blue: 0.000),
            darkIncreased: AppColorComponents(red: 1.000, green: 0.880, blue: 0.120)
        ),
        .stateArmed: AppColorPalette(
            lightStandard: AppColorComponents(red: 0.550, green: 0.220, blue: 0.000),
            lightIncreased: AppColorComponents(red: 0.420, green: 0.160, blue: 0.000),
            darkStandard: AppColorComponents(red: 0.950, green: 0.480, blue: 0.000),
            darkIncreased: AppColorComponents(red: 1.000, green: 0.620, blue: 0.050)
        ),
        .stateConnecting: AppColorPalette(
            lightStandard: AppColorComponents(red: 0.000, green: 0.290, blue: 0.700),
            darkStandard: AppColorComponents(red: 0.250, green: 0.550, blue: 1.000)
        ),
        .stateLive: AppColorPalette(
            lightStandard: AppColorComponents(red: 0.000, green: 0.430, blue: 0.140),
            lightIncreased: AppColorComponents(red: 0.000, green: 0.320, blue: 0.100),
            darkStandard: AppColorComponents(red: 0.180, green: 0.780, blue: 0.320),
            darkIncreased: AppColorComponents(red: 0.280, green: 0.920, blue: 0.430)
        ),
        .stateError: AppColorPalette(
            lightStandard: AppColorComponents(red: 0.780, green: 0.000, blue: 0.000),
            lightIncreased: AppColorComponents(red: 0.620, green: 0.000, blue: 0.000),
            darkStandard: AppColorComponents(red: 1.000, green: 0.270, blue: 0.250),
            darkIncreased: AppColorComponents(red: 1.000, green: 0.380, blue: 0.360)
        ),
        .stateWarning: AppColorPalette(
            lightStandard: AppColorComponents(red: 0.500, green: 0.250, blue: 0.000),
            lightIncreased: AppColorComponents(red: 0.380, green: 0.160, blue: 0.000),
            darkStandard: AppColorComponents(red: 1.000, green: 0.640, blue: 0.000),
            darkIncreased: AppColorComponents(red: 1.000, green: 0.720, blue: 0.120)
        ),
        .stateWarningBackground: AppColorPalette(
            lightStandard: AppColorComponents(red: 1.000, green: 0.950, blue: 0.800),
            darkStandard: AppColorComponents(red: 1.000, green: 0.640, blue: 0.000, alpha: 0.14)
        ),
        .meterClip: AppColorPalette(
            lightStandard: AppColorComponents(red: 1.000, green: 0.170, blue: 0.170),
            darkStandard: AppColorComponents(red: 1.000, green: 0.170, blue: 0.170)
        ),
    ]

    func color(for role: AppColorRole, scheme: ColorScheme, contrast: ColorSchemeContrast) -> Color {
        components(for: role, scheme: scheme, contrast: contrast).color
    }

    func components(for role: AppColorRole, scheme: ColorScheme, contrast: ColorSchemeContrast) -> AppColorComponents {
        palettes[role]?.components(scheme: scheme, contrast: contrast)
            ?? AppColorComponents(red: 0, green: 0, blue: 0)
    }
}

private struct AppColorComponents: Sendable {
    let red: Double
    let green: Double
    let blue: Double
    var alpha: Double = 1

    var color: Color {
        Color(red: red, green: green, blue: blue).opacity(alpha)
    }

    #if canImport(AppKit)
    var nsColor: NSColor {
        NSColor(calibratedRed: red, green: green, blue: blue, alpha: alpha)
    }
    #endif

    var relativeLuminance: Double {
        0.2126 * linearized(red) + 0.7152 * linearized(green) + 0.0722 * linearized(blue)
    }

    func contrastRatio(against background: AppColorComponents) -> Double {
        let lighter = max(relativeLuminance, background.relativeLuminance)
        let darker = min(relativeLuminance, background.relativeLuminance)
        return (lighter + 0.05) / (darker + 0.05)
    }

    func withAlpha(_ alpha: Double) -> AppColorComponents {
        AppColorComponents(red: red, green: green, blue: blue, alpha: alpha)
    }

    func composited(over background: AppColorComponents) -> AppColorComponents {
        let outputAlpha = alpha + background.alpha * (1 - alpha)
        guard outputAlpha > 0 else {
            return AppColorComponents(red: 0, green: 0, blue: 0, alpha: 0)
        }
        return AppColorComponents(
            red: ((red * alpha) + (background.red * background.alpha * (1 - alpha))) / outputAlpha,
            green: ((green * alpha) + (background.green * background.alpha * (1 - alpha))) / outputAlpha,
            blue: ((blue * alpha) + (background.blue * background.alpha * (1 - alpha))) / outputAlpha,
            alpha: outputAlpha
        )
    }

    private func linearized(_ component: Double) -> Double {
        component <= 0.03928 ? component / 12.92 : pow((component + 0.055) / 1.055, 2.4)
    }
}

private struct AppColorPalette: Sendable {
    let lightStandard: AppColorComponents
    let lightIncreased: AppColorComponents
    let darkStandard: AppColorComponents
    let darkIncreased: AppColorComponents

    init(
        lightStandard: AppColorComponents,
        lightIncreased: AppColorComponents? = nil,
        darkStandard: AppColorComponents,
        darkIncreased: AppColorComponents? = nil
    ) {
        self.lightStandard = lightStandard
        self.lightIncreased = lightIncreased ?? lightStandard
        self.darkStandard = darkStandard
        self.darkIncreased = darkIncreased ?? darkStandard
    }

    func components(scheme: ColorScheme, contrast: ColorSchemeContrast) -> AppColorComponents {
        switch (scheme, contrast) {
        case (.light, .increased):
            lightIncreased
        case (.light, _):
            lightStandard
        case (_, .increased):
            darkIncreased
        case (_, _):
            darkStandard
        }
    }
}

#if canImport(AppKit)
private struct AppColorEnvironment {
    let scheme: ColorScheme
    let contrast: ColorSchemeContrast

    init(appearance: NSAppearance) {
        let match = appearance.bestMatch(from: [
            .accessibilityHighContrastDarkAqua,
            .darkAqua,
            .accessibilityHighContrastAqua,
            .aqua,
        ])
        switch match {
        case .darkAqua, .accessibilityHighContrastDarkAqua:
            scheme = .dark
        default:
            scheme = .light
        }
        switch match {
        case .accessibilityHighContrastAqua, .accessibilityHighContrastDarkAqua:
            contrast = .increased
        default:
            contrast = .standard
        }
    }
}
#endif

enum AppConstants {
    static let packetMonitorCapacity = 100
}

// MARK: - Spacing scale

enum AppSpacing {
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 8
    static let s: CGFloat = 12
    static let m: CGFloat = 16
    static let l: CGFloat = 24
    static let xl: CGFloat = 32
}

// MARK: - Typography helpers

extension Font {
    /// Large hero display for the latency readout — thin monospaced.
    static var latencyHero: Font {
        .system(.largeTitle, design: .monospaced).weight(.bold)
    }

    /// Medium metrics value — semibold monospaced.
    static var metricsValue: Font {
        .system(size: 13, weight: .semibold, design: .monospaced)
    }
}

// MARK: - Window minimum sizes

enum AppWindowSize {
    static let operatorMinWidth: CGFloat = 1024
    static let operatorMinHeight: CGFloat = 720
    static let sessionMonitorMinWidth: CGFloat = 1080
    static let sessionMonitorMinHeight: CGFloat = 720
    static let settingsMinWidth: CGFloat = 540
    static let settingsMaxWidth: CGFloat = 800
    static let settingsWidth: CGFloat = 680
    static let sidebarWidth: CGFloat = 240
}

// MARK: - Session state machine

/// Ordered states for the P2P session lifecycle.
enum AppSessionState: String, CaseIterable {
    case unconfigured = "Unconfigured"
    case ready = "Ready"
    case armed = "Armed"
    case connecting = "Connecting"
    case supervisorRunning = "Supervisor Running"
    case dryRunRunning = "Dry Run Running"
    case validating = "Validating"
    case awaitingEvidence = "Awaiting Evidence"
    case validated = "Evidence Validated"
    case receiverWarning = "Preview Warning"
    case error = "Error"

    var color: Color {
        switch self {
        case .unconfigured: AppDesignSystem.stateUnconfigured
        case .ready: AppDesignSystem.stateReady
        case .armed: AppDesignSystem.stateArmed
        case .connecting: AppDesignSystem.stateConnecting
        case .supervisorRunning: AppDesignSystem.stateConnecting
        case .dryRunRunning: AppDesignSystem.stateArmed
        case .validating: AppDesignSystem.stateConnecting
        case .awaitingEvidence: AppDesignSystem.stateReady
        case .validated: AppDesignSystem.stateReady
        case .receiverWarning: AppDesignSystem.stateWarning
        case .error: AppDesignSystem.stateError
        }
    }

    var systemImage: String {
        switch self {
        case .unconfigured: "exclamationmark.circle"
        case .ready: "flag"
        case .armed: "checkmark.shield.fill"
        case .connecting: "dot.radiowaves.left.and.right"
        case .supervisorRunning: "terminal"
        case .dryRunRunning: "doc.text.magnifyingglass"
        case .validating: "checkmark.seal"
        case .awaitingEvidence: "clock.badge.exclamationmark"
        case .validated: "checkmark.seal.fill"
        case .receiverWarning: "exclamationmark.triangle.fill"
        case .error: "exclamationmark.triangle.fill"
        }
    }

    var isAnimated: Bool {
        switch self {
        case .armed, .connecting, .supervisorRunning, .dryRunRunning, .validating, .awaitingEvidence, .receiverWarning: true
        default: false
        }
    }
}

// MARK: - Design-system-aware panel

/// A panel card that supports both the standard surface and a nested elevated surface.
struct DesignPanel<Content: View>: View {
    let title: String
    let systemImage: String
    var elevated: Bool = false
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.s) {
            Label(title, systemImage: systemImage)
                .font(.headline)
            content
        }
        .padding(AppSpacing.m - 2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            elevated ? AppDesignSystem.elevatedBackground : AppDesignSystem.panelBackground,
            in: RoundedRectangle(cornerRadius: 8)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(AppDesignSystem.panelBorder, lineWidth: 1)
        }
    }
}

// MARK: - Monospaced-digit label helpers

extension LabeledContent where Label == Text, Content == Text {
    /// Numeric value rendered with `.monospacedDigit()` for stable layout.
    static func metric(_ label: String, value: String) -> some View {
        LabeledContent(label) {
            Text(value)
                .monospacedDigit()
        }
    }
}
