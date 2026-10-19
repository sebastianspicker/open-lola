//! Turns a panic in the session worker into a failed result so the runtime never stays active.

use super::{SessionError, SessionResult};
use std::any::Any;
use std::panic::{catch_unwind, AssertUnwindSafe};

fn panic_message(payload: &(dyn Any + Send)) -> String {
    payload
        .downcast_ref::<&str>()
        .map(|message| (*message).to_string())
        .or_else(|| payload.downcast_ref::<String>().cloned())
        .unwrap_or_else(|| "non-string panic payload".into())
}

/// Run the session body; a panic becomes a failed `SessionResult` carrying its message.
/// `AssertUnwindSafe` is sound here: the closure owns its session state and nothing it
/// touched is observed again after the panic except through the returned result.
pub(super) fn run_guarded(run: impl FnOnce() -> SessionResult) -> SessionResult {
    catch_unwind(AssertUnwindSafe(run)).unwrap_or_else(|payload| {
        let error = format!("session worker panicked: {}", panic_message(&*payload));
        SessionResult {
            error: error.clone(),
            failure: Some(SessionError::Protocol(error)),
            ..Default::default()
        }
    })
}
