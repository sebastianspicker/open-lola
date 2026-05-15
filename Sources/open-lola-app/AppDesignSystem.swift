import Foundation
#if canImport(AppKit)
import AppKit
#endif
import SwiftUI

enum AppDesignSystem {
    private static let colorTheme: AppColorTheme = AppDefaultColorTheme()
    private static let appBackgroundComponents = colorTheme.components(
        for: .appBackground,
        scheme: .dark,
        contrast: .standard
    )
    private static let secondaryTextReferenceComponents = AppColorComponents(red: 0.64, green: 0.64, blue: 0.66)
    static let minimumNormalTextContrastRatio = 4.5
    static let appBackgroundSecondaryTextContrastRatio =
        secondaryTextReferenceComponents.contrastRatio(against: appBackgroundComponents)
    static let appBackgroundMeetsSecondaryTextContrast =
        appBackgroundSecondaryTextContrastRatio >= minimumNormalTextContrastRatio
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
    case meterSafe
    case meterCaution
    case meterClip
}

private protocol AppColorTheme: Sendable {
    func color(for role: AppColorRole, scheme: ColorScheme, contrast: ColorSchemeContrast) -> Color
    func components(for role: AppColorRole, scheme: ColorScheme, contrast: ColorSchemeContrast) -> AppColorComponents
}

private struct AppDefaultColorTheme: AppColorTheme {
    func color(for role: AppColorRole, scheme: ColorScheme, contrast: ColorSchemeContrast) -> Color {
        components(for: role, scheme: scheme, contrast: contrast).color
    }

