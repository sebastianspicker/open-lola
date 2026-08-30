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
