//!  gdg_whid65040_032.zig
//!
//!  Emulator of the GDG WHID 65040-032, a custom chip found in the SHARP MZ-800 computer.
//!  It is used mainly as CRT controller.
//!  The GDG acts as memory controller, too. We don't emulate that here.
//!
const std = @import("std");
const chipz = @import("chipz");
const bitutils = chipz.common.bitutils;
const mask = bitutils.mask;
const maskm = bitutils.maskm;

/// GDG WHID 65040-032 pin declarations
pub const Pins = struct {
    /// Data bus
    DBUS: [8]comptime_int,
    /// Address bus (shared with lower Z80 address bus)
    ABUS: [16]comptime_int,
    M1: comptime_int,
    IORQ: comptime_int,
    /// Read
    RD: comptime_int,
    /// Write
    WR: comptime_int,
};

/// Default pin configuration (mainly useful for debugging)
pub const DefaultPins = Pins{
    .ABUS = .{ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15 },
    .DBUS = .{ 16, 17, 18, 19, 20, 21, 22, 23 },
    .M1 = 24,
    .IORQ = 26,
    .RD = 27,
    .WR = 28,
};

/// Comptime type configuration for GDG
pub const TypeConfig = struct {
    pins: Pins,
    bus: type,
};

pub fn Type(comptime cfg: TypeConfig) type {
    return struct {
        const Self = @This();
        const Bus = cfg.bus;

        pub const Options = struct {
            cgrom: []const u8,
            rgba8_buffer: [FRAMEBUFFER_SIZE_PIXEL]u32,
        };

        pub const DBUS = maskm(Bus, &cfg.pins.DBUS);
        pub const ABUS = maskm(Bus, &cfg.pins.ABUS);
        pub const M1 = mask(Bus, cfg.pins.M1);
        pub const IOREQ = mask(Bus, cfg.pins.IORQ);
        pub const RD = mask(Bus, cfg.pins.RD);
        pub const WR = mask(Bus, cfg.pins.WR);

        /// IO addresses of the GDG registers
        pub const IO_ADDR = struct {
            /// Registers that can be written by CPU
            pub const IN = struct {
                /// Write format register (writing to VRAM)
                pub const WF: u16 = 0x00cc;
                /// Read format register (reading from VRAM)
                pub const RF: u16 = 0x00cd;
                /// Display mode register
                pub const DMD: u16 = 0x00ce;
                /// Scroll offset 1 register
                pub const SOF1: u16 = 0x01cf;
                /// Scroll offset 2 register
                pub const SOF2: u16 = 0x02cf;
                /// Scroll width register
                pub const SW: u16 = 0x03cf;
                /// Scroll start address register
                pub const SSA: u16 = 0x04cf;
                /// Scroll end address register
                pub const SEA: u16 = 0x05cf;
                /// Border color register
                pub const BCOL: u16 = 0x06cf;
                /// Clock switch register
                pub const CKSW: u16 = 0x07cf;
                /// Palette register
                pub const PAL: u16 = 0x00f0;
            };
            /// Registers that can be read by CPU
            pub const OUT = struct {
                pub const STATUS: u16 = 0x00ce;
            };
        };

        /// Write format register
        pub const WF_MODE = struct {
            pub const PLANE_I: u8 = 1 << 0;
            pub const PLANE_II: u8 = 1 << 1;
            pub const PLANE_III: u8 = 1 << 2;
            pub const PLANE_IV: u8 = 1 << 3;
            pub const FRAME_B: u8 = 1 << 4;
            /// Write format mode
            pub const WMD_MASK = maskm(u8, .{ 5, 6, 7 });
            pub const WMD = struct {
                pub const SINGLE: u8 = 0b000 << 5;
                pub const XOR: u8 = 0b001 << 5;
                pub const OR: u8 = 0b010 << 5;
                pub const RESET: u8 = 0b011 << 5;
                pub const REPLACE0: u8 = 0b100 << 5;
                pub const REPLACE1: u8 = 0b101 << 5;
                pub const PSET0: u8 = 0b110 << 5;
                pub const PSET1: u8 = 0b111 << 5;
            };
        };

        /// Read format register
        pub const RF_MODE = struct {
            pub const PLANE_I: u8 = 1 << 0;
            pub const PLANE_II: u8 = 1 << 1;
            pub const PLANE_III: u8 = 1 << 2;
            pub const PLANE_IV: u8 = 1 << 3;
            pub const FRAME_B: u8 = 1 << 4;
            pub const SEARCH: u8 = 1 << 7;
        };

        /// Display mode register
        pub const DMD_MODE = struct {
            pub const HIRES: u4 = 1 << 2;
            pub const HICOLOR: u4 = 1 << 1;
            pub const FRAME_B: u4 = 1 << 0;
            pub const MZ700: u4 = 1 << 3;
        };

        /// Status register
        pub const STATUS_MODE = struct {
            pub const MZ800: u8 = 1 << 1;
        };

        /// Color intensity helper function
        fn CI(i: u1) u8 {
            // Color intensity high
            const CI0: u8 = 0x78;
            // Color intensity low
            const CI1: u8 = 0xdf;
            return if (i == 0) CI0 else CI1;
        }

        fn colorIRGBtoABGR(i: u1, g: u1, r: u1, b: u1) u32 {
            var result: u32 = 0xff000000;
            result |= @as(u32, (@as(u8, b) * CI(i))) << 16;
            result |= @as(u32, (@as(u8, g) * CI(i))) << 8;
            result |= @as(u32, (@as(u8, r) * CI(i))) << 0;
            return result;
        }

        /// Colors - the MZ-800 has 16 fixed colors.
        /// Color codes on the MZ-800 are IGRB (Intensity, Green, Red, Blue).
        /// NOTE: the colors in the emulation frame buffer are encoded in ABGR.
        pub const COLOR = struct {
            // Intensity low
            pub const black = colorIRGBtoABGR(0, 0, 0, 0); // 0000 black
            pub const blue = colorIRGBtoABGR(0, 0, 0, 1); // 0001 blue
            pub const red = colorIRGBtoABGR(0, 0, 1, 0); // 0010 red
            pub const purple = colorIRGBtoABGR(0, 0, 1, 1); // 0011 purple
            pub const green = colorIRGBtoABGR(0, 1, 0, 0); // 0100 green
            pub const cyan = colorIRGBtoABGR(0, 1, 0, 1); // 0101 cyan
            pub const yellow = colorIRGBtoABGR(0, 1, 1, 0); // 0110 yellow
            pub const white = colorIRGBtoABGR(0, 1, 1, 1); // 0111 white
            // Intensity high
            pub const gray = colorIRGBtoABGR(1, 0, 0, 0); // 1000 gray
            pub const light_blue = colorIRGBtoABGR(1, 0, 0, 1); // 1001 light blue
            pub const light_red = colorIRGBtoABGR(1, 0, 1, 0); // 1010 light red
            pub const light_purple = colorIRGBtoABGR(1, 0, 1, 1); // 1011 light purple
            pub const light_green = colorIRGBtoABGR(1, 1, 0, 0); // 1100 light green
            pub const light_cyan = colorIRGBtoABGR(1, 1, 0, 1); // 1101 light cyan
            pub const light_yellow = colorIRGBtoABGR(1, 1, 1, 0); // 1110 light yellow
            pub const light_white = colorIRGBtoABGR(1, 1, 1, 1); // 1111 light white

            pub const all = [16]u32{ black, blue, red, purple, green, cyan, yellow, white, gray, light_blue, light_red, light_purple, light_green, light_cyan, light_yellow, light_white };
        };

        /// Palette size
        const PALETTE_SIZE = 4;

        /// Size of physical VRAM bank (two can be installed)
        const VRAM_SIZE = 0x4000; // 16K
        /// VRAM plane offset, used to calculate VRAM addresses
        const VRAM_PLANE_OFFSET = 0x2000;

        // Display size
        pub const DISPLAY_WIDTH = 640;
        pub const DISPLAY_HEIGHT = 200;
        pub const FRAMEBUFFER_SIZE_PIXEL = DISPLAY_WIDTH * DISPLAY_HEIGHT;

        // GDG Registers

        /// Write format register (writing to VRAM)
        wf: u8 = 0,
        /// Read format register (reading from VRAM)
        rf: u8 = 0,
        /// Display mode register
        dmd: u8 = 0,
        /// Display status register
        /// BLNK, SYNC, SW1 Mode switch, TEMPO
        status: u8 = 0,
        /// Scroll Registers need to be set in increments of 0x5.
        /// Scroll offsets have a range from 0x0 to 0x3e8, stored
        /// as 10 bit number in two registers SOF1 and SOF2.
        /// Scroll offset 1 register
        sof1: u8 = 0,
        /// Scroll offset 2 register
        sof2: u8 = 0,
        /// Scroll width register (0x0 to 0x7d)
        sw: u8 = 0,
        /// Scroll start address register (0x0 to 0x78)
        ssa: u8 = 0,
        /// Scroll end address register (0x5 to 0x7d)
        sea: u8 = 0,
        /// Border color register
        bcol: u8 = 0,
        /// Palette registers
        plt: [PALETTE_SIZE]u4 = [_]u4{0} ** PALETTE_SIZE,
        /// Palette switch register (for 16 color mode)
        plt_sw: u2 = 0,

        // VRAM
        // In MZ-700 mode: Starting at 0x0000 each byte corresponds to a character (40x25).
        // Starting at 0x0800 each byte corresponds to a color code that controls the color
        // for each character and its background. Bit 7 controls if the alternative character set
        // should be used for that character.
        // In MZ-800 Mode: one byte for each pixel, we need only 4 bit per pixel.
        // Each bit corresponds to a pixel on planes I, II, III, IV.

        /// VRAM bank 1
        vram1: [VRAM_SIZE]u8 = [_]u8{0} ** VRAM_SIZE,
        /// VRAM bank 2 (only available if VRAM extension is installed).
        vram2: [VRAM_SIZE]u8 = [_]u8{0} ** VRAM_SIZE,

        /// CGROM contains bitmapped character shapes.
        cgrom: []const u8,

        /// RGBA8 buffer for displaying color graphics on screen.
        /// Uses 8bit color components.
        rgba8_buffer: [FRAMEBUFFER_SIZE_PIXEL]u32,

        /// Indicates if machine is in MZ-700 mode. This is actually toggled by setting the DMD register.
        is_mz700: bool = false,

        /// Get data bus value
        pub inline fn getData(bus: Bus) u8 {
            return @truncate(bus >> cfg.pins.DBUS[0]);
        }

        /// Set data bus value
        pub inline fn setData(bus: Bus, data: u8) Bus {
            return (bus & ~DBUS) | (@as(Bus, data) << cfg.pins.DBUS[0]);
        }

        /// Get data ABUS value
        pub inline fn getABUS(bus: Bus) u16 {
            return @truncate(bus >> cfg.pins.ABUS[0]);
        }

        /// Set data ABUS value
        pub inline fn setABUS(bus: Bus, data: u16) Bus {
            return (bus & ~ABUS) | (@as(Bus, data) << cfg.pins.ABUS[0]);
        }

        /// Return an initialized GDG instance
        pub fn init(opts: Options) Self {
            var self = Self{
                .cgrom = opts.cgrom,
                .rgba8_buffer = opts.rgba8_buffer,
            };
            self.reset();
            return self;
        }

        /// Reset GDG instance
        pub fn reset(self: *Self) void {
            self.wf = 0;
            self.rf = 0;
            self.status = 0; // needs to be set before setting DMD
            self.set_dmd(0);
            self.sof1 = 0;
            self.sof2 = 0;
            self.sw = 0;
            self.ssa = 0;
            self.sea = 0;
            self.bcol = 0;
            self.plt = std.mem.zeroes(@TypeOf((self.plt)));
            self.plt_sw = 0;
            self.vram1 = std.mem.zeroes(@TypeOf((self.vram1)));
            self.vram2 = std.mem.zeroes(@TypeOf((self.vram2)));
            self.rgba8_buffer = std.mem.zeroes(@TypeOf(self.rgba8_buffer));
        }

        pub fn set_dmd(self: *Self, value: u8) void {
            self.dmd = value;
            self.is_mz700 = (value & 0x0f) == DMD_MODE.MZ700;
            if (self.is_mz700) {
                self.status &= ~STATUS_MODE.MZ800;
            } else {
                self.status |= STATUS_MODE.MZ800;
            }
        }
    };
}
