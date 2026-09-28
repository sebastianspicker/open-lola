//! Minimal PCM WAV read/write (RIFF).

use std::fs::File;
use std::io::{Read, Seek, SeekFrom, Write};
use std::path::Path;
use thiserror::Error;

#[derive(Debug, Error)]
pub enum WavError {
    #[error("io: {0}")]
    Io(#[from] std::io::Error),
    #[error("not a RIFF/WAVE file")]
    NotRiff,
    #[error("missing fmt or data chunk")]
    MissingChunk,
    #[error("only PCM supported, format={0}")]
    NotPcm(u16),
    #[error("unsupported sample width {0}")]
    BadWidth(u16),
    #[error("WAV data exceeds the RIFF size limit")]
    DataTooLarge,
}

#[derive(Debug, Clone)]
pub struct WavData {
    pub channels: u16,
    pub sample_rate: u32,
    pub bits_per_sample: u16,
    pub pcm: Vec<u8>,
}

/// Incremental PCM WAV writer. Call [`finish`](Self::finish) to finalize sizes.
pub struct WavStreamWriter {
    file: File,
    data_len: u64,
}

impl WavStreamWriter {
    pub fn create(
        path: impl AsRef<Path>,
        channels: u16,
        sample_rate: u32,
        bits_per_sample: u16,
    ) -> Result<Self, WavError> {
        if !supported_width(bits_per_sample) {
            return Err(WavError::BadWidth(bits_per_sample));
        }
        let bytes_per_sample = u32::from(bits_per_sample / 8);
        let block_align = channels
            .checked_mul(bits_per_sample / 8)
            .ok_or(WavError::DataTooLarge)?;
        let byte_rate = sample_rate
            .checked_mul(u32::from(channels))
            .and_then(|rate| rate.checked_mul(bytes_per_sample))
            .ok_or(WavError::DataTooLarge)?;
        let mut output = std::fs::OpenOptions::new();
        output.write(true).create(true);
        #[cfg(unix)]
        {
            use std::os::unix::fs::OpenOptionsExt;
            output
                .mode(0o600)
                .custom_flags(libc::O_NOFOLLOW | libc::O_NONBLOCK | libc::O_CLOEXEC);
        }
        #[cfg(windows)]
        {
            use std::os::windows::fs::OpenOptionsExt;
            output.custom_flags(0x00200000); // FILE_FLAG_OPEN_REPARSE_POINT
        }
        let mut file = output.open(path)?;
        if !file.metadata()?.is_file() {
            return Err(std::io::Error::new(
                std::io::ErrorKind::InvalidInput,
                "WAV output must be a regular file",
            )
            .into());
        }
        file.set_len(0)?;
        write_header(
            &mut file,
            channels,
            sample_rate,
            bits_per_sample,
            byte_rate,
            block_align,
        )?;
        Ok(Self { file, data_len: 0 })
    }

    pub fn append(&mut self, pcm: &[u8]) -> Result<(), WavError> {
        const MAX_DATA_LEN: u64 = u32::MAX as u64 - 36;
        let appended_len = self
            .data_len
            .checked_add(pcm.len() as u64)
            .ok_or(WavError::DataTooLarge)?;
        if appended_len > MAX_DATA_LEN {
            return Err(WavError::DataTooLarge);
        }
        write_pcm(&mut self.file, pcm, &mut self.data_len)
    }

    pub fn data_len(&self) -> u64 {
        self.data_len
    }

    pub fn finish(mut self) -> Result<(), WavError> {
        let data_len = self.data_len as u32;
        let padding = self.data_len % 2;
        if padding != 0 {
            self.file.write_all(&[0])?;
        }
        self.file.flush()?;
        let riff_len = 36 + data_len + padding as u32;
        self.file.seek(SeekFrom::Start(4))?;
        self.file.write_all(&riff_len.to_le_bytes())?;
        self.file.seek(SeekFrom::Start(40))?;
        self.file.write_all(&data_len.to_le_bytes())?;
        self.file.flush()?;
        Ok(())
    }
}

fn supported_width(bits_per_sample: u16) -> bool {
    matches!(bits_per_sample, 8 | 16 | 24 | 32)
}

fn write_header(
    file: &mut File,
    channels: u16,
    sample_rate: u32,
    bits_per_sample: u16,
    byte_rate: u32,
    block_align: u16,
) -> Result<(), WavError> {
    file.write_all(b"RIFF")?;
    file.write_all(&0u32.to_le_bytes())?;
    file.write_all(b"WAVEfmt ")?;
    file.write_all(&16u32.to_le_bytes())?;
    file.write_all(&1u16.to_le_bytes())?;
    file.write_all(&channels.to_le_bytes())?;
    file.write_all(&sample_rate.to_le_bytes())?;
    file.write_all(&byte_rate.to_le_bytes())?;
    file.write_all(&block_align.to_le_bytes())?;
    file.write_all(&bits_per_sample.to_le_bytes())?;
    file.write_all(b"data")?;
    file.write_all(&0u32.to_le_bytes())?;
    Ok(())
}

fn write_pcm(file: &mut File, pcm: &[u8], data_len: &mut u64) -> Result<(), WavError> {
    let mut remaining = pcm;
    while !remaining.is_empty() {
        let written = file.write(remaining)?;
        if written == 0 {
            return Err(std::io::Error::new(
                std::io::ErrorKind::WriteZero,
                "could not append WAV data",
            )
            .into());
        }
        *data_len += written as u64;
        remaining = &remaining[written..];
    }
    Ok(())
}

impl WavData {
    pub fn sample_width(&self) -> usize {
        (self.bits_per_sample / 8) as usize
    }

