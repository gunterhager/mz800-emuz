const std = @import("std");
const chipz = @import("chipz");
const chips = @import("chips");
const intel8253 = chips.intel8253;
const ui_chip = chipz.ui.ui_chip;
const ig = @import("cimgui");

pub const TypeConfig = struct {
    bus: type,
    ctc: type,
};

pub fn Type(comptime cfg: TypeConfig) type {
    return struct {
        const Self = @This();
        const Bus = cfg.bus;
        const INTEL8253 = cfg.ctc;
        const UI_Chip = ui_chip.Type(.{ .bus = cfg.bus });

        pub const Options = struct {
            title: []const u8,
            ctc: *INTEL8253,
            origin: ig.ImVec2,
            size: ig.ImVec2 = .{},
            open: bool = false,
            chip: UI_Chip,
        };

        title: []const u8,
        ctc: *INTEL8253,
        origin: ig.ImVec2,
        size: ig.ImVec2,
        open: bool,
        last_open: bool,
        valid: bool,
        chip: UI_Chip,

        pub fn initInPlace(self: *Self, opts: Options) void {
            self.* = .{
                .title = opts.title,
                .ctc = opts.ctc,
                .origin = opts.origin,
                .size = .{ .x = if (opts.size.x == 0) 440 else opts.size.x, .y = if (opts.size.y == 0) 370 else opts.size.y },
                .open = opts.open,
                .last_open = opts.open,
                .valid = true,
                .chip = opts.chip.init(),
            };
        }

        pub fn discard(self: *Self) void {
            self.valid = false;
        }

        fn drawState(self: *Self) void {
            const ctc = self.ctc;
            if (ig.igBeginTable("##ctc_counter", 4, ig.ImGuiTableFlags_None)) {
                ig.igTableSetupColumnEx("", ig.ImGuiTableColumnFlags_WidthFixed, 56, 0);
                ig.igTableSetupColumnEx("0", ig.ImGuiTableColumnFlags_WidthFixed, 32, 0);
                ig.igTableSetupColumnEx("1", ig.ImGuiTableColumnFlags_WidthFixed, 32, 0);
                ig.igTableSetupColumnEx("2", ig.ImGuiTableColumnFlags_WidthFixed, 32, 0);
                ig.igTableHeadersRow();
                _ = ig.igTableNextColumn();
                ig.igText("Mode");
                _ = ig.igTableNextColumn();
                for (0..3) |index| {
                    ig.igText("%d", @intFromEnum(ctc.counter[index].mode));
                    _ = ig.igTableNextColumn();
                }
                ig.igText("BCD");
                _ = ig.igTableNextColumn();
                for (0..3) |index| {
                    if (ctc.counter[index].bcd) {
                        ig.igText("ON");
                    } else {
                        ig.igText("OFF");
                    }
                    _ = ig.igTableNextColumn();
                }
                ig.igText("Value");
                _ = ig.igTableNextColumn();
                for (0..3) |index| {
                    ig.igText("%05X", @as(u32, @intCast(ctc.counter[index].value)));
                    _ = ig.igTableNextColumn();
                }
                ig.igText("Latch");
                _ = ig.igTableNextColumn();
                for (0..3) |index| {
                    ig.igText("%05X", ctc.counter[index].read_latch);
                    _ = ig.igTableNextColumn();
                }

                ig.igEndTable();
            }
            ig.igSeparator();
            ig.igText("Control %02X", ctc.control);
        }

        pub fn draw(self: *Self, in_bus: Bus) void {
            if (self.open != self.last_open) {
                self.last_open = self.open;
            }
            if (!self.open) return;
            ig.igSetNextWindowPos(self.origin, ig.ImGuiCond_FirstUseEver);
            ig.igSetNextWindowSize(self.size, ig.ImGuiCond_FirstUseEver);
            if (ig.igBegin(self.title.ptr, &self.open, ig.ImGuiWindowFlags_None)) {
                if (ig.igBeginChild("##ctc_chip", .{ .x = 176, .y = 0 }, ig.ImGuiChildFlags_None, ig.ImGuiWindowFlags_None)) {
                    self.chip.draw(in_bus);
                }
                ig.igEndChild();
                ig.igSameLine();
                if (ig.igBeginChild("##ctc_vals", .{}, ig.ImGuiChildFlags_None, ig.ImGuiWindowFlags_None)) {
                    self.drawState();
                }
                ig.igEndChild();
            }
            ig.igEnd();
        }
    };
}
