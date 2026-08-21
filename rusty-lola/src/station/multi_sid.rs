//! Multi-SID session profiles and sequential/concurrent software session runners.

use crate::config::{
    StationSettings, DEFAULT_AUDIO_PORT, DEFAULT_CONTROL_PORT, DEFAULT_VIDEO_PORT,
};
use crate::station::profile::{
    load_session_profile, profile_to_settings, save_session_profile, SessionProfile,
};
use crate::station::runtime::{SessionConfig, SessionHandle, SessionRuntime, SessionSnapshot};
use crate::station::session::{run_session, SessionOptions, SessionResult};
use crate::station::sync::lock_unpoison;
use crate::station::SessionError;
use serde_json::{json, Value};
use std::collections::BTreeSet;
use std::path::{Path, PathBuf};
use std::sync::{Arc, Mutex};
use std::thread;

/// The protocol SID used to select one independently owned persistent session.
pub type SID = i64;

const MAX_CONCURRENT_SIDS: usize = 3;

struct ManagedSidSession {
    runtime: SessionRuntime,
    handle: SessionHandle,
}

/// Owns up to three independently controlled persistent station sessions.
///
/// A runtime is deliberately allocated for every SID instead of sharing a
/// worker or `SessionRuntimeControl`; cancelling or queuing a control for one
/// SID therefore cannot affect another SID.
#[derive(Default)]
pub struct MultiSidRuntime {
    sessions: std::collections::BTreeMap<SID, ManagedSidSession>,
}

impl MultiSidRuntime {
    pub fn new() -> Self {
        Self::default()
    }

    /// Validate and start one persistent runtime for every supplied SID.
    ///
    /// The batch is preflighted before the first worker starts. If creating a
    /// later worker fails, all workers already created for this batch are
    /// cancelled and joined, and this owner remains empty.
    pub fn start<I>(&mut self, configs: I) -> Result<(), SessionError>
    where
        I: IntoIterator<Item = SessionConfig>,
    {
        if !self.sessions.is_empty() {
            return Err(SessionError::AlreadyActive);
        }

        let mut configs = configs.into_iter().collect::<Vec<_>>();
        validate_runtime_configs(&configs)?;

        let mut started = std::collections::BTreeMap::new();
        for mut config in configs.drain(..) {
            let sid = config.settings.network.session_id;
            // Loopback allocates per-session ephemeral peer and client ports.
            // A global serialisation lock would turn this owner into a queue,
            // rather than independent persistent runtimes.
            if config.options.peer_mode.eq_ignore_ascii_case("loopback") {
                config.options.serialize_loopback = false;
            }
            let runtime = SessionRuntime::new();
            match runtime.start(config) {
                Ok(handle) => {
                    started.insert(sid, ManagedSidSession { runtime, handle });
                }
                Err(error) => {
                    stop_and_wait(&started);
                    return Err(error);
                }
            }
        }
        self.sessions = started;
        Ok(())
    }

    pub fn session_ids(&self) -> Vec<SID> {
        self.sessions.keys().copied().collect()
    }

    /// Return one immutable runtime snapshot for a SID.
    pub fn snapshot(&self, sid: SID) -> Result<SessionSnapshot, SessionError> {
        self.sessions
            .get(&sid)
            .map(|session| session.runtime.snapshot())
            .ok_or(SessionError::NotActive)
    }

    /// Return immutable snapshots for all owned SIDs, ordered by SID.
    pub fn snapshots(&self) -> std::collections::BTreeMap<SID, SessionSnapshot> {
        self.sessions
            .iter()
            .map(|(&sid, session)| (sid, session.runtime.snapshot()))
            .collect()
    }

    /// Queue a control only for the selected SID.
    pub fn send_control(&self, sid: SID, message: impl Into<String>) -> Result<(), SessionError> {
        self.sessions
            .get(&sid)
            .ok_or(SessionError::NotActive)?
            .handle
            .send_control(message)
    }

    /// Request shutdown for one SID without changing any other session.
    pub fn stop(&self, sid: SID) -> Result<SessionSnapshot, SessionError> {
        self.sessions
            .get(&sid)
            .map(|session| session.handle.stop())
            .ok_or(SessionError::NotActive)
    }

    /// Request shutdown for every owned SID. Repeated calls are harmless.
    pub fn stop_all(&self) -> std::collections::BTreeMap<SID, SessionSnapshot> {
        self.sessions
            .iter()
            .map(|(&sid, session)| (sid, session.handle.stop()))
            .collect()
    }

    /// Join every worker and return one terminal snapshot per SID.
    pub fn wait_all(&self) -> std::collections::BTreeMap<SID, SessionSnapshot> {
        self.sessions
            .iter()
            .map(|(&sid, session)| (sid, session.handle.wait()))
            .collect()
    }
}

