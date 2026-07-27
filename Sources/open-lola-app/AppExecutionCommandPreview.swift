// Previews generated execution commands, keeping command rendering separate from process launch.
import OpenLolaCore

@MainActor
extension AppExecutionController {
    func executionCommand(
        executablePath: String,
        operatorSurface: NativeAppShellOperatorPrototypeState,
        dryRun: Bool
    ) -> Result<[String], Error> {
        Result {
            let resolvedExecutable = try AppExecutablePathResolver.verifiedPath(executablePath)
            switch operatorSurface.sessionMode.appExecutionRoute {
            case .directMacPeer:
                var previewSettings = settings
                previewSettings.execute = !dryRun
                return try previewSettings.supervisorArguments(executablePath: resolvedExecutable)
            case .windowsLoLa:
                return try operatorSurface.windowsLoLaSessionArguments(
                    executablePath: resolvedExecutable,
                    dryRun: dryRun
                )
            case .externalConnector(let connector):
                return try operatorSurface.externalConnectorSessionArguments(
                    connector: connector,
                    executablePath: resolvedExecutable,
                    dryRun: dryRun
                )
            case .unsupportedExternalConnector:
                throw NativeAppShellSurfaceValidationError.invalidCommandField("sessionMode")
            }
        }
    }

    func validatorCommand(
        executablePath: String,
        operatorSurface: NativeAppShellOperatorPrototypeState
    ) -> Result<[String], Error> {
        Result {
            let resolvedExecutable = try AppExecutablePathResolver.verifiedPath(executablePath)
            switch operatorSurface.sessionMode.appExecutionRoute {
            case .directMacPeer:
                return try settings.validatorArguments(executablePath: resolvedExecutable)
            case .windowsLoLa:
                return try operatorSurface.windowsLoLaValidatorArguments(executablePath: resolvedExecutable)
            case .externalConnector(let connector):
                return try operatorSurface.externalConnectorValidatorArguments(
                    connector: connector,
                    executablePath: resolvedExecutable
                )
            case .unsupportedExternalConnector:
                throw NativeAppShellSurfaceValidationError.invalidCommandField("sessionMode")
            }
        }
    }
}
