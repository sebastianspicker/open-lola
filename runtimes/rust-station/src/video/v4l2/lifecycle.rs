use super::{V4l2Error, V4l2Result};

pub(super) trait CaptureLifecycle {
    fn queue(&mut self, index: u32) -> V4l2Result<()>;
    fn stream_on(&mut self) -> V4l2Result<()>;
    fn stream_off(&mut self) -> V4l2Result<()>;
    fn close(&mut self);
    fn unmap(&mut self);
}

pub(super) fn start_capture<T: CaptureLifecycle>(
    io: &mut T,
    queued: &mut [bool],
    streaming: &mut bool,
) -> V4l2Result<()> {
    if *streaming {
        return Ok(());
    }
    for (index, owned) in queued.iter_mut().enumerate() {
        if !*owned {
            if let Err(error) = io.queue(index as u32) {
                return fail_start(io, queued, streaming, error);
            }
            *owned = true;
        }
    }
    if let Err(error) = io.stream_on() {
        return fail_start(io, queued, streaming, error);
    }
    *streaming = true;
    Ok(())
}

fn fail_start<T: CaptureLifecycle>(
    io: &mut T,
    queued: &mut [bool],
    streaming: &mut bool,
    primary: V4l2Error,
) -> V4l2Result<()> {
    let cleanup = if queued.iter().any(|value| *value) {
        io.stream_off().err()
    } else {
        None
    };
    io.close();
    io.unmap();
    queued.fill(false);
    *streaming = false;
    match cleanup {
        Some(error) => Err(V4l2Error::Cleanup(format!(
            "{primary}; STREAMOFF during failed start also failed: {error}"
        ))),
        None => Err(primary),
    }
}

pub(super) fn stop_capture<T: CaptureLifecycle>(
    io: &mut T,
    queued: &mut [bool],
    streaming: &mut bool,
) -> V4l2Result<()> {
    if !*streaming && !queued.iter().any(|value| *value) {
        return Ok(());
    }
    if let Err(error) = io.stream_off() {
        io.close();
        io.unmap();
        queued.fill(false);
        *streaming = false;
        return Err(error);
    }
    queued.fill(false);
    *streaming = false;
    Ok(())
}

pub(super) fn cleanup_capture<T: CaptureLifecycle>(
    io: &mut T,
    queued: &mut [bool],
    streaming: &mut bool,
) {
    if *streaming || queued.iter().any(|value| *value) {
        let _ = io.stream_off();
    }
    io.close();
    io.unmap();
    queued.fill(false);
    *streaming = false;
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::io;

    #[derive(Default)]
    struct FakeIo {
        events: Vec<String>,
        fail_queue: Option<u32>,
        fail_stream_off: bool,
    }

    impl CaptureLifecycle for FakeIo {
        fn queue(&mut self, index: u32) -> V4l2Result<()> {
            self.events.push(format!("queue:{index}"));
            if self.fail_queue == Some(index) {
                return Err(io_error("queue"));
            }
            Ok(())
        }

        fn stream_on(&mut self) -> V4l2Result<()> {
            self.events.push("stream_on".into());
            Ok(())
        }

        fn stream_off(&mut self) -> V4l2Result<()> {
            self.events.push("stream_off".into());
            if self.fail_stream_off {
                return Err(io_error("stream_off"));
            }
            Ok(())
        }

        fn close(&mut self) {
            self.events.push("close".into());
        }

        fn unmap(&mut self) {
            self.events.push("unmap".into());
        }
    }

    fn io_error(operation: &'static str) -> V4l2Error {
        V4l2Error::Io {
            operation,
            source: io::Error::other("injected"),
        }
    }

    #[test]
    fn partial_queue_failure_stops_closes_then_unmaps() {
        let mut io = FakeIo {
            fail_queue: Some(1),
            ..FakeIo::default()
        };
        let mut queued = vec![false; 3];
        let mut streaming = false;
        assert!(start_capture(&mut io, &mut queued, &mut streaming).is_err());
        assert_eq!(
            io.events,
            ["queue:0", "queue:1", "stream_off", "close", "unmap"]
        );
        assert!(!streaming && queued.iter().all(|value| !value));
    }

    #[test]
    fn streamoff_failure_closes_before_unmap() {
        let mut io = FakeIo {
            fail_stream_off: true,
            ..FakeIo::default()
        };
        let mut queued = vec![true; 2];
        let mut streaming = true;
        assert!(stop_capture(&mut io, &mut queued, &mut streaming).is_err());
        assert_eq!(io.events, ["stream_off", "close", "unmap"]);
    }

    #[test]
    fn drop_cleanup_closes_before_unmap_even_when_streamoff_fails() {
        let mut io = FakeIo {
            fail_stream_off: true,
            ..FakeIo::default()
        };
        let mut queued = vec![true];
        let mut streaming = false;
        cleanup_capture(&mut io, &mut queued, &mut streaming);
        assert_eq!(io.events, ["stream_off", "close", "unmap"]);
    }
}
