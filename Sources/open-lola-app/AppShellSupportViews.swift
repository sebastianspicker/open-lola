import AppKit
import OpenLolaCore
import SwiftUI

struct UInt16Field: View {
    let title: String
    @Binding var value: UInt16
    @State private var draftText: String?
    @State private var inputIsInvalid = false

    init(_ title: String, value: Binding<UInt16>) {
        self.title = title
        self._value = value
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
            TextField(title, text: Binding(
                get: { draftText ?? String(value) },
                set: { newValue in
                    draftText = newValue
                    if let parsed = UInt16(newValue) {
                        inputIsInvalid = false
                        value = parsed
                    } else {
                        inputIsInvalid = true
                    }
                }
            ))
            .help("Must be a valid UInt16 value")
            .overlay {
                RoundedRectangle(cornerRadius: 4)
                    .stroke(inputIsInvalid ? Color.orange : Color.clear, lineWidth: 2)
            }
            if inputIsInvalid {
                Label("Enter a whole number from 0 to 65535.", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }
        }
        .onAppear {
            syncExternalValue(value)
        }
        .onChange(of: value) { _, newValue in
            syncExternalValue(newValue)
        }
    }

    private func syncExternalValue(_ newValue: UInt16) {
        inputIsInvalid = false
        draftText = String(newValue)
    }
}

struct IntField: View {
    let title: String
    @Binding var value: Int
    let minimumValue: Int
    @State private var draftText: String?
    @State private var inputIsInvalid = false

    init(_ title: String, value: Binding<Int>, minimumValue: Int = 1) {
        self.title = title
        self._value = value
        self.minimumValue = minimumValue
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
            TextField(title, text: Binding(
                get: { draftText ?? String(value) },
                set: { newValue in
                    draftText = newValue
                    if let parsed = Int(newValue), parsed >= minimumValue {
                        inputIsInvalid = false
                        value = parsed
                    } else {
                        inputIsInvalid = true
                    }
                }
            ))
            .help(minimumValue == 0 ? "Must be a non-negative integer" : "Must be a positive integer")
            .overlay {
                RoundedRectangle(cornerRadius: 4)
                    .stroke(inputIsInvalid ? Color.orange : Color.clear, lineWidth: 2)
            }
            if inputIsInvalid {
                Label(invalidMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }
        }
        .onAppear {
            syncExternalValue(value)
        }
        .onChange(of: value) { _, newValue in
            syncExternalValue(newValue)
        }
    }

    private func syncExternalValue(_ newValue: Int) {
        inputIsInvalid = false
        draftText = String(newValue)
    }

    private var invalidMessage: String {
        minimumValue == 0 ? "Enter a non-negative whole number." : "Enter a positive whole number."
    }
}

struct MetricsGrid<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: AppSpacing.l, verticalSpacing: AppSpacing.xs) { content }
            .frame(maxWidth: 520, alignment: .leading)
    }
}

struct AppReadableMetric: View {
    let label: String
    let value: String
    var monospaced = false

    var body: some View {
        LabeledContent(label) {
            AppReadableValue(label: label, value: value, monospaced: monospaced)
        }
    }
}

enum AppReadableMetricAccessibility {
    static func valueLabel(metric: String, value: String) -> String {
        "\(metric): \(value)"
    }

    static func fullValueHelp(metric: String, value: String) -> String {
        "Full \(metric) value: \(value)"
    }

    static func valueHint(metric: String) -> String {
        "Full \(metric) value is selectable and can be copied."
    }

    static func copyLabel(metric: String) -> String {
        "Copy \(metric) value"
    }
}

struct AppReadableValue: View {
    let label: String
    let value: String
    var monospaced = false
    var copyEnabled = true

    @State private var copyFeedback: AppPasteboardCopyFeedback?

