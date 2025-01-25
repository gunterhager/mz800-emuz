const std = @import("std");
// const fs = std.fs;
// const GeneralPurposeAllocator = std.heap.GeneralPurposeAllocator;
const sokol = @import("sokol");
const sapp = sokol.app;
const slog = sokol.log;
const chipz = @import("chipz");
const chips = chipz.chips;
const host = chipz.host;

const mz800 = @import("system").mz800;
const MZ800 = mz800.Type();
const frequencies = mz800.frequencies;

const name = "MZ-800";

var sys: MZ800 = undefined;

export fn init() void {
    host.audio.init(.{});
    host.time.init();
    host.prof.init();
    sys.initInPlace();
    host.gfx.init(.{ .display = sys.displayInfo() });
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
    _ = ev;
    // TODO: Implement input events
}

pub fn main() void {
    const display = MZ800.displayInfo(null);
    const border = host.gfx.DEFAULT_BORDER;
    const width = 2 * display.view.width + border.left + border.right;
    const height = 2 * display.view.height + border.top + border.bottom;
    sapp.run(.{
        .init_cb = init,
        .frame_cb = frame,
        .cleanup_cb = cleanup,
        .window_title = name,
        .width = width,
        .height = height,
        .icon = .{ .sokol_default = true },
        .logger = .{ .func = slog.func },
    });
}
