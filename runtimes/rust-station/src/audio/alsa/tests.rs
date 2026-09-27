use super::*;
use std::collections::VecDeque;

struct SubstituteBackend {
    capture: Option<NegotiatedPcm>,
    playback: Option<NegotiatedPcm>,
    reads: VecDeque<Result<usize, i32>>,
    writes: VecDeque<Result<usize, i32>>,
    waits: VecDeque<Result<bool, i32>>,
    recoveries: Vec<(StreamDirection, i32)>,
    started: usize,
    stopped: usize,
    read_fill: u8,
    read_would_block: bool,
    sleep_on_wait: bool,
}

impl SubstituteBackend {
    fn exact(config: &AlsaConfig) -> Self {
        let negotiated = NegotiatedPcm::from(config);
        Self {
            capture: config.capture_enabled.then_some(negotiated),
            playback: config.playback_enabled.then_some(negotiated),
            reads: VecDeque::new(),
            writes: VecDeque::new(),
            waits: VecDeque::new(),
            recoveries: Vec::new(),
            started: 0,
            stopped: 0,
            read_fill: 0x5a,
            read_would_block: false,
            sleep_on_wait: false,
        }
    }
}

impl PcmBackend for SubstituteBackend {
    fn negotiated(&self, direction: StreamDirection) -> Option<NegotiatedPcm> {
        match direction {
            StreamDirection::Capture => self.capture,
            StreamDirection::Playback => self.playback,
        }
    }

    fn start(&mut self) -> AlsaResult<()> {
        self.started += 1;
        Ok(())
    }

    fn stop(&mut self) -> AlsaResult<()> {
        self.stopped += 1;
        Ok(())
    }

    fn read_frames(&mut self, destination: &mut [u8], frames: usize) -> Result<usize, i32> {
        let result = self.reads.pop_front().unwrap_or({
            if self.read_would_block {
                Err(-EAGAIN)
            } else {
                Ok(frames)
            }
        });
        if let Ok(count) = result {
            let bytes_per_frame = destination.len() / frames;
            destination[..count * bytes_per_frame].fill(self.read_fill);
        }
        result
    }

    fn write_frames(&mut self, _source: &[u8], frames: usize) -> Result<usize, i32> {
        self.writes.pop_front().unwrap_or(Ok(frames))
    }

    fn wait(&mut self, _direction: StreamDirection, timeout_ms: i32) -> Result<bool, i32> {
        if self.sleep_on_wait {
            std::thread::sleep(Duration::from_millis(timeout_ms as u64));
        }
        self.waits.pop_front().unwrap_or(Ok(true))
    }

    fn recover(&mut self, direction: StreamDirection, error: i32) -> Result<(), i32> {
        self.recoveries.push((direction, error));
        Ok(())
    }

    fn error_text(&self, error: i32) -> String {
        format!("substitute error {error}")
    }
}

fn config() -> AlsaConfig {
    AlsaConfig {
        capture_device: "hw:test-capture".into(),
        playback_device: "hw:test-playback".into(),
        sample_rate: 48_000,
        channels: 2,
        bits_per_sample: 16,
        frames_per_buffer: 8,
        capture_enabled: true,
        playback_enabled: true,
    }
}

#[test]
fn validates_configuration_without_opening_native_audio() {
    let mut candidate = config();
    candidate.capture_enabled = false;
    candidate.playback_enabled = false;
    assert!(matches!(
        candidate.validate(),
        Err(AlsaError::InvalidConfig(_))
    ));

    let mut candidate = config();
    candidate.bits_per_sample = 20;
    assert!(matches!(
        candidate.validate(),
        Err(AlsaError::InvalidConfig(_))
    ));

    let mut candidate = config();
    candidate.capture_device.clear();
    assert!(matches!(
        candidate.validate(),
        Err(AlsaError::InvalidConfig(_))
    ));

    for device in ["default", "plughw:0", "plug:hw:0", "file:/tmp/audio.raw"] {
        let mut candidate = config();
        candidate.capture_device = device.into();
        assert!(matches!(
            candidate.validate(),
            Err(AlsaError::InvalidConfig(_))
        ));
    }
}

#[test]
fn inventory_entries_have_stable_serialized_fields() {
    let device = AlsaDeviceInfo {
        name: "hw:2".into(),
        description: Some("Direct hardware PCM".into()),
        supports_capture: true,
        supports_playback: false,
    };
    assert_eq!(
        serde_json::to_value(device).unwrap(),
        serde_json::json!({
            "name": "hw:2",
            "description": "Direct hardware PCM",
            "supports_capture": true,
            "supports_playback": false,
        })
    );
}

#[test]
fn rejects_any_negotiated_value_that_differs() {
    let config = config();
    let expected = NegotiatedPcm::from(&config);
    for actual in [
        NegotiatedPcm {
            sample_rate: 44_100,
            ..expected
        },
        NegotiatedPcm {
            channels: 1,
            ..expected
        },
        NegotiatedPcm {
            bits_per_sample: 24,
            ..expected
        },
        NegotiatedPcm {
            frames_per_buffer: 16,
            ..expected
        },
    ] {
        assert!(matches!(
            verify_negotiation(expected, actual),
            Err(AlsaError::NegotiationMismatch { .. })
        ));
    }
}

#[test]
fn start_stop_are_idempotent_and_restart_clears_cancellation() {
    let config = config();
    let mut driver = AlsaDriver::new(config.clone(), SubstituteBackend::exact(&config)).unwrap();
    driver.start().unwrap();
    driver.start().unwrap();
    assert_eq!(driver.backend.started, 1);
    driver.cancelled.store(true, Ordering::Release);
    driver.stop().unwrap();
    driver.stop().unwrap();
    assert_eq!(driver.backend.stopped, 1);
    driver.start().unwrap();
    assert!(!driver.cancelled.load(Ordering::Acquire));
}

