/// Retains connector-specific compatibility datagrams for deterministic in-memory transmitters.
final class ExternalConnectorMemoryMediaStorage<Datagram> {
    private(set) var datagrams: [Datagram] = []

    func append(_ datagrams: [Datagram]) -> Int {
        self.datagrams.append(contentsOf: datagrams)
        return datagrams.count
    }
}
