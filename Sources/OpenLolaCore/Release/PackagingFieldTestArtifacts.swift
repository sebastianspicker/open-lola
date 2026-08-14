// Inspects the staged macOS application bundle so release evidence describes a real artifact.
import CryptoKit
import Darwin
import Dispatch
import Foundation

private let stagedOpenLoLaBundleExecutable = "OpenLoLa"
private let stagedOpenLoLaBundleIdentifier = "de.hfmt.open-lola.app"
private let stagedOpenLoLaBundleName = "Open LoLa"
private let stagedOpenLoLaBundleVersion = "0.1.0"
private let stagedOpenLoLaMinimumMacOSVersion = "14.0"
private let maximumStagedPropertyListBytes: Int64 = 1 * 1024 * 1024
private let maximumStagedExecutableBytes: Int64 = 128 * 1024 * 1024
private let maximumCodeSigningOutputBytes = 1 * 1024 * 1024
private let codeSigningTimeoutSeconds: TimeInterval = 15

func packagedPermissionEntitlementSurface() -> MacPackagedPermissionEntitlementSurface {
    MacPackagedPermissionEntitlementSurface(
        infoPlistRelativePath: "OpenLoLa.app/Contents/Info.plist",
        entitlementsRelativePath: "OpenLoLa.app/Contents/Resources/open-lola-app.entitlements",
        microphoneUsageDescription: "Open LoLa captures selected audio inputs for explicit low-latency Mac-to-Mac audio tests.",
        cameraUsageDescription: "Open LoLa captures selected camera frames for explicit Mac-to-Mac video transport tests.",
        localNetworkUsageDescription: "Open LoLa sends and receives local UDP media between explicitly configured Mac peers.",
        networkClientEntitlementKey: "com.apple.security.network.client",
        appSandboxDecision: "No separately recorded app-sandbox decision was supplied with this local package inspection."
    )
}

struct StagedAppBundleMetadata {
    let productName: String
    let bundleIdentifier: String
    let version: String
    let minimumMacOSVersion: String
    let permissionEntitlementSurface: MacPackagedPermissionEntitlementSurface
}

struct StagedCodeSigningInspection {
    let signingReadiness: MacSigningReadiness
    let networkClientEntitlementEnabled: Bool
    let appSandboxEnabled: Bool
}

struct PackagingArtifactInput {
    let kind: MacPackageArtifactKind
    let relativePath: String
}

func stagedAppBundlePackagingInputs(
    surface: MacPackagedPermissionEntitlementSurface
) -> [PackagingArtifactInput] {
    [
        PackagingArtifactInput(kind: .appBundle, relativePath: surface.infoPlistRelativePath),
        PackagingArtifactInput(kind: .appBundle, relativePath: "OpenLoLa.app/Contents/MacOS/\(stagedOpenLoLaBundleExecutable)"),
        PackagingArtifactInput(kind: .commandLineTool, relativePath: "OpenLoLa.app/Contents/MacOS/open-lola"),
        PackagingArtifactInput(kind: .entitlements, relativePath: surface.entitlementsRelativePath)
    ]
}

