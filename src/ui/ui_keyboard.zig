const std = @import("std");
const ig = @import("cimgui");

pub const TypeConfig = struct {
    sys: type,
};

pub fn Type(comptime cfg: TypeConfig) type {
    return struct {
        const Self = @This();
        const Sys = cfg.sys;

        pub const key_w: f32 = 38.0;
        pub const key_h: f32 = 28.0;
        pub const spacing: f32 = 4.0;

        pub const Options = struct {
            sys: *Sys,
            origin: ig.ImVec2,
            size: ig.ImVec2 = .{},
            open: bool = false,
        };

        sys: *Sys,
        origin: ig.ImVec2,
        size: ig.ImVec2,
        open: bool,
        last_open: bool,

        pub fn initInPlace(self: *Self, opts: Options) void {
            const default_size_x: f32 = 18.5 * key_w + 21 * spacing;
            const default_size_y: f32 = 6 * key_h + 7 * spacing + 28;
            self.* = .{
                .sys = opts.sys,
                .origin = opts.origin,
                .size = .{
                    .x = if (opts.size.x == 0) default_size_x else opts.size.x,
                    .y = if (opts.size.y == 0) default_size_y else opts.size.y,
                },
                .open = opts.open,
                .last_open = opts.open,
            };
        }

        const KeyEntry = struct {
            label: [:0]const u8,
            keycode: u32,
            /// Width as multiple of a standard key width (1.0 = normal key)
            width: f32 = 1.0,
            /// If true, render as an invisible spacer instead of a button
            spacer: bool = false,
        };

        const ROW_FUNCTION = [_]KeyEntry{
            .{ .label = "F1", .keycode = 290, .width = 1.5 },
            .{ .label = "F2", .keycode = 291, .width = 1.5 },
            .{ .label = "F3", .keycode = 292, .width = 1.5 },
            .{ .label = "F4", .keycode = 293, .width = 1.5 },
            .{ .label = "F5", .keycode = 294, .width = 1.5 },
            .{ .label = "", .keycode = 0, .width = 9, .spacer = true },
            .{ .label = "INST", .keycode = 260 },
            .{ .label = "DEL", .keycode = 261 },
        };

        const ROW_NUMBERS = [_]KeyEntry{
            .{ .label = "GRAPH", .keycode = 280 },
            .{ .label = "1", .keycode = 49 },
            .{ .label = "2", .keycode = 50 },
            .{ .label = "3", .keycode = 51 },
            .{ .label = "4", .keycode = 52 },
            .{ .label = "5", .keycode = 53 },
            .{ .label = "6", .keycode = 54 },
            .{ .label = "7", .keycode = 55 },
            .{ .label = "8", .keycode = 56 },
            .{ .label = "9", .keycode = 57 },
            .{ .label = "0", .keycode = 48 },
            .{ .label = "-", .keycode = 45 },
            .{ .label = "~", .keycode = 61 },
            .{ .label = "\\", .keycode = 296 },
            .{ .label = "BREAK", .keycode = 256, .width = 1.5 },
        };

        const ROW_QWERTY1 = [_]KeyEntry{
            .{ .label = "TAB", .keycode = 258, .width = 1.5 },
            .{ .label = "Q", .keycode = 81 },
            .{ .label = "W", .keycode = 87 },
            .{ .label = "E", .keycode = 69 },
            .{ .label = "R", .keycode = 82 },
            .{ .label = "T", .keycode = 84 },
            .{ .label = "Y", .keycode = 89 },
            .{ .label = "U", .keycode = 85 },
            .{ .label = "I", .keycode = 73 },
            .{ .label = "O", .keycode = 79 },
            .{ .label = "P", .keycode = 80 },
            .{ .label = "@", .keycode = 295 },
            .{ .label = "[", .keycode = 91 },
            .{ .label = "£", .keycode = 298 },
            .{ .label = "_", .keycode = 96 },
            .{ .label = "", .keycode = 0, .width = 1, .spacer = true },
            .{ .label = "UP", .keycode = 265 },
        };

        const ROW_QWERTY2 = [_]KeyEntry{
            .{ .label = "CTRL", .keycode = 341, .width = 1.75 },
            .{ .label = "A", .keycode = 65 },
            .{ .label = "S", .keycode = 83 },
            .{ .label = "D", .keycode = 68 },
            .{ .label = "F", .keycode = 70 },
            .{ .label = "G", .keycode = 71 },
            .{ .label = "H", .keycode = 72 },
            .{ .label = "J", .keycode = 74 },
            .{ .label = "K", .keycode = 75 },
            .{ .label = "L", .keycode = 76 },
            .{ .label = ";", .keycode = 59 },
            .{ .label = ":", .keycode = 39 },
            .{ .label = "]", .keycode = 93 },
            .{ .label = "CR", .keycode = 257, .width = 1.75 },
            .{ .label = "", .keycode = 0, .width = 0.5, .spacer = true },
            .{ .label = "LEFT", .keycode = 263 },
            .{ .label = "RIGHT", .keycode = 262 },
        };

        const ROW_QWERTY3 = [_]KeyEntry{
            .{ .label = "SHIFT", .keycode = 340, .width = 1.25 },
            .{ .label = "ALPHA", .keycode = 92 },
            .{ .label = "Z", .keycode = 90 },
            .{ .label = "X", .keycode = 88 },
            .{ .label = "C", .keycode = 67 },
            .{ .label = "V", .keycode = 86 },
            .{ .label = "B", .keycode = 66 },
            .{ .label = "N", .keycode = 78 },
            .{ .label = "M", .keycode = 77 },
            .{ .label = ",", .keycode = 44 },
            .{ .label = ".", .keycode = 46 },
            .{ .label = "/", .keycode = 47 },
            .{ .label = "?", .keycode = 297 },
            .{ .label = "SHIFT", .keycode = 344, .width = 2.25 },
            .{ .label = "", .keycode = 0, .width = 1, .spacer = true },
            .{ .label = "DOWN", .keycode = 264 },
        };

        const ROW_BOTTOM = [_]KeyEntry{
            .{ .label = "", .keycode = 0, .width = 3.25, .spacer = true },
            .{ .label = "SPACE", .keycode = 32, .width = 9 },
        };

        fn drawRow(self: *Self, row: []const KeyEntry) void {
            for (row, 0..) |entry, i| {
                if (i > 0) {
                    ig.igSameLine();
                    ig.igSetCursorPosX(ig.igGetCursorPosX() + spacing - ig.igGetStyle().*.ItemSpacing.x);
                }
                const btn_w = key_w * entry.width + spacing * (entry.width - 1.0);
                if (entry.spacer) {
                    ig.igDummy(.{ .x = btn_w, .y = key_h });
                } else {
                    ig.igPushIDInt(@intCast(entry.keycode));
                    _ = ig.igButtonEx(entry.label.ptr, .{ .x = btn_w, .y = key_h });
                    if (ig.igIsItemActive()) {
                        self.sys.keyDown(entry.keycode);
                    }
                    if (ig.igIsItemDeactivated()) {
                        self.sys.keyUp(entry.keycode);
                    }
                    ig.igPopID();
                }
            }
        }

        pub fn draw(self: *Self) void {
            if (self.open != self.last_open) {
                self.last_open = self.open;
            }
            if (!self.open) return;
            ig.igSetNextWindowPos(self.origin, ig.ImGuiCond_FirstUseEver);
            ig.igSetNextWindowSize(self.size, ig.ImGuiCond_FirstUseEver);
            if (ig.igBegin("MZ-800 Keyboard", &self.open, ig.ImGuiWindowFlags_None)) {
                self.drawRow(&ROW_FUNCTION);
                self.drawRow(&ROW_NUMBERS);
                self.drawRow(&ROW_QWERTY1);
                self.drawRow(&ROW_QWERTY2);
                self.drawRow(&ROW_QWERTY3);
                self.drawRow(&ROW_BOTTOM);
            }
            ig.igEnd();
        }
    };
}
