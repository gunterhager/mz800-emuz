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
        pub const IORQ = mask(Bus, cfg.pins.IORQ);
        pub const RD = mask(Bus, cfg.pins.RD);
        pub const WR = mask(Bus, cfg.pins.WR);

        /// IO addresses of the GDG registers
        pub const IO_ADDR = struct {
            /// Registers that can be written by CPU
            pub const WR = struct {
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
            pub const RD = struct {
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
            pub const WMD_MASK = maskm(u8, &[_]comptime_int{ 5, 6, 7 });
            pub const WMD = struct {
                pub const SINGLE: u3 = 0b000;
                pub const XOR: u3 = 0b001;
                pub const OR: u3 = 0b010;
                pub const RESET: u3 = 0b011;
                pub const REPLACE0: u3 = 0b100;
                pub const REPLACE1: u3 = 0b101;
                pub const PSET0: u3 = 0b110;
                pub const PSET1: u3 = 0b111;
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
        pub const PALETTE_SIZE = 4;

        pub const PAL_SW: u8 = 1 << 7;

        /// Size of physical VRAM bank (two can be installed)
        pub const VRAM_SIZE = 0x4000; // 16K
        /// VRAM plane offset, used to calculate VRAM addresses
        pub const VRAM_PLANE_OFFSET = 0x2000;
        /// Last available VRAM address in MZ-700 mode
        pub const VRAM_MAX_MZ700_ADDR: u16 = 0x1f3f;

        pub const VRAM_MAX_LORES_ADDR: u16 = 0x1f3f;
        pub const VRAM_MAX_HIRES_ADDR: u16 = 0x3e7f;

        /// Value we get when reading from illegal memory address
        pub const ILLEGAL_READ_VALUE: u8 = 0xff;

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
        /// Palette registers in RGBA8 format
        plt_rgba8: [PALETTE_SIZE]u32 = [_]u32{0} ** PALETTE_SIZE,
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

        /// Execute one clock cycle
        pub fn tick(self: *Self, in_bus: Bus) Bus {
            return self.iorq(in_bus);
        }

        pub fn set_wf(self: *Self, value: u8) void {
            self.wf = value;
            // Frame flag is shared between WF and RF registers
            const frame = value & WF_MODE.FRAME_B;
            self.rf |= frame;
        }

        pub fn set_rf(self: *Self, value: u8) void {
            // Bits 5 and 6 can't be set
            self.rf = value & (~(@as(u8, 1) << 6 | @as(u8, 1) << 5));
            // Frame flag is shared between WF and RF registers
            const frame = value & RF_MODE.FRAME_B;
            self.wf |= frame;
        }

        /// Perform an IORQ machine cycle
        fn iorq(self: *Self, in_bus: Bus) Bus {
            var bus = in_bus;
            const addr = getABUS(bus);
            const low_addr = addr & 0xff;
            const value = getData(bus);
            switch (bus & (IORQ | M1 | RD | WR)) {
                // Read
                IORQ | RD => {
                    // Display status register
                    if (low_addr == IO_ADDR.RD.STATUS) {
                        bus = setData(bus, self.status);
                    }
                },
                // Write
                IORQ | WR => {
                    switch (low_addr) {
                        // Write format register
                        IO_ADDR.WR.WF => {
                            self.set_wf(value);
                        },
                        // Read format register
                        IO_ADDR.WR.RF => {
                            self.set_rf(value);
                        },
                        // Display mode register
                        IO_ADDR.WR.DMD => {
                            self.set_dmd(value);
                        },
                        // Scroll registers and border color register share the same lower address
                        (IO_ADDR.WR.SOF1 & 0xff) => {
                            switch (addr) {
                                // Scroll offset register 1
                                IO_ADDR.WR.SOF1 => {
                                    self.sof1 = value;
                                },
                                // Scroll offset register 2
                                IO_ADDR.WR.SOF2 => {
                                    // only the two lowest bits can be set
                                    self.sof2 = value & 0x03;
                                },
                                // Scroll width register
                                IO_ADDR.WR.SW => {
                                    // Bit 7 can't be set
                                    self.sw = value & (~(1 << 7));
                                },
                                // Scroll start address register
                                IO_ADDR.WR.SSA => {
                                    // Bit 7 can't be set
                                    self.ssa = value & (~(1 << 7));
                                },
                                // Scroll end address register
                                IO_ADDR.WR.SEA => {
                                    // Bit 7 can't be set
                                    self.sea = value & (~(1 << 7));
                                },
                                // Border color register
                                IO_ADDR.WR.BCOL => {
                                    // Only lower nibble can be set
                                    self.bcol = value & 0x0f;
                                },
                            }
                        },
                        IO_ADDR.WR.PAL => {
                            // Set palette switch register
                            if ((value & PAL_SW) != 0) {
                                // Two lowest bits contain the palette switch value.
                                self.plt_sw = value & ((1 << 1) | 1);
                            } else {
                                // High 3 bits contain palette register index
                                const index: comptime_int = value >> 4;
                                // Lower nibble contains color code in IRGB
                                const color: u4 = value & 0x0f;
                                // Set palette register to color
                                self.plt[index] = color;
                                self.plt_rgba8[index] = COLOR.all[color];
                            }
                        },
                    }
                },
                else => {},
            }
            return bus;
        }

        /// Set display mode register.
        /// This sets also the MZ800/MZ700 mode flags.
        pub fn set_dmd(self: *Self, value: u8) void {
            // Only the lower nibble can be set
            self.dmd = value & 0x0f;
            self.is_mz700 = (value & 0x0f) == DMD_MODE.MZ700;
            if (self.is_mz700) {
                self.status &= ~STATUS_MODE.MZ800;
            } else {
                self.status |= STATUS_MODE.MZ800;
            }
        }

        /// Translate address bus to VRAM addresses in hires mode.
        fn hires_vram_addr(addr: u16) u16 {
            // In hires VRAM addresses are spread over two planes.
            // Even addresses goto lower and odd to higher planes.
            // Therefore we shift down the address and add the correct
            // plane offset depending on the parity.
            return (addr >> 1) + (if ((addr & 1) == 1) @as(u16, 0x2000) else @as(u16, 0x0000));
        }

        /// Plane data helper
        fn p_data(selected: bool, data: u8) u8 {
            return (if (selected) data else ~data);
        }

        /// Read a byte from VRAM. The meaning of the bits in the byte depend on
        /// the read format register of the GDG.
        pub fn mem_rd(self: *Self, addr: u16) u8 {
            if (self.is_mz700) {
                if ((self.rf != RF_MODE.PLANE_I) or (addr > VRAM_MAX_MZ700_ADDR)) {
                    return ILLEGAL_READ_VALUE;
                } else {
                    return self.vram1[addr];
                }
            } else {
                const hires = (self.dmd & DMD_MODE.HIRES) != 0;
                const hicolor = (self.dmd & DMD_MODE.HICOLOR) != 0;

                if (addr > (if (hires) VRAM_MAX_HIRES_ADDR else VRAM_MAX_LORES_ADDR)) {
                    return ILLEGAL_READ_VALUE;
                }

                // Read flags
                const is_searching = (self.rf & RF_MODE.SEARCH) != 0;
                const is_frameB = (self.rf & RF_MODE.FRAME_B) != 0;
                const is_planeI = (self.rf & RF_MODE.PLANE_I) != 0;
                const is_planeII = (self.rf & RF_MODE.PLANE_II) != 0;
                const is_planeIII = (self.rf & RF_MODE.PLANE_III) != 0;
                const is_planeIV = (self.rf & RF_MODE.PLANE_IV) != 0;

                // Plane data
                var planeI_data: u8 = ILLEGAL_READ_VALUE;
                var planeII_data: u8 = ILLEGAL_READ_VALUE;
                var planeIII_data: u8 = ILLEGAL_READ_VALUE;
                var planeIV_data: u8 = ILLEGAL_READ_VALUE;
                if (hires) {
                    planeI_data = self.vram1[hires_vram_addr(addr)];
                    planeIII_data = self.vram2[hires_vram_addr(addr)];
                } else {
                    planeI_data = self.vram1[addr];
                    planeII_data = self.vram1[addr + VRAM_PLANE_OFFSET];
                    planeIII_data = self.vram2[addr];
                    planeIV_data = self.vram2[addr + VRAM_PLANE_OFFSET];
                }

                if (is_searching) {
                    if (hires) {
                        const pI = p_data(is_planeI, planeI_data);
                        if (hicolor) {
                            const pIII = p_data(is_planeIII, planeIII_data);
                            return pI & pIII;
                        } else {
                            return pI;
                        }
                    } else {
                        if (hicolor) {
                            const pI = p_data(is_planeI, planeI_data);
                            const pII = p_data(is_planeII, planeII_data);
                            const pIII = p_data(is_planeIII, planeIII_data);
                            const pIV = p_data(is_planeIV, planeIV_data);
                            return pI & pII & pIII & pIV;
                        } else {
                            if (is_frameB) {
                                const pIII = p_data(is_planeIII, planeIII_data);
                                const pIV = p_data(is_planeIV, planeIV_data);
                                return pIII & pIV;
                            } else {
                                const pI = p_data(is_planeI, planeI_data);
                                const pII = p_data(is_planeII, planeII_data);
                                return pI & pII;
                            }
                        }
                    }
                } else {
                    // Single color read
                    if (is_planeI) {
                        return planeI_data;
                    }
                    if (is_planeII) {
                        return planeII_data;
                    }
                    if (is_planeIII) {
                        return planeIII_data;
                    }
                    if (is_planeIV) {
                        return planeIV_data;
                    }
                    return ILLEGAL_READ_VALUE;
                }
            }
        }

        /// Perform the actual write to VRAM depending on the write mode register.
        fn mem_wr_op(write_mode: u3, vram_ptr: *u8, data: u8, plane_enabled: bool) void {
            switch (write_mode) {
                WF_MODE.WMD.SINGLE => {
                    if (plane_enabled) {
                        vram_ptr.* = data;
                    }
                },
                WF_MODE.WMD.XOR => {
                    if (plane_enabled) {
                        vram_ptr.* = data ^ vram_ptr.*;
                    }
                },
                WF_MODE.WMD.OR => {
                    if (plane_enabled) {
                        vram_ptr.* = data | vram_ptr.*;
                    }
                },
                WF_MODE.WMD.RESET => {
                    if (plane_enabled) {
                        vram_ptr.* = ~data & vram_ptr.*;
                    }
                },
                WF_MODE.WMD.REPLACE0, WF_MODE.WMD.REPLACE1 => {
                    vram_ptr.* = if (plane_enabled) data else 0x00;
                },
                WF_MODE.WMD.PSET0, WF_MODE.WMD.PSET1 => {
                    if (plane_enabled) {
                        vram_ptr.* = data | vram_ptr.*;
                    } else {
                        vram_ptr.* = ~data & vram_ptr.*;
                    }
                },
            }
        }

        /// Write a byte to VRAM. What gets actually written depends on the
        /// write format register of the GDG and the display mode.
        /// Pixel data will also be written to the RGBA8 buffer.
        pub fn mem_wr(self: *Self, addr: u16, data: u8) void {
            if (self.is_mz700) {
                if ((self.wf != RF_MODE.PLANE_I) or (addr > VRAM_MAX_MZ700_ADDR)) {
                    return;
                } else {
                    self.vram1[addr] = data;
                }
            } else {
                const hires = (self.dmd & DMD_MODE.HIRES) != 0;
                const hicolor = (self.dmd & DMD_MODE.HICOLOR) != 0;

                if (addr > (if (hires) VRAM_MAX_HIRES_ADDR else VRAM_MAX_LORES_ADDR)) {
                    return;
                }

                // Write flags
                const write_mode: u3 = @truncate((self.wf & WF_MODE.WMD_MASK) >> 5);
                const is_frameB = (self.wf & WF_MODE.FRAME_B) != 0;
                const is_planeI = (self.wf & WF_MODE.PLANE_I) != 0;
                const is_planeII = (self.wf & WF_MODE.PLANE_II) != 0;
                const is_planeIII = (self.wf & WF_MODE.PLANE_III) != 0;
                const is_planeIV = (self.wf & WF_MODE.PLANE_IV) != 0;

                // Write into VRAM
                if (hires) {
                    if (hicolor) {
                        mem_wr_op(write_mode, &self.vram1[hires_vram_addr(addr)], data, is_planeI);
                        mem_wr_op(write_mode, &self.vram2[hires_vram_addr(addr)], data, is_planeIII);
                    } else {
                        if (is_frameB) {
                            mem_wr_op(write_mode, &self.vram2[hires_vram_addr(addr)], data, is_planeIII);
                        } else {
                            mem_wr_op(write_mode, &self.vram1[hires_vram_addr(addr)], data, is_planeI);
                        }
                    }
                } else {
                    if (hicolor) {
                        mem_wr_op(write_mode, &self.vram1[addr], data, is_planeI);
                        mem_wr_op(write_mode, &self.vram1[addr + VRAM_PLANE_OFFSET], data, is_planeII);
                        mem_wr_op(write_mode, &self.vram2[addr], data, is_planeIII);
                        mem_wr_op(write_mode, &self.vram2[addr + VRAM_PLANE_OFFSET], data, is_planeIV);
                    } else {
                        if (is_frameB) {
                            mem_wr_op(write_mode, &self.vram2[addr], data, is_planeIII);
                            mem_wr_op(write_mode, &self.vram2[addr + VRAM_PLANE_OFFSET], data, is_planeIV);
                        } else {
                            mem_wr_op(write_mode, &self.vram1[addr], data, is_planeI);
                            mem_wr_op(write_mode, &self.vram1[addr + VRAM_PLANE_OFFSET], data, is_planeII);
                        }
                    }
                }
            }
            // Decode VRAM into RGBA8 buffer
            self.decode_vram(addr);
        }

        /// Decode one byte of VRAM into the RGBA8 buffer.
        fn decode_vram(self: *Self, addr: u16) void {
            if (self.is_mz700) {
                self.decode_vram_mz700(addr);
            } else {
                self.decode_vram_mz800(addr);
            }
        }

        /// Decode one byte of VRAM into the RGBA8 buffer in MZ-700 mode.
        fn decode_vram_mz700(self: *Self, addr: u16) void {
            // Convert addr to address offsets in character VRAM and color VRAM
            // Character range: 0x0000 - 0x03f7
            const character_code_addr: u16 = if (addr >= 0x0800) (addr - 0x0800) else addr;
            // Color range: 0x0800 - 0x0bf7
            const color_addr: u16 = if (addr >= 0x0800) addr else (addr + 0x0800);

            // Convert color code to foreground and background colors
            const color_code = self.vram1[color_addr];
            var fg_color_code = (color_code & 0x70) >> 4;
            // All colors except black should be high intensity
            fg_color_code = if (fg_color_code == 0) 0 else fg_color_code | (1 << 7);
            const fg_color = COLOR.all[fg_color_code];
            var bg_color_code = color_code & 0x07;
            // All colors except black should be high intensity
            bg_color_code = if (bg_color_code == 0) 0 else bg_color_code | (1 << 7);
            const bg_color = COLOR.all[bg_color_code];

            // Use bit 7 of color code to select start address in character ROM.
            const use_alternate_characters = (color_code & (1 << 7)) != 0;

            // Convert character code to address offset in character ROM.
            const character_code = self.vram1[character_code_addr];
            // Each character consists of 8 byte
            var character_addr: u16 = character_code * 8;
            if (use_alternate_characters) {
                // A full character set contains 256 characters
                // so this is the offset to the alternate characters.
                character_addr += 256 * 8;
            }

            // Calculate character coordinates

            // 40 characters on a line
            const column: u32 = character_code_addr % 40;
            // 25 lines
            const row: u32 = character_code_addr / 40;
            // Width of character in hires pixel
            const character_width: u32 = 8 * 2;
            // Width of line in hires pixel
            const line_width: u32 = 40 * character_width;
            // Height of character in pixel
            const character_height: u32 = 8;
            // Character start address in RGBA8 buffer
            const character_pixel_addr: u32 = column * character_width + row * line_width * character_height;

            // Character data lookup and copy to RGBA8 buffer
            for (0..8) |char_byte_index| {
                const char_byte = self.cgrom[character_addr + char_byte_index];
                // Pixel index in rgba8_buffer
                var index: u32 = character_pixel_addr;
                const offset: u32 = @as(u32, @intCast(char_byte_index)) * line_width;
                for (0..8) |bit| {
                    // Get color for pixel
                    const foreground = ((char_byte >> @intCast(bit)) & 0x01) == 1;
                    const color = if (foreground) fg_color else bg_color;

                    // Write character data to RGBA8 buffer (in 320x200 resolution, 2 bytes per pixel)
                    self.rgba8_buffer[index + offset] = color;
                    index += 1;
                    self.rgba8_buffer[index + offset] = color;
                    index += 1;
                }
            }
        }

        /// Decode one byte of VRAM into the RGBA8 buffer in MZ-800 mode.
        fn decode_vram_mz800(self: *Self, addr: u16) void {
            const hires = (self.dmd & DMD_MODE.HIRES) != 0;
            const hicolor = (self.dmd & DMD_MODE.HICOLOR) != 0;

            // Pixel index in rgba8_buffer, in lores we write 2 pixels for each lores pixel
            var index: u32 = addr * 8 * (if (hires) @as(u8, 1) else @as(u8, 2));

            // VRAM address check
            if (addr > (if (hires) VRAM_MAX_HIRES_ADDR else VRAM_MAX_LORES_ADDR)) {
                return;
            }

            // Get VRAM bytes for each plane
            var planeI_data: u8 = 0;
            var planeII_data: u8 = 0;
            var planeIII_data: u8 = 0;
            var planeIV_data: u8 = 0;
            if (hires) {
                planeI_data = self.vram1[hires_vram_addr(addr)];
                planeIII_data = self.vram2[hires_vram_addr(addr)];
            } else {
                planeI_data = self.vram1[addr];
                planeII_data = self.vram1[addr + VRAM_PLANE_OFFSET];
                planeIII_data = self.vram2[addr];
                planeIV_data = self.vram2[addr + VRAM_PLANE_OFFSET];
            }

            // Iterate over 8 bits of VRAM bytes from planes.
            // Each bit represents 1 pixel. The color is determined by combining bits of
            // each plane.
            // We need to set one byte of RGBA8 buffer for each VRAM bit (2 bytes in 320x200 mode)
            for (0..8) |bit_index| {
                const bit: u3 = @intCast(bit_index);
                // Combine bits of each plane into a byte
                const value: u8 = ((planeI_data >> bit) & 0x01) | (((planeII_data >> bit) & 0x01) << 1) | (((planeIII_data >> bit) & 0x01) << 2) | (((planeIV_data >> bit) & 0x01) << 3);

                // Look up in palette
                var color_code: u8 = 0;

                // Special lookup for 320x200, 16 colors
                if (!hires and hicolor) {
                    // If plane III and IV match palette switch
                    if (((value >> 2) & 0x03) == self.plt_sw) {
                        // Take color from palette
                        color_code = self.plt[value];
                    } else {
                        // Take color directly from plane data
                        color_code = value;
                    }
                } else { // All other modes take color from palette
                    const is_frameB = (self.dmd & DMD_MODE.FRAME_B) != 0;
                    var palette: u2 = 0;
                    if (hires) {
                        if (hicolor) {
                            // Combine planes I, III
                            palette = @truncate((value | (value >> 1)) & 0x3);
                        } else {
                            palette = @truncate((if (is_frameB) (value >> 2) else value) & 0x1);
                        }
                    } else {
                        palette = @truncate((if (is_frameB) (value >> 2) else value) & 0x3);
                    }
                    color_code = self.plt[palette];
                }

                // Look up final color
                const color = COLOR.all[color_code];

                // Write to RGBA8 buffer
                if (!hires) {
                    // We need to write 2 pixels for each lores pixel
                    self.rgba8_buffer[index] = color;
                    index += 1;
                }
                self.rgba8_buffer[index] = color;
                index += 1;
            }
        }
    };
}
