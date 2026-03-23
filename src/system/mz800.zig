//! MZ-800 emulator

const std = @import("std");
const chipz = @import("chipz");
const clock_dividers = @import("frequencies.zig").clock_dividers;
const frequencies = @import("frequencies.zig").frequencies;
const video = @import("video.zig").video;

const z80 = chipz.chips.z80;
const z80pio = chipz.chips.z80pio;
const intel8255 = chipz.chips.intel8255;
const intel8253 = @import("chips").intel8253;
const gdg_whid65040_032 = @import("chips").gdg_whid65040_032;
const sn76489an = @import("chips").sn76489an;

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
const CMT = @import("cmt.zig").CMT;

/// Z80 bus definitions (0..35)
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

/// Chip select pin numbers
const CS_PINS = struct {
    const PIO: comptime_int = 36;
    const PPI: comptime_int = 37;
    const CTC: comptime_int = 38;
    const GDG: comptime_int = 39;
    const PSG: comptime_int = 40;
};

/// Z80 PIO bus definitions
const PIO_PINS = z80pio.Pins{
    .DBUS = CPU_PINS.DBUS,
    .M1 = CPU_PINS.M1,
    .IORQ = CPU_PINS.IORQ,
    .RD = CPU_PINS.RD,
    .INT = CPU_PINS.INT,
    .CE = CS_PINS.PIO,
    .BASEL = CPU_PINS.ABUS[0], // BASEL pin is directly connected to A0
    .CDSEL = CPU_PINS.ABUS[1], // CDSEL pin is directly connected to A1
    .ARDY = 41,
    .BRDY = 42,
    .ASTB = 43,
    .BSTB = 44,
    .PA = .{ 64, 65, 66, 67, 68, 69, 70, 71 },
    .PB = .{ 72, 73, 74, 75, 76, 77, 78, 79 },
    .RETI = CPU_PINS.RETI,
    .IEIO = 50,
};

/// Intel 8255 PPI pus definitions
const PPI_PINS = intel8255.Pins{
    .RD = CPU_PINS.RD,
    .WR = CPU_PINS.WR,
    .CS = CS_PINS.PPI,
    .DBUS = CPU_PINS.DBUS,
    .ABUS = .{ CPU_PINS.ABUS[0], CPU_PINS.ABUS[1] },
    .PA = .{ 80, 81, 82, 83, 84, 85, 86, 87 },
    .PB = .{ 88, 89, 90, 91, 92, 93, 94, 95 },
    .PC = .{ 96, 97, 98, 99, 100, 101, 102, 103 },
};

/// Intel 8253 CTC pus definitions
const CTC_PINS = intel8253.Pins{
    .RD = CPU_PINS.RD,
    .WR = CPU_PINS.WR,
    .CS = CS_PINS.CTC,
    .DBUS = CPU_PINS.DBUS,
    .ABUS = .{ CPU_PINS.ABUS[0], CPU_PINS.ABUS[1] },
    .CLK0 = 104,
    .GATE0 = 105,
    .OUT0 = 106,
    .CLK1 = 107,
    .GATE1 = 108,
    .OUT1 = 109,
    .CLK2 = 110,
    .GATE2 = 111,
    .OUT2 = 112,
};

const CTC_CLK0 = mask(Bus, CTC_PINS.CLK0);
const CTC_CLK1 = mask(Bus, CTC_PINS.CLK1);
const CTC_CLK2 = mask(Bus, CTC_PINS.CLK2);
const CTC_GATE0 = mask(Bus, CTC_PINS.GATE0);
const CTC_GATE1 = mask(Bus, CTC_PINS.GATE1);
const CTC_GATE2 = mask(Bus, CTC_PINS.GATE2);

/// GDG bus definitions
const GDG_PINS = gdg_whid65040_032.Pins{
    .ABUS = CPU_PINS.ABUS,
    .DBUS = CPU_PINS.DBUS,
    .M1 = CPU_PINS.M1,
    .IORQ = CPU_PINS.IORQ,
    .RD = CPU_PINS.RD,
    .WR = CPU_PINS.WR,
    .CS = CS_PINS.GDG,
};

/// PSG bus definitions
const PSG_PINS = sn76489an.Pins{
    .DBUS = CPU_PINS.DBUS,
    .CE = CS_PINS.PSG,
    .WE = CPU_PINS.WR,
};

