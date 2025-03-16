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

var sys: MZ800 = undefined;
var gpa = GeneralPurposeAllocator(.{}){};

const ig = @import("cimgui");
const simgui = sokol.imgui;

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
                // TODO: open chip window
            }
            if (ig.igMenuItem("Z80 PIO")) {
                // TODO: open chip window
            }
            if (ig.igMenuItem("i8255 PPI")) {
                // TODO: open chip window
            }
            if (ig.igMenuItem("i8253 CTC")) {
                // TODO: open chip window
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
            std.debug.print("🚨 Char code: {}", .{c});
        },
        .KEY_DOWN, .KEY_UP => {
            const code = event.key_code;
            std.debug.print("🚨 Key code: {}", .{code});
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
    std.debug.print("🚨 Name: {s}\n", .{obj_file.header.name});
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
