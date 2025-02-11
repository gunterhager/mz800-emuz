const std = @import("std");
const Build = std.Build;
const ResolvedTarget = Build.ResolvedTarget;
const OptimizeMode = std.builtin.OptimizeMode;
const Module = Build.Module;

pub const Options = struct {
    src_dir: []const u8,
    target: ResolvedTarget,
    optimize: OptimizeMode,
    mod_chips: *Module,
    mod_system: *Module,
};

pub fn build(b: *Build, opts: Options) void {
    const unit_tests = [_][]const u8{
        "gdg_whid65040_032",
        "mzf",
        "mz800",
    };
    const test_step = b.step("test", "Run unit tests");
    inline for (unit_tests) |name| {
        const unit_test = b.addTest(.{
            .name = name ++ ".test",
            .root_module = b.createModule(.{
                .root_source_file = b.path(b.fmt("{s}/{s}.test.zig", .{ opts.src_dir, name })),
                .target = opts.target,
                .imports = &.{
                    .{ .name = "chips", .module = opts.mod_chips },
                    .{ .name = "system", .module = opts.mod_system },
                },
            }),
        });
        b.installArtifact(unit_test); // install an exe for debugging
        const run_unit_test = b.addRunArtifact(unit_test);
        test_step.dependOn(&run_unit_test.step);
    }
}
