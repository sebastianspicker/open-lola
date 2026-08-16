use image::GenericImageView;
use rusty_lola::audio::read_wav;
use rusty_lola::station::{DualStreamRecorder, RECENT_VIDEO_PATH_WINDOW};
use std::fs;
use tempfile::tempdir;

#[test]
fn dual_local_remote_layout() {
    let dir = tempdir().unwrap();
    let mut rec = DualStreamRecorder::new(dir.path(), 48_000, 2, 16);
    rec.write_audio("local", &[1, 0, 2, 0]);
    rec.write_audio("remote", &[3, 0, 4, 0]);
    rec.write_video_frame("local", &[9, 9], 1, 2);
    rec.write_video_frame("remote", &[8, 8], 1, 2);
    let result = rec.close();
    assert!(result
        .local_audio_path
        .as_ref()
        .unwrap()
        .to_string_lossy()
        .contains("_Local.wav"));
    assert!(result
        .remote_audio_path
        .as_ref()
        .unwrap()
        .to_string_lossy()
        .contains("_Remote.wav"));
    assert_eq!((result.local_frames, result.remote_frames), (1, 1));
    assert!(!result.all_paths().is_empty());
    assert!(result.local_video_paths[0].ends_with("frame_0001.jpg"));
    assert_eq!(
        image::open(&result.local_video_paths[0]).unwrap().width(),
        1
    );
}

#[test]
fn configured_video_formats_contain_decodable_images() {
    for format in ["png", "bmp"] {
        let dir = tempdir().unwrap();
        let mut recorder = DualStreamRecorder::with_options(
            dir.path(),
            44_100,
            2,
            16,
            "session",
            "video",
            false,
            false,
            true,
            false,
            format,
        );
        let path = recorder
            .write_video_frame("local", &[1, 2, 3, 4], 2, 2)
            .unwrap();
        assert_eq!(
            path.extension().and_then(|value| value.to_str()),
            Some(format)
        );
        assert_eq!(image::open(path).unwrap().dimensions(), (2, 2));
    }
}

#[test]
fn drop_finalizes_pending_audio_after_early_session_exit() {
    let dir = tempdir().unwrap();
    {
        let mut recorder = DualStreamRecorder::new(dir.path(), 44_100, 2, 16);
        recorder.write_audio("local", &[0; 8]);
    }
    let path = dir.path().join("session_Local.wav");
    assert!(path.is_file());
    assert_eq!(read_wav(path).unwrap().pcm.len(), 8);
}

#[test]
fn multiple_audio_writes_are_finalized_as_a_decodable_wav() {
    let dir = tempdir().unwrap();
    let mut recorder = DualStreamRecorder::new(dir.path(), 44_100, 2, 16);
    recorder.write_audio("local", &[1, 0, 2, 0]);
    let path = dir.path().join("session_Local.wav");
    assert!(path.is_file());
    recorder.write_audio("local", &[3, 0, 4, 0]);
    let finalized = recorder.close_checked();
    assert_eq!(
        finalized.result.local_audio_path.as_deref(),
        Some(path.as_path())
    );
    assert_eq!(read_wav(path).unwrap().pcm, vec![1, 0, 2, 0, 3, 0, 4, 0]);
}

#[test]
fn video_metadata_retains_only_the_recent_path_window() {
    let dir = tempdir().unwrap();
    let mut recorder = DualStreamRecorder::with_options(
        dir.path(),
        44_100,
        2,
        16,
        "session",
        "video",
        false,
        false,
        true,
        false,
        "raw",
    );
    let total = RECENT_VIDEO_PATH_WINDOW + 5;
    for i in 0..total {
        assert!(recorder
            .write_video_frame("local", &[i as u8], 1, 1)
            .is_some());
    }
    let result = recorder.close_checked().result;
    assert_eq!(result.local_frames as usize, total);
    assert_eq!(result.local_video_paths.len(), RECENT_VIDEO_PATH_WINDOW);
    assert_eq!(result.local_video_paths_omitted, 5);
    assert!(result.local_video_paths[0].ends_with("frame_0006.bin"));
    assert_eq!(
        fs::read_dir(dir.path().join("local")).unwrap().count(),
        total
    );
}

#[test]
fn checked_close_reports_stream_creation_failures() {
    let dir = tempdir().unwrap();
    let file = dir.path().join("not-a-directory");
    fs::write(&file, b"occupied").unwrap();
    let mut recorder = DualStreamRecorder::new(file, 44_100, 2, 16);
    recorder.write_audio("local", &[0; 8]);
    let finalized = recorder.close_checked();
    assert!(finalized
        .warnings
        .iter()
        .any(|warning| warning.contains("write local WAV")));
}