    func components(for role: AppColorRole, scheme: ColorScheme, contrast: ColorSchemeContrast) -> AppColorComponents {
        switch (role, scheme, contrast) {
        case (.appBackground, .light, .increased):
            AppColorComponents(red: 0.980, green: 0.984, blue: 0.988)
        case (.appBackground, .light, _):
            AppColorComponents(red: 0.950, green: 0.960, blue: 0.970)
        case (.appBackground, _, .increased):
            AppColorComponents(red: 0.020, green: 0.024, blue: 0.030)
        case (.appBackground, _, _):
            AppColorComponents(red: 0.045, green: 0.052, blue: 0.064)
        case (.panelBackground, .light, .increased):
            AppColorComponents(red: 1.000, green: 1.000, blue: 1.000)
        case (.panelBackground, .light, _):
            AppColorComponents(red: 0.985, green: 0.990, blue: 0.995)
        case (.panelBackground, _, .increased):
            AppColorComponents(red: 0.055, green: 0.064, blue: 0.078)
        case (.panelBackground, _, _):
            AppColorComponents(red: 0.078, green: 0.088, blue: 0.104)
        case (.elevatedBackground, .light, .increased):
            AppColorComponents(red: 0.965, green: 0.972, blue: 0.980)
        case (.elevatedBackground, .light, _):
            AppColorComponents(red: 0.935, green: 0.945, blue: 0.958)
        case (.elevatedBackground, _, .increased):
            AppColorComponents(red: 0.090, green: 0.104, blue: 0.124)
        case (.elevatedBackground, _, _):
            AppColorComponents(red: 0.110, green: 0.125, blue: 0.148)
        case (.meterSafe, _, .increased):
            AppColorComponents(red: 0.060, green: 0.680, blue: 0.260)
        case (.meterSafe, _, _):
            AppColorComponents(red: 0.200, green: 0.780, blue: 0.420)
        case (.meterCaution, _, .increased):
            AppColorComponents(red: 1.000, green: 0.640, blue: 0.000)
        case (.meterCaution, _, _):
            AppColorComponents(red: 0.950, green: 0.780, blue: 0.100)
        case (.panelBorder, .dark, .increased):
            AppColorComponents(red: 1.000, green: 1.000, blue: 1.000, alpha: 0.22)
        case (.panelBorder, .dark, _):
            AppColorComponents(red: 1.000, green: 1.000, blue: 1.000, alpha: 0.09)
        case (.panelBorder, .light, .increased):
            AppColorComponents(red: 0.000, green: 0.000, blue: 0.000, alpha: 0.22)
        case (.panelBorder, .light, _):
            AppColorComponents(red: 0.000, green: 0.000, blue: 0.000, alpha: 0.14)
        case (.sidebarBackground, .dark, _):
            AppColorComponents(red: 0.000, green: 0.000, blue: 0.000, alpha: 0.28)
        case (.sidebarBackground, .light, _):
            AppColorComponents(red: 0.000, green: 0.000, blue: 0.000, alpha: 0.04)
        case (.searchFieldBackground, .dark, _):
            AppColorComponents(red: 1.000, green: 1.000, blue: 1.000, alpha: 0.12)
        case (.searchFieldBackground, .light, _):
            AppColorComponents(red: 0.000, green: 0.000, blue: 0.000, alpha: 0.06)
        case (.footerBackground, .dark, _):
            AppColorComponents(red: 0.000, green: 0.000, blue: 0.000, alpha: 0.18)
        case (.footerBackground, .light, _):
            AppColorComponents(red: 0.000, green: 0.000, blue: 0.000, alpha: 0.03)
        case (.stateUnconfigured, .dark, _):
            AppColorComponents(red: 0.640, green: 0.640, blue: 0.660)
        case (.stateUnconfigured, .light, _):
            AppColorComponents(red: 0.420, green: 0.430, blue: 0.460)
        case (.stateReady, .dark, _):
            AppColorComponents(red: 1.000, green: 0.820, blue: 0.000)
        case (.stateReady, .light, _):
            AppColorComponents(red: 0.720, green: 0.360, blue: 0.000)
        case (.stateArmed, _, _):
            AppColorComponents(red: 0.950, green: 0.480, blue: 0.000)
        case (.stateConnecting, .dark, _):
            AppColorComponents(red: 0.250, green: 0.550, blue: 1.000)
        case (.stateConnecting, .light, _):
            AppColorComponents(red: 0.000, green: 0.290, blue: 0.700)
        case (.stateLive, .dark, _):
            AppColorComponents(red: 0.180, green: 0.780, blue: 0.320)
        case (.stateLive, .light, _):
            AppColorComponents(red: 0.080, green: 0.540, blue: 0.210)
        case (.stateError, .dark, _):
            AppColorComponents(red: 1.000, green: 0.270, blue: 0.250)
        case (.stateError, .light, _):
            AppColorComponents(red: 0.780, green: 0.000, blue: 0.000)
        case (.meterClip, _, _):
            AppColorComponents(red: 1.000, green: 0.170, blue: 0.170)
        default:
            AppColorComponents(red: 0, green: 0, blue: 0)
        }
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

    private func linearized(_ component: Double) -> Double {
        component <= 0.03928 ? component / 12.92 : pow((component + 0.055) / 1.055, 2.4)
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
enum AppSessionState: String {
    case unconfigured = "Unconfigured"
    case ready = "Ready"
    case armed = "Armed"
    case connecting = "Connecting"
    case supervisorRunning = "Supervisor Running"
    case dryRunRunning = "Dry Run Running"
    case awaitingEvidence = "Awaiting Evidence"
    case live = "Live"
    case error = "Error"

    var color: Color {
        switch self {
        case .unconfigured: AppDesignSystem.stateUnconfigured
        case .ready: AppDesignSystem.stateReady
        case .armed: AppDesignSystem.stateArmed
        case .connecting: AppDesignSystem.stateConnecting
        case .supervisorRunning: AppDesignSystem.stateConnecting
        case .dryRunRunning: AppDesignSystem.stateArmed
        case .awaitingEvidence: AppDesignSystem.stateReady
        case .live: AppDesignSystem.stateLive
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
        case .awaitingEvidence: "clock.badge.exclamationmark"
        case .live: "circle.fill"
        case .error: "exclamationmark.triangle.fill"
        }
    }

    var isAnimated: Bool {
        switch self {
        case .armed, .connecting, .supervisorRunning, .dryRunRunning, .awaitingEvidence, .live: true
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
