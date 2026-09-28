//! Repeatable release-only localhost workload; all metrics are software evidence.
use rusty_lola::config::default_settings;
use rusty_lola::station::{run_session, SessionOptions};
use serde_json::json;
use std::alloc::{GlobalAlloc, Layout, System};
use std::sync::atomic::{AtomicU64, Ordering};
use std::time::Instant;

struct SessionAllocator;
static CALLS: AtomicU64 = AtomicU64::new(0);
static LIVE: AtomicU64 = AtomicU64::new(0);
static PEAK: AtomicU64 = AtomicU64::new(0);
// SAFETY: allocation and deallocation forward each original layout/pointer to
// System. Atomic bookkeeping does not allocate or change pointer ownership.
unsafe impl GlobalAlloc for SessionAllocator {
    unsafe fn alloc(&self, layout: Layout) -> *mut u8 {
        // SAFETY: forwarded allocator caller contract.
        let pointer = unsafe { System.alloc(layout) };
        if !pointer.is_null() {
            CALLS.fetch_add(1, Ordering::Relaxed);
            let current =
                LIVE.fetch_add(layout.size() as u64, Ordering::Relaxed) + layout.size() as u64;
            PEAK.fetch_max(current, Ordering::Relaxed);
        }
        pointer
    }
    unsafe fn dealloc(&self, pointer: *mut u8, layout: Layout) {
        LIVE.fetch_sub(layout.size() as u64, Ordering::Relaxed);
        // SAFETY: System allocated this pointer with the unchanged layout.
        unsafe { System.dealloc(pointer, layout) };
    }
}
#[global_allocator]
static ALLOCATOR: SessionAllocator = SessionAllocator;

#[cfg(unix)]
fn process_usage() -> Option<(f64, u64)> {
    let mut usage = std::mem::MaybeUninit::<libc::rusage>::uninit();
    // SAFETY: getrusage writes a complete rusage to valid uninitialized storage.
    if unsafe { libc::getrusage(libc::RUSAGE_SELF, usage.as_mut_ptr()) } != 0 {
        return None;
    }
    // SAFETY: the successful call initialized usage.
    let usage = unsafe { usage.assume_init() };
    let seconds = (usage.ru_utime.tv_sec + usage.ru_stime.tv_sec) as f64
        + (usage.ru_utime.tv_usec + usage.ru_stime.tv_usec) as f64 / 1_000_000.0;
    let rss = usage.ru_maxrss as u64 * if cfg!(target_os = "macos") { 1 } else { 1024 };
    Some((seconds, rss))
}
#[cfg(not(unix))]
fn process_usage() -> Option<(f64, u64)> {
    None
}

fn percentile(values: &mut [f64], fraction: f64) -> f64 {
    values.sort_by(f64::total_cmp);
    values[((values.len() as f64 * fraction).ceil() as usize).saturating_sub(1)]
}

#[test]
#[ignore = "manual repeated release-mode sustained localhost workload"]
fn sustained_sessions_report_scheduler_queue_cpu_allocations_and_memory() {
    if cfg!(debug_assertions) {
        panic!("run with --release");
    }
    let mut settings = default_settings();
    settings.video.width = 640;
    settings.video.height = 480;
    settings.video.bpp = 24;
    settings.video.bayer = 0;
    settings.video.fps = 30;
    settings.network.bind_ip = "127.0.0.1".into();
    let mut options = SessionOptions::demo();
    options.use_catalog_geometry = false;
    options.interleaved_av = true;
    options.duration_sec = Some(1.0);
    options.stream_frames = 1;
    for _ in 0..3 {
        assert!(run_session(settings.clone(), 2.0, options.clone()).ok);
    }
    let mut elapsed_samples = Vec::with_capacity(31);
    for repetition in 0..31 {
        let allocations = CALLS.load(Ordering::Relaxed);
        let memory = LIVE.load(Ordering::Relaxed);
        PEAK.store(memory, Ordering::Relaxed);
        let usage = process_usage();
        let started = Instant::now();
        let result = run_session(settings.clone(), 2.0, options.clone());
        let elapsed = started.elapsed().as_secs_f64();
        let after = process_usage();
        let calls = CALLS.load(Ordering::Relaxed) - allocations;
        let peak_delta = PEAK.load(Ordering::Relaxed).saturating_sub(memory);
        let retained = LIVE.load(Ordering::Relaxed).saturating_sub(memory);
        assert!(result.ok, "{}", result.error);
        assert!(result.audio_frames_sent > 0 && result.audio_frames_received > 0);
        assert!(result.video_frames_sent > 0 && result.video_frames_received > 0);
        elapsed_samples.push(elapsed * 1000.0);
        println!(
            "{}",
            json!({"workload":"sustained-localhost-640x480-capture-160x120-wire-rgb30-pcm44100-stereo64",
            "repetition":repetition,"elapsed_ms":elapsed*1000.0,
            "cpu_percent_one_core":usage.zip(after).map(|(before,after)|(after.0-before.0)/elapsed*100.0),
            "rss_high_water_bytes":after.map(|value|value.1),"allocation_calls":calls,
            "peak_live_delta_bytes":peak_delta,"retained_result_bytes":retained,
            "session":result.to_json(),"evidence":"synthetic localhost software workload"})
        );
    }
    println!(
        "{}",
        json!({"workload":"sustained-summary","samples":31,
        "median_ms":percentile(&mut elapsed_samples,0.5),"p95_ms":percentile(&mut elapsed_samples,0.95)})
    );
}
