// Renders AppDesignSystemColor in the operator interface, keeping SwiftUI presentation distinct from execution and persistence state.
import Foundation
#if canImport(AppKit)
import AppKit
#endif
import SwiftUI

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

struct AppColorTheme: Sendable {
    private let palettes: [AppColorRole: AppColorPalette] = [
        .appBackground: AppColorPalette(
            lightStandard: AppColorComponents(red: 0.950, green: 0.960, blue: 0.970),
            lightIncreased: AppColorComponents(red: 0.980, green: 0.984, blue: 0.988),
            darkStandard: AppColorComponents(red: 0.043, green: 0.051, blue: 0.063),
            darkIncreased: AppColorComponents(red: 0.020, green: 0.024, blue: 0.030)
        ),
        .panelBackground: AppColorPalette(
            lightStandard: AppColorComponents(red: 0.985, green: 0.990, blue: 0.995),
            lightIncreased: AppColorComponents(red: 1.000, green: 1.000, blue: 1.000),
            darkStandard: AppColorComponents(red: 0.078, green: 0.086, blue: 0.106),
            darkIncreased: AppColorComponents(red: 0.055, green: 0.064, blue: 0.078)
        ),
        .elevatedBackground: AppColorPalette(
            lightStandard: AppColorComponents(red: 0.935, green: 0.945, blue: 0.958),
            lightIncreased: AppColorComponents(red: 0.965, green: 0.972, blue: 0.980),
            darkStandard: AppColorComponents(red: 0.110, green: 0.125, blue: 0.149),
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
            darkStandard: AppColorComponents(red: 0.078, green: 0.086, blue: 0.106)
        ),
        .searchFieldBackground: AppColorPalette(
            lightStandard: AppColorComponents(red: 0.000, green: 0.000, blue: 0.000, alpha: 0.06),
            darkStandard: AppColorComponents(red: 0.110, green: 0.125, blue: 0.149)
        ),
        .footerBackground: AppColorPalette(
            lightStandard: AppColorComponents(red: 0.000, green: 0.000, blue: 0.000, alpha: 0.03),
            darkStandard: AppColorComponents(red: 0.043, green: 0.051, blue: 0.063)
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
        )
    ]

    func color(for role: AppColorRole, scheme: ColorScheme, contrast: ColorSchemeContrast) -> Color {
        components(for: role, scheme: scheme, contrast: contrast).color
    }

    func components(for role: AppColorRole, scheme: ColorScheme, contrast: ColorSchemeContrast) -> AppColorComponents {
        palettes[role]?.components(scheme: scheme, contrast: contrast)
            ?? AppColorComponents(red: 0, green: 0, blue: 0)
    }
}

struct AppColorComponents: Sendable {
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

struct AppColorPalette: Sendable {
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
struct AppColorEnvironment {
    let scheme: ColorScheme
    let contrast: ColorSchemeContrast

    init(appearance: NSAppearance) {
        let match = appearance.bestMatch(from: [
            .accessibilityHighContrastDarkAqua,
            .darkAqua,
            .accessibilityHighContrastAqua,
            .aqua
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