    private var accessibilityValueLabel: String {
        AppReadableMetricAccessibility.valueLabel(metric: label, value: value)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
            HStack(spacing: AppSpacing.xs) {
                ScrollView(.horizontal, showsIndicators: false) {
                    Text(value)
                        .font(monospaced ? .system(.caption, design: .monospaced) : .caption)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                        .textSelection(.enabled)
                }
                .frame(minWidth: 120, maxWidth: .infinity, alignment: .leading)
                .help(AppReadableMetricAccessibility.fullValueHelp(metric: label, value: value))

                if copyEnabled {
                    Button {
                        copyFeedback = copyReadableValueToPasteboard(value, label: label)
                    } label: {
                        Image(systemName: "doc.on.doc")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .appCompactToolButtonHitTarget()
                    .help(AppReadableMetricAccessibility.copyLabel(metric: label))
                    .accessibilityLabel(AppReadableMetricAccessibility.copyLabel(metric: label))
                }
            }
            if let copyFeedback {
                AppCopyFeedbackText(feedback: copyFeedback)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(accessibilityValueLabel))
        .accessibilityHint(Text(AppReadableMetricAccessibility.valueHint(metric: label)))
    }
}

enum AppCompactToolButtonSizing {
    static let minimumHitLength: CGFloat = 28
}

private struct AppCompactToolButtonHitTarget: ViewModifier {
    func body(content: Content) -> some View {
        content
            .frame(
                minWidth: AppCompactToolButtonSizing.minimumHitLength,
                minHeight: AppCompactToolButtonSizing.minimumHitLength
            )
            .contentShape(Rectangle())
    }
}

extension View {
    func appCompactToolButtonHitTarget() -> some View {
        modifier(AppCompactToolButtonHitTarget())
    }
}

enum AppStatusBadgeStyle {
    case rounded
    case capsule
}

struct AppStatusBadge: View {
    let title: String
    let systemImage: String
    let tone: Color
    var style: AppStatusBadgeStyle = .capsule

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .lineLimit(1)
            .foregroundStyle(tone)
            .padding(.horizontal, style == .rounded ? 9 : 10)
            .padding(.vertical, 5)
            .background {
                switch style {
                case .rounded:
                    RoundedRectangle(cornerRadius: 6)
                        .fill(tone.opacity(0.14))
                case .capsule:
                    Capsule()
                        .fill(tone.opacity(0.12))
                }
            }
            .accessibilityLabel(title)
    }
}

struct AppVerticalDivider: View {
    var height: CGFloat?
    var verticalPadding: CGFloat = 0

    var body: some View {
        Rectangle()
            .fill(AppDesignSystem.panelBorder)
            .frame(width: 1, height: height)
            .padding(.vertical, verticalPadding)
    }
}

struct AppDisabledControlReasonText: View {
    let reason: String

    var body: some View {
        Label(reason, systemImage: "info.circle")
            .font(.caption2)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityLabel(reason)
    }
}

struct AppCopyFeedbackText: View {
    let feedback: AppPasteboardCopyFeedback

    var body: some View {
        Label(feedback.message, systemImage: feedback.systemImage)
            .font(.caption2)
            .foregroundStyle(feedback.copied ? .secondary : AppDesignSystem.stateWarning)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityLabel(feedback.message)
    }
}

struct AppWarningBanner: View {
    let title: String
    let messages: [String]
    var detail: String?
    let dismissAction: (() -> Void)?

    init(title: String, message: String, detail: String? = nil, dismissAction: (() -> Void)? = nil) {
        self.title = title
        self.messages = [message]
        self.detail = detail
        self.dismissAction = dismissAction
    }

    init(title: String, messages: [String], detail: String? = nil, dismissAction: (() -> Void)? = nil) {
        self.title = title
        self.messages = messages
        self.detail = detail
        self.dismissAction = dismissAction
    }

    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.xs) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(AppDesignSystem.stateWarning)
            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppDesignSystem.stateWarning)
                ForEach(messages, id: \.self) { message in
                    Text(message)
                        .font(.caption)
                        .textSelection(.enabled)
                }
                if let detail {
                    Text(detail)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            if let dismissAction {
                Spacer(minLength: AppSpacing.xs)
                Button(action: dismissAction) {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .appCompactToolButtonHitTarget()
                .accessibilityLabel("Dismiss warning")
            }
        }
        .padding(AppSpacing.xs)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppDesignSystem.stateWarningBackground, in: RoundedRectangle(cornerRadius: 8))
    }
}

func yesNo(_ value: Bool) -> String {
    value ? "yes" : "no"
}

@MainActor
private func copyReadableValueToPasteboard(_ value: String, label: String) -> AppPasteboardCopyFeedback {
    AppPasteboard.copyFeedback(value, target: "\(label) value")
}

extension Result {
    var failureDescription: String? {
        if case .failure(let error) = self { return String(describing: error) }
        return nil
    }
}
