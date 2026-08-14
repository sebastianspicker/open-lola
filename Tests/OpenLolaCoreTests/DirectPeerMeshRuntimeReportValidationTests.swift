// Validate mesh runtime report encoding and aggregate metric invariants across synthetic routes.
import Foundation
import Testing
@testable import OpenLolaCore

@Test
func directPeerMeshRuntimeReportRoundTripsAndValidatesAggregateMetrics() throws {
    let report = try makeValidMeshRuntimeReport()

    try report.validate()
    let encoded = try JSONEncoder().encode(report)
    let decoded = try JSONDecoder().decode(DirectPeerMeshRuntimeReport.self, from: encoded)

    #expect(decoded == report)
}

@Test(arguments: MeshRuntimeTextField.allCases)
func directPeerMeshRuntimeReportRejectsEmptyRequiredText(field: MeshRuntimeTextField) throws {
    var report = try makeValidMeshRuntimeReport()
    field.clear(in: &report)

    #expect(throws: DirectPeerMeshRuntimeError.emptyField(field.validationName)) {
        try report.validate()
    }
}

@Test(arguments: MeshRuntimeRouteMetricField.allCases)
func directPeerMeshRuntimeReportRejectsNegativeRouteMetrics(field: MeshRuntimeRouteMetricField) throws {
    var report = try makeValidMeshRuntimeReport()
    field.makeNegative(in: &report.routeMetrics[0])

    #expect(throws: DirectPeerMeshRuntimeError.negativeMetric(field.validationName)) {
        try report.validate()
    }
}

@Test
func directPeerMeshRuntimeReportRejectsUnknownAndDuplicateRoutes() throws {
    var unknown = try makeValidMeshRuntimeReport()
    unknown.routeMetrics[0].receiverPeerID = "unknown-peer"
    #expect(throws: DirectPeerMeshRuntimeError.routeMetricReferencesUnknownRoute(
        sender: unknown.routeMetrics[0].senderPeerID,
        receiver: "unknown-peer"
    )) {
        try unknown.validate()
    }

    var duplicate = try makeValidMeshRuntimeReport()
    duplicate.routeMetrics[1] = duplicate.routeMetrics[0]
    #expect(throws: DirectPeerMeshRuntimeError.duplicateRouteMetric(
        sender: duplicate.routeMetrics[0].senderPeerID,
        receiver: duplicate.routeMetrics[0].receiverPeerID
    )) {
        try duplicate.validate()
    }
}

@Test(arguments: MeshRuntimeAggregateMetricField.allCases)
func directPeerMeshRuntimeReportRejectsNegativeAggregateMetrics(
    field: MeshRuntimeAggregateMetricField
) throws {
    var report = try makeValidMeshRuntimeReport()
    field.makeNegative(in: &report.metrics)

    #expect(throws: DirectPeerMeshRuntimeError.negativeMetric(field.validationName)) {
        try report.validate()
    }
}

@Test(arguments: MeshRuntimeAggregateMismatchField.allCases)
func directPeerMeshRuntimeReportRejectsAggregateMismatches(
    field: MeshRuntimeAggregateMismatchField
) throws {
    var report = try makeValidMeshRuntimeReport()
    field.increment(in: &report.metrics)

    #expect(throws: DirectPeerMeshRuntimeError.metricMismatch(field.validationName)) {
        try report.validate()
    }
}

@Test
func directPeerMeshRuntimeReportRejectsPassWithoutPhysicalEvidence() throws {
    var report = try makeValidMeshRuntimeReport()
    report.verdict = .pass

    #expect(throws: DirectPeerMeshRuntimeError.passRequiresPhysicalMeshEvidence) {
        try report.validate()
    }
}

private func makeValidMeshRuntimeReport() throws -> DirectPeerMeshRuntimeReport {
    let topology = try DirectPeerMeshTopologySmoke.run(peerCount: 3)
    let routeMetrics = topology.routes.enumerated().map { index, route in
        let count = index + 1
        return DirectPeerMeshRuntimeRouteMetrics(
            senderPeerID: route.senderPeerID,
            receiverPeerID: route.receiverPeerID,
            audioDeadlinesSent: count,
            audioDeadlinesReceived: count,
            audioFragmentsSent: count * 2,
            audioFragmentsReceived: count * 2,
            incompleteAudioDeadlines: 0,
            duplicateAudioFragments: 0
        )
    }
    return DirectPeerMeshRuntimeReport(
        id: "mesh-runtime-validation",
        capturedAt: "2026-08-05T00:00:00Z",
        topology: topology,
        routeMetrics: routeMetrics,
        metrics: DirectPeerMeshRuntimeMetrics(
            peerCount: topology.configuration.peers.count,
            directedRouteCount: routeMetrics.count,
            audioDeadlinesSent: routeMetrics.map(\.audioDeadlinesSent).reduce(0, +),
            audioDeadlinesReceived: routeMetrics.map(\.audioDeadlinesReceived).reduce(0, +),
            audioFragmentsSent: routeMetrics.map(\.audioFragmentsSent).reduce(0, +),
            audioFragmentsReceived: routeMetrics.map(\.audioFragmentsReceived).reduce(0, +),
            incompleteAudioDeadlines: 0,
            duplicateAudioFragments: 0,
            audioPayloadsSentOnControlChannel: 0
        ),
        verdict: .partial,
        notes: "Synthetic validation evidence only."
    )
}

