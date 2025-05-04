//! sn76489an -- emulates the SN 76489 AN Programmable Sound Generator (PSG)
//!    EMULATED PINS:
//!
//!                  +-----------+
//!            CE -->|           |
//!            WE -->|           |
//!         READY <--| sn76489an |--> AUDIO OUT
//!                  |           |
//!           CLK -->|           |
//!                  |           |
//!            D0 <->|           |
//!               ...|           |
//!            D7 <->|           |
//!                  |           |
//!                  +-----------+
//!
//! A 4 channel sound generator, with three squarewave channels and
//! a noise/arbitrary duty cycle channel.
//!
//! From MAME:
//! ** SN76489A uses a 15-bit shift register with taps on bits D and E, output on F,
//! XOR function.
//! It uses a 15-bit ring buffer for periodic noise/arbitrary duty cycle.
//! Its output is not inverted.
//! All the TI-made PSG chips have an audio input line which is mixed with the 4 channels
//! of output. (It is undocumented and may not function properly on the sn76489, 76489a
//! and 76494; the sn76489a input is mentioned in datasheets for the tms5200)
//! All the TI-made PSG chips act as if the frequency was set to 0x400 if 0 is
//! written to the frequency register.

const std = @import("std");
const chipz = @import("chipz");
const bitutils = chipz.common.bitutils;
const mask = bitutils.mask;
const maskm = bitutils.maskm;

pub const Pins = struct {
    CE: comptime_int, // chip enable
    WE: comptime_int, // write enable
    DBUS: [8]comptime_int, // data bus
};

/// default pin configuration (mainly useful for debugging)
pub const DefaultPins = Pins{
    .CE = 40,
    .WE = 28, // Write to PSG, shared with Z80 WR
    .DBUS = .{ 16, 17, 18, 19, 20, 21, 22, 23 }, // Shared with Z80 data bus
};

/// comptime type configuration for PSG
pub const TypeConfig = struct {
    pins: Pins,
    bus: type,
};

