//!  gdg_whid65040_032.zig
//!
//!  Emulator of the GDG WHID 65040-032, a custom chip found in the SHARP MZ-800 computer.
//!  It is used mainly as CRT controller.
//!  The GDG acts as memory controller, too. We don't emulate that here.
//!
const chipz = @import("chipz");
const bitutils = chipz.common.bitutils;
const mask = bitutils.mask;
const maskm = bitutils.maskm;

/// GDG WHID 65040-032 pin declarations
pub const Pins = struct {
    /// Data bus
    DBUS: [8]comptime_int,
    /// Address bus (shared with lower Z80 address bus)
    ABUS: [8]comptime_int,
    M1: comptime_int,
    IORQ: comptime_int,
    /// Read
    RD: comptime_int,
    /// Write
    WR: comptime_int,
};

/// Default pin configuration (mainly useful for debugging)
pub const DefaultPins = Pins{
    .ABUS = .{ 0, 1, 2, 3, 4, 5, 6, 7 },
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
    const Bus = cfg.bus;

    return struct {
        const Self = @This();

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

        /// Color intensity helper function
        fn CI(i: u1) u8 {
            // Color intensity high
            const CI0: u8 = 0x78;
            // Color intensity low
            const CI1: u8 = 0xdf;
            return if (i == 0) CI0 else CI1;
        }

        fn colorIRGBtoABGR(i: u1, g: u1, r: u1, b: u1) u32 {
            return 0xff000000 | (@as(u8, b) * CI(i)) << 16 | (@as(u8, g) * CI(i)) << 8 | (@as(u8, r) * CI(i)) << 0;
        }

        /// Colors - the MZ-800 has 16 fixed colors.
        /// Color codes on the MZ-800 are IGRB (Intensity, Green, Red, Blue).
        /// NOTE: the colors in the emulation frame buffer are encoded in ABGR.
        pub const COLOR = struct {};
    };
}
