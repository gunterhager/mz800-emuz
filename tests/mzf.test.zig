const std = @import("std");
const expect = std.testing.expect;
const tmpDir = std.testing.tmpDir;

const system = @import("system");
const mzf = system.mzf;
const MZF = mzf.Type();

test "load obj file" {
    const input_file_name: []const u8 = "TestCharacters.mzf";
    const input_file = @embedFile("./asm/TestCharacters.mzf");
    var tmp = tmpDir(.{});
    defer tmp.cleanup();
    try tmp.dir.writeFile(.{ .sub_path = input_file_name, .data = input_file });

    var obj_file: MZF = undefined;
    obj_file.load(tmp.dir, input_file_name) catch |err| {
        std.debug.print("Error loading file '{s}': {}\n", .{ input_file_name, err });
    };
    try expect(obj_file.header.start_address == 0x2000);
    try expect(obj_file.header.start_address == 0x2000);
}
