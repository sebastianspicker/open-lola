//! Best-effort priority boost for the media thread.

/// Raises the calling thread's scheduling priority so the audio deadline is
/// not lost to ordinary load. Returns what was applied, or why it could not
/// be. Callers must treat failure as informational.
#[cfg(windows)]
pub(super) fn raise_media_thread_priority() -> Result<String, String> {
    #[link(name = "kernel32")]
    extern "system" {
        fn GetCurrentThread() -> *mut core::ffi::c_void;
        fn SetThreadPriority(thread: *mut core::ffi::c_void, priority: i32) -> i32;
    }
    const THREAD_PRIORITY_TIME_CRITICAL: i32 = 15;
    // SAFETY: GetCurrentThread returns a pseudo-handle valid for the calling
    // thread, and SetThreadPriority only reads its two by-value arguments.
    let applied = unsafe { SetThreadPriority(GetCurrentThread(), THREAD_PRIORITY_TIME_CRITICAL) };
    if applied != 0 {
        Ok("windows:time-critical".into())
    } else {
        Err(format!(
            "SetThreadPriority failed: {}",
            std::io::Error::last_os_error()
        ))
    }
}

#[cfg(target_os = "linux")]
pub(super) fn raise_media_thread_priority() -> Result<String, String> {
    const FIFO_PRIORITY: i32 = 50;
    const NICE_VALUE: i32 = -10;
    let param = libc::sched_param {
        sched_priority: FIFO_PRIORITY,
    };
    // SAFETY: pid 0 addresses the calling thread and `param` is a valid
    // sched_param that outlives the call.
    if unsafe { libc::sched_setscheduler(0, libc::SCHED_FIFO, &param) } == 0 {
        return Ok(format!("linux:SCHED_FIFO:{FIFO_PRIORITY}"));
    }
    let fifo_error = std::io::Error::last_os_error();
    // SAFETY: setpriority takes only by-value arguments; who 0 addresses the
    // calling thread on Linux.
    if unsafe { libc::setpriority(libc::PRIO_PROCESS, 0, NICE_VALUE) } == 0 {
        return Ok(format!(
            "linux:nice:{NICE_VALUE} (SCHED_FIFO: {fifo_error})"
        ));
    }
    Err(format!(
        "SCHED_FIFO: {fifo_error}; setpriority: {}",
        std::io::Error::last_os_error()
    ))
}

#[cfg(target_os = "macos")]
pub(super) fn raise_media_thread_priority() -> Result<String, String> {
    // SAFETY: the call only takes by-value arguments and affects the calling
    // thread.
    let code = unsafe {
        libc::pthread_set_qos_class_self_np(libc::qos_class_t::QOS_CLASS_USER_INTERACTIVE, 0)
    };
    if code == 0 {
        Ok("macos:qos-user-interactive".into())
    } else {
        Err(format!(
            "pthread_set_qos_class_self_np failed: errno {code}"
        ))
    }
}

#[cfg(not(any(windows, target_os = "linux", target_os = "macos")))]
pub(super) fn raise_media_thread_priority() -> Result<String, String> {
    Err("unsupported".into())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn priority_request_reports_an_outcome_without_panicking() {
        match raise_media_thread_priority() {
            Ok(applied) => assert!(!applied.is_empty()),
            Err(reason) => assert!(!reason.is_empty()),
        }
    }
}