fn validate_runtime_configs(configs: &[SessionConfig]) -> Result<(), SessionError> {
    if configs.is_empty() {
        return Err(SessionError::Configuration(
            "at least one SID configuration is required".into(),
        ));
    }
    if configs.len() > MAX_CONCURRENT_SIDS {
        return Err(SessionError::Configuration(format!(
            "max {MAX_CONCURRENT_SIDS} concurrent SIDs"
        )));
    }

    let mut sids = BTreeSet::new();
    let mut bindings = BTreeSet::new();
    for config in configs {
        config
            .settings
            .validate()
            .map_err(|error| SessionError::Configuration(error.to_string()))?;
        if !config.timeout_secs.is_finite() || config.timeout_secs <= 0.0 {
            return Err(SessionError::Configuration(
                "timeout_secs must be finite and greater than zero".into(),
            ));
        }

        let sid = config.settings.network.session_id;
        if !sids.insert(sid) {
            return Err(SessionError::Configuration(format!(
                "SID {sid} appears more than once"
            )));
        }
        let binding = (
            config.settings.network.bind_ip.clone(),
            config.settings.network.control_port,
            config.settings.network.audio_port,
            config.settings.network.video_port,
        );
        if !bindings.insert(binding.clone()) {
            return Err(SessionError::Configuration(format!(
                "SID {sid} collides on {} control={} audio={} video={}",
                binding.0, binding.1, binding.2, binding.3
            )));
        }
    }
    Ok(())
}

fn stop_and_wait(sessions: &std::collections::BTreeMap<SID, ManagedSidSession>) {
    for session in sessions.values() {
        session.handle.stop();
    }
    for session in sessions.values() {
        session.handle.wait();
    }
}

/// Build one SessionProfile per SID.
pub fn create_sid_profiles(
    session_ids: &[i64],
    remote_ip: &str,
    local_ip: &str,
    camera_mode_id: &str,
) -> Result<Vec<SessionProfile>, String> {
    if session_ids.is_empty() {
        return Err("session_ids must contain at least one SID".into());
    }
    let mut seen = std::collections::BTreeSet::new();
    for &sid in session_ids {
        if !seen.insert(sid) {
            return Err(format!("session_ids must be unique, got {session_ids:?}"));
        }
    }
    let mut profiles = Vec::new();
    for &sid in session_ids {
        let p = SessionProfile {
            remote_ip: remote_ip.into(),
            local_ip: local_ip.into(),
            control_port: DEFAULT_CONTROL_PORT,
            audio_port: DEFAULT_AUDIO_PORT,
            video_port: DEFAULT_VIDEO_PORT,
            session_id: sid,
            camera_mode_id: camera_mode_id.into(),
            ..SessionProfile::default()
        };
        profiles.push(p);
    }
    Ok(profiles)
}

pub fn save_sid_profiles(
    directory: impl AsRef<Path>,
    profiles: &[SessionProfile],
) -> Result<Vec<PathBuf>, String> {
    let root = directory.as_ref();
    std::fs::create_dir_all(root).map_err(|e| e.to_string())?;
    let mut paths = Vec::new();
    for profile in profiles {
        let name = format!("sid_{}.session.json", profile.session_id);
        let path = save_session_profile(root.join(name), profile).map_err(|e| e.to_string())?;
        paths.push(path);
    }
    Ok(paths)
}

pub fn load_sid_profiles(directory: impl AsRef<Path>) -> Result<Vec<SessionProfile>, String> {
    let root = directory.as_ref();
    if !root.is_dir() {
        return Err(format!("not a directory: {}", root.display()));
    }
    let mut profiles = Vec::new();
    let rd = std::fs::read_dir(root).map_err(|e| e.to_string())?;
    for ent in rd.flatten() {
        let path = ent.path();
        let name = path.file_name().and_then(|s| s.to_str()).unwrap_or("");
        if name.starts_with("sid_") && name.ends_with(".session.json") {
            profiles.push(load_session_profile(&path).map_err(|e| e.to_string())?);
        }
    }
    profiles.sort_by_key(|p| p.session_id);
    Ok(profiles)
}

#[derive(Debug, Clone, Default)]
pub struct MultiSidRunResult {
    pub session_ids: Vec<i64>,
    pub results: Vec<SessionResult>,
    pub ok: bool,
    pub error: String,
}

impl MultiSidRunResult {
    pub fn result_for(&self, session_id: i64) -> Option<&SessionResult> {
        self.session_ids
            .iter()
            .zip(self.results.iter())
            .find(|(sid, _)| **sid == session_id)
            .map(|(_, r)| r)
    }

    pub fn to_json(&self) -> Value {
        json!({
            "ok": self.ok,
            "error": self.error,
            "session_ids": self.session_ids,
            "results": self.results.iter().map(|r| r.to_json()).collect::<Vec<_>>(),
        })
    }
}

