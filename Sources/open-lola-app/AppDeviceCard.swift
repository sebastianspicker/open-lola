// Renders a device selection and status card, isolating inventory presentation from connection settings.
import OpenLolaCore
import SwiftUI

// MARK: - Audio Device Card

/// Rich device selection card replacing a plain Picker row.
struct AppAudioDeviceCard: View {
    let device: NativeAppShellAudioDeviceOption
    let supportsInput: Bool
    let supportsOutput: Bool
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        AppSelectableDeviceCard(
            title: device.name,
            badges: badges,
            identifier: device.uid,
            icon: deviceIcon,
            isSelected: isSelected,
            onSelect: onSelect
        )
    }

    private var badges: [String] {
        var result: [String] = []
        if supportsInput {
            result.append("\(device.inputChannelCount) in")
        }
        if supportsOutput {
            result.append("\(device.outputChannelCount) out")
        }
        return result
    }

    private var deviceIcon: String {
        if device.supportsInput && device.supportsOutput {
            return "slider.horizontal.3"
        }
        if device.supportsOutput {
            return "speaker.wave.2"
        }
        if device.supportsInput {
            return "waveform.badge.mic"
        }
        return "questionmark.circle"
    }

}

// MARK: - Video Device Card

struct AppVideoDeviceCard: View {
    let device: NativeAppShellVideoDeviceOption
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        AppSelectableDeviceCard(
            title: device.label,
            badges: [device.transport],
            identifier: device.uniqueId,
            icon: deviceIcon,
            isSelected: isSelected,
            onSelect: onSelect
        )
    }

    private var deviceIcon: String {
        if let policyIcon = Self.videoSourcePolicyIcons[device.sourcePolicy] {
            return policyIcon
        }
        if let transportIcon = Self.videoTransportIcons[device.transport.lowercased()] {
            return transportIcon
        }
        return "questionmark.circle"
    }

    private static let videoSourcePolicyIcons: [AVFoundationVideoSourcePolicy: String] = [
        .blackmagicFirstAvFoundationFallback: "video.badge.waveform",
        .genericAvFoundation: "video.fill"
    ]

    private static let videoTransportIcons: [String: String] = [
        "pci": "video.fill.badge.plus",
        "thunderbolt": "video.fill.badge.plus"
    ]
}

private struct AppSelectableDeviceCard: View {
    let title: String
    let badges: [String]
    let identifier: String
    let icon: String
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: AppSpacing.s) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(isSelected ? AppDesignSystem.interactionAccent : Color.secondary)
                    .frame(width: 36, height: 36)
                    .background(
                        (isSelected ? AppDesignSystem.interactionAccent : Color.secondary).opacity(0.1),
                        in: RoundedRectangle(cornerRadius: 6)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.primary)

                    HStack(spacing: AppSpacing.xxs) {
                        ForEach(badges, id: \.self) { badge in
                            Text(badge)
                                .font(.caption2.weight(.medium))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(.secondary.opacity(0.12), in: Capsule())
                                .foregroundStyle(.secondary)
                        }
                    }

                    Text(identifier)
                        .font(.caption2.monospaced())
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(maxWidth: 220, alignment: .leading)
                        .help(AppDeviceIdentifierDisplayPolicy.fullValueHelp(identifier: identifier))
                }

                Spacer(minLength: 0)

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(AppDesignSystem.interactionAccent)
                }
            }
            .padding(AppSpacing.s)
            .background(
                isSelected ? AppDesignSystem.interactionAccent.opacity(0.08) : Color.clear,
                in: RoundedRectangle(cornerRadius: 8)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        isSelected ? AppDesignSystem.interactionAccent.opacity(0.72) : Color.clear,
                        lineWidth: isSelected ? 1.5 : 0
                    )
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .accessibilityHint(AppDeviceIdentifierDisplayPolicy.accessibilityHint(identifier: identifier))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .help(AppDeviceIdentifierDisplayPolicy.fullValueHelp(identifier: identifier))
    }
}

enum AppDeviceIdentifierDisplayPolicy {
    static func fullValueHelp(identifier: String) -> String {
        "Full device identifier: \(identifier)"
    }

    static func accessibilityHint(identifier: String) -> String {
        "Full device identifier: \(identifier)"
    }
}