func inspectedStagedAppBundleMetadata(appBundleURL: URL) throws -> StagedAppBundleMetadata {
    let expectedSurface = packagedPermissionEntitlementSurface()
    let infoPlist = try stagedPropertyList(
        in: appBundleURL,
        relativePath: expectedSurface.infoPlistRelativePath
    )
    let entitlements = try stagedPropertyList(
        in: appBundleURL,
        relativePath: expectedSurface.entitlementsRelativePath
    )
    try requireStagedPlistValue("CFBundleExecutable", expected: stagedOpenLoLaBundleExecutable, in: infoPlist)
    try requireStagedPlistValue("CFBundleIdentifier", expected: stagedOpenLoLaBundleIdentifier, in: infoPlist)
    try requireStagedPlistValue("CFBundleName", expected: stagedOpenLoLaBundleName, in: infoPlist)
    try requireStagedPlistValue("CFBundleShortVersionString", expected: stagedOpenLoLaBundleVersion, in: infoPlist)
    try requireStagedPlistValue("LSMinimumSystemVersion", expected: stagedOpenLoLaMinimumMacOSVersion, in: infoPlist)
    try requireEnabledEntitlement(expectedSurface.networkClientEntitlementKey, in: entitlements)

    return StagedAppBundleMetadata(
        productName: try requiredStagedPlistString("CFBundleName", in: infoPlist),
        bundleIdentifier: try requiredStagedPlistString("CFBundleIdentifier", in: infoPlist),
        version: try requiredStagedPlistString("CFBundleShortVersionString", in: infoPlist),
        minimumMacOSVersion: try requiredStagedPlistString("LSMinimumSystemVersion", in: infoPlist),
        permissionEntitlementSurface: MacPackagedPermissionEntitlementSurface(
            infoPlistRelativePath: expectedSurface.infoPlistRelativePath,
            entitlementsRelativePath: expectedSurface.entitlementsRelativePath,
            microphoneUsageDescription: try requiredStagedPlistString("NSMicrophoneUsageDescription", in: infoPlist),
            cameraUsageDescription: try requiredStagedPlistString("NSCameraUsageDescription", in: infoPlist),
            localNetworkUsageDescription: try requiredStagedPlistString("NSLocalNetworkUsageDescription", in: infoPlist),
            networkClientEntitlementKey: expectedSurface.networkClientEntitlementKey,
            appSandboxDecision: expectedSurface.appSandboxDecision
        )
    )
}

func inspectedStagedAppBundleArtifacts(
    surface: MacPackagedPermissionEntitlementSurface,
    appBundleURL: URL
) throws -> [MacPackageArtifact] {
    return try stagedAppBundlePackagingInputs(surface: surface).map { input in
        return MacPackageArtifact(
            kind: input.kind,
            relativePath: input.relativePath,
            required: true,
            sha256: try packagingSHA256(
                in: appBundleURL,
                relativePath: input.relativePath,
                maximumBytes: maximumStagedBytes(for: input.relativePath)
            )
        )
    }
}

func inspectedStagedAppBundleCodeSigning(appBundleURL: URL) throws -> StagedCodeSigningInspection {
    let executableURL = appBundleURL.appendingPathComponent("Contents/MacOS/\(stagedOpenLoLaBundleExecutable)")
    try validateStagedArtifact(
        in: appBundleURL,
        relativePath: "OpenLoLa.app/Contents/MacOS/\(stagedOpenLoLaBundleExecutable)",
        maximumBytes: maximumStagedExecutableBytes
    )
    let entitlementsOutput = try codeSigningCommandOutput(
        ["--display", "--entitlements", ":-", executableURL.path],
        appBundleURL: appBundleURL
    )
    let embeddedEntitlements = try embeddedEntitlements(
        from: entitlementsOutput.standardOutput,
        appBundleURL: appBundleURL
    )
    guard embeddedEntitlements[packagedPermissionEntitlementSurface().networkClientEntitlementKey] as? Bool == true else {
        throw PackagingFieldArtifactInspectionError.missingEmbeddedEntitlement(
            packagedPermissionEntitlementSurface().networkClientEntitlementKey
        )
    }
    let signingDetails = try codeSigningCommandOutput(
        ["--display", "--verbose=4", executableURL.path],
        appBundleURL: appBundleURL
    )
    guard signingDetails.standardError.contains("Signature=adhoc"),
          signingDetails.standardError.contains("TeamIdentifier=not set") else {
        throw PackagingFieldArtifactInspectionError.unexpectedCodeSigningIdentity(appBundleURL.path)
    }
    _ = try codeSigningCommandOutput(
        ["--verify", "--deep", "--strict", appBundleURL.path],
        appBundleURL: appBundleURL
    )
    return StagedCodeSigningInspection(
        signingReadiness: MacSigningReadiness(
            signed: true,
            signatureValid: true,
            identityType: .adHoc,
            signingIdentityLabel: "ad-hoc local build",
            hardenedRuntimeEnabled: codeDirectoryEnablesHardenedRuntime(signingDetails.standardError),
            secureTimestampPresent: false
        ),
        networkClientEntitlementEnabled: true,
        appSandboxEnabled: embeddedEntitlements["com.apple.security.app-sandbox"] as? Bool == true
    )
}