enum MeshRuntimeTextField: String, CaseIterable, Sendable {
    case id
    case capturedAt
    case notes

    var validationName: String { rawValue }

    func clear(in report: inout DirectPeerMeshRuntimeReport) {
        switch self {
        case .id: report.id = ""
        case .capturedAt: report.capturedAt = ""
        case .notes: report.notes = ""
        }
    }
}

enum MeshRuntimeRouteMetricField: String, CaseIterable, Sendable {
    case audioDeadlinesSent = "routeMetrics.audioDeadlinesSent"
    case audioDeadlinesReceived = "routeMetrics.audioDeadlinesReceived"
    case audioFragmentsSent = "routeMetrics.audioFragmentsSent"
    case audioFragmentsReceived = "routeMetrics.audioFragmentsReceived"
    case incompleteAudioDeadlines = "routeMetrics.incompleteAudioDeadlines"
    case duplicateAudioFragments = "routeMetrics.duplicateAudioFragments"

    var validationName: String { rawValue }

    func makeNegative(in metric: inout DirectPeerMeshRuntimeRouteMetrics) {
        switch self {
        case .audioDeadlinesSent: metric.audioDeadlinesSent = -1
        case .audioDeadlinesReceived: metric.audioDeadlinesReceived = -1
        case .audioFragmentsSent: metric.audioFragmentsSent = -1
        case .audioFragmentsReceived: metric.audioFragmentsReceived = -1
        case .incompleteAudioDeadlines: metric.incompleteAudioDeadlines = -1
        case .duplicateAudioFragments: metric.duplicateAudioFragments = -1
        }
    }
}

enum MeshRuntimeAggregateMetricField: String, CaseIterable, Sendable {
    case peerCount = "metrics.peerCount"
    case directedRouteCount = "metrics.directedRouteCount"
    case audioDeadlinesSent = "metrics.audioDeadlinesSent"
    case audioDeadlinesReceived = "metrics.audioDeadlinesReceived"
    case audioFragmentsSent = "metrics.audioFragmentsSent"
    case audioFragmentsReceived = "metrics.audioFragmentsReceived"
    case incompleteAudioDeadlines = "metrics.incompleteAudioDeadlines"
    case duplicateAudioFragments = "metrics.duplicateAudioFragments"
    case audioPayloadsSentOnControlChannel = "metrics.audioPayloadsSentOnControlChannel"

    var validationName: String { rawValue }

    func makeNegative(in metrics: inout DirectPeerMeshRuntimeMetrics) {
        switch self {
        case .peerCount: metrics.peerCount = -1
        case .directedRouteCount: metrics.directedRouteCount = -1
        case .audioDeadlinesSent: metrics.audioDeadlinesSent = -1
        case .audioDeadlinesReceived: metrics.audioDeadlinesReceived = -1
        case .audioFragmentsSent: metrics.audioFragmentsSent = -1
        case .audioFragmentsReceived: metrics.audioFragmentsReceived = -1
        case .incompleteAudioDeadlines: metrics.incompleteAudioDeadlines = -1
        case .duplicateAudioFragments: metrics.duplicateAudioFragments = -1
        case .audioPayloadsSentOnControlChannel: metrics.audioPayloadsSentOnControlChannel = -1
        }
    }
}

enum MeshRuntimeAggregateMismatchField: String, CaseIterable, Sendable {
    case peerCount = "metrics.peerCount"
    case directedRouteCount = "metrics.directedRouteCount"
    case audioDeadlinesSent = "metrics.audioDeadlinesSent"
    case audioDeadlinesReceived = "metrics.audioDeadlinesReceived"
    case audioFragmentsSent = "metrics.audioFragmentsSent"
    case audioFragmentsReceived = "metrics.audioFragmentsReceived"
    case incompleteAudioDeadlines = "metrics.incompleteAudioDeadlines"
    case duplicateAudioFragments = "metrics.duplicateAudioFragments"

    var validationName: String { rawValue }

    func increment(in metrics: inout DirectPeerMeshRuntimeMetrics) {
        switch self {
        case .peerCount: metrics.peerCount += 1
        case .directedRouteCount: metrics.directedRouteCount += 1
        case .audioDeadlinesSent: metrics.audioDeadlinesSent += 1
        case .audioDeadlinesReceived: metrics.audioDeadlinesReceived += 1
        case .audioFragmentsSent: metrics.audioFragmentsSent += 1
        case .audioFragmentsReceived: metrics.audioFragmentsReceived += 1
        case .incompleteAudioDeadlines: metrics.incompleteAudioDeadlines += 1
        case .duplicateAudioFragments: metrics.duplicateAudioFragments += 1
        }
    }
}