    pub fn nframes(&self) -> usize {
        let frame = self.channels as usize * self.sample_width();
        self.pcm.len().checked_div(frame).unwrap_or(0)
    }
}

pub fn write_wav(path: impl AsRef<Path>, data: &WavData) -> Result<(), WavError> {
    let mut writer =
        WavStreamWriter::create(path, data.channels, data.sample_rate, data.bits_per_sample)?;
    writer.append(&data.pcm)?;
    writer.finish()
}

pub fn read_wav(path: impl AsRef<Path>) -> Result<WavData, WavError> {
    let mut f = File::open(path)?;
    let mut buf = Vec::new();
    f.read_to_end(&mut buf)?;
    if buf.len() < 12 || &buf[0..4] != b"RIFF" || &buf[8..12] != b"WAVE" {
        return Err(WavError::NotRiff);
    }
    let mut pos = 12usize;
    let mut channels = 0u16;
    let mut sample_rate = 0u32;
    let mut bits = 0u16;
    let mut audio_format = 0u16;
    let mut pcm = Vec::new();
    let mut got_fmt = false;
    let mut got_data = false;
    while pos + 8 <= buf.len() {
        let id = &buf[pos..pos + 4];
        let size = u32::from_le_bytes(buf[pos + 4..pos + 8].try_into().unwrap()) as usize;
        pos += 8;
        if pos + size > buf.len() {
            break;
        }
        let chunk = &buf[pos..pos + size];
        if id == b"fmt " {
            if chunk.len() < 16 {
                return Err(WavError::MissingChunk);
            }
            audio_format = u16::from_le_bytes(chunk[0..2].try_into().unwrap());
            channels = u16::from_le_bytes(chunk[2..4].try_into().unwrap());
            sample_rate = u32::from_le_bytes(chunk[4..8].try_into().unwrap());
            bits = u16::from_le_bytes(chunk[14..16].try_into().unwrap());
            got_fmt = true;
        } else if id == b"data" {
            pcm = chunk.to_vec();
            got_data = true;
        }
        pos += size;
        if size % 2 == 1 {
            pos += 1; // pad
        }
    }
    if !got_fmt || !got_data {
        return Err(WavError::MissingChunk);
    }
    if audio_format != 1 {
        return Err(WavError::NotPcm(audio_format));
    }
    if !supported_width(bits) {
        return Err(WavError::BadWidth(bits));
    }
    Ok(WavData {
        channels,
        sample_rate,
        bits_per_sample: bits,
        pcm,
    })
}

#[cfg(all(test, unix))]
mod output_security_tests {
    use super::*;
    #[test]
    fn wav_output_never_follows_a_symlink_or_blocks_on_fifo() {
        let dir = tempfile::tempdir().unwrap();
        let victim = dir.path().join("victim");
        std::fs::write(&victim, b"unchanged").unwrap();
        let link = dir.path().join("output.wav");
        std::os::unix::fs::symlink(&victim, &link).unwrap();
        assert!(WavStreamWriter::create(&link, 2, 44100, 16).is_err());
        assert_eq!(std::fs::read(&victim).unwrap(), b"unchanged");
        std::fs::remove_file(&link).unwrap();
        let name = std::ffi::CString::new(link.as_os_str().as_encoded_bytes()).unwrap();
        // SAFETY: name is a live NUL-terminated filesystem pathname.
        assert_eq!(unsafe { libc::mkfifo(name.as_ptr(), 0o600) }, 0);
        assert!(WavStreamWriter::create(&link, 2, 44100, 16).is_err());
    }
}