private func stagedPropertyList(in appBundleURL: URL, relativePath: String) throws -> [String: Any] {
    let data: Data
    do {
        data = try stagedArtifactData(
            in: appBundleURL,
            relativePath: relativePath,
            maximumBytes: maximumStagedPropertyListBytes
        )
    } catch let error as PackagingFieldArtifactInspectionError {
        throw error
    } catch {
        throw PackagingFieldArtifactInspectionError.unreadableStagedArtifact(relativePath)
    }
    do {
        guard let dictionary = try PropertyListSerialization.propertyList(
            from: data,
            options: [],
            format: nil
        ) as? [String: Any] else {
            throw PackagingFieldArtifactInspectionError.invalidPropertyList(relativePath)
        }
        return dictionary
    } catch let error as PackagingFieldArtifactInspectionError {
        throw error
    } catch {
        throw PackagingFieldArtifactInspectionError.invalidPropertyList(relativePath)
    }
}

private func requiredStagedPlistString(_ key: String, in plist: [String: Any]) throws -> String {
    guard let value = plist[key] as? String, !value.isEmpty else {
        throw PackagingFieldArtifactInspectionError.missingPlistValue(key)
    }
    return value
}

private func requireStagedPlistValue(_ key: String, expected: String, in plist: [String: Any]) throws {
    let actual = try requiredStagedPlistString(key, in: plist)
    guard actual == expected else {
        throw PackagingFieldArtifactInspectionError.unexpectedPlistValue(
            key: key,
            expected: expected,
            actual: actual
        )
    }
}

private func requireEnabledEntitlement(_ key: String, in entitlements: [String: Any]) throws {
    guard entitlements[key] as? Bool == true else {
        throw PackagingFieldArtifactInspectionError.missingEnabledEntitlement(key)
    }
}

private func embeddedEntitlements(from output: String, appBundleURL: URL) throws -> [String: Any] {
    guard !output.isEmpty else {
        return [:]
    }
    do {
        guard let entitlements = try PropertyListSerialization.propertyList(
            from: Data(output.utf8),
            options: [],
            format: nil
        ) as? [String: Any] else {
            throw PackagingFieldArtifactInspectionError.invalidEmbeddedEntitlements(appBundleURL.path)
        }
        return entitlements
    } catch let error as PackagingFieldArtifactInspectionError {
        throw error
    } catch {
        throw PackagingFieldArtifactInspectionError.invalidEmbeddedEntitlements(appBundleURL.path)
    }
}

private func codeSigningCommandOutput(
    _ arguments: [String],
    appBundleURL: URL
) throws -> (standardOutput: String, standardError: String) {
    do {
        return try boundedPackagingSubprocessOutput(
            executableURL: URL(fileURLWithPath: "/usr/bin/codesign"),
            arguments: arguments,
            timeoutSeconds: codeSigningTimeoutSeconds,
            maximumCaptureBytes: maximumCodeSigningOutputBytes
        )
    } catch {
        throw PackagingFieldArtifactInspectionError.codeSigningVerificationFailed(appBundleURL.path)
    }
}

enum PackagingFieldSubprocessError: Error, Equatable, Sendable {
    case timedOut
    case outputLimitExceeded
    case failedToStart
    case nonZeroExit(Int32)
}