/// Run run_session once per profile, in order.
pub fn run_sequential_sessions(
    profiles: &[SessionProfile],
    timeout: f64,
    options: Option<SessionOptions>,
) -> Result<MultiSidRunResult, String> {
    if profiles.is_empty() {
        return Err("profiles must contain at least one SessionProfile".into());
    }
    let mut aggregate = MultiSidRunResult::default();
    let mut opts = options.unwrap_or_else(|| {
        let mut o = SessionOptions::demo();
        o.control_extras = false;
        o.use_catalog_geometry = false;
        o
    });
    opts.serialize_loopback = true;

    let mut all_ok = true;
    for profile in profiles {
        let settings = profile_to_settings(profile);
        let result = run_session(settings, timeout, opts.clone());
        aggregate.session_ids.push(profile.session_id);
        if !result.ok {
            all_ok = false;
            aggregate.error = format!(
                "SID {} failed: {}",
                profile.session_id,
                if result.error.is_empty() {
                    "unknown"
                } else {
                    &result.error
                }
            );
        }
        aggregate.results.push(result);
    }
    aggregate.ok = all_ok;
    Ok(aggregate)
}

/// Run up to 3 concurrent sessions (closed 2.0 style).
pub fn run_concurrent_sessions(
    profiles: &[SessionProfile],
    timeout: f64,
    options: Option<SessionOptions>,
) -> Result<MultiSidRunResult, String> {
    if profiles.is_empty() {
        return Err("profiles must contain at least one SessionProfile".into());
    }
    if profiles.len() > 3 {
        return Err("max 3 concurrent SIDs".into());
    }
    let base_opts = options.unwrap_or_else(|| {
        let mut o = SessionOptions::demo();
        o.control_extras = false;
        o.use_catalog_geometry = false;
        o
    });
    validate_concurrent_bindings(profiles, &base_opts)?;

    let results: Arc<Mutex<Vec<(usize, i64, SessionResult)>>> = Arc::new(Mutex::new(Vec::new()));
    let mut handles = Vec::new();

    for (idx, profile) in profiles.iter().enumerate() {
        let settings = profile_to_settings(profile);
        let sid = profile.session_id;
        let mut opts = base_opts.clone();
        // Allow true concurrency: each session uses ephemeral peer ports
        opts.serialize_loopback = false;
        let results = results.clone();
        handles.push(thread::spawn(move || {
            let result = run_session(settings, timeout, opts);
            lock_unpoison(&results).push((idx, sid, result));
        }));
    }
    for h in handles {
        let _ = h.join();
    }

    let mut pairs = lock_unpoison(&results).clone();
    pairs.sort_by_key(|(idx, _, _)| *idx);

    let mut aggregate = MultiSidRunResult::default();
    let mut all_ok = true;
    for (_, sid, result) in pairs {
        aggregate.session_ids.push(sid);
        if !result.ok {
            all_ok = false;
            if aggregate.error.is_empty() {
                aggregate.error = format!(
                    "SID {sid} failed: {}",
                    if result.error.is_empty() {
                        "unknown"
                    } else {
                        &result.error
                    }
                );
            }
        }
        aggregate.results.push(result);
    }
    aggregate.ok = all_ok;
    Ok(aggregate)
}

fn validate_concurrent_bindings(
    profiles: &[SessionProfile],
    options: &SessionOptions,
) -> Result<(), String> {
    if options.peer_mode.eq_ignore_ascii_case("loopback") {
        return Ok(());
    }
    let mut bindings = BTreeSet::new();
    for profile in profiles {
        let binding = (
            profile.bind_ip.clone(),
            profile.control_port,
            profile.audio_port,
            profile.video_port,
        );
        if !bindings.insert(binding.clone()) {
            return Err(format!(
                "concurrent SID profiles collide on {} control={} audio={} video={}; assign a distinct local bind address or port tuple",
                binding.0, binding.1, binding.2, binding.3
            ));
        }
    }
    Ok(())
}

/// CLI helper: parse "1,2" SIDs and run sequential or concurrent.
pub fn run_multi_sid(
    sids: &[i64],
    remote: &str,
    timeout: f64,
    frames: u32,
    concurrent: bool,
) -> Result<MultiSidRunResult, String> {
    let profiles = create_sid_profiles(sids, remote, "127.0.0.1", "009")?;
    let mut opts = SessionOptions::demo();
    opts.stream_frames = frames.max(1);
    opts.control_extras = false;
    opts.use_catalog_geometry = true;
    if concurrent {
        run_concurrent_sessions(&profiles, timeout, Some(opts))
    } else {
        run_sequential_sessions(&profiles, timeout, Some(opts))
    }
}

/// Map profile onto settings (re-export convenience).
pub fn settings_from_profile(profile: &SessionProfile) -> StationSettings {
    profile_to_settings(profile)
}
