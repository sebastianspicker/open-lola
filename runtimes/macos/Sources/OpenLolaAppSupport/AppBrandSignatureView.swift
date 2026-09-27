// Presents the compact Open LoLa brand signature in the application header.
import SwiftUI

enum AppBrandSignaturePolicy {
    static let masterName = "Open LoLa"
    static let wordmark = "open lola"
    static let descriptor = "Signal Desk"
    static let accessibilityLabel = masterName
}

struct AppBrandSignature: View {
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
            HStack(alignment: .top, spacing: 2) {
                Text(AppBrandSignaturePolicy.wordmark)
                    .font(.system(size: 30, weight: .medium, design: .rounded))
                    .tracking(-0.45)
                Circle()
                    .fill(AppDesignSystem.signalAccent)
                    .frame(width: 6, height: 6)
                    .padding(.top, 3)
                    .accessibilityHidden(true)
            }

        }
        .padding(.vertical, AppSpacing.m)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(AppBrandSignaturePolicy.accessibilityLabel)
        .accessibilityValue(AppBrandSignaturePolicy.descriptor)
    }
}
