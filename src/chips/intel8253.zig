//! intel8253 -- emulates the Intel 8253 Programmable Interval Timer chip
//!    EMULATED PINS:
//!
//!                  +-----------+
//!            CS -->|           |<-- CLK0
//!            RD -->|           |<-- GATE0
//!            WR -->|   i8253   |--> OUT0
//!            A0 -->|           |
//!            A1 -->|           |<-- CLK1
//!                  |           |<-- GATE1
//!            D0 <->|           |--> OUT1
//!               ...|           |
//!            D7 <->|           |<-- CLK2
//!                  |           |<-- GATE2
//!                  |           |--> OUT2
//!                  +-----------+
//!
//! CLK0..2: count on falling edge
//! GATE0..2: enable/disable counting, depending on mode.
//!
//! NOTE: Mode 4 and Mode 5 are not implemented!
//!

const std = @import("std");
const chipz = @import("chipz");
const bitutils = chipz.common.bitutils;
const mask = bitutils.mask;
const maskm = bitutils.maskm;

pub const Pins = struct {
    RD: comptime_int, // read
    WR: comptime_int, // write
    CS: comptime_int, // chip select
    DBUS: [8]comptime_int, // data bus
    ABUS: [2]comptime_int, // address bus
    CLK0: comptime_int,
    GATE0: comptime_int,
    OUT0: comptime_int,
    CLK1: comptime_int,
    GATE1: comptime_int,
    OUT1: comptime_int,
    CLK2: comptime_int,
    GATE2: comptime_int,
    OUT2: comptime_int,
};

/// default pin configuration (mainly useful for debugging)
pub const DefaultPins = Pins{
    .RD = 27, // Read from PPI, shared with Z80 RD
    .WR = 28, // Write to PPI, shared with Z80 WR
    .CS = 40, // Chip select, PPI responds to RD/WR when active
    .ABUS = .{ 0, 1 }, // Shared with Z80 lowest address bus pins
    .DBUS = .{ 16, 17, 18, 19, 20, 21, 22, 23 }, // Shared with Z80 data bus
    .CLK0 = 48,
    .GATE0 = 49,
    .OUT0 = 50,
    .CLK1 = 51,
    .GATE1 = 52,
    .OUT1 = 53,
    .CLK2 = 54,
    .GATE2 = 55,
    .OUT2 = 56,
};

