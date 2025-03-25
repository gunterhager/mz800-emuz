const std = @import("std");
const chipz = @import("chipz");
const chips = @import("chips");
const gdg_whid65040_032 = chips.gdg_whid65040_032;
const ui_chip = chipz.ui.ui_chip;
const ig = @import("cimgui");

pub const TypeConfig = struct {
    bus: type,
    gdg: type,
};

pub fn Type(comptime cfg: TypeConfig) type {
    return struct {
        const Self = @This();
        const Bus = cfg.bus;
        const GDG_WHID65040_032 = cfg.gdg;
        const UI_Chip = ui_chip.Type(.{ .bus = cfg.bus });

        pub const Options = struct {
            title: []const u8,
            gdg: *GDG_WHID65040_032,
            origin: ig.ImVec2,
            size: ig.ImVec2 = .{},
            open: bool = false,
            chip: UI_Chip,
        };

        title: []const u8,
        gdg: *GDG_WHID65040_032,
        origin: ig.ImVec2,
        size: ig.ImVec2,
        open: bool,
        last_open: bool,
        valid: bool,
        chip: UI_Chip,

        pub fn initInPlace(self: *Self, opts: Options) void {
            self.* = .{
                .title = opts.title,
                .gdg = opts.gdg,
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

        fn drawWriteFormatRegister(self: *Self) void {
            const gdg = self.gdg;
            ig.igText("Write Format Register");
            ig.igText("Mode:");
            if (gdg.is_mz700) {
                ig.igText("MZ700");
                return;
            }
            const write_mode: u3 = @truncate((self.wf & GDG_WHID65040_032.WF_MODE.WMD_MASK) >> 5);
            const is_frameB = (self.wf & GDG_WHID65040_032.WF_MODE.FRAME_B) != 0;
            const is_planeI = (self.wf & GDG_WHID65040_032.WF_MODE.PLANE_I) != 0;
            const is_planeII = (self.wf & GDG_WHID65040_032.WF_MODE.PLANE_II) != 0;
            const is_planeIII = (self.wf & GDG_WHID65040_032.WF_MODE.PLANE_III) != 0;
            const is_planeIV = (self.wf & GDG_WHID65040_032.WF_MODE.PLANE_IV) != 0;
        }
        fn drawReadFormatRegister(self: *Self) void {
            const gdg = self.gdg;
            const is_searching = (gdg.rf & GDG_WHID65040_032.RF_MODE.SEARCH) != 0;
            const is_frameB = (gdg.rf & GDG_WHID65040_032.RF_MODE.FRAME_B) != 0;
            const is_planeI = (gdg.rf & GDG_WHID65040_032.RF_MODE.PLANE_I) != 0;
            const is_planeII = (gdg.rf & GDG_WHID65040_032.RF_MODE.PLANE_II) != 0;
            const is_planeIII = (gdg.rf & GDG_WHID65040_032.RF_MODE.PLANE_III) != 0;
            const is_planeIV = (gdg.rf & GDG_WHID65040_032.RF_MODE.PLANE_IV) != 0;
        }

        fn drawState(self: *Self) void {
            const gdg = self.gdg;
            self.drawReadFormatRegister();
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
