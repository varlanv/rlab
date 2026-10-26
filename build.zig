const std = @import("std");
const Translator = @import("translate_c").Translator;

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const strip = b.option(
        bool,
        "strip",
        "Remove debug information",
    ) orelse false;

    const exe = b.addExecutable(.{
        .name = "rlab",
        .root_module = b.createModule(.{
            .strip = strip,
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    b.installArtifact(exe);

    const run_step = b.step("run", "Run the app");
    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);
    run_cmd.step.dependOn(b.getInstallStep());
    run_cmd.addPassthruArgs();
    if (target.result.os.tag == .windows) {
        exe.root_module.linkSystemLibrary("vulkan-1", .{});
    } else {
        exe.root_module.link_libc = true;
        exe.root_module.addObjectFile(.{
            .cwd_relative = "/usr/lib64/libvulkan.so.1",
        });
    }
    const exe_tests = b.addTest(.{
        .root_module = exe.root_module,
    });
    const run_exe_tests = b.addRunArtifact(exe_tests);
    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_exe_tests.step);
}
