const std = @import("std");
const fs = std.fs;
const GeneralPurposeAllocator = std.heap.GeneralPurposeAllocator;
const sokol = @import("sokol");
const sapp = sokol.app;
const slog = sokol.log;
const chipz = @import("chipz");
const host = chipz.host;
const chips = @import("chips");
const system = @import("system");
const mz800 = system.mz800;
const MZ800 = mz800.Type();
const frequencies = mz800.frequencies;
const mzf = system.mzf;
const MZF = mzf.Type();

const mz800_name = "MZ-800";
const mz700_name = "MZ-700";

const ui = chipz.ui;
const ui_intern = @import("ui");
const ig = @import("cimgui");
const simgui = sokol.imgui;

const UI_CHIP = ui.ui_chip.Type(.{ .bus = mz800.Bus });
const UI_Z80 = ui.ui_z80.Type(.{ .bus = mz800.Bus, .cpu = mz800.Z80 });
const UI_Z80_Pins = [_]UI_CHIP.Pin{
    .{ .name = "D0", .slot = 0, .mask = mz800.Z80.D0 },
    .{ .name = "D1", .slot = 1, .mask = mz800.Z80.D1 },
    .{ .name = "D2", .slot = 2, .mask = mz800.Z80.D2 },
    .{ .name = "D3", .slot = 3, .mask = mz800.Z80.D3 },
    .{ .name = "D4", .slot = 4, .mask = mz800.Z80.D4 },
    .{ .name = "D5", .slot = 5, .mask = mz800.Z80.D5 },
    .{ .name = "D6", .slot = 6, .mask = mz800.Z80.D6 },
    .{ .name = "D7", .slot = 7, .mask = mz800.Z80.D7 },
    .{ .name = "M1", .slot = 8, .mask = mz800.Z80.M1 },
    .{ .name = "MREQ", .slot = 9, .mask = mz800.Z80.MREQ },
    .{ .name = "IORQ", .slot = 10, .mask = mz800.Z80.IORQ },
    .{ .name = "RD", .slot = 11, .mask = mz800.Z80.RD },
    .{ .name = "WR", .slot = 12, .mask = mz800.Z80.WR },
    .{ .name = "RFSH", .slot = 13, .mask = mz800.Z80.RFSH },
    .{ .name = "HALT", .slot = 14, .mask = mz800.Z80.HALT },
    .{ .name = "INT", .slot = 15, .mask = mz800.Z80.INT },
    .{ .name = "NMI", .slot = 16, .mask = mz800.Z80.NMI },
    .{ .name = "WAIT", .slot = 17, .mask = mz800.Z80.WAIT },
    .{ .name = "A0", .slot = 18, .mask = mz800.Z80.A0 },
    .{ .name = "A1", .slot = 19, .mask = mz800.Z80.A1 },
    .{ .name = "A2", .slot = 20, .mask = mz800.Z80.A2 },
    .{ .name = "A3", .slot = 21, .mask = mz800.Z80.A3 },
    .{ .name = "A4", .slot = 22, .mask = mz800.Z80.A4 },
    .{ .name = "A5", .slot = 23, .mask = mz800.Z80.A5 },
    .{ .name = "A6", .slot = 24, .mask = mz800.Z80.A6 },
    .{ .name = "A7", .slot = 25, .mask = mz800.Z80.A7 },
    .{ .name = "A8", .slot = 26, .mask = mz800.Z80.A8 },
    .{ .name = "A9", .slot = 27, .mask = mz800.Z80.A9 },
    .{ .name = "A10", .slot = 28, .mask = mz800.Z80.A10 },
    .{ .name = "A11", .slot = 29, .mask = mz800.Z80.A11 },
    .{ .name = "A12", .slot = 30, .mask = mz800.Z80.A12 },
    .{ .name = "A13", .slot = 31, .mask = mz800.Z80.A13 },
    .{ .name = "A14", .slot = 32, .mask = mz800.Z80.A14 },
    .{ .name = "A15", .slot = 33, .mask = mz800.Z80.A15 },
};
const UI_Z80PIO = ui.ui_z80pio.Type(.{ .bus = mz800.Bus, .pio = mz800.PIO });
const UI_Z80PIO_Pins = [_]UI_CHIP.Pin{
    .{ .name = "D0", .slot = 0, .mask = mz800.Z80.D0 },
    .{ .name = "D1", .slot = 1, .mask = mz800.Z80.D1 },
    .{ .name = "D2", .slot = 2, .mask = mz800.Z80.D2 },
    .{ .name = "D3", .slot = 3, .mask = mz800.Z80.D3 },
    .{ .name = "D4", .slot = 4, .mask = mz800.Z80.D4 },
    .{ .name = "D5", .slot = 5, .mask = mz800.Z80.D5 },
    .{ .name = "D6", .slot = 6, .mask = mz800.Z80.D6 },
    .{ .name = "D7", .slot = 7, .mask = mz800.Z80.D7 },
    .{ .name = "CE", .slot = 9, .mask = mz800.PIO.CE },
    .{ .name = "BASEL", .slot = 10, .mask = mz800.PIO.BASEL },
    .{ .name = "CDSEL", .slot = 11, .mask = mz800.PIO.CDSEL },
    .{ .name = "M1", .slot = 12, .mask = mz800.PIO.M1 },
    .{ .name = "IORQ", .slot = 13, .mask = mz800.PIO.IORQ },
    .{ .name = "RD", .slot = 14, .mask = mz800.PIO.RD },
    .{ .name = "INT", .slot = 15, .mask = mz800.PIO.INT },
    .{ .name = "ARDY", .slot = 20, .mask = mz800.PIO.ARDY },
    .{ .name = "ASTB", .slot = 21, .mask = mz800.PIO.ASTB },
    .{ .name = "PA0", .slot = 22, .mask = mz800.PIO.PA0 },
    .{ .name = "PA1", .slot = 23, .mask = mz800.PIO.PA1 },
    .{ .name = "PA2", .slot = 24, .mask = mz800.PIO.PA2 },
    .{ .name = "PA3", .slot = 25, .mask = mz800.PIO.PA3 },
    .{ .name = "PA4", .slot = 26, .mask = mz800.PIO.PA4 },
    .{ .name = "PA5", .slot = 27, .mask = mz800.PIO.PA5 },
    .{ .name = "PA6", .slot = 28, .mask = mz800.PIO.PA6 },
    .{ .name = "PA7", .slot = 29, .mask = mz800.PIO.PA7 },
    .{ .name = "BRDY", .slot = 30, .mask = mz800.PIO.ARDY },
    .{ .name = "BSTB", .slot = 31, .mask = mz800.PIO.ASTB },
    .{ .name = "PB0", .slot = 32, .mask = mz800.PIO.PB0 },
    .{ .name = "PB1", .slot = 33, .mask = mz800.PIO.PB1 },
    .{ .name = "PB2", .slot = 34, .mask = mz800.PIO.PB2 },
    .{ .name = "PB3", .slot = 35, .mask = mz800.PIO.PB3 },
    .{ .name = "PB4", .slot = 36, .mask = mz800.PIO.PB4 },
    .{ .name = "PB5", .slot = 37, .mask = mz800.PIO.PB5 },
    .{ .name = "PB6", .slot = 38, .mask = mz800.PIO.PB6 },
    .{ .name = "PB7", .slot = 39, .mask = mz800.PIO.PB7 },
};
const UI_INTEL8255 = ui.ui_intel8255.Type(.{ .bus = mz800.Bus, .ppi = mz800.PPI });
const UI_INTEL8255_Pins = [_]UI_CHIP.Pin{
    .{ .name = "D0", .slot = 0, .mask = mz800.Z80.D0 },
    .{ .name = "D1", .slot = 1, .mask = mz800.Z80.D1 },
    .{ .name = "D2", .slot = 2, .mask = mz800.Z80.D2 },
    .{ .name = "D3", .slot = 3, .mask = mz800.Z80.D3 },
    .{ .name = "D4", .slot = 4, .mask = mz800.Z80.D4 },
    .{ .name = "D5", .slot = 5, .mask = mz800.Z80.D5 },
    .{ .name = "D6", .slot = 6, .mask = mz800.Z80.D6 },
    .{ .name = "D7", .slot = 7, .mask = mz800.Z80.D7 },
    .{ .name = "CS", .slot = 9, .mask = mz800.PPI.CS },
    .{ .name = "RD", .slot = 10, .mask = mz800.PPI.RD },
    .{ .name = "WR", .slot = 11, .mask = mz800.PPI.WR },
    .{ .name = "A0", .slot = 12, .mask = mz800.Z80.A0 },
    .{ .name = "A1", .slot = 13, .mask = mz800.Z80.A1 },
    .{ .name = "PC0", .slot = 16, .mask = mz800.PPI.PC0 },
    .{ .name = "PC1", .slot = 17, .mask = mz800.PPI.PC1 },
    .{ .name = "PC2", .slot = 18, .mask = mz800.PPI.PC2 },
    .{ .name = "PC3", .slot = 19, .mask = mz800.PPI.PC3 },
    .{ .name = "PA0", .slot = 20, .mask = mz800.PPI.PA0 },
    .{ .name = "PA1", .slot = 21, .mask = mz800.PPI.PA1 },
    .{ .name = "PA2", .slot = 22, .mask = mz800.PPI.PA2 },
    .{ .name = "PA3", .slot = 23, .mask = mz800.PPI.PA3 },
    .{ .name = "PA4", .slot = 24, .mask = mz800.PPI.PA4 },
    .{ .name = "PA5", .slot = 25, .mask = mz800.PPI.PA5 },
    .{ .name = "PA6", .slot = 26, .mask = mz800.PPI.PA6 },
    .{ .name = "PA7", .slot = 27, .mask = mz800.PPI.PA7 },
    .{ .name = "PB0", .slot = 28, .mask = mz800.PPI.PB0 },
    .{ .name = "PB1", .slot = 29, .mask = mz800.PPI.PB1 },
    .{ .name = "PB2", .slot = 30, .mask = mz800.PPI.PB2 },
    .{ .name = "PB3", .slot = 31, .mask = mz800.PPI.PB3 },
    .{ .name = "PB4", .slot = 32, .mask = mz800.PPI.PB4 },
    .{ .name = "PB5", .slot = 33, .mask = mz800.PPI.PB5 },
    .{ .name = "PB6", .slot = 34, .mask = mz800.PPI.PB6 },
    .{ .name = "PB7", .slot = 35, .mask = mz800.PPI.PB7 },
    .{ .name = "PC4", .slot = 36, .mask = mz800.PPI.PC4 },
    .{ .name = "PC5", .slot = 37, .mask = mz800.PPI.PC5 },
    .{ .name = "PC6", .slot = 38, .mask = mz800.PPI.PC6 },
    .{ .name = "PC7", .slot = 39, .mask = mz800.PPI.PC7 },
};
const UI_INTEL8253 = ui_intern.ui_intel8253.Type(.{ .bus = mz800.Bus, .ctc = mz800.CTC });
const UI_INTEL8253_Pins = [_]UI_CHIP.Pin{
    .{ .name = "D0", .slot = 0, .mask = mz800.Z80.D0 },
    .{ .name = "D1", .slot = 1, .mask = mz800.Z80.D1 },
    .{ .name = "D2", .slot = 2, .mask = mz800.Z80.D2 },
    .{ .name = "D3", .slot = 3, .mask = mz800.Z80.D3 },
    .{ .name = "D4", .slot = 4, .mask = mz800.Z80.D4 },
    .{ .name = "D5", .slot = 5, .mask = mz800.Z80.D5 },
    .{ .name = "D6", .slot = 6, .mask = mz800.Z80.D6 },
    .{ .name = "D7", .slot = 7, .mask = mz800.Z80.D7 },
    .{ .name = "CS", .slot = 9, .mask = mz800.CTC.CS },
    .{ .name = "RD", .slot = 10, .mask = mz800.CTC.RD },
    .{ .name = "WR", .slot = 11, .mask = mz800.CTC.WR },
    .{ .name = "A0", .slot = 12, .mask = mz800.Z80.A0 },
    .{ .name = "A1", .slot = 13, .mask = mz800.Z80.A1 },
    .{ .name = "CLK0", .slot = 16, .mask = mz800.CTC.CLK0 },
    .{ .name = "GATE0", .slot = 17, .mask = mz800.CTC.GATE0 },
    .{ .name = "OUT0", .slot = 18, .mask = mz800.CTC.OUT0 },
    .{ .name = "CLK1", .slot = 20, .mask = mz800.CTC.CLK1 },
    .{ .name = "GATE1", .slot = 21, .mask = mz800.CTC.GATE1 },
    .{ .name = "OUT1", .slot = 22, .mask = mz800.CTC.OUT1 },
    .{ .name = "CLK2", .slot = 24, .mask = mz800.CTC.CLK2 },
    .{ .name = "GATE2", .slot = 25, .mask = mz800.CTC.GATE2 },
    .{ .name = "OUT2", .slot = 26, .mask = mz800.CTC.OUT2 },
};

