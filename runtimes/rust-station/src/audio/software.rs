//! Software duplex audio: synthetic PCM tones for CI / no-hardware path.

/// Manual §4.12: 689 Hz / 750 Hz at −12 dBFS (linear ≈ 10^(-12/20) ≈ 0.251).
pub const TEST_TONE_HZ_PRIMARY: f64 = 689.0;
pub const TEST_TONE_HZ_SECONDARY: f64 = 750.0;
pub const TEST_TONE_AMPLITUDE: f64 = 0.251188643150958; // 10^(-12/20)

/// Generate interleaved signed little-endian PCM tone (8/16/24/32 bits; other values give 16).
pub fn generate_pcm_tone(
    channels: u16,
    sample_rate: u32,
    bits_per_sample: u16,
    n_samples: u32,
    frequency_hz: f64,
    amplitude: f64,
    phase_offset_samples: u32,
) -> Vec<u8> {
    let n = n_samples.max(1) as usize;
    let ch = channels.max(1) as usize;
    let sr = sample_rate.max(1) as f64;
    let amp = amplitude.clamp(0.0, 1.0);
    let freq = frequency_hz.max(1.0);
    let bytes_per_sample = if matches!(bits_per_sample, 8 | 24 | 32) {
        bits_per_sample as usize / 8
    } else {
        2
    };
    let mut out = Vec::with_capacity(n * ch * bytes_per_sample);
    for i in 0..n {
        let t = (phase_offset_samples as f64 + i as f64) / sr;
        let sample = (t * freq * std::f64::consts::TAU).sin() * amp;
        // Signed little-endian PCM, matching the PortAudio/ALSA device formats.
        let bytes = match bits_per_sample {
            24 => ((sample * 8_388_607.0).round() as i32).to_le_bytes(),
            32 => ((sample * 2_147_483_647.0).round() as i32).to_le_bytes(),
            8 => [(sample * 127.0).round() as i8 as u8, 0, 0, 0],
            _ => {
                let [lo, hi] =
                    ((sample * 32767.0).round().clamp(-32768.0, 32767.0) as i16).to_le_bytes();
                [lo, hi, 0, 0]
            }
        };
        for _ in 0..ch {
            out.extend_from_slice(&bytes[..bytes_per_sample]);
        }
    }
    out
}

/// Alternate 689/750 Hz based on frame index (matches Python time-based alternate intent).
pub fn test_tone_frequency(frame_i: u32) -> f64 {
    if frame_i.is_multiple_of(2) {
        TEST_TONE_HZ_PRIMARY
    } else {
        TEST_TONE_HZ_SECONDARY
    }
}
#[derive(Debug, Clone)]
pub struct SoftwareAudio {
    pub sample_rate: u32,
    pub channels: u16,
    pub bits_per_sample: u16,
    pub buffer_samples: u32,
    frame: u32,
}

impl Default for SoftwareAudio {
    fn default() -> Self {
        Self {
            sample_rate: 48000,
            channels: 2,
            bits_per_sample: 16,
            buffer_samples: 64,
            frame: 0,
        }
    }
}

impl SoftwareAudio {
    pub fn open(
        &mut self,
        sample_rate: u32,
        channels: u16,
        bits_per_sample: u16,
        buffer_samples: u32,
    ) {
        self.sample_rate = sample_rate;
        self.channels = channels;
        self.bits_per_sample = bits_per_sample;
        self.buffer_samples = if buffer_samples == 32 || buffer_samples == 64 {
            buffer_samples
        } else {
            64
        };
    }

    pub fn start(&mut self) {
        self.frame = 0;
    }

    pub fn stop(&mut self) {}

    /// Read one buffer of interleaved signed little-endian PCM.
    pub fn read_pcm(&mut self) -> Vec<u8> {
        let mut out = Vec::new();
        self.read_pcm_into(&mut out);
        out
    }

    /// Caller-buffered capture used by the session loop.
    pub fn read_pcm_into(&mut self, out: &mut Vec<u8>) {
        let n = self.buffer_samples as usize;
        let ch = self.channels as usize;
        out.clear();
        let bytes_per_sample = match self.bits_per_sample {
            8 | 24 | 32 => self.bits_per_sample as usize / 8,
            _ => 2,
        };
        out.reserve(n * ch * bytes_per_sample);
        for i in 0..n {
            let t = (self.frame as f32 + i as f32) / self.sample_rate as f32;
            let sample = f64::from((t * 440.0 * std::f32::consts::TAU).sin()) * 0.5;
            for c in 0..ch {
                // Distinct per-channel level so channel routing stays visible.
                let v = sample * (c as f64 + 1.0);
                let bytes = match self.bits_per_sample {
                    8 => [((v * 127.0).clamp(-128.0, 127.0) as i8) as u8, 0, 0, 0],
                    24 => ((v * 8_388_607.0).clamp(-8_388_608.0, 8_388_607.0) as i32).to_le_bytes(),
                    32 => ((v * 2_147_483_647.0) as i32).to_le_bytes(),
                    _ => {
                        let [lo, hi] =
                            ((v * 32767.0).clamp(-32768.0, 32767.0) as i16).to_le_bytes();
                        [lo, hi, 0, 0]
                    }
                };
                out.extend_from_slice(&bytes[..bytes_per_sample]);
            }
        }
        self.frame = self.frame.wrapping_add(self.buffer_samples);
    }
}
