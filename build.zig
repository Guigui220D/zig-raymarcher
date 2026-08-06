const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const zlm_dep = b.dependency("zlm", .{});
    const zigimg_dep = b.dependency("zigimg", .{});
    const csscolorparser_dep = b.dependency("csscolorparser", .{});
    const clap_dep = b.dependency("clap", .{});

    const exe = b.addExecutable(.{
        .name = "zig_raymarcher",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,

            .imports = &.{
                .{ .name = "zlm", .module = zlm_dep.module("zlm") },
                .{ .name = "zigimg", .module = zigimg_dep.module("zigimg") },
                .{ .name = "csscolorparser", .module = csscolorparser_dep.module("csscolorparser") },
                .{ .name = "clap", .module = clap_dep.module("clap") },
            },
        }),
        .use_llvm = true,
    });

    b.installArtifact(exe);

    const run_step = b.step("run", "Run the app");
    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const exe_tests = b.addTest(.{
        .root_module = exe.root_module,
    });
    const run_exe_tests = b.addRunArtifact(exe_tests);

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_exe_tests.step);
}
