//! Support for loading files in MZF/MZT format.
//! Currently only `OBJ`(machine code) files are supported.

const std = @import("std");

pub fn Type() type {
    return struct {
        const Self = @This();

        /// File type attributes
        pub const Attribute = enum(u8) {
            OBJ = 0x01, // Machine code program
            BTX = 0x05, // BASIC program
            TXT = 0x94, // Text file
        };

        /// MZF file header format
        pub const Header = extern struct {
            attribute: Attribute,
            name: [17]u8 align(1), // Name in MZ-ASCII, terminated with 0x0d ('\r')
            file_length: u16, // Length of the binary data without header (little endian)
            loading_address: u16, // Address where the file should be loaded to (little endian)
            start_address: u16, // Address to jump to after loading (little endian)
            comment: [104]u8 align(1), // Comment in MZ-ASCII, mostly unused
        };

        header: Header,
        data: [0x100000]u8, // 64K buffer

        pub fn load(self: *Self, dir: std.fs.Dir, path: []const u8) !void {
            var file = try dir.openFile(path, .{});
            defer file.close();
            const file_reader = file.reader();
            self.header = try file_reader.readStructEndian(Header, .little);
            const len = try file_reader.read(&self.data);

            if (self.header.attribute != .OBJ) {
                // Currently only OBJ files can be read
                return error.WrongFileType;
            }
            if (len != self.header.file_length) {
                std.debug.print("🚨 File length mismatch: header file length: {}, found file length: {}\n", .{ self.header.file_length, len });
                return error.WrongFileLength;
            }
        }
    };
}
