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

const name = "MZ-800";

var sys: MZ800 = undefined;
var gpa = GeneralPurposeAllocator(.{}){};

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
}

export fn frame() void {
    const frame_time = host.time.frameTime();
    host.prof.pushMicroSeconds(.FRAME, frame_time);
    host.time.emuStart();
    const num_ticks = sys.exec(frame_time);
    host.prof.pushMicroSeconds(.EMU, host.time.emuEnd());
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

export fn cleanup() void {
    host.gfx.shutdown();
    host.prof.shutdown();
    host.audio.shutdown();
}

export fn input(ev: ?*const sapp.Event) void {
    const event = ev.?;
    // const shift = (0 != (event.modifiers & sapp.modifier_shift));

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
    for (0..num_of_files) |index| {
        const path = sapp.getDroppedFilePath(@intCast(index));
        std.debug.print("🚨 File dropped: {s}\n", .{path});
        const data = fileLoad(path) catch |err| {
            std.debug.print("{?}", .{err});
            return;
        };
        std.debug.print("🚨 Read {} bytes.\n", .{data.?.len});
    }
}

fn fileLoad(path: []const u8) !?[]const u8 {
    const allocator = gpa.allocator();
    var file_data: ?[]const u8 = null;
    file_data = fs.cwd().readFileAlloc(allocator, path, 0x10000) catch |err| {
        std.debug.print("Error loading file '{s}'", .{path});
        return err;
    };
    return file_data;
}

pub fn main() void {
    const display = MZ800.displayInfo(null);
    const border = host.gfx.DEFAULT_BORDER;
    const width = 2 * display.view.width + border.left + border.right;
    const height = 2 * display.view.height + border.top + border.bottom;
    std.debug.print("🚨 Display: {}x{}\n", .{ width, height });
    sapp.run(.{
        .init_cb = init,
        .event_cb = input,
        .frame_cb = frame,
        .cleanup_cb = cleanup,
        .window_title = name,
        .width = width,
        .height = height,
        .icon = .{ .sokol_default = true },
        .logger = .{ .func = slog.func },
        .enable_dragndrop = true,
    });
}
