const std = @import("std");
const chipz = @import("chipz");
const ig = @import("cimgui");

pub const TypeConfig = struct {
    bus: type,
    cpu: type,
};

pub fn Type(comptime cfg: TypeConfig) type {
    const UI_DBG = chipz.ui.ui_dbg.Type(.{ .bus = cfg.bus, .cpu = cfg.cpu });

    return struct {
        const Self = @This();

        pub const Options = struct {
            dbg: *UI_DBG,
            origin: ig.ImVec2,
            size: ig.ImVec2 = .{ .x = 300, .y = 220 },
            open: bool = false,
        };

        dbg: *UI_DBG,
        origin: ig.ImVec2,
        size: ig.ImVec2,
        open: bool,
        last_open: bool,
        add_addr: u16,

        pub fn initInPlace(self: *Self, opts: Options) void {
            self.* = .{
                .dbg = opts.dbg,
                .origin = opts.origin,
                .size = opts.size,
                .open = opts.open,
                .last_open = opts.open,
                .add_addr = 0,
            };
        }

        pub fn draw(self: *Self) void {
            if (self.open != self.last_open) self.last_open = self.open;
            if (!self.open) return;

            ig.igSetNextWindowPos(self.origin, ig.ImGuiCond_FirstUseEver);
            ig.igSetNextWindowSize(self.size, ig.ImGuiCond_FirstUseEver);
            if (ig.igBegin("Breakpoints", &self.open, ig.ImGuiWindowFlags_None)) {
                const dbg = self.dbg;

                // Breakpoint list
                var to_remove: i32 = -1;
                for (dbg.breakpoints[0..dbg.num_breakpoints], 0..) |*bp, i| {
                    ig.igPushIDInt(@intCast(i));

                    // Enabled checkbox
                    _ = ig.igCheckbox("##en", &bp.enabled);
                    ig.igSameLine();

                    // Address label
                    var addr_buf: [8]u8 = undefined;
                    const addr_s = std.fmt.bufPrint(&addr_buf, "{X:0>4}\x00", .{bp.addr}) catch unreachable;
                    _ = addr_s;
                    ig.igTextUnformatted(&addr_buf);
                    ig.igSameLine();

                    // Delete button
                    if (ig.igButton("X")) to_remove = @intCast(i);

                    ig.igPopID();
                }
                if (to_remove >= 0) {
                    dbg.removeBreakpoint(dbg.breakpoints[@intCast(to_remove)].addr);
                }

                ig.igSeparator();

                // Add breakpoint row
                ig.igSetNextItemWidth(60);
                _ = ig.igInputScalarEx(
                    "##add_addr",
                    ig.ImGuiDataType_U16,
                    &self.add_addr,
                    null,
                    null,
                    "%04X",
                    ig.ImGuiInputTextFlags_CharsHexadecimal,
                );
                ig.igSameLine();
                if (ig.igButton("Add")) {
                    dbg.addBreakpoint(self.add_addr);
                }
                ig.igSameLine();
                if (ig.igButton("Clear All")) {
                    dbg.num_breakpoints = 0;
                }
            }
            ig.igEnd();
        }
    };
}