var sys: MZ800 = undefined;
var gpa = GeneralPurposeAllocator(.{}){};

var ui_z80: UI_Z80 = undefined;
var ui_z80pio: UI_Z80PIO = undefined;
var ui_intel8255: UI_INTEL8255 = undefined;
var ui_intel8253: UI_INTEL8253 = undefined;

export fn init() void {
    std.debug.print("🚨 Booting MZ-800...\n", .{});
    host.audio.init(.{});
    host.time.init();
    host.prof.init();
    sys.initInPlace(.{ .roms = .{
        .rom1 = @embedFile("system/roms/MZ800_ROM1.bin"),
        .cgrom = @embedFile("system/roms/MZ800_CGROM.bin"),
        .rom2 = @embedFile("system/roms/MZ800_ROM2.bin"),
    } });
    host.gfx.init(.{
        .display = sys.displayInfo(),
        .pixel_aspect = .{
            .width = 1,
            .height = 2,
        },
    });

    // Setting up debug UI
    var start = ig.ImVec2{ .x = 20, .y = 20 };
    const d = ig.ImVec2{ .x = 10, .y = 10 };
    ui_z80.initInPlace(.{
        .title = "Z80 CPU",
        .cpu = &sys.cpu,
        .origin = start,
        .chip = .{ .name = "Z80\nCPU", .num_slots = 36, .pins = &UI_Z80_Pins },
    });
    start.x += d.x;
    start.y += d.y;
    ui_z80pio.initInPlace(.{
        .title = "Z80 PIO",
        .pio = &sys.pio,
        .origin = start,
        .chip = .{ .name = "Z80\nPIO", .num_slots = 40, .pins = &UI_Z80PIO_Pins },
    });
    start.x += d.x;
    start.y += d.y;
    ui_intel8255.initInPlace(.{
        .title = "intel8255 PPI",
        .ppi = &sys.ppi,
        .origin = start,
        .chip = .{ .name = "i8255\nPPI", .num_slots = 40, .pins = &UI_INTEL8255_Pins },
    });
    start.x += d.x;
    start.y += d.y;
    ui_intel8253.initInPlace(.{
        .title = "intel8253 CTC",
        .ctc = &sys.ctc,
        .origin = start,
        .chip = .{ .name = "i8253\nCTC", .num_slots = 28, .pins = &UI_INTEL8253_Pins },
    });
    start.x += d.x;
    start.y += d.y;

    // initialize sokol-imgui
    simgui.setup(.{
        .logger = .{ .func = slog.func },
    });
    host.gfx.addDrawFunc(renderGUI);
}