/// Runs a trusted local tool with bounded concurrent pipe capture so it cannot deadlock or retain unbounded output.
func boundedPackagingSubprocessOutput(
    executableURL: URL,
    arguments: [String],
    timeoutSeconds: TimeInterval,
    maximumCaptureBytes: Int
) throws -> (standardOutput: String, standardError: String) {
    let process = Process()
    let standardOutput = Pipe()
    let standardError = Pipe()
    let capture = BoundedPackagingSubprocessCapture(maximumBytes: maximumCaptureBytes)
    let readLock = NSLock()
    let completed = DispatchSemaphore(value: 0)

    process.executableURL = executableURL
    process.arguments = arguments
    process.standardOutput = standardOutput
    process.standardError = standardError
    process.terminationHandler = { _ in completed.signal() }

    let drain: @Sendable (FileHandle, Bool) -> Void = { handle, toStandardOutput in
        readLock.lock()
        let data = handle.availableData
        readLock.unlock()
        guard !data.isEmpty else { return }
        if capture.append(data, toStandardOutput: toStandardOutput), process.isRunning {
            process.terminate()
        }
    }

    standardOutput.fileHandleForReading.readabilityHandler = { handle in
        drain(handle, true)
    }
    standardError.fileHandleForReading.readabilityHandler = { handle in
        drain(handle, false)
    }

    do {
        try process.run()
    } catch {
        standardOutput.fileHandleForReading.readabilityHandler = nil
        standardError.fileHandleForReading.readabilityHandler = nil
        throw PackagingFieldSubprocessError.failedToStart
    }

    let exitedBeforeDeadline = completed.wait(
        timeout: .now() + .milliseconds(max(1, Int(timeoutSeconds * 1_000)))
    ) == .success
    if !exitedBeforeDeadline {
        terminatePackagingSubprocess(process, completion: completed)
    }

    standardOutput.fileHandleForReading.readabilityHandler = nil
    standardError.fileHandleForReading.readabilityHandler = nil
    readLock.lock()
    let trailingStandardOutput = standardOutput.fileHandleForReading.readDataToEndOfFile()
    let trailingStandardError = standardError.fileHandleForReading.readDataToEndOfFile()
    readLock.unlock()
    _ = capture.append(trailingStandardOutput, toStandardOutput: true)
    _ = capture.append(trailingStandardError, toStandardOutput: false)

    guard exitedBeforeDeadline else {
        throw PackagingFieldSubprocessError.timedOut
    }
    guard !capture.outputLimitExceeded else {
        throw PackagingFieldSubprocessError.outputLimitExceeded
    }
    guard process.terminationStatus == 0 else {
        throw PackagingFieldSubprocessError.nonZeroExit(process.terminationStatus)
    }
    return capture.output
}

private func terminatePackagingSubprocess(_ process: Process, completion: DispatchSemaphore) {
    process.terminate()
    if completion.wait(timeout: .now() + .milliseconds(500)) == .timedOut {
        _ = kill(process.processIdentifier, SIGKILL)
        _ = completion.wait(timeout: .now() + .seconds(1))
    }
}

private final class BoundedPackagingSubprocessCapture: @unchecked Sendable {
    private let maximumBytes: Int
    private let lock = NSLock()
    private var standardOutput = Data()
    private var standardError = Data()
    private var capturedByteCount = 0
    private(set) var outputLimitExceeded = false

    init(maximumBytes: Int) {
        self.maximumBytes = max(0, maximumBytes)
    }

    func append(_ data: Data, toStandardOutput: Bool) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard !data.isEmpty, !outputLimitExceeded else { return outputLimitExceeded }
        let permittedByteCount = max(0, maximumBytes - capturedByteCount)
        let capturedData = data.prefix(permittedByteCount)
        if toStandardOutput {
            standardOutput.append(capturedData)
        } else {
            standardError.append(capturedData)
        }
        capturedByteCount += capturedData.count
        if capturedData.count != data.count {
            outputLimitExceeded = true
        }
        return outputLimitExceeded
    }

    var output: (standardOutput: String, standardError: String) {
        lock.lock()
        defer { lock.unlock() }
        return (
            String(data: standardOutput, encoding: .utf8) ?? "",
            String(data: standardError, encoding: .utf8) ?? ""
        )
    }
}

