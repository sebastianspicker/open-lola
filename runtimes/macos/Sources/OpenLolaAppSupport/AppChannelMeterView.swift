// Renders AppChannelMeterView in the operator interface, keeping SwiftUI presentation distinct from execution and persistence state.
import SwiftUI

// MARK: - Channel Meter View

/// Broadcast-style vertical VU meters rendered via Canvas.
/// Supports up to 64 channels with three color zones and peak-hold.
struct AppChannelMeterView: View {
    /// Current RMS levels, each in 0…1 range (linear amplitude).
    let levels: [Double]
    /// How many channels to display (clamped to levels.count).
    var visibleChannels: Int = 8

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var peakState = PeakHoldState.empty
    @StateObject private var peakDecayTask = PeakDecayTaskOwner()

    private enum Layout {
        static let meterWidth: CGFloat = 6
        static let meterGap: CGFloat = 2
        static let peakHoldDuration: Double = 2.0
        static let peakFallRate: Double = 0.008
        static let decayInterval: Duration = .nanoseconds(33_333_333)
    }

    private var levelSnapshot: ChannelMeterLevelSnapshot {
        ChannelMeterLevelSnapshot(levels: levels, visibleChannels: visibleChannels)
    }

    private var channelCount: Int {
        levelSnapshot.values.count
    }

