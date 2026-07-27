// Shares placeholder-field projection for direct-link route evidence validation.

func directLinkRoutePlaceholderFields(
    packetCaptureArtifact: String,
    routeReport: UdpPcmRouteReport
) -> [(name: String, value: String)] {
    [
        ("directLink.packetCaptureArtifact", packetCaptureArtifact),
        ("directLink.routeReport.id", routeReport.id),
        ("directLink.routeReport.title", routeReport.title),
        ("directLink.routeReport.route.label", routeReport.route.label),
        ("directLink.routeReport.route.topology", routeReport.route.topology),
        ("directLink.routeReport.sender.hostName", routeReport.sender.hostName),
        ("directLink.routeReport.receiver.hostName", routeReport.receiver.hostName),
        (
            "directLink.routeReport.network.packetCapture.point",
            routeReport.network.packetCapture.point ?? ""
        ),
        (
            "directLink.routeReport.network.packetCapture.notes",
            routeReport.network.packetCapture.notes
        )
    ]
}
