//! MZ-800 emulator

const std = @import("std");
const chipz = @import("chipz");
const frequencies = @import("frequencies.zig");
const gdg_whid65040_032 = @import("chips").gdg_whid65040_032;
const z80 = chipz.chips.z80;
const z80pio = chipz.chips.z80pio;
const intel8255 = chipz.chips.intel8255;
const common = chipz.common;
const memory = common.memory;
const clock = common.clock;
const keybuf = common.keybuf;
const pins = common.bitutils.pins;
const mask = common.bitutils.mask;
const maskm = common.bitutils.maskm;
const cp = common.utils.cp;
const audio = common.audio;
const DisplayInfo = common.glue.DisplayInfo;

/// Z80 bus definitions
const CPU_PINS = z80.Pins{
    .DBUS = .{ 0, 1, 2, 3, 4, 5, 6, 7 },
    .ABUS = .{ 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23 },
    .M1 = 24,
    .MREQ = 25,
    .IORQ = 26,
    .RD = 27,
    .WR = 28,
    .RFSH = 29,
    .HALT = 30,
    .WAIT = 31,
    .INT = 32,
    .NMI = 33,
    .RETI = 35,
};

/// Z80 PIO bus definitions
const PIO_PINS = z80pio.Pins{
    .DBUS = CPU_PINS.DBUS,
    .M1 = CPU_PINS.M1,
    .IORQ = CPU_PINS.IORQ,
    .RD = CPU_PINS.RD,
    .INT = CPU_PINS.INT,
    .CE = 36,
    .BASEL = CPU_PINS.ABUS[0], // BASEL pin is directly connected to A0
    .CDSEL = CPU_PINS.ABUS[1], // CDSEL pin is directly connected to A1
    .ARDY = 37,
    .BRDY = 38,
    .ASTB = 39,
    .BSTB = 40,
    .PA = .{ 64, 65, 66, 67, 68, 69, 70, 71 },
    .PB = .{ 72, 73, 74, 75, 76, 77, 78, 79 },
    .RETI = CPU_PINS.RETI,
    .IEIO = 50,
};

/// GDG bus definitions
const GDG_PINS = gdg_whid65040_032.Pins{
    .ABUS = CPU_PINS.ABUS,
    .DBUS = CPU_PINS.DBUS,
    .M1 = CPU_PINS.M1,
    .IORQ = CPU_PINS.IORQ,
    .RD = CPU_PINS.RD,
    .WR = CPU_PINS.WR,
};

const Bus = u128;
// Memory is mapped in 1K pages
const Memory = memory.Type(.{ .page_size = 0x0400 });
const Z80 = z80.Type(.{ .pins = CPU_PINS, .bus = Bus });
const Z80PIO = z80pio.Type(.{ .pins = PIO_PINS, .bus = Bus });
const PPI = intel8255.Type(.{ .pins = PIO_PINS, .bus = Bus });
const GDG = gdg_whid65040_032.Type(.{ .pins = GDG_PINS, .bus = Bus });
const KeyBuf = keybuf.Type(.{ .num_slots = 4 });
const Audio = audio.Type(.{ .num_voices = 2 });

const getData = Z80.getData;
const setData = Z80.setData;
const getAddr = Z80.getAddr;
const MREQ = Z80.MREQ;
const IORQ = Z80.IORQ;
const RD = Z80.RD;
const WR = Z80.WR;

