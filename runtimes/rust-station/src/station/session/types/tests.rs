use super::*;
use crate::test_alloc::{measure_allocations, samples, timing_json};

#[test]
fn preview_generation_reuses_shared_pixels_and_public_boundary_owns_bytes() {
    let control = SessionRuntimeControl::default();
    control.publish_video(2, 1, &[1, 2, 3, 4, 5, 6], "RGB24");
    let VideoPreviewUpdate::Changed(first) = control.latest_video_update(None) else {
        panic!("first preview must be new");
    };
    let VideoPreviewUpdate::Changed(second) = control.latest_video_update(None) else {
        panic!("unversioned caller must receive the frame");
    };
    assert!(Arc::ptr_eq(&first.rgb, &second.rgb));
    assert!(matches!(
        control.latest_video_update(Some(first.generation)),
        VideoPreviewUpdate::Unchanged
    ));

    let mut owned = control.latest_video().expect("public preview");
    assert_eq!(owned.rgb, [1, 2, 3, 4, 5, 6]);
    owned.rgb[0] = 99;
    assert_eq!(
        control.latest_video().expect("fresh owned preview").rgb[0],
        1
    );
}

#[test]
fn grayscale_publish_expands_exactly_and_invalid_input_does_not_advance() {
    let control = SessionRuntimeControl::default();
    assert!(matches!(
        control.latest_video_update(None),
        VideoPreviewUpdate::Empty
    ));
    control.publish_video(2, 1, &[7], "Mono8");
    assert!(matches!(
        control.latest_video_update(None),
        VideoPreviewUpdate::Empty
    ));
    control.publish_video(2, 1, &[7, 8], "Mono8");
    let VideoPreviewUpdate::Changed(frame) = control.latest_video_update(None) else {
        panic!("valid grayscale preview");
    };
    assert_eq!(&*frame.rgb, &[7, 7, 7, 8, 8, 8]);
}

#[test]
fn preview_generation_is_unique_across_session_controls() {
    let first = SessionRuntimeControl::default();
    first.publish_video(1, 1, &[1, 2, 3], "RGB24");
    let VideoPreviewUpdate::Changed(first_frame) = first.latest_video_update(None) else {
        panic!("first session frame");
    };
    let second = SessionRuntimeControl::default();
    second.publish_video(1, 1, &[4, 5, 6], "RGB24");
    assert!(matches!(
        second.latest_video_update(Some(first_frame.generation)),
        VideoPreviewUpdate::Changed(_)
    ));
}

#[test]
#[ignore = "manual release-mode preview generation benchmark"]
fn preview_generation_benchmark() {
    const OPERATIONS: u64 = 8_192;
    let output_path = std::env::var("RUSTY_LOLA_PREVIEW_BENCHMARK_OUTPUT")
        .expect("set an external benchmark output path");
    let control = SessionRuntimeControl::default();
    let pixels = vec![0x5a; 128 * 72 * 3];
    control.publish_video(128, 72, &pixels, "RGB24");
    let VideoPreviewUpdate::Changed(frame) = control.latest_video_update(None) else {
        panic!("published frame");
    };
    let mut unchanged = || {
        let mut unchanged = 0_u64;
        for _ in 0..OPERATIONS {
            if matches!(
                control.latest_video_update(Some(frame.generation)),
                VideoPreviewUpdate::Unchanged
            ) {
                unchanged += 1;
            }
        }
        (OPERATIONS, unchanged, frame.rgb.len() as u64)
    };
    let mut first_touch = || {
        let mut shared_bytes = 0_u64;
        let mut generation_sum = 0_u64;
        for _ in 0..OPERATIONS {
            let VideoPreviewUpdate::Changed(current) = control.latest_video_update(None) else {
                panic!("unversioned poll receives shared frame");
            };
            shared_bytes += current.rgb.len() as u64;
            generation_sum = generation_sum.wrapping_add(current.generation);
        }
        (OPERATIONS, shared_bytes, generation_sum)
    };
    let mut owned_snapshot_oracle = || {
        let mut copied_bytes = 0_u64;
        let mut checksum = 0_u64;
        for _ in 0..OPERATIONS {
            let first_copy = control.latest_video().expect("first owned snapshot copy");
            let second_copy = first_copy.clone();
            copied_bytes += (first_copy.rgb.len() + second_copy.rgb.len()) as u64;
            checksum = checksum.wrapping_add(u64::from(second_copy.rgb[0]));
        }
        (OPERATIONS, copied_bytes, checksum)
    };
    let row = |name: &str,
               run: &mut dyn FnMut() -> (u64, u64, u64),
               expected_calls: u64,
               expected_bytes: u64| {
        let (elapsed, work) = samples(&mut *run);
        let (measured_work, memory) = measure_allocations(&mut *run);
        assert_eq!(measured_work, work);
        assert_eq!(memory.calls, expected_calls);
        assert_eq!(memory.bytes, expected_bytes);
        serde_json::json!({
            "workload": name,
            "timing": timing_json(elapsed),
            "memory": {"allocation_calls": memory.calls, "allocated_bytes": memory.bytes},
            "work": {"operations": work.0, "bytes_or_count": work.1, "checksum": work.2},
        })
    };
    let pixel_bytes = pixels.len() as u64;
    let report = serde_json::json!({
        "rows": [
            row("unchanged_preview_generation_poll", &mut unchanged, 0, 0),
            row("changed_preview_generation_poll", &mut first_touch, 0, 0),
            row(
                "old_owned_snapshot_clone_oracle",
                &mut owned_snapshot_oracle,
                OPERATIONS * 2,
                OPERATIONS * pixel_bytes * 2,
            ),
        ],
    });
    std::fs::write(
        output_path,
        serde_json::to_vec_pretty(&report).expect("serialize benchmark"),
    )
    .expect("write benchmark output");
}
