//! MZ-800 emulator

const std = @import("std");
const chipz = @import("chipz");
const clock_dividers = @import("frequencies.zig").clock_dividers;
const frequencies = @import("frequencies.zig").frequencies;
const video = @import("video.zig").video;
const gdg_whid65040_032 = @import("chips").gdg_whid65040_032;
const z80 = chipz.chips.z80;
const z80pio = chipz.chips.z80pio;
const intel8255 = chipz.chips.intel8255;
const intel8253 = @import("chips").intel8253;
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
const mzf = @import("mzf.zig");
const MZF = mzf.Type();

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

/// Intel 8255 PPI pus definitions
const PPI_PINS = intel8255.Pins{
    .RD = CPU_PINS.RD,
    .WR = CPU_PINS.WR,
    .CS = 37,
    .DBUS = CPU_PINS.DBUS,
    .ABUS = .{ CPU_PINS.ABUS[0], CPU_PINS.ABUS[1] },
    .PA = .{ 64, 65, 66, 67, 68, 69, 70, 71 },
    .PB = .{ 72, 73, 74, 75, 76, 77, 78, 79 },
    .PC = .{ 80, 81, 82, 83, 84, 85, 86, 87 },
};

/// Intel 8253 CTC pus definitions
const CTC_PINS = intel8253.Pins{
    .RD = CPU_PINS.RD,
    .WR = CPU_PINS.WR,
    .CS = 37,
    .DBUS = CPU_PINS.DBUS,
    .ABUS = .{ CPU_PINS.ABUS[0], CPU_PINS.ABUS[1] },
    .CLK0 = 64,
    .GATE0 = 65,
    .OUT0 = 66,
    .CLK1 = 67,
    .GATE1 = 68,
    .OUT1 = 69,
    .CLK2 = 70,
    .GATE2 = 71,
    .OUT2 = 72,
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

pub const Bus = u128;
// Memory is mapped in 1K pages
const Memory = memory.Type(.{ .page_size = 0x0400 });
const Z80 = z80.Type(.{ .pins = CPU_PINS, .bus = Bus });
const Z80PIO = z80pio.Type(.{ .pins = PIO_PINS, .bus = Bus });
const PPI = intel8255.Type(.{ .pins = PPI_PINS, .bus = Bus });
const CTC = intel8253.Type(.{ .pins = CTC_PINS, .bus = Bus });
const GDG = gdg_whid65040_032.Type(.{ .pins = GDG_PINS, .bus = Bus });
const KeyBuf = keybuf.Type(.{ .num_slots = 4 });
const Audio = audio.Type(.{ .num_voices = 2 });

pub const getData = Z80.getData;
pub const setData = Z80.setData;
pub const getAddr = Z80.getAddr;
pub const setAddr = Z80.setAddr;
const MREQ = Z80.MREQ;
pub const IORQ = Z80.IORQ;
pub const ABUS = Z80.ABUS;
pub const RD = Z80.RD;
pub const WR = Z80.WR;

pub fn Type() type {
    return struct {
        const Self = @This();

        /// Runtime options
        pub const Options = struct {
            roms: struct {
                rom1: []const u8,
                cgrom: []const u8,
                rom2: []const u8,
            },
        };

        pub const DISPLAY = struct {
            pub const WIDTH = video.display.width;
            pub const HEIGHT = video.display.height;
            pub const FB_WIDTH = 1024;
            pub const FB_HEIGHT = 512;
            pub const FB_SIZE = FB_WIDTH * FB_HEIGHT;
            pub const FB_CANVAS_ORIGIN = video.border.top * DISPLAY.FB_WIDTH + video.border.left;
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
                pub const VRAM_LORES_END = VRAM_START + VRAM_LORES_SIZE;
                pub const VRAM_HIRES_END = VRAM_START + VRAM_HIRES_SIZE;
            };
            pub const MZ700 = struct {
                pub const VRAM_START: u16 = 0xd000;
                pub const VRAM_SIZE: u16 = 0x1000;
                pub const VRAM_END: u16 = VRAM_START + VRAM_SIZE;

                // Memory mapped IO for MZ-700
                pub const IO_START: u16 = 0xe000;
                pub const IO_END: u16 = 0xe009;
            };
        };

        /// ROM banks
        pub const ROM = struct {
            /// Monitor ROM part 1
            rom1: [MEM_CONFIG.MZ800.ROM1_SIZE]u8,
            /// Character ROM
            cgrom: [MEM_CONFIG.MZ800.CGROM_SIZE]u8,
            /// Monitor ROM part 2
            rom2: [MEM_CONFIG.MZ800.ROM2_SIZE]u8,
        };

        // MZ-800 emulator state
        bus: Bus = 0,

        // CPU Z80A
        cpu: Z80,

        // PIO Z80 PIO, parallel I/O unit
        pio: Z80PIO,

        // PPI i8255, keyboard and cassette driver
        ppi: PPI,

        // CTC i8253, programmable counter/timer
        ctc: CTC,

        // GDG WHID 65040-032, CRT controller
        gdg: GDG,

        // PSG SN 76489 AN, sound generator
        // TODO: implement PSG

        video: struct {
            tick: usize = 0,
            h_tick: usize = 0,
            v_count: usize = 0,
        } = .{},

        mem: Memory,

        key_buf: KeyBuf,

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
                const value: u8 = if ((index & 1) == 0) 0x00 else 0xff;
                slice[index] = value;
            }
        }

        pub fn initInPlace(self: *Self, opts: Options) void {
            self.* = .{
                .bus = 0,
                .cpu = Z80.init(),
                .pio = Z80PIO.init(),
                .ppi = PPI.init(),
                .ctc = CTC.init(),
                .gdg = GDG.init(.{
                    .cgrom = &self.rom.cgrom,
                    .rgba8_buffer = &self.fb,
                }),
                .mem = Memory.init(.{
                    .junk_page = &self.junk_page,
                    .unmapped_page = &self.unmapped_page,
                }),
                .key_buf = KeyBuf.init(.{
                    // let keys stick for 2 PAL frames
                    .sticky_time = 2 * (1000 / 50) * 1000,
                }),
                .ram = [_]u8{0} ** MEM_CONFIG.MZ800.RAM_SIZE,
                .rom = initRoms(opts),
                .fb = std.mem.zeroes(@TypeOf(self.fb)),
                .junk_page = std.mem.zeroes(@TypeOf(self.junk_page)),
                .unmapped_page = [_]u8{0xFF} ** Memory.PAGE_SIZE,
            };
            // Hard reset
            self.reset(false);
        }

        fn initRoms(opts: Options) ROM {
            var rom: ROM = undefined;
            cp(opts.roms.rom1, &rom.rom1);
            cp(opts.roms.cgrom, &rom.cgrom);
            cp(opts.roms.rom2, &rom.rom2);
            return rom;
        }

        pub fn reset(self: *Self, is_soft_reset: bool) void {
            // TODO: check soft/hard reset
            self.video = .{};
            self.resetMemoryMap(is_soft_reset);
            self.pio.reset();
            self.ppi.reset();
            self.ctc.reset();
            self.gdg.reset();
            self.cpu.reset();
        }

        // 17.734475 MHz = 56.387347243152 ns(p)
        pub fn exec(self: *Self, micro_seconds: u32) u32 {
            var bus = self.bus;
            const CLK0: u64 = @intFromFloat(frequencies.CLK0);
            const num_ticks = clock.microSecondsToTicks(CLK0, micro_seconds);
            for (0..num_ticks) |ticks| {
                if ((ticks % clock_dividers.CPU_CLK) == 0) {
                    bus = self.tick(bus);
                }
                bus = self.videoTick(bus);
            }
            self.bus = bus;
            // self.updateKeyboard(micro_seconds);
            return num_ticks;
        }

        pub fn tick(self: *Self, in_bus: Bus) Bus {
            var bus = in_bus;

            // Tick CPU
            bus = self.cpu.tick(bus);

            // Memory request
            if ((bus & MREQ) != 0) {
                const addr = getAddr(bus);

                // MZ-700 VRAM
                if (self.isMZ700VRAMAddr(addr)) {
                    const vram_addr = addr - MEM_CONFIG.MZ700.VRAM_START;
                    if ((bus & RD) != 0) {
                        const data = self.gdg.mem_rd(vram_addr);
                        bus = setData(bus, data);
                    } else if ((bus & WR) != 0) {
                        const data = getData(bus);
                        self.gdg.mem_wr(vram_addr, data);
                    }
                }
                // MZ-800 VRAM
                else if (self.isMZ800VRAMAddr(addr)) {
                    const vram_addr = addr - MEM_CONFIG.MZ800.VRAM_START;
                    if ((bus & RD) != 0) {
                        const data = self.gdg.mem_rd(vram_addr);
                        bus = setData(bus, data);
                    } else if ((bus & WR) != 0) {
                        const data = getData(bus);
                        self.gdg.mem_wr(vram_addr, data);
                    }
                }
                // MZ-700 memory mapped IO
                else if (self.gdg.is_mz700 and isInRange(addr, MEM_CONFIG.MZ700.IO_START, MEM_CONFIG.MZ700.IO_END)) {
                    bus = self.mz700TranslateIOREQ(bus);
                }
                // Other memory
                else {
                    if ((bus & RD) != 0) {
                        bus = setData(bus, self.mem.rd(addr));
                    } else if ((bus & WR) != 0) {
                        self.mem.wr(addr, getData(bus));
                    }
                }
            }
            // IO request
            else if (((bus & Z80.IORQ) != 0) and (bus & (RD | WR)) != 0) {
                bus = self.iorq(bus);
            }

            return bus;
        }

        fn videoTick(self: *Self, bus: Bus) Bus {
            self.video.tick += 1;
            if (self.video.tick == video.screen.frame) {
                self.video.tick = 0;
            }
            self.video.h_tick += 1;
            if (self.video.h_tick == video.screen.horizontal.line) {
                self.video.h_tick = 0;
                self.video.v_count += 1;
                if (self.video.v_count == video.screen.height) {
                    self.video.v_count = 0;
                }
            }

            // Convert to coordinates if beam is in visible area
            if (videoHTickToFrameX(self.video.h_tick)) |x| {
                if (videoTickToFrameY(self.video.tick)) |y| {
                    const index = framebufferIndex(x, y);

                    // Video status updates
                    // Start of real HSYNC (used for CTC CLK1 - this isn't used for the status flags)
                    if (x == 950) {
                        // TODO: use real HSYNC
                    }
                    // Start of HSYNC
                    if (x == 926) {
                        self.gdg.status &= ~GDG.STATUS_MODE.HSYNC;
                    }
                    // End of HSYNC
                    if (x == 1133) {
                        self.gdg.status |= GDG.STATUS_MODE.HSYNC;
                    }
                    // Start of HBLANK
                    if (x == video.border.left + video.canvas.width) {
                        self.gdg.status &= ~GDG.STATUS_MODE.HBLANK;
                    }
                    // End of HBLANK
                    if (x == video.border.left) {
                        self.gdg.status |= GDG.STATUS_MODE.HBLANK;
                    }
                    // Start of VBLANK
                    if (x == 790 and y == video.border.top + video.canvas.height) {
                        self.gdg.status &= ~GDG.STATUS_MODE.VBLANK;
                    }
                    // End of VBLANK
                    if (x == 790 and y == video.border.top) {
                        self.gdg.status |= GDG.STATUS_MODE.VBLANK;
                    }
                    // Start of VSYNC
                    if (x == 792 and y == video.border.top + video.canvas.height + video.border.bottom) {
                        self.gdg.status &= ~GDG.STATUS_MODE.VSYNC;
                    }
                    // End of VSYNC
                    if (x == 792 and y == 0) {
                        self.gdg.status |= GDG.STATUS_MODE.VSYNC;
                    }

                    // In border area
                    if ((x < video.border.left) or (x >= video.border.left + video.canvas.width) or (y < video.border.top) or (y >= video.border.top + video.canvas.height)) {
                        self.fb[index] = GDG.COLOR.all[self.gdg.bcol];
                    }
                    // In canvas area
                    else {
                        const canvas_x = x - video.border.left;
                        const canvas_y = y - video.border.top;
                        // Decode MZ-700 VRAM
                        if (self.gdg.is_mz700) {
                            if ((canvas_x % 16) == 0) {
                                // Decode VRAM character codes for screen coordinates (40x25 characters)
                                const row_addr: u16 = @intCast((canvas_y / 8) * 40);
                                const col_addr: u16 = @intCast(canvas_x / 16);
                                const addr: u16 = row_addr + col_addr;
                                const char_byte_index = canvas_y % 8;
                                self.gdg.decode_vram_mz700(addr, char_byte_index, @intCast(index));
                            }
                        }
                        // Decode MZ-800 VRAM
                        else {
                            const pixel_width: u16 = if (self.gdg.isHires()) 1 else 2;
                            const adjusted_x: u16 = @as(u16, @intCast(canvas_x)) / pixel_width;
                            if ((adjusted_x % 8) == 0) {
                                // We decode in 8 pixel batches
                                const canvas_width: u16 = video.canvas.width / pixel_width;
                                const width: u16 = canvas_width / 8;
                                const row_addr: u16 = @as(u16, @intCast(canvas_y)) * width;
                                const col_addr: u16 = adjusted_x / 8;
                                const addr: u16 = row_addr + col_addr;
                                self.gdg.decode_vram_mz800(addr, @intCast(index));
                            }
                        }
                    }
                }
            }

            return bus;
        }

        inline fn videoHTickToFrameX(h_tick: usize) ?usize {
            if (h_tick < video.screen.horizontal.video_enable_start) return null;
            const x = h_tick - video.screen.horizontal.video_enable_start;
            return if (x < video.screen.horizontal.video_enable) x else null;
        }

        inline fn videoTickToFrameY(video_tick: usize) ?usize {
            if (video_tick < video.screen.vertical.video_enable_start) return null;
            const y_tick = video_tick - video.screen.vertical.video_enable_start;
            const y = y_tick / video.screen.horizontal.line;
            return if (y_tick < video.screen.vertical.video_enable) y else null;
        }

        inline fn framebufferIndex(x: usize, y: usize) usize {
            return y * DISPLAY.FB_WIDTH + x;
        }

        pub fn load(self: *Self, obj_file: MZF) void {
            self.reset(false);
            const start = obj_file.header.start_address;
            const end = obj_file.header.file_length;
            for (0..end) |index| {
                const data = obj_file.data[index];
                const addr = start + @as(u16, @truncate(index));
                self.mem.wr(addr, data);
            }
            self.cpu.reset();
            self.cpu.prefetch(start);
        }

        fn isInRange(number: u16, lower_bound: u16, upper_bound: u16) bool {
            return (number >= lower_bound) and (number <= upper_bound);
        }

        fn isMZ700VRAMAddr(self: *Self, addr: u16) bool {
            if (!self.vram_banked_in) return false;
            if (!self.gdg.is_mz700) return false;
            return (addr >= MEM_CONFIG.MZ700.VRAM_START) and (addr < MEM_CONFIG.MZ700.VRAM_END);
        }

        fn isMZ800VRAMAddr(self: *Self, addr: u16) bool {
            if (!self.vram_banked_in) return false;
            if (self.gdg.is_mz700) return false;
            if (addr < MEM_CONFIG.MZ800.VRAM_START) return false;
            const hires = (self.gdg.dmd & GDG.DMD_MODE.HIRES) != 0;
            return addr < (if (hires) MEM_CONFIG.MZ800.VRAM_HIRES_END else MEM_CONFIG.MZ800.VRAM_LORES_END);
        }

        fn mz700TranslateIOREQ(self: *Self, in_bus: Bus) Bus {
            var bus = in_bus;
            var io_addr: u16 = 0;
            switch (bus & ABUS | RD | WR) {
                // i8255
                MEM_CONFIG.MZ700.IO_START | WR => io_addr = 0xd0,
                MEM_CONFIG.MZ700.IO_START + 0x01 | RD => io_addr = 0xd1,
                MEM_CONFIG.MZ700.IO_START + 0x02 | WR => io_addr = 0xd2,
                MEM_CONFIG.MZ700.IO_START + 0x02 | RD => io_addr = 0xd2,
                MEM_CONFIG.MZ700.IO_START + 0x03 | WR => io_addr = 0xd3,

                // i8253
                MEM_CONFIG.MZ700.IO_START + 0x04 | WR => io_addr = 0xd4,
                MEM_CONFIG.MZ700.IO_START + 0x04 | RD => io_addr = 0xd4,
                MEM_CONFIG.MZ700.IO_START + 0x05 | WR => io_addr = 0xd5,
                MEM_CONFIG.MZ700.IO_START + 0x05 | RD => io_addr = 0xd5,
                MEM_CONFIG.MZ700.IO_START + 0x06 | WR => io_addr = 0xd6,
                MEM_CONFIG.MZ700.IO_START + 0x06 | RD => io_addr = 0xd6,
                MEM_CONFIG.MZ700.IO_START + 0x07 | WR => io_addr = 0xd7,

                // Implementation of MZ-700 0xe008 is a bit unclear
                // TODO: clarify MZ-700 write to 0xe008 (mem mapped IO)
                MEM_CONFIG.MZ700.IO_START + 0x08 | WR => io_addr = 0xd8,
                MEM_CONFIG.MZ700.IO_START + 0x08 | RD => io_addr = 0xce,

                else => {},
            }

            if (io_addr != 0) {
                bus &= ~Z80.MREQ;
                bus |= Z80.IORQ;
                bus = setAddr(bus, io_addr);
            }

            return self.iorq(bus);
        }

        fn iorq(self: *Self, in_bus: Bus) Bus {
            var bus = in_bus;

            // Check only the lower byte of the address
            const addr = getAddr(bus) & 0xff;

            switch (addr) {
                // Serial IO
                0xb0...0xb3 => {
                    std.debug.panic("Serial IO not implemented", .{});
                },
                // GDG WHID 65040-032, CRT controller
                0xcc...0xcf => {
                    bus = self.gdg.tick(bus);
                },
                // PPI i8255, keyboard and cassette driver
                0xd0...0xd3 => {
                    bus = self.ppi.tick(bus);
                },
                // CTC i8253, programmable counter/timer
                0xd4...0xd7 => {
                    bus = self.ctc.tick(bus);
                },
                // FDC, floppy disc controller
                0xd8...0xdf => {
                    std.debug.panic("FDC not implemented", .{});
                },
                // GDG WHID 65040-032, memory bank switch
                0xe0...0xe6 => {
                    self.updateMemoryMap(bus);
                },

                0xf0...0xf1 => {
                    // GDG WHID 65040-032, Palette register (write only)
                    if ((addr == 0xf0) and ((bus & WR) != 0)) {
                        bus = self.gdg.tick(bus);
                    }
                    // Joystick (read only)
                    else if ((bus & RD) != 0) {
                        bus = self.ppi.tick(bus);
                    }
                },
                // PSG SN 76489 AN, sound generator
                0xf2 => {
                    std.debug.panic("PSG not implemented", .{});
                },
                // QDC, quick disk controller
                0xf4...0xf7 => {
                    std.debug.panic("QDC not implemented", .{});
                },
                // PIO Z80 PIO, parallel I/O unit
                0xfc...0xff => {
                    bus = self.pio.tick(bus);
                },
                else => {},
            }

            return bus;
        }

        /// Reset the memory map depending on type of reset
        fn resetMemoryMap(self: *Self, soft: bool) void {
            // Soft reset: when pressing reset button while holding CTRL on keyboard
            if (soft) {
                // All memory will be DRAM
                self.mem.mapRAM(0x0000, MEM_CONFIG.MZ800.RAM_SIZE, &self.ram);
                return;
            }

            // Hard reset: when powering on or resetting with reset button
            // Fill RAM with  0x00, 0xff alternating.
            fillMem(&self.ram);

            // According to SHARP Service Manual
            self.mem.mapROM(MEM_CONFIG.MZ800.ROM1_START, MEM_CONFIG.MZ800.ROM1_SIZE, &self.rom.rom1);
            self.mem.mapROM(MEM_CONFIG.MZ800.CGROM_START, MEM_CONFIG.MZ800.CGROM_SIZE, &self.rom.cgrom);
            self.mem.mapRAM(0x2000, 0x6000, self.ram[0x2000..0x8000]);
            // VRAM is handled by GDG not regular memory mapping here
            self.vram_banked_in = true;
            self.mem.mapRAM(0x8000, 0x4000, self.ram[0x8000..0xc000]);
            self.mem.mapRAM(0xc000, 0x2000, self.ram[0xc000..0xe000]);
            self.mem.mapROM(MEM_CONFIG.MZ800.ROM2_START, MEM_CONFIG.MZ800.ROM2_SIZE, &self.rom.rom2);
        }

        /// Memory bank switching with IORQ
        pub fn updateMemoryMap(self: *Self, bus: Bus) void {
            const sw: u8 = @truncate(getAddr(bus));
            switch (bus & (RD | WR | IORQ)) {
                (WR | IORQ) => {
                    const MEM = IO_ADDR.WR.MEM;
                    switch (sw) {
                        MEM.SW0 => {
                            self.mem.mapRAM(0x0000, 0x8000, self.ram[0x0000..0x8000]);
                        },
                        MEM.SW1 => {
                            if (self.gdg.is_mz700) {
                                self.vram_banked_in = false;
                                self.mem.mapRAM(MEM_CONFIG.MZ700.VRAM_START, 0x3000, self.ram[MEM_CONFIG.MZ700.VRAM_START..0x10000]);
                            } else {
                                self.mem.mapRAM(0xe000, 0x2000, self.ram[0xe000..0x10000]);
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
                                self.mem.mapRAM(0x1000, 0xd000, self.ram[0x1000..0xe000]);
                            } else {
                                self.mem.mapROM(MEM_CONFIG.MZ800.CGROM_START, MEM_CONFIG.MZ800.CGROM_SIZE, &self.rom.cgrom);
                                self.mem.mapRAM(0x2000, 0xc000, self.ram[0x2000..0xe000]);
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
                            self.mem.mapRAM(0x1000, 0x1000, self.ram[0x1000..0x2000]);
                            self.vram_banked_in = false;
                        },
                        else => {},
                    }
                },
                else => {},
            }
        }

        pub fn displayInfo(selfOrNull: ?*const Self) DisplayInfo {
            return .{
                .fb = .{
                    .dim = .{
                        .width = DISPLAY.FB_WIDTH,
                        .height = DISPLAY.FB_HEIGHT,
                    },
                    .buffer = if (selfOrNull) |self| .{ .Rgba8 = &self.fb } else null,
                },
                .view = .{
                    .x = 0,
                    .y = 0,
                    .width = DISPLAY.WIDTH,
                    .height = DISPLAY.HEIGHT,
                },
                .palette = null,
                .orientation = .Landscape,
            };
        }
    };
}
