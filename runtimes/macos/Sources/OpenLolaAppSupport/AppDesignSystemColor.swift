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
    case interactionAccent
    case signalAccent
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
            lightStandard: AppColorComponents(red: 246.0 / 255.0, green: 246.0 / 255.0, blue: 243.0 / 255.0),
            lightIncreased: AppColorComponents(red: 1.000, green: 1.000, blue: 0.988),
            darkStandard: AppColorComponents(red: 18.0 / 255.0, green: 20.0 / 255.0, blue: 21.0 / 255.0),
            darkIncreased: AppColorComponents(red: 0.051, green: 0.055, blue: 0.059)
        ),
        .panelBackground: AppColorPalette(
            lightStandard: AppColorComponents(red: 0.984, green: 0.984, blue: 0.973),
            lightIncreased: AppColorComponents(red: 1.000, green: 1.000, blue: 0.992),
            darkStandard: AppColorComponents(red: 27.0 / 255.0, green: 30.0 / 255.0, blue: 32.0 / 255.0),
            darkIncreased: AppColorComponents(red: 0.125, green: 0.137, blue: 0.145)
        ),
        .elevatedBackground: AppColorPalette(
            lightStandard: AppColorComponents(red: 1.000, green: 1.000, blue: 0.992),
            lightIncreased: AppColorComponents(red: 1.000, green: 1.000, blue: 1.000),
            darkStandard: AppColorComponents(red: 32.0 / 255.0, green: 35.0 / 255.0, blue: 37.0 / 255.0),
            darkIncreased: AppColorComponents(red: 0.145, green: 0.157, blue: 0.165)
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
            lightStandard: AppColorComponents(red: 18.0 / 255.0, green: 20.0 / 255.0, blue: 21.0 / 255.0, alpha: 0.14),
            lightIncreased: AppColorComponents(red: 18.0 / 255.0, green: 20.0 / 255.0, blue: 21.0 / 255.0, alpha: 0.28),
            darkStandard: AppColorComponents(red: 246.0 / 255.0, green: 246.0 / 255.0, blue: 243.0 / 255.0, alpha: 0.11),
            darkIncreased: AppColorComponents(red: 246.0 / 255.0, green: 246.0 / 255.0, blue: 243.0 / 255.0, alpha: 0.26)
        ),
        .sidebarBackground: AppColorPalette(
            lightStandard: AppColorComponents(red: 0.937, green: 0.937, blue: 0.925),
            lightIncreased: AppColorComponents(red: 0.953, green: 0.953, blue: 0.941),
            darkStandard: AppColorComponents(red: 27.0 / 255.0, green: 30.0 / 255.0, blue: 32.0 / 255.0),
            darkIncreased: AppColorComponents(red: 0.125, green: 0.137, blue: 0.145)
        ),
        .searchFieldBackground: AppColorPalette(
            lightStandard: AppColorComponents(red: 18.0 / 255.0, green: 20.0 / 255.0, blue: 21.0 / 255.0, alpha: 0.06),
            lightIncreased: AppColorComponents(red: 18.0 / 255.0, green: 20.0 / 255.0, blue: 21.0 / 255.0, alpha: 0.10),
            darkStandard: AppColorComponents(red: 32.0 / 255.0, green: 35.0 / 255.0, blue: 37.0 / 255.0),
            darkIncreased: AppColorComponents(red: 0.145, green: 0.157, blue: 0.165)
        ),
        .footerBackground: AppColorPalette(
            lightStandard: AppColorComponents(red: 0.953, green: 0.953, blue: 0.941),
            lightIncreased: AppColorComponents(red: 0.965, green: 0.965, blue: 0.953),
            darkStandard: AppColorComponents(red: 18.0 / 255.0, green: 20.0 / 255.0, blue: 21.0 / 255.0),
            darkIncreased: AppColorComponents(red: 0.051, green: 0.055, blue: 0.059)
        ),
        .interactionAccent: AppColorPalette(
            lightStandard: AppColorComponents(red: 18.0 / 255.0, green: 20.0 / 255.0, blue: 21.0 / 255.0),
            lightIncreased: AppColorComponents(red: 0.000, green: 0.000, blue: 0.000),
            darkStandard: AppColorComponents(red: 246.0 / 255.0, green: 246.0 / 255.0, blue: 243.0 / 255.0),
            darkIncreased: AppColorComponents(red: 1.000, green: 1.000, blue: 1.000)
        ),
        .signalAccent: AppColorPalette(
            lightStandard: AppColorComponents(red: 1.000, green: 226.0 / 255.0, blue: 0.000),
            darkStandard: AppColorComponents(red: 1.000, green: 226.0 / 255.0, blue: 0.000)
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
            darkStandard: AppColorComponents(red: 89.0 / 255.0, green: 158.0 / 255.0, blue: 1.000),
            darkIncreased: AppColorComponents(red: 110.0 / 255.0, green: 173.0 / 255.0, blue: 1.000)
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
            darkStandard: AppColorComponents(red: 1.000, green: 89.0 / 255.0, blue: 84.0 / 255.0),
            darkIncreased: AppColorComponents(red: 1.000, green: 107.0 / 255.0, blue: 102.0 / 255.0)
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