#[test]
fn capture_reuses_caller_capacity_and_completes_partial_reads() {
    let config = config();
    let mut backend = SubstituteBackend::exact(&config);
    backend.reads.extend([Ok(3), Ok(5)]);
    let mut driver = AlsaDriver::new(config.clone(), backend).unwrap();
    driver.start().unwrap();
    let expected = config.block_bytes().unwrap();
    let mut output = Vec::with_capacity(expected);
    let pointer = output.as_ptr();
    driver.read_pcm_into(&mut output).unwrap();
    assert_eq!(output, vec![0x5a; expected]);
    assert_eq!(output.as_ptr(), pointer);
}

#[test]
fn capture_waits_after_would_block() {
    let config = config();
    let mut backend = SubstituteBackend::exact(&config);
    backend.reads.extend([Err(-EAGAIN), Ok(8)]);
    backend.waits.push_back(Ok(true));
    let mut driver = AlsaDriver::new(config.clone(), backend).unwrap();
    driver.start().unwrap();
    let mut output = Vec::with_capacity(config.block_bytes().unwrap());
    driver.read_pcm_into(&mut output).unwrap();
    assert_eq!(output.len(), config.block_bytes().unwrap());
    assert!(driver.backend.waits.is_empty());
}

#[test]
fn capture_timeout_returns_an_empty_not_ready_result() {
    let mut config = config();
    config.frames_per_buffer = 1;
    let mut backend = SubstituteBackend::exact(&config);
    backend.read_would_block = true;
    backend.sleep_on_wait = true;
    let mut driver = AlsaDriver::new(config, backend).unwrap();
    driver.start().unwrap();
    let mut output = vec![1, 2, 3];
    driver.read_pcm_into(&mut output).unwrap();
    assert!(output.is_empty());
}

#[test]
fn cancellation_interrupts_transfer_at_a_finite_boundary() {
    let config = config();
    let backend = SubstituteBackend::exact(&config);
    let mut driver = AlsaDriver::new(config, backend).unwrap();
    driver.start().unwrap();
    driver.cancelled.store(true, Ordering::Release);
    let mut output = Vec::new();
    assert!(matches!(
        driver.read_pcm_into(&mut output),
        Err(AlsaError::Cancelled)
    ));
    assert!(output.is_empty());
}

#[test]
fn xruns_are_recovered_and_counted() {
    let config = config();
    let mut backend = SubstituteBackend::exact(&config);
    backend.reads.extend([Err(-EPIPE), Err(-ESTRPIPE), Ok(8)]);
    let mut driver = AlsaDriver::new(config, backend).unwrap();
    driver.start().unwrap();
    let mut output = Vec::new();
    driver.read_pcm_into(&mut output).unwrap();
    assert_eq!(driver.xruns, 2);
    assert_eq!(
        driver.backend.recoveries,
        vec![
            (StreamDirection::Capture, -EPIPE),
            (StreamDirection::Capture, -ESTRPIPE),
        ]
    );
}

#[test]
fn wait_side_xruns_use_the_bounded_recovery_path() {
    for error in [-EPIPE, -ESTRPIPE] {
        let config = config();
        let mut backend = SubstituteBackend::exact(&config);
        backend.reads.extend([Err(-EAGAIN), Ok(8)]);
        backend.waits.push_back(Err(error));
        let mut driver = AlsaDriver::new(config, backend).unwrap();
        driver.start().unwrap();
        let mut output = Vec::new();
        driver.read_pcm_into(&mut output).unwrap();
        assert_eq!(driver.xruns, 1);
        assert_eq!(
            driver.backend.recoveries,
            vec![(StreamDirection::Capture, error)]
        );
    }
}

#[test]
fn repeated_wait_side_xruns_stop_at_the_recovery_limit() {
    let config = config();
    let mut backend = SubstituteBackend::exact(&config);
    backend
        .reads
        .extend((0..=MAX_RECOVERIES).map(|_| Err(-EAGAIN)));
    backend
        .waits
        .extend((0..=MAX_RECOVERIES).map(|_| Err(-EPIPE)));
    let mut driver = AlsaDriver::new(config, backend).unwrap();
    driver.start().unwrap();
    let mut output = Vec::new();
    let error = driver.read_pcm_into(&mut output).unwrap_err();
    assert!(matches!(
        error,
        AlsaError::Native {
            operation: "capture",
            code,
            ..
        } if code == -EPIPE
    ));
    assert_eq!(driver.backend.recoveries.len(), MAX_RECOVERIES);
    assert_eq!(driver.xruns, MAX_RECOVERIES as u64);
}

#[test]
fn playback_requires_one_exact_block_and_completes_partial_writes() {
    let config = config();
    let mut backend = SubstituteBackend::exact(&config);
    backend.writes.extend([Ok(2), Ok(6)]);
    let mut driver = AlsaDriver::new(config.clone(), backend).unwrap();
    driver.start().unwrap();
    let block = vec![0x33; config.block_bytes().unwrap()];
    driver.write_pcm(&block).unwrap();
    assert!(driver.backend.writes.is_empty());
    assert!(matches!(
        driver.write_pcm(&block[..block.len() - 1]),
        Err(AlsaError::InvalidPayload { .. })
    ));
}

#[test]
fn disabled_directions_have_deterministic_errors() {
    let mut config = config();
    config.capture_enabled = false;
    let backend = SubstituteBackend::exact(&config);
    let mut driver = AlsaDriver::new(config, backend).unwrap();
    driver.start().unwrap();
    let mut output = Vec::new();
    assert!(matches!(
        driver.read_pcm_into(&mut output),
        Err(AlsaError::DirectionDisabled("capture"))
    ));
}
