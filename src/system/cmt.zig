//! CMT (Cassette Magnetic Tape) emulation for SHARP MZ-800.
//!
//! Replays 8-bit mono PCM WAV data as the CMT RDATA signal on PPI Port C bit 5 (PC5).
//! The ROM monitor reads PC5 and measures pulse widths to decode tape bits — no
//! decoding is done here; raw PCM samples are threshold-compared and fed directly.
//!
//! PPI Port C CMT signals:
//!   PC5 (R) RDATA  — serial data input from tape recorder (injected from WAV)
//!   PC4 (R) MOTOR  — motor status readback (0=OFF, 1=ON)
//!   PC3 (W) M-ON   — motor on/off, activated by rising edge 0→1

const std = @import("std");

/// Maximum number of PCM samples (~45 seconds at 44100 Hz, sufficient for MZF tapes).
pub const MAX_SAMPLES: usize = 2 * 1024 * 1024;

pub const CMT = struct {
    const Self = @This();

    /// Raw 8-bit unsigned PCM samples (0x00..0xFF, mid-scale = 0x80 = silence).
    /// Only valid indices 0..sample_count-1 are meaningful.
    samples: [MAX_SAMPLES]u8,
    /// Number of valid samples loaded.
    sample_count: usize,
    /// WAV sample rate in Hz (typically 44100).
    sample_rate: u32,
    /// Fixed-point 32.32 playback position.
    /// High 32 bits = current sample index, low 32 bits = fractional part.
    position: u64,
    /// Increment added to position each master clock tick.
    /// Computed as (sample_rate << 32) / master_clock_hz.
    /// Example: (44100 << 32) / 17734475 ≈ 10681 per tick → one sample per ~402 ticks.
    tick_increment: u64,
    /// True when the motor is running (tape advances).
    motor: bool,
    /// Previous value of M-ON (PC3) for rising-edge detection.
    prev_m_on: bool,
    /// True when a WAV file has been successfully loaded.
    loaded: bool,

    pub fn init() Self {
        return .{
            .samples = undefined,
            .sample_count = 0,
            .sample_rate = 44100,
            .position = 0,
            .tick_increment = 0,
            .motor = false,
            .prev_m_on = false,
            .loaded = false,
        };
    }

    /// Precompute the per-tick position increment from the master clock frequency.
    /// Call once after loading a WAV (or after initInPlace).
    pub fn configure(self: *Self, master_clock_hz: u64) void {
        if (master_clock_hz == 0) return;
        self.tick_increment = (@as(u64, self.sample_rate) << 32) / master_clock_hz;
    }

    /// Advance playback by one master clock tick.
    /// No-op if no WAV is loaded or the motor is off.
    pub fn tick(self: *Self) void {
        if (!self.loaded or !self.motor) return;
        self.position +%= self.tick_increment;
    }

    /// Returns the current RDATA signal level for PPI PC5.
    /// true = high (sample > 128), false = low (sample ≤ 128 or not loaded/ended).
    pub fn readBit(self: *const Self) bool {
        if (!self.loaded) return false;
        const idx = @as(usize, @truncate(self.position >> 32));
        if (idx >= self.sample_count) return false;
        return self.samples[idx] > 128;
    }

    /// Returns the motor status for PPI PC4 readback (1 = motor on).
    pub fn motorStatus(self: *const Self) bool {
        return self.motor;
    }

    /// Update motor state from M-ON (PC3 output).
    /// Motor activates on a rising edge (0→1 transition).
    pub fn updateMotor(self: *Self, m_on: bool) void {
        if (m_on and !self.prev_m_on) {
            // Rising edge: start motor
            self.motor = true;
            std.debug.print("🚨 CMT: motor ON\n", .{});
        } else if (!m_on and self.prev_m_on) {
            // Falling edge: stop motor
            self.motor = false;
            std.debug.print("🚨 CMT: motor OFF\n", .{});
        }
        self.prev_m_on = m_on;
    }

    /// Rewind tape to the beginning.
    pub fn rewind(self: *Self) void {
        self.position = 0;
    }

    /// Parse and load a RIFF/WAV file from a byte slice.
    /// Validates: RIFF container, WAVE type, PCM format (1), mono, 8-bit samples.
    /// Accepts any sample rate. Copies samples into the internal buffer.
    pub fn loadWav(self: *Self, data: []const u8) !void {
        if (data.len < 12) return error.WavTooShort;

        if (!std.mem.eql(u8, data[0..4], "RIFF")) return error.NotRiff;
        if (!std.mem.eql(u8, data[8..12], "WAVE")) return error.NotWave;

        var offset: usize = 12;
        var fmt_found = false;
        var data_start: usize = 0;
        var data_size: usize = 0;
        var sample_rate: u32 = 0;

        while (offset + 8 <= data.len) {
            const chunk_id = data[offset..][0..4];
            const chunk_size: usize = std.mem.readInt(u32, data[offset + 4 ..][0..4], .little);
            const chunk_data = offset + 8;
            if (chunk_data + chunk_size > data.len) return error.WavTruncated;

            if (std.mem.eql(u8, chunk_id, "fmt ")) {
                if (chunk_size < 16) return error.WavFmtTooShort;
                const audio_format = std.mem.readInt(u16, data[chunk_data..][0..2], .little);
                const num_channels = std.mem.readInt(u16, data[chunk_data + 2 ..][0..2], .little);
                sample_rate = std.mem.readInt(u32, data[chunk_data + 4 ..][0..4], .little);
                const bits_per_sample = std.mem.readInt(u16, data[chunk_data + 14 ..][0..2], .little);
                if (audio_format != 1) return error.WavNotPCM;
                if (num_channels != 1) return error.WavNotMono;
                if (bits_per_sample != 8) return error.WavNot8Bit;
                fmt_found = true;
            } else if (std.mem.eql(u8, chunk_id, "data")) {
                data_start = chunk_data;
                data_size = chunk_size;
            }

            offset = chunk_data + chunk_size;
            if (chunk_size & 1 != 0) offset += 1; // word-align
        }

        if (!fmt_found) return error.WavNoFmtChunk;
        if (data_size == 0) return error.WavNoDataChunk;

        const count = @min(data_size, MAX_SAMPLES);
        @memcpy(self.samples[0..count], data[data_start..][0..count]);
        self.sample_count = count;
        self.sample_rate = sample_rate;
        self.position = 0;
        self.motor = false;
        self.prev_m_on = false;
        self.loaded = true;

        std.debug.print("🚨 CMT: loaded {d} samples @ {d} Hz\n", .{ count, sample_rate });
    }
};
