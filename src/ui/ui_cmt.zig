const std = @import("std");
const ig = @import("cimgui");

pub const TypeConfig = struct {
    sys: type,
};

pub fn Type(comptime cfg: TypeConfig) type {
    return struct {
        const Self = @This();
        const Sys = cfg.sys;

        pub const Options = struct {
            sys: *Sys,
            origin: ig.ImVec2,
            size: ig.ImVec2 = .{ .x = 300, .y = 90 },
            open: bool = false,
        };

        sys: *Sys,
        origin: ig.ImVec2,
        size: ig.ImVec2,
        open: bool,
        last_open: bool,

        pub fn initInPlace(self: *Self, opts: Options) void {
            self.* = .{
                .sys = opts.sys,
                .origin = opts.origin,
                .size = opts.size,
                .open = opts.open,
                .last_open = opts.open,
            };
        }

        pub fn draw(self: *Self) void {
            if (self.open != self.last_open) {
                self.last_open = self.open;
            }
            if (!self.open) return;
            ig.igSetNextWindowPos(self.origin, ig.ImGuiCond_FirstUseEver);
            ig.igSetNextWindowSize(self.size, ig.ImGuiCond_FirstUseEver);
            if (ig.igBegin("CMT", &self.open, ig.ImGuiWindowFlags_None)) {
                const cmt = &self.sys.cmt;
                if (!cmt.loaded) {
                    ig.igTextUnformatted("No tape loaded.");
                } else {
                    const current: usize = @truncate(cmt.position >> 32);
                    const total = cmt.sample_count;
                    const fraction: f32 = if (total > 0)
                        @min(1.0, @as(f32, @floatFromInt(current)) / @as(f32, @floatFromInt(total)))
                    else
                        0.0;

                    // Progress bar filling the full window width
                    var overlay_buf: [8:0]u8 = std.mem.zeroes([8:0]u8);
                    _ = std.fmt.bufPrintZ(&overlay_buf, "{d:.0}%", .{fraction * 100.0}) catch {};
                    ig.igProgressBar(fraction, .{ .x = -1.0, .y = 0.0 }, &overlay_buf);

                    // Auto-close when playback reaches the end of the tape
                    if (current >= total) self.open = false;

                    // Motor status and time remaining
                    const remaining = if (current < total) total - current else 0;
                    const secs: f32 = @as(f32, @floatFromInt(remaining)) /
                        @as(f32, @floatFromInt(cmt.sample_rate));
                    var status_buf: [48:0]u8 = std.mem.zeroes([48:0]u8);
                    _ = std.fmt.bufPrintZ(&status_buf, "Motor: {s}   Time left: {d:.1}s", .{
                        if (cmt.motor) @as([]const u8, "ON") else "OFF",
                        secs,
                    }) catch {};
                    ig.igTextUnformatted(&status_buf);
                }
            }
            ig.igEnd();
        }
    };
}
