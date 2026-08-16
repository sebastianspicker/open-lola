// Defines native app runtime smoke command arguments and parsing failures.
import Foundation

/// Defines the validated fields for native app runtime smoke configuration.
public struct NativeAppRuntimeSmokeConfiguration: Codable, Equatable, Sendable {
    public let headlessReportPath: String
    public let outputPath: String

    public init(headlessReportPath: String, outputPath: String) {
        self.headlessReportPath = headlessReportPath
        self.outputPath = outputPath
    }

    public static func parse(_ arguments: [String]) throws -> NativeAppRuntimeSmokeConfiguration {
        let allowed = [
            "--headless-report",
            "--output"
        ]
        var values: [String: String] = [:]
        var index = 0

        while index < arguments.count {
            let argument = arguments[index]
            guard allowed.contains(argument) else {
                throw NativeAppRuntimeSmokeConfigurationError.unknownArgument(argument)
            }
            guard values[argument] == nil else {
                throw NativeAppRuntimeSmokeConfigurationError.duplicateArgument(argument)
            }
            let valueIndex = index + 1
            guard valueIndex < arguments.count, !arguments[valueIndex].hasPrefix("--") else {
                throw NativeAppRuntimeSmokeConfigurationError.missingValue(argument)
            }
            values[argument] = arguments[valueIndex]
            index += 2
        }

        return NativeAppRuntimeSmokeConfiguration(
            headlessReportPath: try requiredNativeAppRuntimeString("--headless-report", values),
            outputPath: try requiredNativeAppRuntimeString("--output", values)
        )
    }
}

/// Defines failures reported when native app runtime smoke configuration error cannot continue.
public enum NativeAppRuntimeSmokeConfigurationError: Error, Equatable, Sendable {
    case missingRequiredArgument(String)
    case missingValue(String)
    case unknownArgument(String)
    case duplicateArgument(String)
}

private func requiredNativeAppRuntimeString(
    _ argument: String,
    _ values: [String: String]
) throws -> String {
    guard let value = values[argument], !value.isEmpty else {
        throw NativeAppRuntimeSmokeConfigurationError.missingRequiredArgument(argument)
    }
    return value
}
