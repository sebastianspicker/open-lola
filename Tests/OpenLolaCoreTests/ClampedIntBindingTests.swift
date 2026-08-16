// Verifies clamped integer bindings keep operator and persisted settings in sync.
import SwiftUI
import Testing

@testable import OpenLolaAppSupport
@testable import OpenLolaCore

@MainActor
struct ClampedIntBindingTests {
    @Test
    func windowsLoLaDurationBindingReadsInitialValueAndClampsWrites() {
        var operatorSurface = appOperatorState(remoteSelectionComplete: true)
        operatorSurface.windowsLoLaPeerFields.durationSeconds = 18
        var appSettings = BindingSettings(duration: 42)
        var mutations: [String] = []
        let binding = clampedIntBinding(
            operatorSurface: Binding(
                get: { operatorSurface },
                set: {
                    operatorSurface = $0
                    mutations.append("surface")
                }
            ),
            fields: \.windowsLoLaPeerFields,
            keyPath: \.durationSeconds,
            appSettings: Binding(
                get: { appSettings },
                set: {
                    appSettings = $0
                    mutations.append("settings")
                }
            ),
            storage: \.duration
        )

        #expect(binding.wrappedValue == 18)

        binding.wrappedValue = 0

        #expect(operatorSurface.windowsLoLaPeerFields.durationSeconds == 1)
        #expect(appSettings.duration == 1)
        #expect(mutations == ["surface", "settings"])
    }

    @Test
    func directPeerDurationBindingReadsInitialValueAndClampsWrites() {
        var operatorSurface = appOperatorState(remoteSelectionComplete: true)
        operatorSurface.directPeerCommandFields.durationSeconds = 27
        var appSettings = BindingSettings(duration: 42)
        var mutations: [String] = []
        let binding = clampedIntBinding(
            operatorSurface: Binding(
                get: { operatorSurface },
                set: {
                    operatorSurface = $0
                    mutations.append("surface")
                }
            ),
            fields: \.directPeerCommandFields,
            keyPath: \.durationSeconds,
            appSettings: Binding(
                get: { appSettings },
                set: {
                    appSettings = $0
                    mutations.append("settings")
                }
            ),
            storage: \.duration
        )

        #expect(binding.wrappedValue == 27)

        binding.wrappedValue = -4

        #expect(operatorSurface.directPeerCommandFields.durationSeconds == 1)
        #expect(appSettings.duration == 1)
        #expect(mutations == ["surface", "settings"])
    }
}

private struct BindingSettings {
    var duration: Int
}
