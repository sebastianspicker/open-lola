// Presents the compact Open LoLa brand signature in the Signal Desk sidebar.
import SwiftUI

enum AppBrandSignaturePolicy {
    static let masterName = "Open LoLa"
    static let descriptor = "Signal Desk"
    static let accessibilityLabel = "Open LoLa Signal Desk"
}

struct AppBrandSignature: View {
    var body: some View {
        HStack(spacing: AppSpacing.s) {
            Image(systemName: "waveform")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 28, height: 28)
                .background(Color.accentColor.opacity(0.10), in: RoundedRectangle(cornerRadius: 6))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 1) {
                Text(AppBrandSignaturePolicy.masterName)
                    .font(.system(size: 15, weight: .semibold))
                Text(AppBrandSignaturePolicy.descriptor)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, AppSpacing.xs)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(AppBrandSignaturePolicy.accessibilityLabel)
    }
}
