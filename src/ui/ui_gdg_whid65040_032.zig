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
            if (gdg.is_mz700) {
                ig.igText("Mode: MZ700");
                return;
            } else {
                const write_mode: u3 = @truncate((gdg.wf & GDG_WHID65040_032.WF_MODE.WMD_MASK) >> 5);
                var mode_string: [*c]const u8 = undefined;
                switch (write_mode) {
                    GDG_WHID65040_032.WF_MODE.WMD.SINGLE => {
                        mode_string = "SINGLE";
                    },
                    GDG_WHID65040_032.WF_MODE.WMD.XOR => {
                        mode_string = "XOR";
                    },
                    GDG_WHID65040_032.WF_MODE.WMD.OR => {
                        mode_string = "OR";
                    },
                    GDG_WHID65040_032.WF_MODE.WMD.RESET => {
                        mode_string = "REST";
                    },
                    GDG_WHID65040_032.WF_MODE.WMD.REPLACE0 => {
                        mode_string = "REPLACE0";
                    },
                    GDG_WHID65040_032.WF_MODE.WMD.REPLACE1 => {
                        mode_string = "REPLACE1";
                    },
                    GDG_WHID65040_032.WF_MODE.WMD.PSET0 => {
                        mode_string = "PSET0";
                    },
                    GDG_WHID65040_032.WF_MODE.WMD.PSET1 => {
                        mode_string = "PSET1";
                    },
                }
                ig.igText("Mode: %s", mode_string);
                // ig.igText(mode_string);
                const is_frameB = (gdg.wf & GDG_WHID65040_032.WF_MODE.FRAME_B) != 0;
                const frame: [*c]const u8 = if (is_frameB) "B" else "A";
                ig.igText("Frame: %s", frame);
                const is_planeI = (gdg.wf & GDG_WHID65040_032.WF_MODE.PLANE_I) != 0;
                const is_planeII = (gdg.wf & GDG_WHID65040_032.WF_MODE.PLANE_II) != 0;
                const is_planeIII = (gdg.wf & GDG_WHID65040_032.WF_MODE.PLANE_III) != 0;
                const is_planeIV = (gdg.wf & GDG_WHID65040_032.WF_MODE.PLANE_IV) != 0;
                const p1: [*c]const u8 = if (is_planeI) "I" else "-";
                const p2: [*c]const u8 = if (is_planeII) "II" else "-";
                const p3: [*c]const u8 = if (is_planeIII) "III" else "-";
                const p4: [*c]const u8 = if (is_planeIV) "IV" else "-";
                ig.igText("Planes: %s %s %s %s", p1, p2, p3, p4);
            }
        }
        fn drawReadFormatRegister(self: *Self) void {
            const gdg = self.gdg;
            ig.igText("Read Format Register");
            if (gdg.is_mz700) {
                ig.igText("Mode: MZ700");
                return;
            } else {
                const is_searching = (gdg.rf & GDG_WHID65040_032.RF_MODE.SEARCH) != 0;
                const mode_string: [*c]const u8 = if (is_searching) "SEARCH" else "SINGLE";
                ig.igText("Mode: %s", mode_string);
                const is_frameB = (gdg.rf & GDG_WHID65040_032.RF_MODE.FRAME_B) != 0;
                const frame: [*c]const u8 = if (is_frameB) "B" else "A";
                ig.igText("Frame: %s", frame);
                const is_planeI = (gdg.rf & GDG_WHID65040_032.RF_MODE.PLANE_I) != 0;
                const is_planeII = (gdg.rf & GDG_WHID65040_032.RF_MODE.PLANE_II) != 0;
                const is_planeIII = (gdg.rf & GDG_WHID65040_032.RF_MODE.PLANE_III) != 0;
                const is_planeIV = (gdg.rf & GDG_WHID65040_032.RF_MODE.PLANE_IV) != 0;
                const p1: [*c]const u8 = if (is_planeI) "I" else "-";
                const p2: [*c]const u8 = if (is_planeII) "II" else "-";
                const p3: [*c]const u8 = if (is_planeIII) "III" else "-";
                const p4: [*c]const u8 = if (is_planeIV) "IV" else "-";
                ig.igText("Planes: %s %s %s %s", p1, p2, p3, p4);
            }
        }

        fn drawDisplayModeRegister(self: *Self) void {
            const gdg = self.gdg;
            if (gdg.is_mz700) {
                ig.igText("Display Mode: MZ700");
                return;
            } else {
                const hires: [*c]const u8 = if (gdg.isHires()) "HIRES" else "LORES";
                const hicolor: [*c]const u8 = if (gdg.isHicolor()) "HICOLOR" else "LOCOLOR";
                const is_frameB = (gdg.dmd & GDG_WHID65040_032.DMD_MODE.FRAME_B) != 0;
                const frame: [*c]const u8 = if (is_frameB) "B" else "A";
                ig.igText("Display Mode: %s, %s, Frame: %s", hires, hicolor, frame);
            }
        }

        fn drawStatusRegister(self: *Self) void {
            const gdg = self.gdg;
            ig.igText("Status: %02X", gdg.status);
        }

        fn drawScrollRegisters(self: *Self) void {
            const gdg = self.gdg;
            ig.igText("Scroll Offset:        %04X", gdg.sof);
            ig.igText("Scroll Width:         %04X", gdg.sw);
            ig.igText("Scroll Start Address: %04X", gdg.ssa);
            ig.igText("Scroll End Address:   %04X", gdg.sea);
        }

        fn drawBorderColorRegister(self: *Self) void {
            const gdg = self.gdg;
            var color: [*c]const u8 = undefined;
            switch (gdg.bcol) {
                0b0000 => color = "Black",
                0b0001 => color = "Blue",
                0b0010 => color = "Red",
                0b0011 => color = "Purple",
                0b0100 => color = "Green",
                0b0101 => color = "Cyan",
                0b0110 => color = "Yellow",
                0b0111 => color = "White",
                0b1000 => color = "Gray",
                0b1001 => color = "Light Blue",
                0b1010 => color = "Light Red",
                0b1011 => color = "Light Purple",
                0b1100 => color = "Light Green",
                0b1101 => color = "Light Cyan",
                0b1110 => color = "Light Yellow",
                0b1111 => color = "Light White",
                else => color = "Illegal",
            }
            ig.igText("Border Color %s", color);
        }

        fn drawState(self: *Self) void {
            self.drawWriteFormatRegister();
            ig.igSeparator();
            self.drawReadFormatRegister();
            ig.igSeparator();
            self.drawDisplayModeRegister();
            ig.igSeparator();
            self.drawStatusRegister();
            ig.igSeparator();
            self.drawScrollRegisters();
            ig.igSeparator();
            self.drawBorderColorRegister();
        }

        pub fn draw(self: *Self) void {
            if (self.open != self.last_open) {
                self.last_open = self.open;
            }
            if (!self.open) return;
            ig.igSetNextWindowPos(self.origin, ig.ImGuiCond_FirstUseEver);
            ig.igSetNextWindowSize(self.size, ig.ImGuiCond_FirstUseEver);
            if (ig.igBegin(self.title.ptr, &self.open, ig.ImGuiWindowFlags_None)) {
                self.drawState();
            }
            ig.igEnd();
        }
    };
}
