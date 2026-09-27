use super::*;
#[test]
fn finalization_drains_audio_and_reports_admission_failures() {
    let record_root = tempfile::tempdir().unwrap();
    let preview_root = tempfile::tempdir().unwrap();
    let mut recorder = SessionRecorder::with_options(
        Some(record_root.path().to_path_buf()),
        Some(preview_root.path().to_path_buf()),
        44100,
        2,
        16,
        "test",
        "audio",
        true,
        false,
        false,
        false,
        "jpg",
    );
    recorder.write_audio("local", &[1; 256]);
    recorder.write_preview_frame(0, &[7; 64]);
    recorder.write_audio("local", &[2; 1026]);
    let result = recorder.close_checked();
    assert_eq!(result.result.local_audio_bytes, 256);
    assert!(result
        .result
        .local_audio_path
        .unwrap()
        .starts_with(record_root.path()));
    assert_eq!(result.preview_paths.len(), 1);
    assert!(result.preview_paths[0].starts_with(preview_root.path()));
    assert_eq!(std::fs::read(&result.preview_paths[0]).unwrap(), [7; 64]);
    assert!(result
        .warnings
        .iter()
        .any(|warning| warning.contains("1 media blocks")));
}
#[test]
fn full_queue_refuses_video_before_materializing_payload() {
    let (sender, _receiver) = mpsc::sync_channel(QUEUE_CAPACITY);
    let mut recorder = SessionRecorder {
        sender: Some(sender),
        worker: None,
        dropped: 0,
        startup_error: None,
        pending: Arc::new(AtomicUsize::new(QUEUE_CAPACITY)),
        cancelled: Arc::new(AtomicBool::new(false)),
        admission: RecordAdmission {
            local_audio: false,
            remote_audio: false,
            local_video: true,
            remote_video: false,
            previews: false,
        },
    };
    let pixels = vec![0; MAX_VIDEO_BYTES];
    for _ in 0..100 {
        recorder.write_video_frame("local", &pixels, 1, 1);
    }
    assert_eq!(recorder.dropped, 100);
    assert_eq!(recorder.pending.load(Ordering::Acquire), QUEUE_CAPACITY);
    assert!(_receiver.try_recv().is_err());
}

#[test]
fn preview_only_admits_only_preview_jobs() {
    let (sender, receiver) = mpsc::sync_channel(QUEUE_CAPACITY);
    let mut recorder = SessionRecorder {
        sender: Some(sender),
        worker: None,
        dropped: 0,
        startup_error: None,
        pending: Arc::new(AtomicUsize::new(0)),
        cancelled: Arc::new(AtomicBool::new(false)),
        admission: RecordAdmission::new("none", true, true, true, true, true),
    };
    recorder.write_audio("local", &[1; 8]);
    recorder.write_video_frame("remote", &[2; 8], 1, 1);
    recorder.write_preview_frame(0, &[3; 8]);
    assert!(matches!(
        receiver.try_recv().unwrap().payload,
        RecordPayload::Preview { .. }
    ));
    assert!(receiver.try_recv().is_err());
    assert_eq!(recorder.dropped, 0);
}

#[test]
fn stalled_worker_does_not_make_finalization_unbounded() {
    let cancelled = Arc::new(AtomicBool::new(false));
    let stop = cancelled.clone();
    let worker = std::thread::spawn(move || {
        while !stop.load(Ordering::Acquire) {
            std::thread::sleep(Duration::from_millis(1));
        }
        DualRecordFinalize::default()
    });
    let mut recorder = SessionRecorder {
        sender: None,
        worker: Some(worker),
        dropped: 0,
        startup_error: None,
        pending: Arc::new(AtomicUsize::new(0)),
        cancelled,
        admission: RecordAdmission {
            local_audio: false,
            remote_audio: false,
            local_video: false,
            remote_video: false,
            previews: false,
        },
    };
    let started = Instant::now();
    let result = recorder.finish();
    assert!(started.elapsed() < Duration::from_secs(2));
    assert!(result.warnings.iter().any(|value| value.contains("500 ms")));
}

#[test]
fn repeated_preview_failures_produce_one_bounded_warning() {
    let directory = tempfile::tempdir().unwrap();
    let path = directory.path().join("preview_0000.raw");
    std::fs::write(&path, b"occupied").unwrap();
    let mut output = PreviewOutput::new(directory.path().to_path_buf());
    for _ in 0..100 {
        output.write("preview_0000.raw", &[1; 16]);
    }
    assert!(output.failed);
    assert!(output.paths.is_empty());
    assert!(output.warning.is_some());
    assert_eq!(std::fs::read(path).unwrap(), b"occupied");
}

#[cfg(unix)]
#[test]
fn preview_output_does_not_follow_symlinks() {
    let directory = tempfile::tempdir().unwrap();
    let victim = directory.path().join("victim");
    std::fs::write(&victim, b"unchanged").unwrap();
    let preview = directory.path().join("preview_0000.raw");
    std::os::unix::fs::symlink(&victim, &preview).unwrap();
    assert!(write_preview_file(&preview, b"replacement").is_err());
    assert_eq!(std::fs::read(victim).unwrap(), b"unchanged");
}
