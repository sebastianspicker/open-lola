use super::*;

#[allow(clippy::too_many_arguments)]
pub(super) fn drive_transfer<B, F>(
    backend: &mut B,
    cancelled: &AtomicBool,
    xruns: &mut u64,
    direction: StreamDirection,
    total_frames: usize,
    deadline: Instant,
    mut transfer: F,
) -> AlsaResult<()>
where
    B: PcmBackend,
    F: FnMut(&mut B, usize, usize) -> Result<usize, i32>,
{
    let operation = direction.label();
    let mut completed = 0usize;
    let mut recoveries = 0usize;
    while completed < total_frames {
        check_cancelled(cancelled)?;
        if Instant::now() >= deadline {
            return Err(AlsaError::Timeout { operation });
        }
        let recovery = match transfer(backend, completed, total_frames - completed) {
            Ok(0) => wait_ready(backend, cancelled, direction, deadline)?,
            Err(error) if error == -EAGAIN => wait_ready(backend, cancelled, direction, deadline)?,
            Ok(frames) if frames <= total_frames - completed => {
                completed += frames;
                None
            }
            Ok(frames) => {
                return Err(AlsaError::Native {
                    operation,
                    code: 0,
                    detail: format!("driver returned {frames} frames beyond the request"),
                });
            }
            Err(error) if [-EPIPE, -ESTRPIPE, -EINTR].contains(&error) => Some(error),
            Err(error) => return Err(native_error(backend, operation, error)),
        };
        if let Some(error) = recovery {
            recover_stream(backend, xruns, direction, operation, error, &mut recoveries)?;
        }
    }
    Ok(())
}

fn recover_stream<B: PcmBackend>(
    backend: &mut B,
    xruns: &mut u64,
    direction: StreamDirection,
    operation: &'static str,
    error: i32,
    recoveries: &mut usize,
) -> AlsaResult<()> {
    if *recoveries == MAX_RECOVERIES {
        return Err(native_error(backend, operation, error));
    }
    backend
        .recover(direction, error)
        .map_err(|code| native_error(backend, "recovery", code))?;
    *recoveries += 1;
    if [-EPIPE, -ESTRPIPE].contains(&error) {
        *xruns = xruns.saturating_add(1);
    }
    Ok(())
}

fn wait_ready<B: PcmBackend>(
    backend: &mut B,
    cancelled: &AtomicBool,
    direction: StreamDirection,
    deadline: Instant,
) -> AlsaResult<Option<i32>> {
    check_cancelled(cancelled)?;
    let remaining = deadline.saturating_duration_since(Instant::now());
    if remaining.is_zero() {
        return Err(AlsaError::Timeout {
            operation: direction.label(),
        });
    }
    let millis = remaining.as_millis().max(1).min(WAIT_SLICE_MS as u128) as i32;
    match backend.wait(direction, millis) {
        Ok(_) => Ok(None),
        Err(code) if code == -EINTR => Ok(None),
        Err(code) if [-EPIPE, -ESTRPIPE].contains(&code) => Ok(Some(code)),
        Err(code) => Err(native_error(backend, "wait", code)),
    }
}

fn check_cancelled(cancelled: &AtomicBool) -> AlsaResult<()> {
    if cancelled.load(Ordering::Acquire) {
        Err(AlsaError::Cancelled)
    } else {
        Ok(())
    }
}

fn native_error<B: PcmBackend>(backend: &B, operation: &'static str, code: i32) -> AlsaError {
    AlsaError::Native {
        operation,
        code,
        detail: backend.error_text(code),
    }
}
