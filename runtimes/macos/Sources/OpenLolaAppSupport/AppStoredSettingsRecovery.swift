// Recovers invalid persisted settings field by field and reports what was reset, instead of silently resetting a whole group.
import Foundation
import OpenLolaCore

/// Fields loaded from persistence together with operator-visible notes about anything that had to be reset.
struct AppStoredSettingsLoad<Fields> {
    var fields: Fields
    var notices: [String]
}

/// Resets one named field of `Fields` to the value held by a known-good fallback.
typealias AppStoredFieldReset<Fields> = (inout Fields, Fields) -> Void

enum AppStoredSettingsRecovery {
    /// Builds a reset action for a single writable field.
    static func reset<Fields, Value>(_ keyPath: WritableKeyPath<Fields, Value>) -> AppStoredFieldReset<Fields> {
        { fields, fallback in fields[keyPath: keyPath] = fallback[keyPath: keyPath] }
    }

    /// Validates `fields`, resetting only the offending field to its default until validation passes.
    ///
    /// Falls back to the complete default group, with a note, only when an invalid field cannot be named or
    /// resetting it makes no progress (for example when the default itself is rejected in this combination).
    static func recover<Fields: Equatable>(
        _ fields: Fields,
        fallback: Fields,
        group: String,
        resets: [String: AppStoredFieldReset<Fields>],
        validate: (Fields) throws -> Void
    ) -> AppStoredSettingsLoad<Fields> {
        var current = fields
        var notices: [String] = []
        for _ in 0...resets.count {
            do {
                try validate(current)
                return AppStoredSettingsLoad(fields: current, notices: notices)
            } catch {
                guard let name = offendingField(error), let reset = resets[name] else {
                    return wholeGroupReset(fallback, group: group, notices: notices, error: error)
                }
                let before = current
                reset(&current, fallback)
                guard current != before else {
                    return wholeGroupReset(fallback, group: group, notices: notices, error: error)
                }
                notices.append("\(group) setting \"\(name)\" was invalid (\(reason(error))) and was reset to its default.")
            }
        }
        return wholeGroupReset(fallback, group: group, notices: notices, error: nil)
    }

    static func offendingField(_ error: Error) -> String? {
        if error as? JPEGXSReferenceCodecError == .notBuiltIn {
            return "videoCompression"
        }
        switch error as? NativeAppShellSurfaceValidationError {
        case .invalidCommandField(let field), .duplicateCommandPort(let field):
            return field
        default:
            return nil
        }
    }

    private static func reason(_ error: Error) -> String {
        if error as? JPEGXSReferenceCodecError == .notBuiltIn {
            return "JPEG XS is not built in"
        }
        switch error as? NativeAppShellSurfaceValidationError {
        case .invalidCommandField:
            return "value not allowed"
        case .duplicateCommandPort:
            return "port is used twice"
        default:
            return error.localizedDescription
        }
    }

    private static func wholeGroupReset<Fields>(
        _ fallback: Fields,
        group: String,
        notices: [String],
        error: Error?
    ) -> AppStoredSettingsLoad<Fields> {
        let cause = error.map { ": \(reason($0))" } ?? ""
        return AppStoredSettingsLoad(
            fields: fallback,
            notices: notices + ["\(group) settings could not be repaired field by field\(cause); all were reset to defaults."]
        )
    }
}
