// Builds the operator-facing notices that make external-connector dry-run and default-duration behaviour explicit.
extension ExternalConnectorSessionConfiguration {
    /// Returns the notices an operator must see before this configuration runs.
    /// - Parameter durationSecondsWasExplicit: whether `--duration-seconds` was passed on the command line.
    public func operatorNotices(durationSecondsWasExplicit: Bool) -> [String] {
        if dryRun {
            return ["DRY RUN: nothing was launched; pass --dry-run false to start the connector session."]
        }
        if !durationSecondsWasExplicit {
            return ["NOTICE: --duration-seconds was not given; the session will run for the default \(durationSeconds) second(s)."]
        }
        return []
    }
}
