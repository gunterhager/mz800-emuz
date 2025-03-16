const std = @import("std");
const tests = @import("tests/build.zig");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const dep_chipz = b.dependency("chipz", .{
        .target = target,
        .optimize = optimize,
    });

    const dep_sokol = b.dependency("sokol", .{
        .target = target,
        .optimize = optimize,
        .with_sokol_imgui = true,
    });

    const dep_cimgui = b.dependency("cimgui", .{
        .target = target,
        .optimize = optimize,
    });

    // inject the cimgui header search path into the sokol C library compile step
    dep_sokol.artifact("sokol_clib").addIncludePath(dep_cimgui.path("src"));

    const mod_chips = b.addModule("chips", .{
        .root_source_file = b.path("src/chips/chips.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "chipz", .module = dep_chipz.module("chipz") },
        },
    });

    const mod_system = b.addModule("system", .{
        .root_source_file = b.path("src/system/system.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "chipz", .module = dep_chipz.module("chipz") },
            .{ .name = "chips", .module = mod_chips },
        },
    });

    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "chipz", .module = dep_chipz.module("chipz") },
            .{ .name = "sokol", .module = dep_sokol.module("sokol") },
            .{ .name = "cimgui", .module = dep_cimgui.module("cimgui") },
            .{ .name = "chips", .module = mod_chips },
            .{ .name = "system", .module = mod_system },
        },
    });

    const exe = b.addExecutable(.{
        .name = "mz800-emuz",
        .root_module = exe_mod,
    });

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    tests.build(b, .{
        .src_dir = "tests",
        .target = target,
        .optimize = optimize,
        .mod_chips = mod_chips,
        .mod_system = mod_system,
    });
}
