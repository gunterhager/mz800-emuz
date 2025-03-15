//! Sharp RGBI PAL video signal
//! All values are taken from: https://github.com/SHARPENTIERS/mz800emu/blob/master/src/gdg/video.h

// Sharp RGBI PAL video signal generator (JP1 connected - basic settings for Europe):
//
//
//
// Radkov's timing:
// =================
//
// Hsync: 80T
// Back Porch: 106 T
// Video Enable: 928T
// Front Porch: 22 T
// ----------------------
// Total rows: 1,136 T
//
//
// Image timing:
// ==================
//
// Vsync: 3408 T ( 3 lines )
// Back porch: 21,586 T (19 rows + 2 T)
// Video enable: 326 032 T ( 287 lines )
// Front porch: 3,406 T ( 3 rows )
// ------------------------------------------------- --
// Total frames: 354 432 T ( 312 rows )
//
//
// Upper border: 136 T + 45 rows
// Screen: 200 line
// Lower border: 41 rows + 792 T
//
//
// Left border: 154 T
// Screen: 640T
// Right border: 134 T
//
//
//
// Signal events:
//
// vvv - visible rows (top border + screen + bottom border)
// sss - screen rows
// aaa - all beam rows
//
// 0, 0 - initial pixel of the image
// vvv, 0 - the beginning of the left border
// vvv, 153 - the last pixel of the left border (154 pixels)
// sss, 154 - the beginning of the screen
// 45,790 - end (1) PIOZ80 PA5 (VBLN) (112 row == 127,232 pixels, inactive: 200 row == 227,200 pixels)
// 245, 790 - start (0) PIOZ80 PA5 (VBLN)
// 290, 790 - start (0) real_Vsync
// 293,790 - end (1) real_Vsync (3 lines == 3408 pixels)
// 0, 792 - beam_enabled_start - from here the first line of the upper border starts to be drawn
// 288, 792 - beam_enabled_end - the last rows of the lower border are displayed here at the end
// sss, 793 - the last pixel of the screen (640 pixels)
// sss, 794 - beginning of the right border
// vvv, 928 - the end of the right border (134 pixels), the last displayed pixel per line
// aaa, 950 - start (0) real_Hsync
// aaa, 1030 - end (1) real_Hsync (80px)
// aaa, 1078 - end (1) sts_Hsync (128px)
// aaa, 1135 - the last pixel of the image row (1136 pixels)
//
//
// Links:
//
// CLK1 - real HSync (we are only interested in the falling edge)
// PIO8255_PC7 - VBLN
// PIOZ80_PA5 - VBLN
//
//
// I'll summarize it a bit for clarity :)
//
//
//
//   +----------------------------- Screen ------------------------------+
//   |                                                                   |
//   |                                                                   |
//   |                                                                   |
//   |  0,0 -> +------------- Display (visible area) ----------+         |
//   |  beam   |Top border                                     |         |
//   |  start  |                                               |         |
//   |  here   |                                               |         |
//   |         | Left  +----------- Canvas ------------+ Right |         |
//   |         | border|                               | border|         |
//   |         |       |                               |       |         |
//   |         |       |                               |       |         |
//   |         |       |                               |       |         |
//   |         |       |                               |       |         |
//   |         |       |                               |       |         |
//   |         |       |                               |       |         |
//   |         |       +---------- 640 x 200 ----------+       |         |
//   |         |Bottom border                                  |         |
//   |         |                                               |         |
//   |         |                                               |         |
//   |         +------------------ 928 x 288 ------------------+         |
//   |                                                                   |
//   |                                                                   |
//   |                                                                   |
//   +--------------------------- 1136 x 312 ----------------------------+

// Beam line (in GDG ticks, CLK0)
// One full beam line consists of:
// HSYNC: 80T
// Back Porch: 106T
// Video Enable: 928T (Border + Canvas)
// Front Porch: 22T

/// Video dimensions
pub const video = struct {
    /// Border area (single color)
    pub const border = struct {
        pub const left: comptime_int = 154;
        pub const right: comptime_int = 134;
        pub const top: comptime_int = 46;
        pub const bottom: comptime_int = 42;
    };

    /// User drawable area dimensions
    /// in pixels: 640 x 200
    pub const canvas = struct {
        pub const width: comptime_int = 640;
        pub const height: comptime_int = 200;
    };

    /// Visible display dimensions
    /// in pixels: 928 x 288
    pub const display = struct {
        pub const width = border.left + canvas.width + border.right;
        pub const height = border.top + canvas.height + border.bottom;
    };

    /// Screen dimensions in GDG ticks (CLK0)
    /// Screen in pixels: 1136 x 312
    pub const screen = struct {
        pub const horizontal = struct {
            pub const hsync: comptime_int = 80;
            pub const back_porch: comptime_int = 106;
            pub const video_enable = display.width;
            pub const front_porch: comptime_int = 22;

            pub const video_enable_start = hsync + back_porch;
            pub const video_enable_end = video_enable_start + video_enable;

            pub const line = hsync + back_porch + video_enable + front_porch;
        };

        pub const vertical = struct {
            pub const vsync = horizontal.line * 3;
            pub const back_porch = horizontal.line * 19 + 2;
            pub const video_enable = horizontal.line * display.height;
            pub const front_porch = horizontal.line * 3;

            pub const video_enable_start = vsync + back_porch;
            pub const video_enable_end = video_enable_start + video_enable;
        };

        pub const width = horizontal.line;
        pub const height: comptime_int = 312; // lines

        pub const frame = vertical.vsync + vertical.back_porch + vertical.video_enable + vertical.front_porch;
    };
};
