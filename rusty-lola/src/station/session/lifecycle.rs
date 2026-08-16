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

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn cleanup_failure_does_not_skip_later_finalizers() {
        use std::cell::RefCell;
        use std::rc::Rc;

        let mut report = CleanupReport::default();
        let steps = Rc::new(RefCell::new(Vec::new()));
        let first_steps = Rc::clone(&steps);
        let second_steps = Rc::clone(&steps);
        let mut first = move || {
            first_steps.borrow_mut().push("recorder");
            Err(SessionError::Cleanup("recorder".into()))
        };
        let mut second = move || {
            second_steps.borrow_mut().push("audio");
            Ok(())
        };
        let mut finalizers: [CleanupFinalizer<'_>; 2] =
            [("recorder", &mut first), ("audio", &mut second)];
        assert!(report.finalize(None, &mut finalizers).is_err());
        assert_eq!(*steps.borrow(), ["recorder", "audio"]);
    }

    #[test]
    fn cleanup_visible_on_stop() {
        let mut report = CleanupReport::default();
        let mut failing = || Err(SessionError::Cleanup("transport".into()));
        let mut finalizers: [CleanupFinalizer<'_>; 1] = [("transport", &mut failing)];
        assert!(matches!(
            report.finalize(None, &mut finalizers),
            Err(SessionError::Cleanup(_))
        ));
        assert_eq!(report.warnings.len(), 1);
    }

    #[test]
    fn second_finalize_no_op() {
        let mut report = CleanupReport::default();
        let mut calls = 0;
        let mut finalizer = || {
            calls += 1;
            Ok(())
        };
        let mut finalizers: [CleanupFinalizer<'_>; 1] = [("one", &mut finalizer)];
        assert!(report.finalize(None, &mut finalizers).is_ok());
        assert!(report.finalize(None, &mut finalizers).is_ok());
        assert_eq!(calls, 1);
    }
}