    var body: some View {
        let snapshot = levelSnapshot
        Canvas { context, size in
            let channelCount = snapshot.values.count
            let totalWidth = CGFloat(channelCount) * (Layout.meterWidth + Layout.meterGap) - Layout.meterGap
            let startX = (size.width - totalWidth) / 2

            // swiftlint:disable:next identifier_name
            for (i, level) in snapshot.values.enumerated() {
                let peak = i < peakState.holds.count ? peakState.holds[i] : 0
                // swiftlint:disable:next identifier_name
                let x = startX + CGFloat(i) * (Layout.meterWidth + Layout.meterGap)
                drawBar(context: context, x: x, height: size.height, level: level, peak: peak)
            }
        }
        .frame(minHeight: 120)
        .onAppear {
            initPeakHolds(channelCapacity: snapshot.values.count)
            startPeakDecay()
        }
        .onDisappear {
            peakDecayTask.cancel()
        }
        .onChange(of: snapshot) { _, newSnapshot in updatePeaks(newSnapshot) }
        .onChange(of: reduceMotion) { _, reduceMotionEnabled in
            if reduceMotionEnabled {
                peakDecayTask.cancel()
            } else {
                startPeakDecay()
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Audio level meters")
        .accessibilityValue(meterAccessibilityValue)
        .accessibilityHint(AppChannelMeterAccessibilityPolicy.scopeHint)
    }

    private var meterAccessibilityValue: String {
        AppChannelMeterAccessibilityPolicy.value(
            channelCount: channelCount,
            peak: levelSnapshot.values.max()
        )
    }

    // MARK: - Drawing

    private func drawBar(
        context: GraphicsContext,
        // swiftlint:disable:next identifier_name
        x: CGFloat,
        height: CGFloat,
        level: Double,
        peak: Double
    ) {
        guard Layout.meterWidth > 0, height > 0 else {
            return
        }
        let barRect = CGRect(x: x, y: 0, width: Layout.meterWidth, height: height)

        // Track background
        context.fill(
            Path(barRect),
            with: .color(.primary.opacity(0.10))
        )

        // Split the filled level into three threshold zones.
        let clampedLevel = min(1.0, max(0.0, level))
        let safeThreshold = 0.25  // −12 dBFS approx (linear)
        let cautionThreshold = 0.7 // −3 dBFS approx (linear)

        drawLevelZones(
            context: context,
            x: x,
            height: height,
            level: clampedLevel,
            thresholds: MeterZoneThresholds(safe: safeThreshold, caution: cautionThreshold)
        )

        // Peak hold line
        if peak > 0.001 {
            let clampedPeak = min(1.0, max(0.0, peak))
            let peakY = min(max(0, height * (1 - CGFloat(clampedPeak))), max(0, height - 2))
            let peakColor: Color = peak > cautionThreshold ? AppDesignSystem.meterClip
                : peak > safeThreshold ? AppDesignSystem.meterCaution
                : AppDesignSystem.meterSafe
            let peakRect = CGRect(x: x, y: peakY, width: Layout.meterWidth, height: 2)
            context.fill(Path(peakRect), with: .color(peakColor))
        }
    }

    private func drawLevelZones(
        context: GraphicsContext,
        // swiftlint:disable:next identifier_name
        x: CGFloat,
        height: CGFloat,
        level: Double,
        thresholds: MeterZoneThresholds
    ) {
        guard level > 0 else {
            return
        }
        fillZone(
            context,
            x: x,
            height: height,
            bounds: MeterZoneBounds(lower: 0, upper: min(level, thresholds.safe)),
            color: AppDesignSystem.meterSafe
        )
        fillZone(
            context,
            x: x,
            height: height,
            bounds: MeterZoneBounds(lower: thresholds.safe, upper: min(level, thresholds.caution)),
            color: AppDesignSystem.meterCaution
        )
        fillZone(
            context,
            x: x,
            height: height,
            bounds: MeterZoneBounds(lower: thresholds.caution, upper: level),
            color: AppDesignSystem.meterClip
        )
    }

    private func fillZone(
        _ context: GraphicsContext,
        // swiftlint:disable:next identifier_name
        x: CGFloat,
        height: CGFloat,
        bounds: MeterZoneBounds,
        color: Color
    ) {
        guard bounds.upper > bounds.lower else {
            return
        }
        let yTop = height * (1 - CGFloat(bounds.upper))
        let yBottom = height * (1 - CGFloat(bounds.lower))
        let zoneRect = CGRect(
            x: x,
            y: max(0, yTop),
            width: Layout.meterWidth,
            height: max(0, min(height, yBottom) - max(0, yTop))
        )
        context.fill(Path(zoneRect), with: .color(color))
    }

    // MARK: - Peak hold logic

    private func initPeakHolds(channelCapacity: Int? = nil) {
        let capacity = max(channelCapacity ?? channelCount, 64)
        if peakState.holds.count != capacity {
            peakState = PeakHoldState(capacity: capacity)
        }
    }

    private func updatePeaks(_ snapshot: ChannelMeterLevelSnapshot) {
        let newLevels = snapshot.values
        initPeakHolds(channelCapacity: newLevels.count)
        var nextState = peakState
        // swiftlint:disable:next identifier_name
        for i in 0..<min(newLevels.count, nextState.holds.count) where newLevels[i] > nextState.holds[i] {
            nextState.holds[i] = newLevels[i]
            nextState.timers[i] = Layout.peakHoldDuration
        }
        if nextState != peakState {
            peakState = nextState
        }
    }

    private func startPeakDecay() {
        guard !reduceMotion else {
            peakDecayTask.cancel()
            return
        }
        peakDecayTask.start(interval: Layout.decayInterval) {
            decayPeaks()
        }
    }

    private func decayPeaks() {
        var nextState = peakState
        // swiftlint:disable:next identifier_name
        for i in 0..<nextState.holds.count {
            if nextState.timers[i] > 0 {
                nextState.timers[i] -= 1.0 / 30.0
            } else if nextState.holds[i] > 0 {
                nextState.holds[i] = max(0, nextState.holds[i] - Layout.peakFallRate)
            }
        }
        if nextState != peakState {
            peakState = nextState
        }
    }
}

struct ChannelMeterLevelSnapshot: Equatable, Sendable {
    let values: [Double]

    init(levels: [Double], visibleChannels: Int) {
        values = Array(levels.prefix(max(0, visibleChannels)))
    }
}

private struct MeterZoneBounds {
    var lower: Double
    var upper: Double
}

private struct MeterZoneThresholds {
    var safe: Double
    var caution: Double
}

private final class PeakDecayTaskOwner: ObservableObject {
    private var task: Task<Void, Never>?

    deinit {
        task?.cancel()
    }

    @MainActor
    func start(interval: Duration, tick: @escaping @MainActor () -> Void) {
        cancel()
        task = Task { @MainActor in
            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: interval)
                } catch {
                    return
                }
                tick()
            }
        }
    }

    func cancel() {
        task?.cancel()
        task = nil
    }
}

struct PeakHoldState: Equatable {
    static let empty = PeakHoldState(capacity: 0)

    var holds: [Double]
    var timers: [Double]

    init(capacity: Int) {
        holds = Array(repeating: 0, count: capacity)
        timers = Array(repeating: 0, count: capacity)
    }
}

enum AppChannelMeterAccessibilityPolicy {
    static let scopeHint = "Compact overview only; this meter does not expose per-channel diagnostic readings."

    static func value(channelCount: Int, peak: Double?) -> String {
        guard channelCount > 0 else {
            return "Overview only. No channels visible"
        }
        let clampedPeak = min(1.0, max(0.0, peak ?? 0))
        return "Overview only. \(channelCount) channels, peak \(Int((clampedPeak * 100).rounded())) percent"
    }
}

// MARK: - Compact meter strip

/// 8-channel compact strip for the main operator window.
struct AppCompactMeterStrip: View {
    let levels: [Double]
    let status: String

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            AppChannelMeterView(levels: levels, visibleChannels: 8)
                .frame(height: 80)

            Text(status)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}