export fn frame() void {
    const frame_time = host.time.frameTime();
    host.prof.pushMicroSeconds(.FRAME, frame_time);
    host.time.emuStart();
    const num_ticks = sys.exec(frame_time);
    host.prof.pushMicroSeconds(.EMU, host.time.emuEnd());
    const name = if (sys.gdg.is_mz700) mz700_name else mz800_name;

    // call simgui.newFrame() before any ImGui calls
    simgui.newFrame(.{
        .width = sapp.width(),
        .height = sapp.height(),
        .delta_time = sapp.frameDuration(),
        .dpi_scale = sapp.dpiScale(),
    });

    uiDrawMenu();
    ui_z80.draw(sys.bus);
    ui_z80pio.draw(sys.bus);
    ui_intel8255.draw(sys.bus);
    ui_intel8253.draw(sys.bus);

    host.gfx.draw(.{
        .display = sys.displayInfo(),
        .status = .{
            .name = name,
            .num_ticks = num_ticks,
            .frame_stats = host.prof.stats(.FRAME),
            .emu_stats = host.prof.stats(.EMU),
        },
    });
}

pub fn renderGUI() void {
    simgui.render();
}

fn uiDrawMenu() void {
    if (ig.igBeginMainMenuBar()) {
        if (ig.igBeginMenu("System")) {
            if (ig.igMenuItem("Reset")) {
                sys.reset(false);
            }
            if (ig.igMenuItem("Soft Reset")) {
                sys.reset(true);
            }
            ig.igEndMenu();
        }
        if (ig.igBeginMenu("Hardware")) {
            if (ig.igMenuItem("Z80")) {
                ui_z80.open = true;
            }
            if (ig.igMenuItem("Z80 PIO")) {
                ui_z80pio.open = true;
            }
            if (ig.igMenuItem("i8255 PPI")) {
                ui_intel8255.open = true;
            }
            if (ig.igMenuItem("i8253 CTC")) {
                ui_intel8253.open = true;
            }
            ig.igEndMenu();
        }
        if (ig.igBeginMenu("Debug")) {
            if (ig.igMenuItem("CPU Debugger")) {
                // TODO: open window
            }
            if (ig.igMenuItem("Breakpoints")) {
                // TODO: open window
            }
            if (ig.igBeginMenu("Memory Editor")) {
                if (ig.igMenuItem("VRAM")) {
                    // TODO: open window
                }
                ig.igEndMenu();
            }
            ig.igEndMenu();
        }
        ig.igEndMainMenuBar();
    }
}