/// comptime type configuration for i8255 PPI
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
        pub const ABUS = maskm(Bus, &cfg.pins.ABUS);
        pub const A0 = mask(Bus, cfg.pins.ABUS[0]);
        pub const A1 = mask(Bus, cfg.pins.ABUS[1]);
        pub const RD = mask(Bus, cfg.pins.RD);
        pub const WR = mask(Bus, cfg.pins.WR);
        pub const CS = mask(Bus, cfg.pins.CS);
        pub const CLK0 = mask(Bus, cfg.pins.CLK0);
        pub const GATE0 = mask(Bus, cfg.pins.GATE0);
        pub const OUT0 = mask(Bus, cfg.pins.OUT0);
        pub const CLK1 = mask(Bus, cfg.pins.CLK1);
        pub const GATE1 = mask(Bus, cfg.pins.GATE1);
        pub const OUT1 = mask(Bus, cfg.pins.OUT1);
        pub const CLK2 = mask(Bus, cfg.pins.CLK2);
        pub const GATE2 = mask(Bus, cfg.pins.GATE2);
        pub const OUT2 = mask(Bus, cfg.pins.OUT2);

        /// Control word bits
        ///
        /// | C7 | C6 | C5 | C4 | C3 | C2 | C1 | C0 |
        ///
        /// C0: BCD - Counter number format:
        ///   0 binary counter 16 bits (0..65,536)
        ///   1 BCD counter (0..10,000)
        ///
        /// C1..C3: M - Mode control bits:
        ///   0 0 0 Mode 0: interrupt on terminal count (min: 1, max: 0, 0 executes 10000H count)
        ///   0 0 1 Mode 1: programmable one-shot  (min: 1, max: 0, 0 executes 10000H count)
        ///   0 1 0 Mode 2: rate generator  (min: 2, max: 0, 0 executes 10000H count, 1 cannot be counted)
        ///   0 1 1 Mode 3: square wave generator (min: 2, max: 1, 1 executes 10001H count)
        ///   1 0 0 Mode 4: software triggered strobe (min: 1, max: 0, 0 executes 10000H count)
        ///   1 0 1 Mode 5: hardware triggered strobe (min: 1, max: 0, 0 executes 10000H count)
        ///
        /// C4..C5: RW - Read/Write:
        ///   0 0 Counter latch command
        ///   0 1 R/W least significant byte only
        ///   1 0 R/W most significant byte only
        ///   1 1 R/W least significant byte first, the most significant byte.
        ///
        /// C6..C7: SC - Select Counter:
        ///   0 0 Select counter 0
        ///   0 1 Select counter 1
        ///   1 0 Select counter 2
        ///   1 1 Illegal
        ///
        pub const CTRL = struct {
            pub const BCD: u8 = 1;

            pub const MODE = struct {
                pub const MODE0: u8 = 0b000 << 1;
                pub const MODE1: u8 = 0b001 << 1;
                pub const MODE2: u8 = 0b010 << 1;
                pub const MODE3: u8 = 0b011 << 1;
                pub const MODE4: u8 = 0b100 << 1;
                pub const MODE5: u8 = 0b101 << 1;
            };

            pub const RW = struct {
                pub const LATCH: u8 = 0b00 << 4;
                pub const LSB: u8 = 0b01 << 4;
                pub const MSB: u8 = 0b10 << 4;
                pub const LSB_MSB: u8 = 0b11 << 4;
            };

            pub const SC = struct {
                pub const COUNTER0: u8 = 0b00 << 6;
                pub const COUNTER1: u8 = 0b01 << 6;
                pub const COUNTER2: u8 = 0b10 << 6;
                pub const ILLEGAL: u8 = 0b11 << 6;
            };

            // Reset state
            pub const RESET: u8 = 0;
        };

        pub const ABUS_MODE = struct {
            pub const COUNTER0: u2 = 0;
            pub const COUNTER1: u2 = 1;
            pub const COUNTER2: u2 = 2;
            pub const CTRL: u2 = 3;
        };

        pub const MODE = enum(u8) {
            MODE0 = 0, // Interrupt on Terminal Count
            MODE1, // Programmable One-Shot
            MODE2, // Rate Generator
            MODE3, // Square Wave Generator
            MODE4, // Software Triggered Strobe
            MODE5, // Hardware Triggered Strobe
        };

        pub const READ_LOAD_FORMAT = enum(u8) {
            LATCH,
            LSB, // Read/load LSB
            MSB, // Read/load MSB
            LSB_MSB, // Read/load LSB followed by MSB
        };

        pub const CounterID = enum(comptime_int) {
            C0 = 0,
            C1,
            C2,
        };

        pub const State = enum {
            init, // CW has been entered
            init_done, // CW has been entered followed by falling CLK
            load, // LOAD has started
            preset_error, // PRESET = 0x0001 in MODE2 - can't be calculated, setting VALUE again calls LOAD_DONE
            load_done, // LOAD is done, followed by PRESET regardless of GATE state
            wait_gate_high, // Waiting for GATE = 1
            preset, // preparation before starting reading, it can be recalled when GATE = 0, we put PRESET in VALUE
            preset32, // preparation before starting reading, it can be recalled when GATE = 0, we put the constant 32 in VALUE
            countdown, // subtract with target
            mode1_trigger_error, // MODE1: the trigger GATE = 0|1 arrived, but it was not LOAD_DONE yet, after the next LOAD completion, we call PRESET32
            blind_count, // subtract without target
        };

        pub const Counter = struct {
            clk: u1 = 0, // we tick the counter on falling edge of CLK
            out_pin: u7,
            out: u1 = 0,
            gate_pin: u7,
            gate: u1 = 0,
            mode: MODE = .MODE0,
            bcd: bool = false,
            read_load_format: READ_LOAD_FORMAT = .LSB_MSB,
            state: State = .init_done,
            load_done: bool = false,
            read_load_msb: bool = false,
            latch_operation: bool = false, // if true we need to set read_latch
            read_latch: u16 = 0,
            preset_value: u17 = 0xffff,
            preset_latch: u16 = 0,
            value: u17 = 0,
            mode3_destination_value: u17 = 0,
            mode3_half_value: u17 = 0,

            pub fn setOut(self: *Counter, value: u1, bus: Bus) Bus {
                self.out = value;
                return bus & ~(@as(Bus, 1) << self.out_pin) | @as(Bus, value) << self.out_pin;
            }

            pub fn setCLK(self: *Counter, value: u1, bus: Bus) Bus {
                if ((self.clk != value) and (value == 0)) {
                    self.clk = value;
                    return self.tick(bus);
                } else {
                    self.clk = value;
                    return bus;
                }
            }

            pub fn tick(self: *Counter, in_bus: Bus) Bus {
                var bus = in_bus;
                switch (self.mode) {
                    .MODE0 => {
                        switch (self.state) {
                            .countdown, .mode1_trigger_error, .blind_count => {
                                self.value -= 1;
                                if (self.value == 0) {
                                    bus = self.setOut(1, bus);
                                    self.state = .blind_count;
                                    self.value = 0xffff;
                                }
                                return bus;
                            },
                            .load_done => {
                                self.writeValue(@truncate(self.preset_value));
                                if (self.gate == 1) {
                                    self.state = .countdown;
                                } else {
                                    self.state = .wait_gate_high;
                                }
                                return bus;
                            },
                            else => {},
                        }
                    },
                    .MODE1 => {
                        switch (self.state) {
                            .blind_count => {
                                self.value -= 1;
                                if (self.value == 0) {
                                    self.value = 0xffff;
                                }
                                return bus;
                            },
                            .countdown => {
                                self.value -= 1;
                                if (self.value == 0) {
                                    bus = self.setOut(1, bus);
                                    if (self.gate == 1) {
                                        self.state = .blind_count;
                                    } else {
                                        self.state = .wait_gate_high;
                                    }
                                }
                                return bus;
                            },
                            .load_done => {
                                if (self.gate == 1) {
                                    self.state = .blind_count;
                                } else {
                                    self.state = .wait_gate_high;
                                }
                                return bus;
                            },
                            .preset => {
                                self.writeValue(@truncate(self.preset_value));
                                bus = self.setOut(0, bus);
                                self.state = .countdown;
                                return bus;
                            },
                            .preset32 => {
                                self.value = 32;
                                self.state = .countdown;
                                return bus;
                            },
                            else => {},
                        }
                    },
                    .MODE2 => {
                        switch (self.state) {
                            .countdown => {
                                self.value -= 1;
                                if (self.value == 0x0001) {
                                    bus = self.setOut(0, bus);
                                    self.state = .preset;
                                }
                                return bus;
                            },
                            .preset, .load_done => {
                                bus = self.setOut(1, bus);
                                self.writeValue(@truncate(self.preset_value));
                                if (self.value == 0x0001) {
                                    self.state = .preset_error;
                                } else {
                                    if (self.gate == 1) {
                                        self.state = .countdown;
                                    } else {
                                        self.state = .wait_gate_high;
                                    }
                                }
                                return bus;
                            },
                            else => {},
                        }
                    },
                    .MODE3 => {
                        switch (self.state) {
                            .countdown => {
                                self.value -= 1;
                                if (self.value == self.mode3_destination_value) {
                                    if (self.out == 1) {
                                        bus = self.setOut(0, bus);
                                        self.value = self.mode3_half_value;
                                        self.mode3_destination_value = 0;
                                    } else {
                                        bus = self.setOut(1, bus);
                                        self.writeValue(@truncate(self.preset_value));
                                        self.mode3_destination_value = self.mode3_half_value;
                                        if (self.gate == 1) {
                                            self.state = .countdown;
                                        } else {
                                            self.state = .wait_gate_high;
                                        }
                                    }
                                }
                                return bus;
                            },
                            .preset, .load_done => {
                                bus = self.setOut(1, bus);
                                self.writeValue(@truncate(self.preset_value));
                                self.mode3_destination_value = self.mode3_half_value;
                                if (self.gate == 1) {
                                    self.state = .countdown;
                                } else {
                                    self.state = .wait_gate_high;
                                }
                                return bus;
                            },
                            else => {},
                        }
                    },
                    .MODE4 => {
                        std.debug.panic("CTC MODE4 not implemented", .{});
                        return bus;
                    },
                    .MODE5 => {
                        std.debug.panic("CTC MODE5 not implemented", .{});
                        return bus;
                    },
                }

                if (self.state == .init) {
                    if (self.load_done == true) {
                        self.state = .load_done;
                        self.load_done = false;
                    } else {
                        self.state = .init_done;
                    }
                }
                return bus;
            }

            pub fn setGATE(self: *Counter, value: u1, in_bus: Bus) Bus {
                var bus = in_bus;
                if (self.gate == value) return bus;

                self.gate = value;
                if (self.state == .init) return bus;

                switch (self.mode) {
                    .MODE0 => {
                        if (self.gate == 0) {
                            self.state = .wait_gate_high;
                        } else {
                            if (self.out == 0) {
                                self.state = .countdown;
                            } else {
                                self.state = .blind_count;
                            }
                        }
                    },
                    .MODE1 => {
                        if (self.gate == 0) {
                            if (self.state == .blind_count) {
                                self.state = .wait_gate_high;
                            }
                        } else {
                            switch (self.state) {
                                .load_done, .wait_gate_high, .countdown => {
                                    self.state = .preset;
                                },
                                .init_done => {
                                    // GATE was set to high before LOAD was completed
                                    bus = self.setOut(0, bus);
                                    self.state = .mode1_trigger_error;
                                },
                                else => {},
                            }
                        }
                    },
                    .MODE2, .MODE3 => {
                        if (self.gate == 0) {
                            if ((self.state == .countdown) or (self.state == .preset)) {
                                bus = self.setOut(1, bus);
                                self.state = .wait_gate_high;
                            }
                        } else {
                            if (self.state == .wait_gate_high) {
                                self.state = .preset;
                            }
                        }
                    },
                    .MODE4 => {
                        std.debug.panic("CTC MODE4 not implemented", .{});
                    },
                    .MODE5 => {
                        std.debug.panic("CTC MODE5 not implemented", .{});
                    },
                }
                return bus;
            }

            /// Sets value interpreting given new_value as binary or BCD depending on the bcd flag
            fn writeValue(self: *Counter, new_value: u16) void {
                self.value = if (self.bcd) intFromBCD(new_value) else new_value;
            }

            /// Returns value in binary or BCD depending on the bcd flag.
            /// Uses value or read_latch depending on latch_operation flag.
            fn readValue(self: *Counter) u16 {
                const value = if (self.latch_operation) self.read_latch else self.value;
                return if (self.bcd) bcdFromInt(@truncate(value)) else @truncate(value);
            }

            pub fn writeControl(self: *Counter, bus: Bus) Bus {
                const data = getData(bus);
                const read_load_format: READ_LOAD_FORMAT = @enumFromInt((data >> 4) & 0b11);
                self.read_load_msb = false;
                if (read_load_format == .LATCH) {
                    self.latch_operation = true;
                    self.read_latch = @truncate(self.value);
                    return bus;
                }

                self.latch_operation = false;
                self.read_load_format = read_load_format;
                const raw_mode = (data >> 1) & 0b111;
                self.mode = @enumFromInt(if (raw_mode > 5) (raw_mode & 0b101) else raw_mode);
                self.bcd = (data & 0b1) == 1;
                self.state = .init;
                self.load_done = false;
                const output: u1 = if (self.mode == .MODE0) 0 else 1;
                return self.setOut(output, bus);
            }

            pub fn writeData(self: *Counter, in_bus: Bus) Bus {
                var bus = in_bus;
                const data = getData(in_bus);
                self.latch_operation = false;
                if ((self.mode == .MODE0) and (self.state != .init) and (self.state != .init_done)) {
                    self.state = .load;
                    bus = self.setOut(0, bus);
                }

                switch (self.read_load_format) {
                    .LSB => {
                        self.preset_latch = data;
                    },
                    .MSB => {
                        self.preset_latch = @as(u16, data) << 8;
                    },
                    .LSB_MSB => {
                        if (self.read_load_msb == false) {
                            self.preset_latch = data;
                            self.read_load_msb = true;
                        } else {
                            self.preset_latch |= @as(u16, data) << 8;
                            self.read_load_msb = false;
                        }
                    },
                    else => {},
                }
                self.preset_value = if (self.preset_latch == 0) 0x10000 else self.preset_latch;
                if (self.mode == .MODE3) {
                    if (self.preset_value == 1) {
                        self.preset_value = 0x10001;
                    }
                    self.mode3_half_value = self.preset_value;
                    if ((self.mode3_half_value & 1) == 1) {
                        self.mode3_half_value += 1;
                    }
                    self.mode3_half_value >>= 1;
                }

                // LOAD completed
                switch (self.state) {
                    .init => {
                        self.load_done = true;
                    },
                    .init_done, .load, .preset_error => {
                        self.state = .load_done;
                    },
                    .mode1_trigger_error => {
                        self.state = .preset32;
                    },
                    else => {},
                }
                return bus;
            }

            pub fn readData(self: *Counter, in_bus: Bus) Bus {
                var bus = in_bus;
                const value = self.readValue();
                var result: u8 = 0;

                switch (self.read_load_format) {
                    .LSB => {
                        self.latch_operation = false;
                        result = @truncate(value);
                    },
                    .MSB => {
                        self.latch_operation = false;
                        result = @truncate(value >> 8);
                    },
                    .LSB_MSB => {
                        if (self.read_load_msb == false) {
                            self.read_load_msb = true;
                            result = @truncate(value);
                        } else {
                            self.read_load_msb = false;
                            self.latch_operation = false;
                            result = @truncate(value >> 8);
                        }
                    },
                    else => {
                        return bus;
                    },
                }
                bus = setData(bus, result);
                return bus;
            }
        };

        counter: [3]Counter = .{
            .{
                .out_pin = cfg.pins.OUT0,
                .gate_pin = cfg.pins.GATE0,
            },
            .{
                .out_pin = cfg.pins.OUT1,
                .gate_pin = cfg.pins.GATE1,
            },
            .{
                .out_pin = cfg.pins.OUT2,
                .gate_pin = cfg.pins.GATE2,
            },
        },
        control: u8 = 0,
        reset_active: bool = false,

        /// Get data bus value
        pub inline fn getData(bus: Bus) u8 {
            return @truncate(bus >> cfg.pins.DBUS[0]);
        }

        /// Set data bus value
        pub inline fn setData(bus: Bus, data: u8) Bus {
            return (bus & ~DBUS) | (@as(Bus, data) << cfg.pins.DBUS[0]);
        }

        /// Get data ABUS value
        pub inline fn getABUS(bus: Bus) u2 {
            return @truncate(bus >> cfg.pins.ABUS[0]);
        }

        /// Set data ABUS value
        pub inline fn setABUS(bus: Bus, data: u2) Bus {
            return (bus & ~ABUS) | (@as(Bus, data) << cfg.pins.ABUS[0]);
        }

        /// Return an initialized CTC instance
        pub fn init() Self {
            var self: Self = .{};
            self.reset();
            return self;
        }

        /// Reset CTC instance
        pub fn reset(self: *Self) void {
            self.reset_active = true;
        }

        /// Execute one clock cycle
        pub fn tick(self: *Self, in_bus: Bus) Bus {
            var bus = in_bus;
            if ((bus & CS) != 0) {
                if ((bus & RD) != 0) {
                    bus = self.read(bus);
                } else if ((bus & WR) != 0) {
                    bus = self.write(bus);
                }
            }
            return bus;
        }

        /// Set CLK of counter to value on the bus
        pub fn setCLK0(self: *Self, bus: Bus) Bus {
            const value: u1 = if ((bus & CLK0) != 0) 1 else 0;
            return self.counter[0].setCLK(value, bus);
        }

        /// Set CLK of counter to value on the bus
        pub fn setCLK1(self: *Self, bus: Bus) Bus {
            const value: u1 = if ((bus & CLK1) != 0) 1 else 0;
            return self.counter[1].setCLK(value, bus);
        }

        /// Set CLK of counter to value on the bus
        pub fn setCLK2(self: *Self, bus: Bus) Bus {
            const value: u1 = if ((bus & CLK2) != 0) 1 else 0;
            return self.counter[2].setCLK(value, bus);
        }

        /// Set GATE of counter to value on the bus
        pub fn setGATE0(self: *Self, bus: Bus) Bus {
            const value: u1 = if ((bus & GATE0) != 0) 1 else 0;
            return self.counter[0].setGATE(value, bus);
        }

        /// Set GATE of counter to value on the bus
        pub fn setGATE1(self: *Self, bus: Bus) Bus {
            const value: u1 = if ((bus & GATE1) != 0) 1 else 0;
            return self.counter[1].setGATE(value, bus);
        }

        /// Set GATE of counter to value on the bus
        pub fn setGATE2(self: *Self, bus: Bus) Bus {
            const value: u1 = if ((bus & GATE2) != 0) 1 else 0;
            return self.counter[2].setGATE(value, bus);
        }

        /// Write a value to the CTC
        pub fn write(self: *Self, in_bus: Bus) Bus {
            const data = getData(in_bus);
            const addr = getABUS(in_bus);
            switch (addr) {
                ABUS_MODE.CTRL => {
                    const sc = data & 0b11000000;
                    if (sc == CTRL.SC.ILLEGAL) return in_bus;
                    const cs = sc >> 6;
                    return self.counter[cs].writeControl(in_bus);
                },
                else => {
                    const cs = addr;
                    return self.counter[cs].writeData(in_bus);
                },
            }
        }

        // Read a value from the CTC
        pub fn read(self: *Self, in_bus: Bus) Bus {
            const addr = getABUS(in_bus);
            switch (addr) {
                ABUS_MODE.COUNTER0, ABUS_MODE.COUNTER1, ABUS_MODE.COUNTER2 => {
                    return self.counter[addr].readData(in_bus);
                },
                else => {},
            }
            return in_bus;
        }
    };
}

pub fn intFromBCD(bcd: u16) u16 {
    var result: u16 = 0;
    var exp: u16 = 1;
    for (0..4) |index| {
        const digit = (bcd >> @intCast(index * 4)) & 0xf;
        result += digit * exp;
        exp *= 10;
    }
    return result;
}

pub fn bcdFromInt(in_int: u16) u16 {
    var int = in_int;
    var result: u16 = 0;
    for (0..4) |index| {
        const digit = int % 10;
        int = int / 10;
        result += digit << @intCast(index * 4);
    }
    return result;
}
