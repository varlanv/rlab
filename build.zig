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
    addSdl(b, exe, target, optimize);
    b.installArtifact(exe);

    const run_step = b.step("run", "Run the app");
    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);
    run_cmd.step.dependOn(b.getInstallStep());
    run_cmd.addPassthruArgs();
    const exe_tests = b.addTest(.{
        .root_module = exe.root_module,
    });
    const run_exe_tests = b.addRunArtifact(exe_tests);
    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_exe_tests.step);
}

fn addSdl(
    b: *std.Build,
    exe: *std.Build.Step.Compile,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) void {
    const sdl = b.dependency("sdl", .{});

    // Configure SDL.
    const configure = b.addSystemCommand(&.{
        "cmake", "-S",
    });
    configure.addDirectoryArg2(sdl.path(""), .{
        .make_absolute = true,
    });

    configure.addArg("-B");
    const build_dir = configure.addOutputDirectoryArg2(
        "sdl-build",
        .{ .make_absolute = true },
    );

    configure.addArgs(&.{
        "-DCMAKE_BUILD_TYPE=Release",
        "-DCMAKE_INSTALL_LIBDIR=lib",
        "-DSDL_SHARED=ON",
        "-DSDL_STATIC=OFF",
        "-DSDL_TEST_LIBRARY=OFF",
        "-DSDL_TESTS=OFF",
        "-DSDL_EXAMPLES=OFF",
        "-DSDL_FRAMEWORK=OFF",
    });

    // Compile SDL.
    const compile = b.addSystemCommand(&.{
        "cmake", "--build",
    });
    compile.addDirectoryArg2(build_dir, .{
        .make_absolute = true,
    });
    compile.addArgs(&.{
        "--config", "Release", "--parallel",
    });

    // Install into Zig's build cache.
    const install = b.addSystemCommand(&.{
        "cmake", "--install",
    });
    install.addDirectoryArg2(build_dir, .{
        .make_absolute = true,
    });
    install.addArgs(&.{
        "--config", "Release", "--prefix",
    });

    const prefix = install.addOutputDirectoryArg2(
        "sdl-install",
        .{ .make_absolute = true },
    );
    install.step.dependOn(&compile.step);

    // Translate SDL headers into a Zig module.
    const headers = b.addTranslateC(.{
        .root_source_file = sdl.path("include/SDL3/SDL.h"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    headers.addIncludePath(sdl.path("include"));

    exe.root_module.addImport("sdl", headers.createModule());

    // Link against the SDL library we just built.
    exe.root_module.addLibraryPath(prefix.path(b, "lib"));
    exe.root_module.linkSystemLibrary("SDL3", .{
        .use_pkg_config = .no,
    });

    // Place SDL's shared library beside the executable.
    const windows = target.result.os.tag == .windows;

    const copy = b.addInstallDirectory(.{
        .source_dir = prefix.path(
            b,
            if (windows) "bin" else "lib",
        ),
        .install_dir = .bin,
        .install_subdir = "",
    });
    b.getInstallStep().dependOn(&copy.step);

    switch (target.result.os.tag) {
        .linux => exe.root_module.addRPathSpecial("$ORIGIN"),
        .macos => exe.root_module.addRPathSpecial("@loader_path"),
        else => {},
    }
}