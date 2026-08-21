//! Idempotent session finalization with best-effort ordered cleanup.

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
