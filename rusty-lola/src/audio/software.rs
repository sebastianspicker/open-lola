//! Software duplex audio: synthetic PCM tones for CI / no-hardware path.

/// Manual §4.12: 689 Hz / 750 Hz at −12 dBFS (linear ≈ 10^(-12/20) ≈ 0.251).
pub const TEST_TONE_HZ_PRIMARY: f64 = 689.0;
pub const TEST_TONE_HZ_SECONDARY: f64 = 750.0;
pub const TEST_TONE_AMPLITUDE: f64 = 0.251188643150958; // 10^(-12/20)

/// Generate interleaved PCM tone (s16le when bits==16).
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
    let mut out = Vec::with_capacity(n * ch * (bits_per_sample as usize / 8).max(1));
    for i in 0..n {
        let t = (phase_offset_samples as f64 + i as f64) / sr;
        let sample = (t * freq * std::f64::consts::TAU).sin() * amp;
        if bits_per_sample == 16 {
            let s16 = (sample * 32767.0).round().clamp(-32768.0, 32767.0) as i16;
            for _ in 0..ch {
                out.extend_from_slice(&s16.to_le_bytes());
            }
        } else {
            let u = ((sample * 127.0) + 128.0).round().clamp(0.0, 255.0) as u8;
            for _ in 0..ch {
                out.push(u);
            }
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

#[cfg(test)]
mod tone_tests {
    use super::*;

    #[test]
    fn test_tone_689_has_energy_and_level() {
        let pcm = generate_pcm_tone(
            1,
            48000,
            16,
            480,
            TEST_TONE_HZ_PRIMARY,
            TEST_TONE_AMPLITUDE,
            0,
        );
        assert_eq!(pcm.len(), 480 * 2);
        let mut peak = 0i16;
        for i in 0..480 {
            let s = i16::from_le_bytes([pcm[i * 2], pcm[i * 2 + 1]]);
            peak = peak.max(s.abs());
        }
        // −12 dBFS peak ≈ 0.251 * 32767 ≈ 8230
        assert!(peak > 7000 && peak < 10000, "peak={peak}");
    }

    #[test]
    fn alternate_freq() {
        assert!((test_tone_frequency(0) - TEST_TONE_HZ_PRIMARY).abs() < 0.01);
        assert!((test_tone_frequency(1) - TEST_TONE_HZ_SECONDARY).abs() < 0.01);
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

    /// Read one buffer of interleaved PCM (s16le when 16-bit).
    pub fn read_pcm(&mut self) -> Vec<u8> {
        let n = self.buffer_samples as usize;
        let ch = self.channels as usize;
        let mut out = Vec::with_capacity(n * ch * (self.bits_per_sample as usize / 8));
        for i in 0..n {
            let t = (self.frame as f32 + i as f32) / self.sample_rate as f32;
            let sample = (t * 440.0 * std::f32::consts::TAU).sin();
            let s16 = (sample * 16000.0) as i16;
            for c in 0..ch {
                let scaled = s16.wrapping_mul((c as i16) + 1);
                if self.bits_per_sample == 16 {
                    out.extend_from_slice(&scaled.to_le_bytes());
                } else {
                    out.push((scaled as u8).wrapping_add(c as u8));
                }
            }
        }
        self.frame = self.frame.wrapping_add(self.buffer_samples);
        out
    }
}
