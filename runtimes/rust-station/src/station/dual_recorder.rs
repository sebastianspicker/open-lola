//! Dual local/remote stream recorder (`_Local` / `_Remote` file suffixes).

use crate::audio::WavStreamWriter;
use crate::video::{decode_jpeg, encode_frame_jpeg};
use image::{ColorType, ImageFormat};
use serde_json::{json, Value};
use std::collections::VecDeque;
use std::fs;
use std::io::Write;
use std::path::{Path, PathBuf};

#[derive(Debug, Clone, Default)]
pub struct DualRecordResult {
    pub local_audio_path: Option<PathBuf>,
    pub remote_audio_path: Option<PathBuf>,
    pub local_video_paths: Vec<PathBuf>,
    pub remote_video_paths: Vec<PathBuf>,
    pub local_frames: u32,
    pub remote_frames: u32,
    pub local_audio_bytes: usize,
    pub remote_audio_bytes: usize,
    pub local_video_paths_omitted: u32,
    pub remote_video_paths_omitted: u32,
}

#[derive(Debug, Clone, Default)]
pub struct DualRecordFinalize {
    pub result: DualRecordResult,
    /// Preview files that were successfully completed by the recording worker.
    pub preview_paths: Vec<PathBuf>,
    pub warnings: Vec<String>,
}

impl DualRecordResult {
    pub fn to_json(&self) -> Value {
        json!({
            "local_audio_path": self.local_audio_path.as_ref().map(|p| p.display().to_string()),
            "remote_audio_path": self.remote_audio_path.as_ref().map(|p| p.display().to_string()),
            "local_video_paths": self.local_video_paths.iter().map(|p| p.display().to_string()).collect::<Vec<_>>(),
            "remote_video_paths": self.remote_video_paths.iter().map(|p| p.display().to_string()).collect::<Vec<_>>(),
            "local_frames": self.local_frames,
            "remote_frames": self.remote_frames,
            "local_audio_bytes": self.local_audio_bytes,
            "remote_audio_bytes": self.remote_audio_bytes,
            "local_video_paths_omitted": self.local_video_paths_omitted,
            "remote_video_paths_omitted": self.remote_video_paths_omitted,
        })
    }

    pub fn all_paths(&self) -> Vec<String> {
        let mut out = Vec::new();
        if let Some(p) = &self.local_audio_path {
            out.push(p.display().to_string());
        }
        if let Some(p) = &self.remote_audio_path {
            out.push(p.display().to_string());
        }
        for p in &self.local_video_paths {
            out.push(p.display().to_string());
        }
        for p in &self.remote_video_paths {
            out.push(p.display().to_string());
        }
        out
    }
}

/// Number of newest video paths retained in each finalize result.
pub const RECENT_VIDEO_PATH_WINDOW: usize = 128;

struct AudioOutput {
    path: PathBuf,
    writer: Option<WavStreamWriter>,
    written_bytes: usize,
    failed: bool,
    finalization_attempted: bool,
    finalized: bool,
}

impl AudioOutput {
    fn new(path: PathBuf) -> Self {
        Self {
            path,
            writer: None,
            written_bytes: 0,
            failed: false,
            finalization_attempted: false,
            finalized: false,
        }
    }

    fn append(
        &mut self,
        pcm: &[u8],
        channels: u16,
        sample_rate: u32,
        bits_per_sample: u16,
    ) -> Result<(), crate::audio::WavError> {
        if self.failed {
            return Ok(());
        }
        let outcome = self.append_once(pcm, channels, sample_rate, bits_per_sample);
        self.failed = outcome.is_err();
        outcome
    }
    fn append_once(
        &mut self,
        pcm: &[u8],
        channels: u16,
        sample_rate: u32,
        bits_per_sample: u16,
    ) -> Result<(), crate::audio::WavError> {
        if self.writer.is_none() {
            self.writer = Some(WavStreamWriter::create(
                &self.path,
                channels,
                sample_rate,
                bits_per_sample,
            )?);
        }
        let result = self
            .writer
            .as_mut()
            .expect("writer was created")
            .append(pcm);
        self.written_bytes = self
            .writer
            .as_ref()
            .expect("writer was created")
            .data_len()
            .min(usize::MAX as u64) as usize;
        result
    }

    fn bytes(&self) -> usize {
        self.written_bytes
    }

    fn finalize(&mut self) -> Result<Option<PathBuf>, crate::audio::WavError> {
        if self.finalization_attempted {
            return Ok(self.finalized.then(|| self.path.clone()));
        }
        let Some(writer) = self.writer.take() else {
            return Ok(None);
        };
        self.finalization_attempted = true;
        writer.finish()?;
        self.finalized = true;
        Ok(Some(self.path.clone()))
    }
}

