//! Process-wide SIGINT/SIGTERM (Ctrl-C) flag and the watcher that turns it into session cancellation.

use crate::station::SessionRuntimeControl;
use std::sync::atomic::{AtomicBool, AtomicI32, Ordering};
use std::sync::Arc;
use std::thread::{self, JoinHandle};
use std::time::Duration;

/// Exit status for a run ended by an interrupt (128 + SIGINT).
pub(super) const INTERRUPTED_EXIT_CODE: i32 = 130;
#[cfg(windows)]
const SIGINT: i32 = 2;
const SIGTERM: i32 = 15;

const WATCH_INTERVAL: Duration = Duration::from_millis(50);

static INTERRUPTED: AtomicBool = AtomicBool::new(false);
/// Signal number of the first interrupt (0 = none); written before `INTERRUPTED`.
static SIGNAL: AtomicI32 = AtomicI32::new(0);

/// The signal that interrupted the run, if any. Console events report SIGINT.
pub(super) fn signal() -> Option<i32> {
    interrupted().then(|| SIGNAL.load(Ordering::SeqCst))
}

/// Shell-style exit status for a run stopped by `signal` (128 + signal number).
pub(super) fn exit_code_for(signal: i32) -> i32 {
    128 + signal
}

pub(super) fn signal_name(signal: i32) -> &'static str {
    match signal {
        SIGTERM => "SIGTERM",
        _ => "SIGINT",
    }
}

/// True once SIGINT/SIGTERM (or a console control event) was received after `install`.
pub(super) fn interrupted() -> bool {
    INTERRUPTED.load(Ordering::SeqCst)
}

// A second interrupt while the first is still pending exits at once so a wedged
// shutdown can always be killed from the terminal.
#[cfg(unix)]
extern "C" fn on_signal(signal: libc::c_int) {
    SIGNAL
        .compare_exchange(0, signal, Ordering::SeqCst, Ordering::SeqCst)
        .ok();
    if INTERRUPTED.swap(true, Ordering::SeqCst) {
        // SAFETY: `_exit` is async-signal-safe and takes no pointers.
        unsafe { libc::_exit(INTERRUPTED_EXIT_CODE) };
    }
}

/// Route SIGINT and SIGTERM to the interrupt flag instead of killing the process.
#[cfg(unix)]
pub(super) fn install() {
    for signal in [libc::SIGINT, libc::SIGTERM] {
        // SAFETY: the zeroed `sigaction` is fully initialised below before use, and the
        // handler only performs async-signal-safe atomic and `_exit` operations.
        unsafe {
            let mut action: libc::sigaction = std::mem::zeroed();
            action.sa_sigaction = on_signal as extern "C" fn(libc::c_int) as libc::sighandler_t;
            libc::sigemptyset(&mut action.sa_mask);
            // Restart interrupted socket reads; cancellation goes through the polled flag.
            action.sa_flags = libc::SA_RESTART;
            libc::sigaction(signal, &action, std::ptr::null_mut());
        }
    }
}

#[cfg(windows)]
extern "system" {
    fn SetConsoleCtrlHandler(
        handler: Option<unsafe extern "system" fn(u32) -> i32>,
        add: i32,
    ) -> i32;
}

#[cfg(windows)]
unsafe extern "system" fn on_ctrl_event(event: u32) -> i32 {
    // CTRL_C_EVENT, CTRL_BREAK_EVENT, CTRL_CLOSE_EVENT
    if event > 2 {
        return 0;
    }
    SIGNAL.store(SIGINT, Ordering::SeqCst);
    if INTERRUPTED.swap(true, Ordering::SeqCst) {
        std::process::exit(INTERRUPTED_EXIT_CODE);
    }
    1
}

/// Route console Ctrl-C/Break/Close events to the interrupt flag.
#[cfg(windows)]
pub(super) fn install() {
    // SAFETY: `on_ctrl_event` matches the PHANDLER_ROUTINE signature and stays valid for
    // the life of the process.
    unsafe {
        SetConsoleCtrlHandler(Some(on_ctrl_event), 1);
    }
}

#[cfg(not(any(unix, windows)))]
pub(super) fn install() {}

/// Background poller that cancels a session once its flag is raised; stops on drop.
pub(super) struct CancelWatcher {
    done: Arc<AtomicBool>,
    thread: Option<JoinHandle<()>>,
}

impl CancelWatcher {
    pub(super) fn spawn(
        control: SessionRuntimeControl,
        is_interrupted: impl Fn() -> bool + Send + 'static,
    ) -> Self {
        let done = Arc::new(AtomicBool::new(false));
        let watcher_done = Arc::clone(&done);
        let thread = thread::Builder::new()
            .name("cli-interrupt-watch".into())
            .spawn(move || {
                while !watcher_done.load(Ordering::Acquire) {
                    if is_interrupted() {
                        control.cancel();
                        return;
                    }
                    thread::sleep(WATCH_INTERVAL);
                }
            })
            .ok();
        Self { done, thread }
    }
}

impl Drop for CancelWatcher {
    fn drop(&mut self) {
        self.done.store(true, Ordering::Release);
        if let Some(thread) = self.thread.take() {
            let _ = thread.join();
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::time::Instant;

    #[test]
    fn watcher_cancels_control_when_flag_is_raised() {
        let control = SessionRuntimeControl::default();
        let flag = Arc::new(AtomicBool::new(false));
        let watcher_flag = Arc::clone(&flag);
        let watcher =
            CancelWatcher::spawn(control.clone(), move || watcher_flag.load(Ordering::SeqCst));
        assert!(!control.is_cancelled());
        flag.store(true, Ordering::SeqCst);
        let deadline = Instant::now() + Duration::from_secs(2);
        while !control.is_cancelled() && Instant::now() < deadline {
            thread::sleep(Duration::from_millis(5));
        }
        assert!(control.is_cancelled());
        drop(watcher);
    }

    #[test]
    fn cancelled_control_ends_a_listening_session_promptly() {
        let control = SessionRuntimeControl::default();
        control.cancel();
        let mut options = crate::station::SessionOptions::demo();
        options.peer_mode = "listen".into();
        options.runtime_control = Some(control);
        let started = Instant::now();
        let result = crate::station::run_session(crate::config::default_settings(), 30.0, options);
        assert!(started.elapsed() < Duration::from_secs(5), "{result:?}");
        assert!(!result.ok, "{result:?}");
        assert!(result.error.contains("cancelled"), "{result:?}");
    }

    #[test]
    fn dropped_watcher_does_not_cancel_without_interrupt() {
        let control = SessionRuntimeControl::default();
        drop(CancelWatcher::spawn(control.clone(), || false));
        assert!(!control.is_cancelled());
    }
}
