//! Helper functions for using strings encoded with MZASCII

pub const MZASCII = struct {
    const nonstandard_characters = [_][2]u8{
        [_]u8{ 0x7b, '°' },
        [_]u8{ 0x80, '}' },
        [_]u8{ 0x8b, '^' },
        [_]u8{ 0x90, '_' },
        [_]u8{ 0x93, '`' },
        [_]u8{ 0x94, '~' },
        [_]u8{ 0xbe, '{' },
        [_]u8{ 0xc0, '|' },
        [_]u8{ 0xfb, '£' },

        [_]u8{ 0xbb, 'ä' },
        [_]u8{ 0xb9, 'Ä' },
        [_]u8{ 0xba, 'ö' },
        [_]u8{ 0xa8, 'Ö' },
        [_]u8{ 0xad, 'ü' },
        [_]u8{ 0xb2, 'Ü' },
        [_]u8{ 0xae, 'ß' },

        [_]u8{ 0xa1, 'a' },
        [_]u8{ 0x9a, 'b' },
        [_]u8{ 0x9f, 'c' },
        [_]u8{ 0x9c, 'd' },
        [_]u8{ 0x92, 'e' },
        [_]u8{ 0xaa, 'f' },
        [_]u8{ 0x97, 'g' },
        [_]u8{ 0x98, 'h' },
        [_]u8{ 0xa6, 'i' },
        [_]u8{ 0xaf, 'j' },
        [_]u8{ 0xa9, 'k' },
        [_]u8{ 0xb8, 'l' },
        [_]u8{ 0xb3, 'm' },
        [_]u8{ 0xb0, 'n' },
        [_]u8{ 0xb7, 'o' },
        [_]u8{ 0x9e, 'p' },
        [_]u8{ 0xa0, 'q' },
        [_]u8{ 0x9d, 'r' },
        [_]u8{ 0xa4, 's' },
        [_]u8{ 0x96, 't' },
        [_]u8{ 0xa5, 'u' },
        [_]u8{ 0xab, 'v' },
        [_]u8{ 0xa3, 'w' },
        [_]u8{ 0x9b, 'x' },
        [_]u8{ 0xbd, 'y' },
        [_]u8{ 0xa2, 'z' },
    };

    pub fn mzToASCII(char: u8) u8 {
        switch (char) {
            0x0d, 0x20...0x5d => {
                return char;
            },
            else => {
                // Characters not present in standard ASCII
                for (nonstandard_characters) |item| {
                    if (char == item[0]) {
                        return item[1];
                    }
                }
                return '?';
            },
        }
    }
};
