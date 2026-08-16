//! Split multichannel PCM WAV into mono Track_N files.

use super::wav::{read_wav, write_wav, WavData, WavError};
use std::path::{Path, PathBuf};
use thiserror::Error;

#[derive(Debug, Error)]
pub enum WavSplitError {
    #[error(transparent)]
    Wav(#[from] WavError),
    #[error("input must have at least 2 channels")]
    Mono,
    #[error("io: {0}")]
    Io(#[from] std::io::Error),
}

/// Split multichannel PCM WAV into `{stem}_Track_{n}.wav` mono files (1-based).
pub fn split_wav(
    src: impl AsRef<Path>,
    out_dir: Option<&Path>,
) -> Result<Vec<PathBuf>, WavSplitError> {
    let src = src.as_ref();
    let data = read_wav(src)?;
    if data.channels < 2 {
        return Err(WavSplitError::Mono);
    }
    let out_dir = out_dir.unwrap_or_else(|| src.parent().unwrap_or(Path::new(".")));
    std::fs::create_dir_all(out_dir)?;
    let sw = data.sample_width();
    let nch = data.channels as usize;
    let frame_size = nch * sw;
    let nframes = data.pcm.len() / frame_size;
    let stem = src.file_stem().and_then(|s| s.to_str()).unwrap_or("track");

    let mut tracks: Vec<Vec<u8>> = (0..nch).map(|_| Vec::with_capacity(nframes * sw)).collect();
    for i in 0..nframes {
        let base = i * frame_size;
        for (ch, track) in tracks.iter_mut().enumerate().take(nch) {
            let off = base + ch * sw;
            track.extend_from_slice(&data.pcm[off..off + sw]);
        }
    }

    let mut written = Vec::new();
    for (ch, pcm) in tracks.into_iter().enumerate() {
        let out_path = out_dir.join(format!("{stem}_Track_{}.wav", ch + 1));
        write_wav(
            &out_path,
            &WavData {
                channels: 1,
                sample_rate: data.sample_rate,
                bits_per_sample: data.bits_per_sample,
                pcm,
            },
        )?;
        written.push(out_path);
    }
    Ok(written)
}

/// Write a small multichannel PCM fixture for tests.
pub fn write_pcm_fixture(
    path: impl AsRef<Path>,
    channels: u16,
    rate: u32,
    seconds: f32,
    sampwidth: u16,
) -> Result<PathBuf, WavError> {
    let path = path.as_ref();
    if let Some(p) = path.parent() {
        std::fs::create_dir_all(p)?;
    }
    let nframes = ((rate as f32 * seconds).max(1.0)) as usize;
    let mut frames = Vec::new();
    for i in 0..nframes {
        for ch in 0..channels {
            let sample =
                ((i as u32).wrapping_mul((ch as u32) + 1).wrapping_mul(17) & 0xFFFF) as u16;
            if sampwidth == 2 {
                frames.extend_from_slice(&sample.to_le_bytes());
            } else if sampwidth == 1 {
                frames.push((sample & 0xFF) as u8);
            } else {
                return Err(WavError::BadWidth(sampwidth));
            }
        }
    }
    write_wav(
        path,
        &WavData {
            channels,
            sample_rate: rate,
            bits_per_sample: sampwidth * 8,
            pcm: frames,
        },
    )?;
    Ok(path.to_path_buf())
}

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::tempdir;

    #[test]
    fn split_stereo() {
        let dir = tempdir().unwrap();
        let src = dir.path().join("mix.wav");
        write_pcm_fixture(&src, 2, 48000, 0.02, 2).unwrap();
        let out = split_wav(&src, None).unwrap();
        assert_eq!(out.len(), 2);
        assert!(out[0]
            .file_name()
            .unwrap()
            .to_str()
            .unwrap()
            .ends_with("_Track_1.wav"));
        assert!(out[1]
            .file_name()
            .unwrap()
            .to_str()
            .unwrap()
            .ends_with("_Track_2.wav"));
        let t1 = read_wav(&out[0]).unwrap();
        assert_eq!(t1.channels, 1);
    }
}
