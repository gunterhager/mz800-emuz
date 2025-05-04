const std = @import("std");
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;

const system = @import("system");
const MZASCII = system.mzascii.MZASCII;

test "ASCII CR" {
    const carriage_return: u8 = 0x0d;
    try expectEqual(carriage_return, MZASCII.mzToASCII(carriage_return));
}

test "ASCII regular" {
    const regular_characters = [_]u8{
        ' ',
        '!',
        '\"',
        '#',
        '$',
        '%',
        '&',
        '\'',
        '(',
        ')',
        '*',
        '+',
        ',',
        '-',
        '.',
        '/',
        '0',
        '1',
        '2',
        '3',
        '4',
        '5',
        '6',
        '7',
        '8',
        '9',
        ':',
        ';',
        '<',
        '=',
        '>',
        '?',
        '@',
        'A',
        'B',
        'C',
        'D',
        'E',
        'F',
        'G',
        'H',
        'I',
        'J',
        'K',
        'L',
        'M',
        'N',
        'O',
        'P',
        'Q',
        'R',
        'S',
        'T',
        'U',
        'V',
        'W',
        'X',
        'Y',
        'Z',
        '[',
        '\\',
        ']',
    };

    for (regular_characters) |char| {
        try expectEqual(char, MZASCII.mzToASCII(char));
    }
}

test "ASCII lowercase" {
    const lowercase_characters = [_][2]u8{
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

    for (lowercase_characters) |item| {
        try expectEqual(item[1], MZASCII.mzToASCII(item[0]));
    }
}

test "ASCII umlauts" {
    const umlaut_characters = [_][2]u8{
        [_]u8{ 0xbb, 'ä' },
        [_]u8{ 0xb9, 'Ä' },
        [_]u8{ 0xba, 'ö' },
        [_]u8{ 0xa8, 'Ö' },
        [_]u8{ 0xad, 'ü' },
        [_]u8{ 0xb2, 'Ü' },
        [_]u8{ 0xae, 'ß' },
    };

    for (umlaut_characters) |item| {
        try expectEqual(item[1], MZASCII.mzToASCII(item[0]));
    }
}

test "ASCII others" {
    const other_characters = [_][2]u8{
        [_]u8{ 0x7b, '°' },
        [_]u8{ 0x80, '}' },
        [_]u8{ 0x8b, '^' },
        [_]u8{ 0x90, '_' },
        [_]u8{ 0x93, '`' },
        [_]u8{ 0x94, '~' },
        [_]u8{ 0xbe, '{' },
        [_]u8{ 0xc0, '|' },
        [_]u8{ 0xfb, '£' },
    };

    for (other_characters) |item| {
        try expectEqual(item[1], MZASCII.mzToASCII(item[0]));
    }
}