pub const Bus = u128;
// Memory is mapped in 1K pages
pub const Memory = memory.Type(.{ .page_size = 0x0400 });
pub const Z80 = z80.Type(.{ .pins = CPU_PINS, .bus = Bus });
pub const PIO = z80pio.Type(.{ .pins = PIO_PINS, .bus = Bus });
pub const PPI = intel8255.Type(.{ .pins = PPI_PINS, .bus = Bus });
pub const CTC = intel8253.Type(.{ .pins = CTC_PINS, .bus = Bus });
pub const GDG = gdg_whid65040_032.Type(.{ .pins = GDG_PINS, .bus = Bus });
pub const PSG = sn76489an.Type(.{ .pins = PSG_PINS, .bus = Bus });
pub const KeyBuf = keybuf.Type(.{ .num_slots = 4 });
pub const Audio = audio.Type(.{ .num_voices = 4 });

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
            audio: Audio.Options,
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
        pio: PIO,

        // PPI i8255, keyboard and cassette driver
        ppi: PPI,

        // CTC i8253, programmable counter/timer
        ctc: CTC,

        // GDG WHID 65040-032, CRT controller
        gdg: GDG,

        // PSG SN 76489 AN, sound generator
        psg: PSG,

        video: struct {
            ticks: usize = 0,
            h_ticks: usize = 0,
            v_count: usize = 0,
            // Vertical BLaNk signal: 1 = inactive (during canvas display), 0 = active (during blanking).
            // Wired to PPI Port C bit 7 (PC7) and PIO Port A bit 5 (PA5).
            vbln: u1 = 0,
            // 556 cursor oscillator output: toggles at clock_dividers.CURSOR rate.
            // Wired to PPI Port C bit 6 (PC6).
            cursor_osc: u1 = 0,
        } = .{},

        // Internal clock for the emulator. Counts CLK0 ticks from emulator boot.
        // With CLK0 frequency about 17.7 MHz the 64-bit counter should allow for roughly 32K years.
        clock: struct {
            ticks: u64 = 0,
        } = .{},

        mem: Memory,

        key_buf: KeyBuf,
        keyboard_matrix: [10]u8 = [_]u8{0xFF} ** 10,

        /// Memory buffers for 64K RAM
        ram: [MEM_CONFIG.MZ800.RAM_SIZE]u8,
        rom: ROM,
        vram_banked_in: bool = false,
        /// Tracks which ROMs are currently mapped, used by PROHIBIT/RETURN.
        rom1_mapped: bool = true,
        cgrom_mapped: bool = true,
        rom2_mapped: bool = true,
        /// Saved ROM mapping state before PROHIBIT (0xE5) was issued.
        pre_prohibit_rom1: bool = false,
        pre_prohibit_cgrom: bool = false,
        pre_prohibit_rom2: bool = false,
        /// Whether PROHIBIT mode is active (0xE5 was written, awaiting 0xE6 RETURN).
        prohibit_active: bool = false,
        /// Preferred mode to boot into after reset. Survives sys.reset() calls.
        preferred_is_mz700: bool = false,
        junk_page: [Memory.PAGE_SIZE]u8,
        unmapped_page: [Memory.PAGE_SIZE]u8,
        audio: Audio,
        audio_sample_tick: u64,
        // CMT cassette tape emulation
        cmt: CMT,
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
                .pio = PIO.init(),
                .ppi = PPI.init(),
                .ctc = CTC.init(),
                .gdg = GDG.init(.{
                    .cgrom = &self.rom.cgrom,
                    .rgba8_buffer = &self.fb,
                }),
                .psg = PSG.init(),
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
                .audio = Audio.init(opts.audio),
                .audio_sample_tick = @intFromFloat(frequencies.CLK0 / @as(f64, @floatFromInt(opts.audio.sample_rate))),
                .cmt = CMT.init(),
                .fb = std.mem.zeroes(@TypeOf(self.fb)),
                .junk_page = std.mem.zeroes(@TypeOf(self.junk_page)),
                .unmapped_page = [_]u8{0xFF} ** Memory.PAGE_SIZE,
            };
            self.cmt.configure(@intFromFloat(frequencies.CLK0));
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
            self.video = .{};
            self.resetMemoryMap(is_soft_reset);
            self.pio.reset();
            self.ppi.reset();
            self.ctc.reset();
            // Sync DIP switch to GDG before reset so the ROM reads the correct
            // status bit 1 and programs the DMD register accordingly.
            self.gdg.dip_is_mz700 = self.preferred_is_mz700;
            if (is_soft_reset) {
                self.gdg.softReset();
            } else {
                self.gdg.reset();
            }
            self.psg.reset();
            self.cpu.reset();
            self.keyboard_matrix = [_]u8{0xFF} ** 10;
            // GATE1 and GATE2 are pulled high on real MZ-800 hardware.
            // Set gates directly to avoid triggering state machine transitions
            // before the ROM programs the counters.
            self.bus |= CTC_GATE1 | CTC_GATE2;
            self.ctc.counter[1].gate = 1;
            self.ctc.counter[2].gate = 1;
            // GATE0 is controlled by the GDG CT53G7 register in MZ-700 mode (default low),
            // and pulled high in MZ-800 mode.
            self.bus = self.setCTC0Gate(self.bus, if (self.gdg.is_mz700) 0 else 1);
        }

        pub fn exec(self: *Self, micro_seconds: u32) u32 {
            var bus = self.bus;
            const CLK0: u64 = @intFromFloat(frequencies.CLK0);
            const num_ticks = clock.microSecondsToTicks(CLK0, micro_seconds);
            for (0..num_ticks) |_| {
                self.clock.ticks +%= 1;
                // CPU tick
                if ((self.clock.ticks % clock_dividers.CPU_CLK) == 0) {
                    bus = self.tick(bus);
                }
                // CTC CLK0 tick, CTC counters count only falling edge so we need to
                // toggle the signal at clock divider / 2
                if ((self.clock.ticks % clock_dividers.CKMS) == (clock_dividers.CKMS / 2)) {
                    // Toggle CLK0
                    bus ^= CTC_CLK0;
                    bus = self.ctc.setCLK0(bus);
                }
                // CLK1 (real HSYNC) is now driven from videoTick() based on h_ticks,
                // asserting at h_tick=950 and deasserting at h_tick=1030 each line.
                // TEMPO tick (cursor blink oscillator)
                if ((self.clock.ticks % (clock_dividers.TEMPO / 2)) == 0) {
                    self.gdg.status ^= GDG.STATUS_MODE.TEMPO;
                }
                // 556 cursor oscillator tick → PC6
                if ((self.clock.ticks % (clock_dividers.CURSOR / 2)) == 0) {
                    self.video.cursor_osc ^= 1;
                }
                // PSG tick (~221.7 kHz)
                if ((self.clock.ticks % clock_dividers.PSG_CLK) == 0) {
                    self.psg.step();
                }
                // Audio sample tick (at host sample rate)
                if ((self.clock.ticks % self.audio_sample_tick) == 0) {
                    // Mix PSG output with 8253 Ch.0 square wave, gated by SMSK (PC0).
                    const smsk = (self.ppi.ports[2].output & (1 << 0)) != 0;
                    const pit_out0: f32 = if (smsk and self.ctc.counter[0].out == 1) 1.0 else 0.0;
                    self.audio.put(self.psg.sample() + pit_out0);
                }
                // Video tick
                bus = self.videoTick(bus);
                // CMT tick: advance tape position by one master clock tick
                self.cmt.tick();
            }
            self.bus = bus;
            self.updateKeyboard(micro_seconds);
            return num_ticks;
        }

        fn updateKeyboard(self: *Self, micro_seconds: u32) void {
            self.key_buf.update(micro_seconds);
        }

        pub fn tick(self: *Self, in_bus: Bus) Bus {
            var bus = in_bus;

            // Tick CPU
            bus = self.cpu.tick(bus);

            // Clear chip enables and INT.
            // INT is redriven each tick by PIO.tick() and the CTC/INTMSK logic below,
            // so it must be cleared here to prevent it from accumulating on self.bus
            // and permanently asserting the interrupt after the first timer firing.
            bus &= ~(PIO.CE | PPI.CS | CTC.CS | PSG.CE | Z80.INT);

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
                else if (self.gdg.is_mz700 and self.vram_banked_in and isInRange(addr, MEM_CONFIG.MZ700.IO_START, MEM_CONFIG.MZ700.IO_END)) {
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

            // Tick chips (only those that tick with CPU clock)
            const was_mz700 = self.gdg.is_mz700;
            bus = self.gdg.tick(bus);
            // If MZ-700/MZ-800 mode changed via DMD register, update CTC GATE0.
            if (self.gdg.is_mz700 != was_mz700) {
                // MZ-700 mode: GATE0 follows ct53g7 (default low). MZ-800 mode: GATE0 = 1.
                bus = self.setCTC0Gate(bus, if (self.gdg.is_mz700) self.gdg.ct53g7 else 1);
            }
            // Inject VBLN onto PIO Port A bit 5 (PA5, bus bit 69).
            // VBLN is inactive (1) during canvas display, active (0) during blanking.
            const pio_pa5_mask: Bus = @as(Bus, 1) << PIO_PINS.PA[5];
            if (self.video.vbln == 1) {
                bus |= pio_pa5_mask;
            } else {
                bus &= ~pio_pa5_mask;
            }
            bus = self.pio.tick(bus);
            // Inject keyboard matrix onto PPI Port B bus pins (active low).
            // The column to read is the lower nibble of Port A output.
            const kb_col: usize = self.ppi.ports[0].output & 0x0F;
            const ppi_pb_mask: Bus = @as(Bus, 0xFF) << 88;
            const kb_data: u8 = if (kb_col < self.keyboard_matrix.len) self.keyboard_matrix[kb_col] else 0xFF;
            bus = (bus & ~ppi_pb_mask) | (@as(Bus, kb_data) << 88);
            // Inject VBLN onto PPI Port C bit 7 (PC7, bus bit 103).
            const ppi_pc7_mask: Bus = @as(Bus, 1) << PPI_PINS.PC[7];
            if (self.video.vbln == 1) {
                bus |= ppi_pc7_mask;
            } else {
                bus &= ~ppi_pc7_mask;
            }
            // Inject 556 cursor oscillator onto PPI Port C bit 6 (PC6, bus bit 102).
            const ppi_pc6_mask: Bus = @as(Bus, 1) << PPI_PINS.PC[6];
            if (self.video.cursor_osc == 1) {
                bus |= ppi_pc6_mask;
            } else {
                bus &= ~ppi_pc6_mask;
            }
            // Inject CMT RDATA onto PPI Port C bit 5 (PC5, bus bit 101).
            // PC5 is an input: the ROM reads it to receive serial tape data.
            const ppi_pc5_mask: Bus = @as(Bus, 1) << PPI_PINS.PC[5];
            if (self.cmt.readBit()) {
                bus |= ppi_pc5_mask;
            } else {
                bus &= ~ppi_pc5_mask;
            }
            // Inject CMT motor status onto PPI Port C bit 4 (PC4, bus bit 100).
            // PC4 is an input: the ROM reads it to check whether the motor is running.
            const ppi_pc4_mask: Bus = @as(Bus, 1) << PPI_PINS.PC[4];
            if (self.cmt.motorStatus()) {
                bus |= ppi_pc4_mask;
            } else {
                bus &= ~ppi_pc4_mask;
            }
            bus = self.ppi.tick(bus);
            // Read M-ON from PPI Port C bit 3 (PC3): motor on/off control (rising edge 0→1).
            const m_on = (self.ppi.ports[2].output & (1 << 3)) != 0;
            self.cmt.updateMotor(m_on);
            // Read WDATA from PPI Port C bit 1 (PC1): serial data output to tape recorder.
            const wdata = (self.ppi.ports[2].output & (1 << 1)) != 0;
            self.cmt.writeData(wdata);
            bus = self.ctc.tick(bus);
            // 8253 Ch.2 OUT drives Z80 INT, gated by PPI Port C bit 2 (INTMSK).
            // Interrupt fires only when both OUT2 = 1 and PC2 = 1.
            const ctc_out2 = (bus & (@as(Bus, 1) << CTC_PINS.OUT2)) != 0;
            const ppi_pc2 = (self.ppi.ports[2].output & (1 << 2)) != 0;
            if (ctc_out2 and ppi_pc2) {
                bus |= @as(Bus, 1) << CPU_PINS.INT;
            }
            // 8253 Ch.0 OUT drives PIO Port A bit 4 (PA4, active-low / inverted).
            // When CTC0 OUT is high, PA4 goes low; when CTC0 OUT is low, PA4 is high.
            // The PIO generates an IM2 interrupt on the falling edge of PA4.
            const ctc_out0 = (bus & (@as(Bus, 1) << CTC_PINS.OUT0)) != 0;
            const pio_pa4_mask: Bus = @as(Bus, 1) << PIO_PINS.PA[4];
            if (ctc_out0) {
                bus &= ~pio_pa4_mask;
            } else {
                bus |= pio_pa4_mask;
            }
            bus = self.psg.tick(bus);

            return bus;
        }

        fn videoTick(self: *Self, in_bus: Bus) Bus {
            var bus = in_bus;
            self.video.ticks += 1;
            if (self.video.ticks == video.screen.frame) {
                self.video.ticks = 0;
            }
            self.video.h_ticks += 1;
            if (self.video.h_ticks == video.screen.horizontal.line) {
                self.video.h_ticks = 0;
                self.video.v_count += 1;
                if (self.video.v_count == video.screen.height) {
                    self.video.v_count = 0;
                }
            }

            // Real HSYNC signal (CLK1 of CTC): assert at h_tick=950, deassert at h_tick=1030.
            // Driven directly from h_ticks so it fires on every line, including during VBLANK.
            if (self.video.h_ticks == video.screen.horizontal.sts_hsync_h_start) {
                bus &= ~CTC_CLK1;
                bus = self.ctc.setCLK1(bus);
                // Update CLK2 from OUT1 of Counter 1
                if (self.ctc.counter[1].out == 0) {
                    bus &= ~CTC_CLK2;
                } else {
                    bus |= CTC_CLK2;
                }
                bus = self.ctc.setCLK2(bus);
            }
            if (self.video.h_ticks == video.screen.horizontal.real_hsync_h_end) {
                bus |= CTC_CLK1;
                bus = self.ctc.setCLK1(bus);
                if (self.ctc.counter[1].out == 0) {
                    bus &= ~CTC_CLK2;
                } else {
                    bus |= CTC_CLK2;
                }
                bus = self.ctc.setCLK2(bus);
            }

            // sts_Hsync status bit: asserts at h_tick=950, deasserts at h_tick=1078.
            // Placed outside the visible-area check so it updates on every line.
            if (self.video.h_ticks == video.screen.horizontal.sts_hsync_h_start) {
                self.gdg.status &= ~GDG.STATUS_MODE.HSYNC;
            }
            if (self.video.h_ticks == video.screen.horizontal.sts_hsync_h_end) {
                self.gdg.status |= GDG.STATUS_MODE.HSYNC;
            }

            // Convert to coordinates if beam is in visible area
            if (videoHTickToFrameX(self.video.h_ticks)) |x| {
                if (videoTickToFrameY(self.video.ticks)) |y| {
                    const index = framebufferIndex(x, y);

                    // Video status updates
                    // Start of HBLANK
                    if (x == video.border.left + video.canvas.width) {
                        self.gdg.status &= ~GDG.STATUS_MODE.HBLANK;
                    }
                    // End of HBLANK
                    if (x == video.border.left) {
                        self.gdg.status |= GDG.STATUS_MODE.HBLANK;
                    }
                    // Start of VBLANK (active = 0) at end of last canvas row
                    if (x == 790 and y == (video.border.top + video.canvas.height - 1)) {
                        self.gdg.status &= ~GDG.STATUS_MODE.VBLANK;
                        // VBLN goes active (0): wired to PPI PC7 and PIO PA5
                        self.video.vbln = 0;
                    }
                    // End of VBLANK (inactive = 1) at end of last top-border row
                    if (x == 790 and y == (video.border.top - 1)) {
                        self.gdg.status |= GDG.STATUS_MODE.VBLANK;
                        // VBLN goes inactive (1): wired to PPI PC7 and PIO PA5
                        self.video.vbln = 1;
                    }
                    // Start of VSYNC
                    if (x == 792 and y == (video.border.top + video.canvas.height + video.border.bottom - 1)) {
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

        /// Load a WAV file for CMT playback from a byte slice.
        pub fn loadWav(self: *Self, data: []const u8) !void {
            try self.cmt.loadWav(data);
            self.cmt.configure(@intFromFloat(frequencies.CLK0));
        }

        /// Load an MZF file into memory, resets CPU and starts the loaded start address.
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

        inline fn isInRange(number: u16, lower_bound: u16, upper_bound: u16) bool {
            return (number >= lower_bound) and (number <= upper_bound);
        }

        fn isMZ700VRAMAddr(self: *Self, addr: u16) bool {
            if (!self.vram_banked_in) return false;
            if (!self.gdg.is_mz700) return false;
            // Character VRAM: 0xD000-0xD3FF only
            if (addr >= 0xD000 and addr < 0xD400) return true;
            // Color VRAM: 0xD800-0xDBFF only
            if (addr >= 0xD800 and addr < 0xDC00) return true;
            return false;
        }

        fn isMZ800VRAMAddr(self: *Self, addr: u16) bool {
            if (!self.vram_banked_in) return false;
            if (self.gdg.is_mz700) return false;
            if (addr < MEM_CONFIG.MZ800.VRAM_START) return false;
            const hires = (self.gdg.dmd & GDG.DMD_MODE.HIRES) != 0;
            return addr < (if (hires) MEM_CONFIG.MZ800.VRAM_HIRES_END else MEM_CONFIG.MZ800.VRAM_LORES_END);
        }

        /// Set CTC counter 0 GATE0: updates both the bus pin and the counter gate state.
        fn setCTC0Gate(self: *Self, bus: Bus, val: u1) Bus {
            self.ctc.counter[0].gate = val;
            return if (val == 1) bus | CTC_GATE0 else bus & ~CTC_GATE0;
        }

        fn mz700TranslateIOREQ(self: *Self, in_bus: Bus) Bus {
            var bus = in_bus;
            var io_addr: u16 = 0;
            // The bus stores the address in bits 8-23 (shifted left by 8 from the u16 value).
            // Use getAddr() to extract it, then check RD/WR separately.
            const addr = getAddr(bus);
            const is_rd = (bus & RD) != 0;
            const is_wr = (bus & WR) != 0;
            switch (addr) {
                // i8255
                MEM_CONFIG.MZ700.IO_START => if (is_wr) { io_addr = 0xd0; },
                MEM_CONFIG.MZ700.IO_START + 0x01 => if (is_rd) { io_addr = 0xd1; },
                MEM_CONFIG.MZ700.IO_START + 0x02 => io_addr = 0xd2,
                MEM_CONFIG.MZ700.IO_START + 0x03 => if (is_wr) { io_addr = 0xd3; },

                // i8253
                MEM_CONFIG.MZ700.IO_START + 0x04 => io_addr = 0xd4,
                MEM_CONFIG.MZ700.IO_START + 0x05 => io_addr = 0xd5,
                MEM_CONFIG.MZ700.IO_START + 0x06 => io_addr = 0xd6,
                MEM_CONFIG.MZ700.IO_START + 0x07 => if (is_wr) { io_addr = 0xd7; },

                // 0xE008: read maps to GDG status register (0xCE).
                // Write controls CTC counter 0 GATE signal (bit 0 only).
                MEM_CONFIG.MZ700.IO_START + 0x08 => {
                    if (is_rd) {
                        io_addr = 0xce;
                    } else if (is_wr) {
                        const gate_val: u1 = @truncate(getData(bus));
                        self.gdg.ct53g7 = gate_val;
                        self.bus = self.setCTC0Gate(self.bus, gate_val);
                    }
                },

                else => {},
            }

            if (io_addr != 0) {
                bus &= ~Z80.MREQ;
                bus |= Z80.IORQ;
                bus = setAddr(bus, io_addr);
            }

            return self.iorq(bus);
        }

        /// Translate IO addresses into chip select bits on the bus
        fn iorq(self: *Self, in_bus: Bus) Bus {
            var bus = in_bus;

            // Check only the lower byte of the address
            const addr = getAddr(bus) & 0xff;

            switch (addr) {
                // Serial IO (not implemented: return 0xFF on read, ignore writes)
                0xb0...0xb3 => if ((bus & RD) != 0) { bus = setData(bus, 0xFF); },
                // GDG WHID 65040-032, CRT controller
                0xcc...0xcf => {},
                // PPI i8255, keyboard and cassette driver
                0xd0...0xd3 => bus |= PPI.CS,
                // CTC i8253, programmable counter/timer
                0xd4...0xd7 => bus |= CTC.CS,
                // FDC, floppy disc controller (not implemented: return 0xFF on read, ignore writes)
                0xd8...0xdf => if ((bus & RD) != 0) { bus = setData(bus, 0xFF); },
                // GDG WHID 65040-032, memory bank switch
                0xe0...0xe6 => self.updateMemoryMap(bus),
                0xf0...0xf1 => {
                    // GDG WHID 65040-032, Palette register (write only, handled by gdg.tick())
                    // Joystick (read only)
                    if ((bus & RD) != 0) {
                        bus |= PPI.CS;
                    }
                },
                // PSG SN 76489 AN, sound generator
                0xf2 => bus |= PSG.CE,
                // QDC, quick disk controller (not implemented: return 0xFF on read, ignore writes)
                0xf4...0xf7 => if ((bus & RD) != 0) { bus = setData(bus, 0xFF); },
                // PIO Z80 PIO, parallel I/O unit
                0xfc...0xff => bus |= PIO.CE,
                // Unhandled ports: return 0xFF for reads (floating bus / pull-up behavior).
                else => if ((bus & RD) != 0) { bus = setData(bus, 0xFF); },
            }

            return bus;
        }

        /// Reset the memory map depending on type of reset
        fn resetMemoryMap(self: *Self, soft: bool) void {
            self.prohibit_active = false;
            // Soft reset: when pressing reset button while holding CTRL on keyboard
            if (soft) {
                // All memory will be DRAM; VRAM intercept must be disabled.
                self.vram_banked_in = false;
                self.rom1_mapped = false;
                self.cgrom_mapped = false;
                self.rom2_mapped = false;
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
            self.rom1_mapped = true;
            self.cgrom_mapped = true;
            self.rom2_mapped = true;
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
                            self.rom1_mapped = false;
                            self.cgrom_mapped = false;
                        },
                        MEM.SW1 => {
                            if (self.gdg.is_mz700) {
                                self.vram_banked_in = false;
                                self.mem.mapRAM(MEM_CONFIG.MZ700.VRAM_START, 0x3000, self.ram[MEM_CONFIG.MZ700.VRAM_START..0x10000]);
                            } else {
                                self.mem.mapRAM(0xe000, 0x2000, self.ram[0xe000..0x10000]);
                                self.rom2_mapped = false;
                            }
                        },
                        MEM.SW2 => {
                            self.mem.mapROM(MEM_CONFIG.MZ800.ROM1_START, MEM_CONFIG.MZ800.ROM1_SIZE, &self.rom.rom1);
                            self.rom1_mapped = true;
                        },
                        MEM.SW3 => {
                            // Special treatment in MZ-700: VRAM in 0xd000-0xdfff, Key, Timer in 0xe000-0xe070
                            // This isn't handled by regular memory mapping
                            if (self.gdg.is_mz700) {
                                self.vram_banked_in = true;
                            }
                            self.mem.mapROM(MEM_CONFIG.MZ800.ROM2_START, MEM_CONFIG.MZ800.ROM2_SIZE, &self.rom.rom2);
                            self.rom2_mapped = true;
                        },
                        MEM.SW4 => {
                            self.mem.mapROM(MEM_CONFIG.MZ800.ROM1_START, MEM_CONFIG.MZ800.ROM1_SIZE, &self.rom.rom1);
                            self.rom1_mapped = true;
                            if (self.gdg.is_mz700) {
                                self.mem.mapRAM(0x1000, 0xd000, self.ram[0x1000..0xe000]);
                            } else {
                                self.mem.mapROM(MEM_CONFIG.MZ800.CGROM_START, MEM_CONFIG.MZ800.CGROM_SIZE, &self.rom.cgrom);
                                self.cgrom_mapped = true;
                                self.mem.mapRAM(0x2000, 0xc000, self.ram[0x2000..0xe000]);
                            }
                            self.vram_banked_in = true;
                            self.mem.mapROM(MEM_CONFIG.MZ800.ROM2_START, MEM_CONFIG.MZ800.ROM2_SIZE, &self.rom.rom2);
                            self.rom2_mapped = true;
                        },
                        MEM.PROHIBIT => {
                            // Save current ROM mapping state and hide all ROMs.
                            self.pre_prohibit_rom1 = self.rom1_mapped;
                            self.pre_prohibit_cgrom = self.cgrom_mapped;
                            self.pre_prohibit_rom2 = self.rom2_mapped;
                            self.prohibit_active = true;
                            self.mem.mapRAM(MEM_CONFIG.MZ800.ROM1_START, MEM_CONFIG.MZ800.ROM1_SIZE, self.ram[MEM_CONFIG.MZ800.ROM1_START .. MEM_CONFIG.MZ800.ROM1_START + MEM_CONFIG.MZ800.ROM1_SIZE]);
                            self.mem.mapRAM(MEM_CONFIG.MZ800.CGROM_START, MEM_CONFIG.MZ800.CGROM_SIZE, self.ram[MEM_CONFIG.MZ800.CGROM_START .. MEM_CONFIG.MZ800.CGROM_START + MEM_CONFIG.MZ800.CGROM_SIZE]);
                            self.mem.mapRAM(MEM_CONFIG.MZ800.ROM2_START, MEM_CONFIG.MZ800.ROM2_SIZE, self.ram[MEM_CONFIG.MZ800.ROM2_START..0x10000]);
                            self.rom1_mapped = false;
                            self.cgrom_mapped = false;
                            self.rom2_mapped = false;
                        },
                        MEM.RETURN => {
                            // Restore ROM mapping to state before PROHIBIT was issued.
                            if (self.prohibit_active) {
                                self.prohibit_active = false;
                                if (self.pre_prohibit_rom1) {
                                    self.mem.mapROM(MEM_CONFIG.MZ800.ROM1_START, MEM_CONFIG.MZ800.ROM1_SIZE, &self.rom.rom1);
                                    self.rom1_mapped = true;
                                }
                                if (self.pre_prohibit_cgrom) {
                                    self.mem.mapROM(MEM_CONFIG.MZ800.CGROM_START, MEM_CONFIG.MZ800.CGROM_SIZE, &self.rom.cgrom);
                                    self.cgrom_mapped = true;
                                }
                                if (self.pre_prohibit_rom2) {
                                    self.mem.mapROM(MEM_CONFIG.MZ800.ROM2_START, MEM_CONFIG.MZ800.ROM2_SIZE, &self.rom.rom2);
                                    self.rom2_mapped = true;
                                }
                            }
                        },
                        else => {},
                    }
                },
                (RD | IORQ) => {
                    const MEM = IO_ADDR.RD.MEM;
                    switch (sw) {
                        MEM.SW0 => {
                            self.mem.mapROM(MEM_CONFIG.MZ800.CGROM_START, MEM_CONFIG.MZ800.CGROM_SIZE, &self.rom.cgrom);
                            self.cgrom_mapped = true;
                            self.vram_banked_in = true;
                        },
                        MEM.SW1 => {
                            self.mem.mapRAM(0x1000, 0x1000, self.ram[0x1000..0x2000]);
                            self.cgrom_mapped = false;
                            // Do NOT clear vram_banked_in: reading $E1 only swaps CGROM→RAM at
                            // $1000–$1FFF. VRAM at $D000–$DBFF remains accessible throughout boot.
                        },
                        else => {},
                    }
                },
                else => {},
            }
        }

        /// Keyboard matrix: sokol Keycode integer values → (column, bit) in the 10×8 matrix.
        /// Active low: 0 = pressed, 1 = released (initial state 0xFF per column).
        /// Integer values match sokol app.zig Keycode enum.
        const KeyEntry = struct { key: u32, col: u4, bit: u3 };
        const KEY_MAP = [_]KeyEntry{
            // Col 0: BLANK(GRAVE), GRAPH(CAPS), LIBRA(F9), ALPHA(BACKSLASH), TAB, ;, :, CR
            .{ .key = 96,  .col = 0, .bit = 7 }, // GRAVE_ACCENT → BLANK
            .{ .key = 280, .col = 0, .bit = 6 }, // CAPS_LOCK → GRAPH
            .{ .key = 298, .col = 0, .bit = 5 }, // F9 → LIBRA
            .{ .key = 92,  .col = 0, .bit = 4 }, // BACKSLASH → ALPHA
            .{ .key = 258, .col = 0, .bit = 3 }, // TAB
            .{ .key = 59,  .col = 0, .bit = 2 }, // SEMICOLON
            .{ .key = 334, .col = 0, .bit = 2 }, // KP_ADD → semicolon key
            .{ .key = 39,  .col = 0, .bit = 1 }, // APOSTROPHE → colon key
            .{ .key = 332, .col = 0, .bit = 1 }, // KP_MULTIPLY → colon key
            .{ .key = 257, .col = 0, .bit = 0 }, // ENTER
            .{ .key = 335, .col = 0, .bit = 0 }, // KP_ENTER
            // Col 1: Y, Z, @(F6), [, ]
            .{ .key = 89,  .col = 1, .bit = 7 }, // Y
            .{ .key = 90,  .col = 1, .bit = 6 }, // Z
            .{ .key = 295, .col = 1, .bit = 5 }, // F6 → @ key
            .{ .key = 91,  .col = 1, .bit = 4 }, // LEFT_BRACKET
            .{ .key = 93,  .col = 1, .bit = 3 }, // RIGHT_BRACKET
            // Col 2: Q R S T U V W X
            .{ .key = 81,  .col = 2, .bit = 7 }, // Q
            .{ .key = 82,  .col = 2, .bit = 6 }, // R
            .{ .key = 83,  .col = 2, .bit = 5 }, // S
            .{ .key = 84,  .col = 2, .bit = 4 }, // T
            .{ .key = 85,  .col = 2, .bit = 3 }, // U
            .{ .key = 86,  .col = 2, .bit = 2 }, // V
            .{ .key = 87,  .col = 2, .bit = 1 }, // W
            .{ .key = 88,  .col = 2, .bit = 0 }, // X
            // Col 3: I J K L M N O P
            .{ .key = 73,  .col = 3, .bit = 7 }, // I
            .{ .key = 74,  .col = 3, .bit = 6 }, // J
            .{ .key = 75,  .col = 3, .bit = 5 }, // K
            .{ .key = 76,  .col = 3, .bit = 4 }, // L
            .{ .key = 77,  .col = 3, .bit = 3 }, // M
            .{ .key = 78,  .col = 3, .bit = 2 }, // N
            .{ .key = 79,  .col = 3, .bit = 1 }, // O
            .{ .key = 80,  .col = 3, .bit = 0 }, // P
            // Col 4: A B C D E F G H
            .{ .key = 65,  .col = 4, .bit = 7 }, // A
            .{ .key = 66,  .col = 4, .bit = 6 }, // B
            .{ .key = 67,  .col = 4, .bit = 5 }, // C
            .{ .key = 68,  .col = 4, .bit = 4 }, // D
            .{ .key = 69,  .col = 4, .bit = 3 }, // E
            .{ .key = 70,  .col = 4, .bit = 2 }, // F
            .{ .key = 71,  .col = 4, .bit = 1 }, // G
            .{ .key = 72,  .col = 4, .bit = 0 }, // H
            // Col 5: 1 2 3 4 5 6 7 8
            .{ .key = 49,  .col = 5, .bit = 7 }, // 1
            .{ .key = 321, .col = 5, .bit = 7 }, // KP_1
            .{ .key = 50,  .col = 5, .bit = 6 }, // 2
            .{ .key = 51,  .col = 5, .bit = 5 }, // 3
            .{ .key = 323, .col = 5, .bit = 5 }, // KP_3
            .{ .key = 52,  .col = 5, .bit = 4 }, // 4
            .{ .key = 53,  .col = 5, .bit = 3 }, // 5
            .{ .key = 325, .col = 5, .bit = 3 }, // KP_5
            .{ .key = 54,  .col = 5, .bit = 2 }, // 6
            .{ .key = 55,  .col = 5, .bit = 1 }, // 7
            .{ .key = 327, .col = 5, .bit = 1 }, // KP_7
            .{ .key = 56,  .col = 5, .bit = 0 }, // 8
            // Col 6: \(F7), EQUAL(~), MINUS, SPACE, 0, 9, COMMA, PERIOD
            .{ .key = 296, .col = 6, .bit = 7 }, // F7 → \ key
            .{ .key = 61,  .col = 6, .bit = 6 }, // EQUAL → ~ key
            .{ .key = 45,  .col = 6, .bit = 5 }, // MINUS
            .{ .key = 333, .col = 6, .bit = 5 }, // KP_SUBTRACT → minus key
            .{ .key = 32,  .col = 6, .bit = 4 }, // SPACE
            .{ .key = 48,  .col = 6, .bit = 3 }, // 0
            .{ .key = 57,  .col = 6, .bit = 2 }, // 9
            .{ .key = 329, .col = 6, .bit = 2 }, // KP_9
            .{ .key = 44,  .col = 6, .bit = 1 }, // COMMA
            .{ .key = 46,  .col = 6, .bit = 0 }, // PERIOD
            // Col 7: INSERT, DELETE, UP, DOWN, RIGHT, LEFT, ?(F8), SLASH(/)
            .{ .key = 260, .col = 7, .bit = 7 }, // INSERT
            .{ .key = 320, .col = 7, .bit = 7 }, // KP_0 (no NumLock) → INSERT
            .{ .key = 261, .col = 7, .bit = 6 }, // DELETE
            .{ .key = 259, .col = 7, .bit = 6 }, // BACKSPACE → DELETE
            .{ .key = 330, .col = 7, .bit = 6 }, // KP_DECIMAL (no NumLock) → DELETE
            .{ .key = 265, .col = 7, .bit = 5 }, // UP
            .{ .key = 328, .col = 7, .bit = 5 }, // KP_8 (no NumLock) → UP
            .{ .key = 264, .col = 7, .bit = 4 }, // DOWN
            .{ .key = 322, .col = 7, .bit = 4 }, // KP_2 (no NumLock) → DOWN
            .{ .key = 262, .col = 7, .bit = 3 }, // RIGHT
            .{ .key = 326, .col = 7, .bit = 3 }, // KP_6 (no NumLock) → RIGHT
            .{ .key = 263, .col = 7, .bit = 2 }, // LEFT
            .{ .key = 324, .col = 7, .bit = 2 }, // KP_4 (no NumLock) → LEFT
            .{ .key = 297, .col = 7, .bit = 1 }, // F8 → ? key
            .{ .key = 47,  .col = 7, .bit = 0 }, // SLASH
            .{ .key = 331, .col = 7, .bit = 0 }, // KP_DIVIDE → slash key
            // Col 8: ESC, CTRL (L/R), SHIFT (L/R)
            .{ .key = 256, .col = 8, .bit = 7 }, // ESCAPE
            .{ .key = 269, .col = 8, .bit = 7 }, // END → ESC
            .{ .key = 341, .col = 8, .bit = 6 }, // LEFT_CONTROL
            .{ .key = 345, .col = 8, .bit = 6 }, // RIGHT_CONTROL
            .{ .key = 340, .col = 8, .bit = 0 }, // LEFT_SHIFT
            .{ .key = 344, .col = 8, .bit = 0 }, // RIGHT_SHIFT
            // Col 9: F1 F2 F3 F4 F5
            .{ .key = 290, .col = 9, .bit = 7 }, // F1
            .{ .key = 291, .col = 9, .bit = 6 }, // F2
            .{ .key = 292, .col = 9, .bit = 5 }, // F3
            .{ .key = 293, .col = 9, .bit = 4 }, // F4
            .{ .key = 294, .col = 9, .bit = 3 }, // F5
        };

        pub fn keyDown(self: *Self, key: u32) void {
            for (KEY_MAP) |entry| {
                if (entry.key == key) {
                    self.keyboard_matrix[entry.col] &= ~(@as(u8, 1) << entry.bit);
                    return;
                }
            }
        }

        pub fn keyUp(self: *Self, key: u32) void {
            for (KEY_MAP) |entry| {
                if (entry.key == key) {
                    self.keyboard_matrix[entry.col] |= @as(u8, 1) << entry.bit;
                    return;
                }
            }
        }

        pub fn flushKeyboard(self: *Self) void {
            self.keyboard_matrix = [_]u8{0xFF} ** 10;
            self.key_buf.flush();
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
                .viewport = .{
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