/// Record local and remote streams to `_Local` / `_Remote` files.
pub struct DualStreamRecorder {
    out_dir: PathBuf,
    sample_rate: u32,
    channels: u16,
    bits_per_sample: u16,
    record_audio: bool,
    record_video: bool,
    record_local_video: bool,
    record_remote_video: bool,
    video_format: String,
    local_audio: Option<AudioOutput>,
    remote_audio: Option<AudioOutput>,
    local_video: VecDeque<PathBuf>,
    remote_video: VecDeque<PathBuf>,
    local_video_paths_omitted: u32,
    remote_video_paths_omitted: u32,
    local_i: u32,
    remote_i: u32,
    closed: bool,
    warnings: Vec<String>,
}

impl DualStreamRecorder {
    pub fn new(
        out_dir: impl AsRef<Path>,
        sample_rate: u32,
        channels: u16,
        bits_per_sample: u16,
    ) -> Self {
        Self::with_options(
            out_dir,
            sample_rate,
            channels,
            bits_per_sample,
            "session",
            "av",
            true,
            true,
            true,
            true,
            "jpg",
        )
    }

    #[allow(clippy::too_many_arguments)]
    pub fn with_options(
        out_dir: impl AsRef<Path>,
        sample_rate: u32,
        channels: u16,
        bits_per_sample: u16,
        stem: &str,
        mode: &str,
        record_local_audio: bool,
        record_remote_audio: bool,
        record_local_video: bool,
        record_remote_video: bool,
        video_format: &str,
    ) -> Self {
        let out_dir = out_dir.as_ref().to_path_buf();
        let mut warnings = Vec::new();
        if let Err(error) = fs::create_dir_all(&out_dir) {
            warnings.push(format!(
                "create recording directory {}: {error}",
                out_dir.display()
            ));
        }
        let mode_l = mode.to_ascii_lowercase();
        let record_audio = mode_l == "av" || mode_l == "audio";
        let record_video = mode_l == "av" || mode_l == "video";
        if record_video {
            for path in [out_dir.join("local"), out_dir.join("remote")] {
                if let Err(error) = fs::create_dir_all(&path) {
                    warnings.push(format!(
                        "create recording directory {}: {error}",
                        path.display()
                    ));
                }
            }
        }
        let stem = if stem.is_empty() { "session" } else { stem };
        let local_audio = (record_audio && record_local_audio)
            .then(|| AudioOutput::new(out_dir.join(format!("{stem}_Local.wav"))));
        let remote_audio = (record_audio && record_remote_audio)
            .then(|| AudioOutput::new(out_dir.join(format!("{stem}_Remote.wav"))));
        Self {
            out_dir,
            sample_rate,
            channels,
            bits_per_sample,
            record_audio,
            record_video,
            record_local_video,
            record_remote_video,
            video_format: video_format.to_ascii_lowercase(),
            local_audio,
            remote_audio,
            local_video: VecDeque::with_capacity(RECENT_VIDEO_PATH_WINDOW),
            remote_video: VecDeque::with_capacity(RECENT_VIDEO_PATH_WINDOW),
            local_video_paths_omitted: 0,
            remote_video_paths_omitted: 0,
            local_i: 0,
            remote_i: 0,
            closed: false,
            warnings,
        }
    }

    pub fn write_audio(&mut self, side: &str, pcm: &[u8]) {
        if self.closed || !self.record_audio || pcm.is_empty() {
            return;
        }
        if side.eq_ignore_ascii_case("remote") {
            if let Some(output) = self.remote_audio.as_mut() {
                if let Err(error) =
                    output.append(pcm, self.channels, self.sample_rate, self.bits_per_sample)
                {
                    self.warnings.push(format!(
                        "write remote WAV {}: {error}",
                        output.path.display()
                    ));
                }
            }
        } else if let Some(output) = self.local_audio.as_mut() {
            if let Err(error) =
                output.append(pcm, self.channels, self.sample_rate, self.bits_per_sample)
            {
                self.warnings.push(format!(
                    "write local WAV {}: {error}",
                    output.path.display()
                ));
            }
        }
    }

    pub fn write_video_frame(
        &mut self,
        side: &str,
        pixels: &[u8],
        width: u32,
        height: u32,
    ) -> Option<PathBuf> {
        if self.closed || !self.record_video || pixels.is_empty() {
            return None;
        }
        let remote = side.eq_ignore_ascii_case("remote");
        if remote && !self.record_remote_video {
            return None;
        }
        if !remote && !self.record_local_video {
            return None;
        }
        let (subdir, idx) = if remote {
            self.remote_i += 1;
            ("remote", self.remote_i)
        } else {
            self.local_i += 1;
            ("local", self.local_i)
        };
        let extension = match self.video_format.as_str() {
            "raw" | "bin" => "bin",
            "png" => "png",
            "bmp" => "bmp",
            _ => "jpg",
        };
        let path = self
            .out_dir
            .join(subdir)
            .join(format!("frame_{idx:04}.{extension}"));
        match write_video_file(&path, pixels, width, height, extension) {
            Ok(()) => {
                if remote {
                    retain_recent_path(
                        &mut self.remote_video,
                        &mut self.remote_video_paths_omitted,
                        path.clone(),
                    );
                } else {
                    retain_recent_path(
                        &mut self.local_video,
                        &mut self.local_video_paths_omitted,
                        path.clone(),
                    );
                }
                Some(path)
            }
            Err(error) => {
                if remote {
                    self.record_remote_video = false;
                } else {
                    self.record_local_video = false;
                }
                self.warnings
                    .push(format!("write video frame {}: {error}", path.display()));
                None
            }
        }
    }

