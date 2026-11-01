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
