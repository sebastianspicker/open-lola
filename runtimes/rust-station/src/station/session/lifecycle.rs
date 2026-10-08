//! Idempotent session finalization with best-effort ordered cleanup.

use super::media::SessionMediaTransport;
use super::SessionResult;
use crate::station::monitor::NetworkMonitor;
use crate::station::SessionError;

pub(super) type CleanupFinalizer<'a> = (&'a str, &'a mut dyn FnMut() -> Result<(), SessionError>);

#[derive(Debug, Default)]
pub(super) struct CleanupReport {
    pub(super) warnings: Vec<String>,
    pub(super) stop_audio_signal_sent: bool,
    pub(super) disconnect_sent: bool,
    finalized: bool,
}

impl CleanupReport {
    pub(super) fn finalize(
        &mut self,
        primary: Option<SessionError>,
        finalizers: &mut [CleanupFinalizer<'_>],
    ) -> Result<(), SessionError> {
        if self.finalized {
            return primary.map_or(Ok(()), Err);
        }
        self.finalized = true;
        for (name, finalizer) in finalizers {
            if let Err(error) = finalizer() {
                self.warnings.push(format!("{name}: {error}"));
            }
        }
        match primary {
            Some(error) => Err(error),
            None if self.warnings.is_empty() => Ok(()),
            None => Err(SessionError::Cleanup(self.warnings.join("; "))),
        }
    }
}

/// Record the common transport and monitor view in the owning session result.
pub(super) fn record_transport_monitor(
    result: &mut SessionResult,
    monitor: &NetworkMonitor,
    transport: &mut SessionMediaTransport,
) -> Result<(), SessionError> {
    let cached = transport.stats();
    let snapshot = transport.stats_snapshot();
    record_transport_monitor_snapshot(result, monitor, cached, snapshot)
}

fn record_transport_monitor_snapshot(
    result: &mut SessionResult,
    monitor: &NetworkMonitor,
    cached: crate::net::TransportStats,
    snapshot: Result<crate::net::TransportStats, SessionError>,
) -> Result<(), SessionError> {
    result.network_monitor = monitor.to_int_map();
    result.network_monitor_report = monitor.to_report();
    // Keep the report schema complete when a native counter source fails. The
    // caller still receives the error, while already observed software
    // counters remain available in the partial terminal report.
    let stats = snapshot.as_ref().copied().unwrap_or(cached);
    record_cached_transport_stats(result, stats);
    snapshot.map(|_| ())
}

/// Replaces every transport-owned report counter from a cached snapshot.
/// This is safe after shutdown and cannot perform another native statistics
/// query. It lets finalization publish a newer final kernel counter while
/// retaining the public report's complete key set on both success and error.
pub(super) fn record_cached_transport_stats(
    result: &mut SessionResult,
    stats: crate::net::TransportStats,
) {
    for (name, value) in [
        ("sent_datagrams", stats.sent_datagrams),
        ("received_datagrams", stats.received_datagrams),
        ("sent_bytes", stats.sent_bytes),
        ("received_bytes", stats.received_bytes),
        ("malformed_drops", stats.malformed_drops),
        ("wrong_peer_drops", stats.wrong_peer_drops),
        ("wrong_port_drops", stats.wrong_port_drops),
        ("kernel_drops", stats.kernel_drops),
        ("backpressure_drops", stats.backpressure_drops),
        ("queue_replacement_drops", stats.queue_replacement_drops),
        ("transient_receive_errors", stats.transient_receive_errors),
    ] {
        result.network_monitor.insert(name.into(), value as i64);
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::net::TransportStats;

    const TRANSPORT_KEYS: [&str; 10] = [
        "sent_datagrams",
        "received_datagrams",
        "sent_bytes",
        "received_bytes",
        "malformed_drops",
        "wrong_peer_drops",
        "wrong_port_drops",
        "kernel_drops",
        "backpressure_drops",
        "queue_replacement_drops",
    ];

    #[test]
    fn cached_final_transport_stats_replace_earlier_snapshot_and_keep_schema() {
        let mut result = SessionResult::default();
        record_cached_transport_stats(
            &mut result,
            TransportStats {
                received_datagrams: 3,
                kernel_drops: 2,
                ..TransportStats::default()
            },
        );
        record_cached_transport_stats(
            &mut result,
            TransportStats {
                received_datagrams: 5,
                kernel_drops: 7,
                ..TransportStats::default()
            },
        );

        assert_eq!(result.network_monitor.get("received_datagrams"), Some(&5));
        assert_eq!(result.network_monitor.get("kernel_drops"), Some(&7));
        assert!(TRANSPORT_KEYS
            .iter()
            .all(|key| result.network_monitor.contains_key(*key)));
    }

    #[test]
    fn reporting_snapshot_failure_keeps_all_cached_transport_counters() {
        let mut result = SessionResult::default();
        let cached = TransportStats {
            sent_datagrams: 11,
            received_datagrams: 7,
            kernel_drops: 3,
            ..TransportStats::default()
        };
        let error = record_transport_monitor_snapshot(
            &mut result,
            &NetworkMonitor::default(),
            cached,
            Err(SessionError::Transport("statistics unavailable".into())),
        )
        .expect_err("snapshot failure must remain visible");

        assert!(error.to_string().contains("statistics unavailable"));
        assert_eq!(result.network_monitor.get("sent_datagrams"), Some(&11));
        assert_eq!(result.network_monitor.get("received_datagrams"), Some(&7));
        assert_eq!(result.network_monitor.get("kernel_drops"), Some(&3));
        assert!(TRANSPORT_KEYS
            .iter()
            .all(|key| result.network_monitor.contains_key(*key)));
    }
}
