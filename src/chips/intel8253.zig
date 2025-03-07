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
                pub const READ_BACK: u8 = 0b11 << 6;
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

        counter0: u16 = 0,
        counter1: u16 = 0,
        counter2: u16 = 0,
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
                    self.write(bus);
                }
            }
            bus = self.write_ports(bus);
            return bus;
        }

        /// Write a value to the CTC
        pub fn write(self: *Self, bus: Bus) void {
            // const data = getData(bus);
            _ = self;
            switch (getABUS(bus)) {
                ABUS_MODE.COUNTER0 => {
                    // Write to counter 0
                },
                else => {},
            }
        }

        // Read a value from the CTC
        fn read(self: *Self, bus: Bus) Bus {
            const data: u8 = 0xff;
            _ = self;
            switch (getABUS(bus)) {
                else => {},
            }
            return setData(bus, data);
        }

        // Write ports to bus
        fn write_ports(self: *Self, in_bus: Bus) Bus {
            self.reset_active = false;
            const bus = in_bus;

            return bus;
        }
    };
}
