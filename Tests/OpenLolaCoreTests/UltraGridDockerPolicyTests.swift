// Verifies that UltraGrid Docker helpers reject mutable latest images.
import Foundation
import Testing

@Test
func ultraGridDockerHelpersRejectMutableLatestImages() throws {
    let dockerfile = try readText("scripts/ultragrid-docker/Dockerfile")
    let dockerfileInstructions = dockerfileInstructionMap(dockerfile)

    let defaultImage = try runBashScript(
        "-c",
        "source scripts/open-lola-ultragrid-docker-policy.sh; open_lola_required_ultragrid_docker_image"
    )
    #expect(defaultImage.status == 0)
    #expect(defaultImage.output.trimmingCharacters(in: .whitespacesAndNewlines) == "open-lola-ultragrid:1.10.4")

    let temporaryRoot = FileManager.default.temporaryDirectory
        .appendingPathComponent("open-lola-ultragrid-policy-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: temporaryRoot, withIntermediateDirectories: true)
    defer {
        try? FileManager.default.removeItem(at: temporaryRoot)
    }

    for invocation in [
        ["scripts/start-local-ultragrid-docker.sh"],
        ["scripts/open-lola-ultragrid-docker-client.sh", "--version"],
        ["scripts/build-local-ultragrid-docker.sh"],
        [
            "scripts/run-local-ultragrid-rxtx-docker.sh",
            temporaryRoot.appendingPathComponent("rxtx").path
        ],
        [
            "scripts/compare-local-ultragrid-parity-docker.sh",
            temporaryRoot.appendingPathComponent("parity").path
        ]
    ] {
        let result = try runBashScript(
            environment: ["OPEN_LOLA_ULTRAGRID_DOCKER_IMAGE": "latest"],
            invocation
        )
        #expect(result.status == 64)
        #expect(result.output.contains("must not use the mutable latest tag"))
        #expect(!result.output.contains("Cannot connect to the Docker daemon"))
    }

    #expect(dockerfileInstructions["FROM"] == [
        "debian:bookworm-slim@sha256:67b30a61dc87758f0caf819646104f29ecbda97d920aaf5edc834128ac8493d3 AS build",
        "debian:bookworm-slim@sha256:67b30a61dc87758f0caf819646104f29ecbda97d920aaf5edc834128ac8493d3"
    ])
    #expect(dockerfileInstructions["ARG"]?.contains {
        $0.hasPrefix("ULTRAGRID_SOURCE_SHA256=")
    } == true)
    #expect(dockerfileInstructions["RUN"]?.contains {
        $0.contains("sha256sum -c -")
    } == true)
    #expect(dockerfileInstructions["USER"] == ["openlola"])
}

@Test
func ultraGridDockerClientUsesReviewedImageWithoutPrivilegedDefaults() throws {
    let temporaryRoot = FileManager.default.temporaryDirectory
        .appendingPathComponent("open-lola-ultragrid-client-\(UUID().uuidString)")
    let fakeBin = temporaryRoot.appendingPathComponent("bin")
    let dockerLog = temporaryRoot.appendingPathComponent("docker-args.txt")
    try FileManager.default.createDirectory(at: fakeBin, withIntermediateDirectories: true)
    defer {
        try? FileManager.default.removeItem(at: temporaryRoot)
    }

    let fakeDocker = fakeBin.appendingPathComponent("docker")
    try """
    #!/usr/bin/env bash
    printf '%s\\n' "$*" >> "$OPEN_LOLA_TEST_DOCKER_ARGS"
    exit 0
    """.write(to: fakeDocker, atomically: true, encoding: .utf8)
    try FileManager.default.setAttributes(
        [.posixPermissions: 0o755],
        ofItemAtPath: fakeDocker.path
    )

    let client = try runBashScript(
        "-c",
        """
        PATH="$1:$PATH" \
        OPEN_LOLA_TEST_DOCKER_ARGS="$2" \
        OPEN_LOLA_ULTRAGRID_DOCKER_IMAGE=reviewed/ultragrid:1.10 \
          bash scripts/open-lola-ultragrid-docker-client.sh \
            -d dummy -r dummy -P 5004:5004:5006:5006 198.51.100.20
        """,
        "open-lola-test",
        fakeBin.path,
        dockerLog.path
    )
    #expect(client.status == 0)

    let dockerArgs = try String(contentsOf: dockerLog, encoding: .utf8)
    #expect(dockerArgs.contains("run --rm --name open-lola-ultragrid-client"))
    #expect(dockerArgs.contains("--add-host host.docker.internal:host-gateway"))
    #expect(dockerArgs.contains("reviewed/ultragrid:1.10"))
    #expect(dockerArgs.contains("--client 198.51.100.20"))
    #expect(!dockerArgs.contains("--privileged"))
    #expect(!dockerArgs.contains("latest"))
}

private var repositoryRoot: URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
}

private struct CommandResult {
    let status: Int32
    let output: String
}

private func readText(_ relativePath: String) throws -> String {
    let url = repositoryRoot.appendingPathComponent(relativePath)
    return try String(contentsOf: url, encoding: .utf8)
}

private func dockerfileInstructionMap(_ text: String) -> [String: [String]] {
    var instructions: [String: [String]] = [:]
    var activeInstruction: (name: String, body: String)?

    func flushActiveInstruction() {
        guard let activeInstruction else {
            return
        }
        instructions[activeInstruction.name, default: []].append(activeInstruction.body)
    }

    for rawLine in text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init) {
        let trimmed = rawLine.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty || trimmed.hasPrefix("#") {
            continue
        }
        let continued = trimmed.hasSuffix("\\")
        let line = continued
            ? String(trimmed.dropLast()).trimmingCharacters(in: .whitespaces)
            : trimmed
        if rawLine.first?.isWhitespace == true, let active = activeInstruction {
            activeInstruction = (active.name, active.body + " " + line)
        } else if let separator = line.firstIndex(of: " ") {
            flushActiveInstruction()
            let name = String(line[..<separator]).uppercased()
            let body = line[line.index(after: separator)...].trimmingCharacters(in: .whitespaces)
            activeInstruction = (name, body)
        }
        if !continued {
            flushActiveInstruction()
            activeInstruction = nil
        }
    }
    flushActiveInstruction()
    return instructions
}

private func runBashScript(
    environment: [String: String] = [:],
    _ arguments: [String]
) throws -> CommandResult {
    let result = try ReleaseArtifactHygieneSupport.runBashScript(
        in: repositoryRoot,
        environment: environment,
        arguments
    )
    return CommandResult(status: result.status, output: result.output)
}

private func runBashScript(
    environment: [String: String] = [:],
    _ arguments: String...
) throws -> CommandResult {
    try runBashScript(environment: environment, arguments)
}