    pub fn close(mut self) -> DualRecordResult {
        self.finalize_checked().result
    }

    pub fn close_checked(mut self) -> DualRecordFinalize {
        self.finalize_checked()
    }

    fn finalize_checked(&mut self) -> DualRecordFinalize {
        self.closed = true;
        let mut result = DualRecordResult {
            local_frames: self.local_i,
            remote_frames: self.remote_i,
            local_audio_bytes: self.local_audio.as_ref().map_or(0, AudioOutput::bytes),
            remote_audio_bytes: self.remote_audio.as_ref().map_or(0, AudioOutput::bytes),
            local_video_paths: self.local_video.iter().cloned().collect(),
            remote_video_paths: self.remote_video.iter().cloned().collect(),
            local_video_paths_omitted: self.local_video_paths_omitted,
            remote_video_paths_omitted: self.remote_video_paths_omitted,
            ..Default::default()
        };
        finalize_audio_output(
            self.local_audio.as_mut(),
            "local",
            &mut result.local_audio_path,
            &mut self.warnings,
        );
        finalize_audio_output(
            self.remote_audio.as_mut(),
            "remote",
            &mut result.remote_audio_path,
            &mut self.warnings,
        );
        DualRecordFinalize {
            result,
            preview_paths: Vec::new(),
            warnings: self.warnings.clone(),
        }
    }
}

fn retain_recent_path(paths: &mut VecDeque<PathBuf>, omitted: &mut u32, path: PathBuf) {
    if paths.len() == RECENT_VIDEO_PATH_WINDOW {
        paths.pop_front();
        *omitted = omitted.saturating_add(1);
    }
    paths.push_back(path);
}

fn finalize_audio_output(
    output: Option<&mut AudioOutput>,
    side: &str,
    destination: &mut Option<PathBuf>,
    warnings: &mut Vec<String>,
) {
    let Some(output) = output else {
        return;
    };
    match output.finalize() {
        Ok(path) => *destination = path,
        Err(error) => warnings.push(format!(
            "finalize {side} WAV {}: {error}",
            output.path.display()
        )),
    }
}

impl Drop for DualStreamRecorder {
    fn drop(&mut self) {
        if !self.closed {
            let _ = self.finalize_checked();
        }
    }
}

fn write_video_file(
    path: &Path,
    pixels: &[u8],
    width: u32,
    height: u32,
    extension: &str,
) -> Result<(), String> {
    let mut file = fs::File::create_new(path).map_err(|error| error.to_string())?;
    if extension == "bin" {
        return file.write_all(pixels).map_err(|error| error.to_string());
    }
    if extension == "jpg" && pixels.starts_with(&[0xff, 0xd8]) {
        return file.write_all(pixels).map_err(|error| error.to_string());
    }

    let decoded;
    let (raw, color_type, pixel_format) = if pixels.starts_with(&[0xff, 0xd8]) {
        decoded = decode_jpeg(pixels).map_err(|error| error.to_string())?;
        let color_type = if decoded.mode == "L" {
            ColorType::L8
        } else {
            ColorType::Rgb8
        };
        let pixel_format = if color_type == ColorType::Rgb8 {
            "RGB24"
        } else {
            "Mono8"
        };
        (decoded.pixels.as_slice(), color_type, pixel_format)
    } else {
        let rgb_len = width as usize * height as usize * 3;
        let mono_len = width as usize * height as usize;
        if pixels.len() >= rgb_len {
            (&pixels[..rgb_len], ColorType::Rgb8, "RGB24")
        } else if pixels.len() >= mono_len {
            (&pixels[..mono_len], ColorType::L8, "Mono8")
        } else {
            return Err(format!(
                "video payload has {} bytes; expected at least {mono_len}",
                pixels.len()
            ));
        }
    };

    match extension {
        "jpg" => file
            .write_all(
                &encode_frame_jpeg(raw, width, height, pixel_format, 90)
                    .map_err(|error| error.to_string())?,
            )
            .map_err(|error| error.to_string()),
        "png" => image::write_buffer_with_format(
            &mut file,
            raw,
            width,
            height,
            color_type,
            ImageFormat::Png,
        )
        .map_err(|error| error.to_string()),
        "bmp" => image::write_buffer_with_format(
            &mut file,
            raw,
            width,
            height,
            color_type,
            ImageFormat::Bmp,
        )
        .map_err(|error| error.to_string()),
        _ => Err(format!(
            "unsupported video recording extension `{extension}`"
        )),
    }
}
