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
//!   PC1 (W) WDATA  — serial data output to tape recorder (recording, stub)

const std = @import("std");

/// Maximum number of PCM samples.
/// 3 MB covers WAV files (~68 s at 44100 Hz) and worst-case 64 KB MZF tapes at 4096 Hz.
pub const MAX_SAMPLES: usize = 3 * 1024 * 1024;

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
    /// Last WDATA bit written by the CPU via PC1 (for future recording support).
    wdata: bool,

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
            .wdata = false,
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

    /// Receives the WDATA signal (PC1 output) for tape recording.
    /// Stores the last bit written; actual recording is not yet implemented.
    pub fn writeData(self: *Self, bit: bool) void {
        self.wdata = bit;
    }

    /// Rewind tape to the beginning.
    pub fn rewind(self: *Self) void {
        self.position = 0;
    }

    /// Encode an MZF file as synthetic PCM for CMT playback.
    ///
    /// Uses the MZ-800 "SANE" tape protocol at 4096 Hz (1 sample ≈ 244 µs):
    ///   Short pulse [0xFF, 0x00]             — 488 µs, encodes bit 0
    ///   Long  pulse [0xFF, 0xFF, 0x00, 0x00] — 976 µs, encodes bit 1 and stop bits
    ///
    /// Tape structure (matches g_mztape_format_sharp_sane, mztape.c lines 121–135):
    ///   Long gap  (6400 short)  + Long TM  (40L+40S) + 2L
    ///   Header (128 B, MSB-first, stop bit per byte)  + CHK (2 B, big-endian popcount) + 2L
    ///   Short gap (11000 short) + Short TM (20L+20S)  + 2L
    ///   Data   (N   B, MSB-first, stop bit per byte)  + CHK (2 B, big-endian popcount) + 2L
    ///
    /// Checksum = count of '1' bits (popcount) across all bytes in the block.
    /// `header` must be the raw 128-byte MZF header; `data` the program bytes.
    pub fn loadMzf(self: *Self, header: []const u8, data: []const u8) !void {
        const SAMPLE_RATE: u32 = 4096;
        var pos: usize = 0;

        // ── Long gap: 6400 short pulses ──────────────────────────────────────
        for (0..6400) |_| pos = try writeShort(&self.samples, pos);

        // ── Long Tape Mark: 40 long + 40 short pulses ────────────────────────
        for (0..40) |_| pos = try writeLong(&self.samples, pos);
        for (0..40) |_| pos = try writeShort(&self.samples, pos);

        // ── 2 long pulses ────────────────────────────────────────────────────
        pos = try writeLong(&self.samples, pos);
        pos = try writeLong(&self.samples, pos);

        // ── Header block: 128 bytes MSB-first with stop bit ──────────────────
        var checksum: u16 = 0;
        for (header) |byte| {
            checksum += @as(u16, @popCount(byte));
            pos = try encodeByte(&self.samples, pos, byte);
        }
        // Header checksum big-endian (high byte first)
        pos = try encodeByte(&self.samples, pos, @truncate(checksum >> 8));
        pos = try encodeByte(&self.samples, pos, @truncate(checksum));

        // ── 2 long pulses ────────────────────────────────────────────────────
        pos = try writeLong(&self.samples, pos);
        pos = try writeLong(&self.samples, pos);

        // ── Short gap: 11000 short pulses ────────────────────────────────────
        for (0..11000) |_| pos = try writeShort(&self.samples, pos);

        // ── Short Tape Mark: 20 long + 20 short pulses ───────────────────────
        for (0..20) |_| pos = try writeLong(&self.samples, pos);
        for (0..20) |_| pos = try writeShort(&self.samples, pos);

        // ── 2 long pulses ────────────────────────────────────────────────────
        pos = try writeLong(&self.samples, pos);
        pos = try writeLong(&self.samples, pos);

        // ── Data block: N bytes MSB-first with stop bit ──────────────────────
        checksum = 0;
        for (data) |byte| {
            checksum += @as(u16, @popCount(byte));
            pos = try encodeByte(&self.samples, pos, byte);
        }
        // Data checksum big-endian (high byte first)
        pos = try encodeByte(&self.samples, pos, @truncate(checksum >> 8));
        pos = try encodeByte(&self.samples, pos, @truncate(checksum));

        // ── 2 long pulses ────────────────────────────────────────────────────
        pos = try writeLong(&self.samples, pos);
        pos = try writeLong(&self.samples, pos);

        self.sample_count = pos;
        self.sample_rate = SAMPLE_RATE;
        self.position = 0;
        self.motor = false;
        self.prev_m_on = false;
        self.loaded = true;

        std.debug.print("🚨 CMT: loaded MZF as {d} samples @ {d} Hz\n", .{ pos, SAMPLE_RATE });
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

/// Emit a short pulse [0xFF, 0x00] (≈ 488 µs at 4096 Hz, encodes bit 0).
fn writeShort(samples: []u8, pos: usize) !usize {
    if (pos + 2 > samples.len) return error.MzfTooLong;
    samples[pos] = 0xFF;
    samples[pos + 1] = 0x00;
    return pos + 2;
}

/// Emit a long pulse [0xFF, 0xFF, 0x00, 0x00] (≈ 976 µs at 4096 Hz, encodes bit 1 / stop bit).
fn writeLong(samples: []u8, pos: usize) !usize {
    if (pos + 4 > samples.len) return error.MzfTooLong;
    samples[pos] = 0xFF;
    samples[pos + 1] = 0xFF;
    samples[pos + 2] = 0x00;
    samples[pos + 3] = 0x00;
    return pos + 4;
}

/// Encode one byte MSB-first (8 data bits + 1 long stop bit) into `samples`.
/// Returns the updated position, or error.MzfTooLong on buffer overflow.
fn encodeByte(samples: []u8, pos: usize, byte_val: u8) !usize {
    var p = pos;
    var b = byte_val;
    for (0..8) |_| {
        if (b & 0x80 != 0) {
            p = try writeLong(samples, p);
        } else {
            p = try writeShort(samples, p);
        }
        b <<= 1;
    }
    // Stop bit: always a long pulse (ref: mztape.c lines 624–626)
    p = try writeLong(samples, p);
    return p;
}