pub fn Type(comptime cfg: TypeConfig) type {
    const Bus = cfg.bus;

    return struct {
        const Self = @This();

        // pin bit-masks
        pub const DBUS = maskm(Bus, &cfg.pins.DBUS);
        pub const D0 = mask(Bus, cfg.pins.D[0]);
        pub const D1 = mask(Bus, cfg.pins.D[1]);
        pub const D2 = mask(Bus, cfg.pins.D[2]);
        pub const D3 = mask(Bus, cfg.pins.D[3]);
        pub const D4 = mask(Bus, cfg.pins.D[4]);
        pub const D5 = mask(Bus, cfg.pins.D[5]);
        pub const D6 = mask(Bus, cfg.pins.D[6]);
        pub const D7 = mask(Bus, cfg.pins.D[7]);
        pub const CE = mask(Bus, cfg.pins.CE);
        pub const WE = mask(Bus, cfg.pins.WE);

        /// Attenuation
        pub const ATTENUATION = enum(u4) {
            DB0 = 0, // 0db, max output volume
            DB2 = 1, // 2db
            DB4 = 2, // 4db
            DB6 = 3, // 6db
            DB8 = 4, // 8db
            DB10 = 5, // 10db
            DB12 = 6, // 12db
            DB14 = 7, // 14db
            DB16 = 8, // 16db
            DB18 = 9, // 18db
            DB20 = 10, // 20db
            DB22 = 11, // 22db
            DB24 = 12, // 24db
            DB26 = 13, // 26db
            DB28 = 14, // 28db
            OFF = 15, // off, no output
        };

        pub const Tone = struct {
            divider: u10,
            divider_latch: u16,
        };

        /// Noise feedback
        pub const NOISE_FB = enum(u1) {
            PERIODIC,
            WHITE,
        };

        pub const NOISE_DIVIDER = enum(u2) {
            TYPE0 = 0, // noise divider 0x10, 6.928 kHz
            TYPE1 = 1, // noise divider 0x20, 3.464 kHz
            TYPE2 = 2, // noise divider 0x40, 1.732 kHz
            TYPE3 = 3, // set noise divider according to channel 2
        };

        pub const Noise = struct {
            feedback: NOISE_FB,
            last_feedback: NOISE_FB,
            divider: NOISE_DIVIDER,
            shift_register: u16,
        };

        pub const ChannelType = enum {
            tone, // square wave tone generator
            noise, // noise generator
        };

        pub const Generator = union(ChannelType) {
            tone: Tone,
            noise: Noise,

            pub const defaultTone: Generator = .{ .tone = .{ .divider = 0, .divider_latch = 0 } };
            pub const defaultNoise: Generator = .{ .noise = .{ .feedback = .PERIODIC, .last_feedback = .PERIODIC, .divider = .TYPE0, .shift_register = 0 } };
        };

        pub const Channel = struct {
            generator: Generator,
            timer: u16,
            attenuation: ATTENUATION,
            output_signal: u16,
        };

        pub const DATA = struct {
            pub const LATCH = mask(u8, 7);
            pub const CHANNEL = maskm(u8, &[_]comptime_int{ 5, 6 });
            pub const ATTENUATION = mask(u8, 4);
            pub const VALUE_LOW = maskm(u8, &[_]comptime_int{ 0, 1, 2, 3 });
            pub const VALUE_HIGH = maskm(u8, &[_]comptime_int{ 0, 1, 2, 3, 4, 5 });
            pub const NOISE_FB = mask(u8, 2);
            pub const NOISE_DIVIDER = maskm(u8, &[_]comptime_int{ 0, 1 });
        };

        channel: [4]Channel = .{
            .{
                .generator = .defaultTone,
                .timer = 0,
                .attenuation = .OFF,
                .output_signal = 0,
            },
            .{
                .generator = .defaultTone,
                .timer = 0,
                .attenuation = .OFF,
                .output_signal = 0,
            },
            .{
                .generator = .defaultTone,
                .timer = 0,
                .attenuation = .OFF,
                .output_signal = 0,
            },
            .{
                .generator = .defaultNoise,
                .timer = 0,
                .attenuation = .OFF,
                .output_signal = 0,
            },
        },
        channel_addr_latch: u2 = 0,

        /// Get data bus value
        pub inline fn getData(bus: Bus) u8 {
            return @truncate(bus >> cfg.pins.DBUS[0]);
        }

        /// Set data bus value
        pub inline fn setData(bus: Bus, data: u8) Bus {
            return (bus & ~DBUS) | (@as(Bus, data) << cfg.pins.DBUS[0]);
        }

        /// Return an initialized PSG instance
        pub fn init() Self {
            var self: Self = .{};
            self.reset();
            return self;
        }

        /// Reset PSG instance
        pub fn reset(self: *Self) void {
            for (self.channel[0..3]) |*channel| {
                channel.*.timer = 0;
                channel.*.attenuation = .OFF;
                channel.*.output_signal = 0;
                switch (channel.generator) {
                    .tone => |*generator| generator.* = Generator.defaultTone.tone,
                    .noise => |*generator| generator.* = Generator.defaultNoise.noise,
                }
            }
        }

        /// Execute one clock cycle
        pub fn tick(self: *Self, in_bus: Bus) Bus {
            var bus = in_bus;
            if (((bus & CE) != 0) and ((bus & WE) != 0)) {
                bus = self.write(bus);
            }
            return bus;
        }

        /// Write a value to the PSG
        pub fn write(self: *Self, in_bus: Bus) Bus {
            const data = getData(in_bus);
            const is_latch = data & DATA.LATCH != 0;
            if (is_latch) {
                const channel_addr: u2 = @truncate((data & DATA.CHANNEL) >> 5);
                const is_attenuation = data & DATA.ATTENUATION != 0;
                const channel = &self.channel[channel_addr];
                self.channel_addr_latch = channel_addr;
                if (is_attenuation) {
                    const value: u4 = @truncate(data & DATA.VALUE_LOW);
                    channel.*.attenuation = @enumFromInt(value);
                } else {
                    switch (channel.*.generator) {
                        .tone => |*generator| {
                            const value: u4 = @truncate(data & DATA.VALUE_LOW);
                            updateToneLow(generator, value);
                        },
                        .noise => |*generator| {
                            const feedback: NOISE_FB = @enumFromInt(@as(u1, @truncate((data & DATA.NOISE_FB) >> 2)));
                            const divider: NOISE_DIVIDER = @enumFromInt(@as(u2, @truncate(data & DATA.NOISE_DIVIDER)));
                            updateNoise(generator, feedback, divider);
                        },
                    }
                }
            } else {
                const channel = &self.channel[self.channel_addr_latch];
                switch (channel.*.generator) {
                    .tone => |*generator| {
                        const value: u6 = @truncate(data & DATA.VALUE_HIGH);
                        updateToneHigh(generator, value);
                    },
                    .noise => {},
                }
            }
            return in_bus;
        }

        fn updateToneLow(generator: *Tone, value: u4) void {
            generator.*.divider = value;
        }

        fn updateToneHigh(generator: *Tone, value: u6) void {
            const divider = generator.*.divider;
            generator.*.divider = divider & @as(u10, DATA.VALUE_LOW) | (@as(u10, value) << 4);
        }

        fn updateNoise(generator: *Noise, feedback: NOISE_FB, divider: NOISE_DIVIDER) void {
            generator.*.last_feedback = generator.*.feedback;
            generator.*.feedback = feedback;
            generator.*.divider = divider;
        }
    };
}