pub fn Type() type {
    return struct {
        const Self = @This();

        pub const DISPLAY = struct {
            pub const WIDTH = 640;
            pub const HEIGHT = 200;
            pub const FB_WIDTH = 1024;
            pub const FB_HEIGHT = 256;
            pub const FB_SIZE = FB_WIDTH * FB_HEIGHT;
        };

        /// IO Addresses grouped by OUT and IN
        pub const IO_ADDR = struct {
            /// OUT: CPU pins IORQ, WR active
            pub const WR = struct {
                /// Memory banking (most have different meanings dependent on MZ-700/MZ800 mode)
                pub const MEM = struct {
                    pub const SW0: u8 = 0xe0;
                    pub const SW1: u8 = 0xe1;
                    pub const SW2: u8 = 0xe2;
                    pub const SW3: u8 = 0xe3;
                    pub const SW4: u8 = 0xe4;
                    /// ROM prohibited mode
                    pub const PROHIBIT: u8 = 0xe5;
                    /// ROM return to previous mode
                    pub const RETURN: u8 = 0xe6;
                };
            };
            /// IN: CPU pins IORQ, RD active
            pub const RD = struct {
                /// Memory banking
                pub const MEM = struct {
                    pub const SW0: u8 = 0xe0;
                    pub const SW1: u8 = 0xe1;
                };
            };
        };

        /// Memory locations and sizes
        pub const MEM_CONFIG = struct {
            pub const MZ800 = struct {
                pub const ROM1_START: u16 = 0x0000;
                pub const CGROM_START: u16 = 0x1000;
                pub const ROM2_START: u16 = 0xe000;

                pub const ROM1_SIZE: u16 = 0x1000;
                pub const CGROM_SIZE: u16 = 0x1000;
                pub const ROM2_SIZE: u16 = 0x2000;
                pub const RAM_SIZE: u17 = 0x10000;

                pub const VRAM_START: u16 = 0x8000;
                pub const VRAM_LORES_SIZE: u16 = 0x2000;
                pub const VRAM_HIRES_SIZE: u16 = 0x4000;
            };
            pub const MZ700 = struct {
                pub const VRAM_START: u16 = 0xd000;
                pub const VRAM_SIZE: u16 = 0x1000;

                // Memory mapped IO for MZ-700
                pub const IO_START: u16 = 0xe000;
                pub const IO_END: u16 = 0xe009;
            };
        };

        /// ROM banks
        pub const ROM = struct {
            /// Monitor ROM part 1
            rom1: [0x1000]u8,
            /// Character ROM
            cgrom: [0x1000]u8,
            /// Monitor ROM part 2
            rom2: [0x2000]u8,
        };

        // MZ-800 emulator state
        bus: Bus = 0,
        cpu: Z80,
        pio: Z80PIO,
        ppi: PPI,
        gdg: GDG,
        video: struct {
            h_tick: u16 = 0,
            v_count: u16 = 0,
        } = .{},
        mem: Memory,
        keybuf: KeyBuf,

        /// Memory buffers for 64K RAM
        ram: [MEM_CONFIG.MZ800.RAM_SIZE]u8,
        rom: ROM,
        vram_banked_in: bool = false,
        junk_page: [Memory.PAGE_SIZE]u8,
        unmapped_page: [Memory.PAGE_SIZE]u8,
        /// Frame buffer for emulator display
        fb: [DISPLAY.FB_SIZE]u32 align(128),

        /// Fill slice with 0x00, 0xff alternating
        fn fillMem(slice: []u8) void {
            for (0..slice.len) |index| {
                const value = if ((index & 1) == 0) 0x00 else 0xff;
                slice[index] = @intCast(value);
            }
        }

        pub fn initInPlace(self: *Self) void {
            self.* = .{
                .bus = 0,
                .cpu = Z80.init(),
                .pio = Z80PIO.init(),
                .ppi = PPI.init(),
                .gdg = GDG.init(.{
                    .cgrom = &self.rom.cgrom,
                    .fb = &self.fb,
                }),
                .mem = Memory.init(.{
                    .junk_page = &self.junk_page,
                    .unmapped_page = &self.unmapped_page,
                }),
                .key_buf = KeyBuf.init(.{
                    // let keys stick for 2 PAL frames
                    .sticky_time = 2 * (1000 / 50) * 1000,
                }),
                .ram = [MEM_CONFIG.MZ800.RAM_SIZE]u8(0),
                .rom = .{
                    .rom1 = @embedFile("roms/MZ800_ROM1.bin"),
                    .cgrom = @embedFile("roms/MZ800_CGROM.bin"),
                    .rom2 = @embedFile("roms/MZ800_ROM2.bin"),
                },
            };
            // Hard reset memory mapping
            self.resetMemoryMap(false);
        }

        pub fn reset(self: *Self) void {
            // TODO: check soft/hard reset
            const is_soft_reset = false;
            self.resetMemoryMap(is_soft_reset);
            self.pio.reset();
            self.ppi.reset();
            self.gdg.reset();
            self.cpu.reset();
        }

        /// Reset the memory map depending on type of reset
        fn resetMemoryMap(self: *Self, soft: bool) void {
            // Soft reset: when pressing reset button while holding CTRL on keyboard
            if (soft) {
                // All memory will be DRAM
                self.mem.mapRAM(0x0000, MEM_CONFIG.MZ800.RAM_SIZE, self.ram[0]);
                return;
            }

            // Hard reset: when powering on or resetting with reset button
            // Fill RAM with  0x00, 0xff alternating.
            fillMem(&self.mem.ram);

            // According to SHARP Service Manual
            self.mem.mapROM(MEM_CONFIG.MZ800.ROM1_START, MEM_CONFIG.MZ800.ROM1_SIZE, &self.rom.rom1);
            self.mem.mapROM(MEM_CONFIG.MZ800.CGROM_START, MEM_CONFIG.MZ800.CGROM_SIZE, &self.rom.cgrom);
            self.mem.mapRAM(0x2000, 0x6000, self.ram[0x2000]);
            // VRAM is handled by GDG not regular memory mapping here
            self.vram_banked_in = true;
            self.mem.mapRAM(0x8000, 0x4000, self.ram[0x8000]);
            self.mem.mapRAM(0xc000, 0x2000, self.ram[0xc000]);
            self.mem.mapROM(MEM_CONFIG.MZ800.ROM2_START, MEM_CONFIG.MZ800.ROM2_SIZE, &self.rom.rom2);
        }

        /// Memory bank switching with IORQ
        fn updateMemoryMap(self: *Self, bus: Bus) void {
            const sw: u8 = @truncate(getAddr(bus));
            switch (bus & (RD | WR | IORQ)) {
                (WR | IORQ) => {
                    const MEM = IO_ADDR.WR.MEM;
                    switch (sw) {
                        MEM.SW0 => {
                            self.mem.mapRAM(0x0000, 0x8000, self.ram[0]);
                        },
                        MEM.SW1 => {
                            if (self.gdg.is_mz700) {
                                self.mem.mapRAM(MEM_CONFIG.MZ700.VRAM_START, 0x3000, self.ram[MEM_CONFIG.MZ700.VRAM_START]);
                            } else {
                                self.mem.mapRAM(0xe000, 0x2000, self.ram[0x2000]);
                            }
                        },
                        MEM.SW2 => {
                            self.mem.mapROM(MEM_CONFIG.MZ800.ROM1_START, MEM_CONFIG.MZ800.ROM1_SIZE, &self.rom.rom1);
                        },
                        MEM.SW3 => {
                            // Special treatment in MZ-700: VRAM in 0xd000-0xdfff, Key, Timer in 0xe000-0xe070
                            // This isn't handled by regular memory mapping
                            if (self.gdg.is_mz700) {
                                self.vram_banked_in = true;
                            }
                            self.mem.mapROM(MEM_CONFIG.MZ800.ROM2_START, MEM_CONFIG.MZ800.ROM2_SIZE, &self.rom.rom2);
                        },
                        MEM.SW4 => {
                            self.mem.mapROM(MEM_CONFIG.MZ800.ROM1_START, MEM_CONFIG.MZ800.ROM1_SIZE, &self.rom.rom1);
                            if (self.gdg.is_mz700) {
                                self.mem.mapRAM(0x1000, 0xd000, self.ram[0x1000]);
                            } else {
                                self.mem.mapROM(MEM_CONFIG.MZ800.CGROM_START, MEM_CONFIG.MZ800.CGROM_SIZE, &self.rom.cgrom);
                                self.mem.mapRAM(0x2000, 0xc000, self.ram[0x2000]);
                            }
                            self.vram_banked_in = true;
                            self.mem.mapROM(MEM_CONFIG.MZ800.ROM2_START, MEM_CONFIG.MZ800.ROM2_SIZE, &self.rom.rom2);
                        },
                        MEM.PROHIBIT => {
                            // Not implemented
                        },
                        MEM.RETURN => {
                            // Not implemented
                        },
                        else => {},
                    }
                },
                (RD | IORQ) => {
                    const MEM = IO_ADDR.RD.MEM;
                    switch (sw) {
                        MEM.SW0 => {
                            self.mem.mapROM(MEM_CONFIG.MZ800.CGROM_START, MEM_CONFIG.MZ800.CGROM_SIZE, &self.rom.cgrom);
                            self.vram_banked_in = true;
                        },
                        MEM.SW1 => {
                            self.mem.mapRAM(0x1000, 0x1000, self.ram[0x1000]);
                            self.vram_banked_in = false;
                        },
                        else => {},
                    }
                },
                else => {},
            }
        }
    };
}