private func codeDirectoryEnablesHardenedRuntime(_ signingDetails: String) -> Bool {
    signingDetails.split(separator: "\n").contains { line in
        line.hasPrefix("CodeDirectory ")
            && (line.contains("(runtime") || line.contains(",runtime") || line.contains("runtime,"))
    }
}

private func maximumStagedBytes(for relativePath: String) -> Int64 {
    relativePath.hasSuffix(".plist") || relativePath.hasSuffix(".entitlements")
        ? maximumStagedPropertyListBytes
        : maximumStagedExecutableBytes
}

private func validateStagedArtifact(
    in appBundleURL: URL,
    relativePath: String,
    maximumBytes: Int64
) throws {
    let handle = try openStagedArtifact(
        in: appBundleURL,
        relativePath: relativePath,
        maximumBytes: maximumBytes
    )
    try? handle.close()
}

private func stagedArtifactData(
    in appBundleURL: URL,
    relativePath: String,
    maximumBytes: Int64
) throws -> Data {
    let handle = try openStagedArtifact(
        in: appBundleURL,
        relativePath: relativePath,
        maximumBytes: maximumBytes
    )
    defer { try? handle.close() }
    do {
        let data = try handle.read(upToCount: Int(maximumBytes + 1)) ?? Data()
        guard data.count <= Int(maximumBytes) else {
            throw PackagingFieldArtifactInspectionError.oversizedStagedArtifact(relativePath)
        }
        return data
    } catch let error as PackagingFieldArtifactInspectionError {
        throw error
    } catch {
        throw PackagingFieldArtifactInspectionError.unreadableStagedArtifact(relativePath)
    }
}

