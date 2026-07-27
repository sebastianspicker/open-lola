// Builds preview bindings, keeping receiver controls synchronized without exposing storage details to the UI.
import SwiftUI

@MainActor
func appPreviewBinding<Value>(
    _ keyPath: ReferenceWritableKeyPath<AppPreviewReceiverState, Value>,
    state: AppPreviewReceiverState,
    storage: Binding<Value>? = nil
) -> Binding<Value> {
    Binding(
        get: { storage?.wrappedValue ?? state[keyPath: keyPath] },
        set: {
            storage?.wrappedValue = $0
            state[keyPath: keyPath] = $0
        }
    )
}

@MainActor
func appPreviewIntBinding(
    _ keyPath: ReferenceWritableKeyPath<AppPreviewReceiverState, Int>,
    state: AppPreviewReceiverState,
    storage: Binding<Int>? = nil
) -> Binding<Int> {
    Binding(
        get: {
            AppShellStoredDefaults.positivePreviewStreamValue(storage?.wrappedValue ?? state[keyPath: keyPath])
        },
        set: {
            let value = AppShellStoredDefaults.positivePreviewStreamValue($0)
            storage?.wrappedValue = value
            state[keyPath: keyPath] = value
        }
    )
}
