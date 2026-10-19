//! Peer-liveness watchdog for persistent sessions.

use super::SessionOptions;
use crate::config::StationSettings;
use crate::station::SessionError;
use std::time::{Duration, Instant};

/// Ends a persistent session whose peer has gone silent. "Activity" is any counter that
/// moves when a datagram from the peer arrives (media datagrams plus control messages).
/// Sessions that expect nothing from the peer (transmit-only) cannot tell silence from
/// a healthy receiver, so the watchdog stays disarmed for them.
pub(super) struct PeerWatchdog {
    timeout: Option<Duration>,
    last_activity: u64,
    last_change: Instant,
}

impl PeerWatchdog {
    pub(super) fn new(settings: &StationSettings, options: &SessionOptions, now: Instant) -> Self {
        let expects_media =
            options.stream_rx_audio || (options.stream_rx_video && !options.audio_only);
        let seconds = settings.network.peer_silence_timeout_secs;
        let armed = options.persistent && expects_media && seconds.is_finite() && seconds > 0.0;
        Self {
            timeout: armed.then(|| Duration::from_secs_f64(seconds)),
            last_activity: 0,
            last_change: now,
        }
    }

    pub(super) fn is_armed(&self) -> bool {
        self.timeout.is_some()
    }

    /// One counter read and one `Instant` comparison per call.
    pub(super) fn check(&mut self, activity: u64, now: Instant) -> Result<(), SessionError> {
        let Some(timeout) = self.timeout else {
            return Ok(());
        };
        if activity != self.last_activity {
            self.last_activity = activity;
            self.last_change = now;
            return Ok(());
        }
        let silent = now.saturating_duration_since(self.last_change);
        if silent > timeout {
            return Err(SessionError::PeerDisconnect(format!(
                "peer silent for {:.1}s",
                silent.as_secs_f64()
            )));
        }
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn watchdog(seconds: f64, persistent: bool, rx: bool, now: Instant) -> PeerWatchdog {
        let mut settings = crate::config::default_settings();
        settings.network.peer_silence_timeout_secs = seconds;
        let mut options = SessionOptions::demo();
        options.persistent = persistent;
        options.stream_rx_audio = rx;
        options.stream_rx_video = rx;
        PeerWatchdog::new(&settings, &options, now)
    }

    #[test]
    fn silence_past_the_timeout_ends_the_session_and_activity_resets_it() {
        let t0 = Instant::now();
        let mut dog = watchdog(5.0, true, true, t0);
        assert!(dog.is_armed());
        dog.check(0, t0 + Duration::from_secs(4)).unwrap();
        // A datagram arrives: the silence clock restarts from that moment.
        dog.check(3, t0 + Duration::from_secs(6)).unwrap();
        dog.check(3, t0 + Duration::from_secs(10)).unwrap();
        let error = dog.check(3, t0 + Duration::from_secs(12)).unwrap_err();
        assert!(
            matches!(&error, SessionError::PeerDisconnect(m) if m.starts_with("peer silent for 6.0s")),
            "{error}"
        );
    }

    #[test]
    fn zero_timeout_non_persistent_and_transmit_only_sessions_are_disarmed() {
        let t0 = Instant::now();
        for dog in [
            watchdog(0.0, true, true, t0),
            watchdog(5.0, false, true, t0),
            watchdog(5.0, true, false, t0),
        ] {
            let mut dog = dog;
            assert!(!dog.is_armed());
            dog.check(0, t0 + Duration::from_secs(3600)).unwrap();
        }
    }
}