export fn cleanup() void {
    simgui.shutdown();
    host.gfx.shutdown();
    host.prof.shutdown();
    host.audio.shutdown();
}

export fn input(ev: ?*const sapp.Event) void {
    const event = ev.?;
    // const shift = (0 != (event.modifiers & sapp.modifier_shift));

    // forward input events to sokol-imgui
    _ = simgui.handleEvent(event.*);

    switch (event.type) {
        .CHAR => {
            const c: u8 = @truncate(event.char_code);
            std.debug.print("🚨 Char code: {}\n", .{c});
        },
        .KEY_DOWN, .KEY_UP => {
            const code = event.key_code;
            std.debug.print("🚨 Key code: {}\n", .{code});
        },
        .FILES_DROPPED => {
            handleDroppedFiles();
        },
        else => {},
    }
}

fn handleDroppedFiles() void {
    const num_of_files: usize = @intCast(sapp.getNumDroppedFiles());
    std.debug.print("🚨 Files dropped: {}\n", .{num_of_files});
    var obj_file: MZF = undefined;
    const path = sapp.getDroppedFilePath(0);
    std.debug.print("🚨 Loading file: {s}\n", .{path});
    obj_file.load(std.fs.cwd(), path) catch |err| {
        std.debug.print("Error loading file '{s}': {}\n", .{ path, err });
    };
    std.debug.print("🚨 Name: {s}\n", .{obj_file.display_name});
    std.debug.print("🚨 Loading address: 0x{x:0>4}\n", .{obj_file.header.loading_address});
    std.debug.print("🚨 Starting address: 0x{x:0>4}\n", .{obj_file.header.start_address});
    sys.load(obj_file);
}

pub fn main() void {
    const display = MZ800.displayInfo(null);
    const width = display.view.width;
    const height = display.view.height;
    std.debug.print("🚨 Display: {}x{}\n", .{ width, height });
    sapp.run(.{
        .init_cb = init,
        .event_cb = input,
        .frame_cb = frame,
        .cleanup_cb = cleanup,
        .window_title = mz800_name,
        .width = width,
        .height = 2 * height,
        .icon = .{ .sokol_default = true },
        .logger = .{ .func = slog.func },
        .enable_dragndrop = true,
    });
}