func packagingSHA256(
    in appBundleURL: URL,
    relativePath: String,
    maximumBytes: Int64
) throws -> String {
    let handle = try openStagedArtifact(
        in: appBundleURL,
        relativePath: relativePath,
        maximumBytes: maximumBytes
    )
    defer { try? handle.close() }
    do {
        var hasher = SHA256()
        var bytesRead: Int64 = 0
        while let chunk = try handle.read(upToCount: 64 * 1024), !chunk.isEmpty {
            bytesRead += Int64(chunk.count)
            guard bytesRead <= maximumBytes else {
                throw PackagingFieldArtifactInspectionError.oversizedStagedArtifact(relativePath)
            }
            hasher.update(data: chunk)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    } catch let error as PackagingFieldArtifactInspectionError {
        throw error
    } catch {
        throw PackagingFieldArtifactInspectionError.unreadableStagedArtifact(relativePath)
    }
}

private func openStagedArtifact(
    in appBundleURL: URL,
    relativePath: String,
    maximumBytes: Int64
) throws -> FileHandle {
    let components = try stagedArtifactPathComponents(relativePath)
    let bundlePath = appBundleURL.standardizedFileURL.path
    let canonicalRoot = appBundleURL.standardizedFileURL.resolvingSymlinksInPath()
    let canonicalArtifact = components.reduce(canonicalRoot) { partialURL, component in
        partialURL.appendingPathComponent(component, isDirectory: false)
    }.resolvingSymlinksInPath()
    guard canonicalArtifact.path == canonicalRoot.appendingPathComponent(components.joined(separator: "/")).path else {
        throw PackagingFieldArtifactInspectionError.unsafeStagedArtifact(relativePath)
    }

    var directoryDescriptor = open(bundlePath, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
    guard directoryDescriptor >= 0 else {
        var metadata = stat()
        if lstat(bundlePath, &metadata) != 0, errno == ENOENT {
            throw PackagingFieldArtifactInspectionError.missingStagedAppBundle(bundlePath)
        }
        throw PackagingFieldArtifactInspectionError.unsafeStagedAppBundle(bundlePath)
    }
    defer { _ = close(directoryDescriptor) }
    guard descriptorIsDirectory(directoryDescriptor) else {
        throw PackagingFieldArtifactInspectionError.unsafeStagedAppBundle(bundlePath)
    }

    for component in components.dropLast() {
        let childDescriptor = openat(
            directoryDescriptor,
            component,
            O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC
        )
        guard childDescriptor >= 0 else {
            throw stagedArtifactOpenError(relativePath)
        }
        guard descriptorIsDirectory(childDescriptor) else {
            _ = close(childDescriptor)
            throw PackagingFieldArtifactInspectionError.unsafeStagedArtifact(relativePath)
        }
        _ = close(directoryDescriptor)
        directoryDescriptor = childDescriptor
    }

    let artifactDescriptor = openat(
        directoryDescriptor,
        components.last!,
        O_RDONLY | O_NONBLOCK | O_NOFOLLOW | O_CLOEXEC
    )
    guard artifactDescriptor >= 0 else {
        throw stagedArtifactOpenError(relativePath)
    }
    var metadata = stat()
    guard fstat(artifactDescriptor, &metadata) == 0 else {
        _ = close(artifactDescriptor)
        throw PackagingFieldArtifactInspectionError.unreadableStagedArtifact(relativePath)
    }
    guard isRegularFile(metadata.st_mode) else {
        _ = close(artifactDescriptor)
        throw PackagingFieldArtifactInspectionError.unsafeStagedArtifact(relativePath)
    }
    guard metadata.st_size >= 0, metadata.st_size <= maximumBytes else {
        _ = close(artifactDescriptor)
        throw PackagingFieldArtifactInspectionError.oversizedStagedArtifact(relativePath)
    }
    return FileHandle(fileDescriptor: artifactDescriptor, closeOnDealloc: true)
}

private func stagedArtifactPathComponents(_ relativePath: String) throws -> [String] {
    let prefix = "OpenLoLa.app/"
    guard relativePath.hasPrefix(prefix) else {
        throw PackagingFieldArtifactInspectionError.unsafeStagedArtifact(relativePath)
    }
    let components = relativePath.dropFirst(prefix.count).split(separator: "/", omittingEmptySubsequences: false)
    guard !components.isEmpty,
          components.allSatisfy({ !$0.isEmpty && $0 != "." && $0 != ".." }) else {
        throw PackagingFieldArtifactInspectionError.unsafeStagedArtifact(relativePath)
    }
    return components.map(String.init)
}

private func descriptorIsDirectory(_ descriptor: Int32) -> Bool {
    var metadata = stat()
    return fstat(descriptor, &metadata) == 0 && (metadata.st_mode & S_IFMT) == S_IFDIR
}

private func isRegularFile(_ mode: mode_t) -> Bool {
    (mode & S_IFMT) == S_IFREG
}

private func stagedArtifactOpenError(_ relativePath: String) -> PackagingFieldArtifactInspectionError {
    errno == ENOENT
        ? .missingStagedArtifact(relativePath)
        : .unsafeStagedArtifact(relativePath)
}

/// Identifies an observed staged-bundle inspection or signature-verification failure.
public enum PackagingFieldArtifactInspectionError: Error, Equatable, Sendable {
    case missingStagedAppBundle(String)
    case unsafeStagedAppBundle(String)
    case missingStagedArtifact(String)
    case unsafeStagedArtifact(String)
    case oversizedStagedArtifact(String)
    case unreadableStagedArtifact(String)
    case invalidPropertyList(String)
    case missingPlistValue(String)
    case unexpectedPlistValue(key: String, expected: String, actual: String)
    case missingEnabledEntitlement(String)
    case missingEmbeddedEntitlement(String)
    case invalidEmbeddedEntitlements(String)
    case unexpectedCodeSigningIdentity(String)
    case codeSigningVerificationFailed(String)
}
