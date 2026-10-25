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

    const sdl_ttf = b.dependency("sdl_ttf", .{}).path("SDL_ttf-release-3.2.2");
    addSdlTtf(b, exe, target, prefix, sdl_ttf);

    // SDL_ttf.h includes SDL.h. Translate them together so both imports share
    // the same SDL types, including GPU device handles used by the text engine.
    const headers = b.addTranslateC(.{
        .root_source_file = sdl_ttf.path(b, "include/SDL3_ttf/SDL_ttf.h"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    headers.addIncludePath(sdl.path("include"));
    headers.addIncludePath(sdl_ttf.path(b, "include"));

    const bindings = headers.createModule();
    exe.root_module.addImport("sdl", bindings);
    exe.root_module.addImport("ttf", bindings);

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
        .linux => {
            exe.root_module.addRPathSpecial("$ORIGIN");
            // Directory installation skips symlinks; install the loader's name explicitly.
            const runtime = b.addInstallFileWithDir(prefix.path(b, "lib/libSDL3.so.0"), .bin, "libSDL3.so.0");
            b.getInstallStep().dependOn(&runtime.step);
        },
        .macos => exe.root_module.addRPathSpecial("@loader_path"),
        else => {},
    }
}

fn addSdlTtf(
    b: *std.Build,
    exe: *std.Build.Step.Compile,
    target: std.Build.ResolvedTarget,
    sdl_prefix: std.Build.LazyPath,
    sdl_ttf: std.Build.LazyPath,
) void {
    // Assemble the release and its pinned submodules in the build cache.
    const sources = b.addWriteFiles();
    const source_dir = sources.addCopyDirectory(sdl_ttf, "sdl-ttf-source", .{});
    _ = sources.addCopyDirectory(
        b.dependency("freetype", .{}).path("freetype-9973564cfa63763a3e4ac67c09147899539b1e07"),
        "sdl-ttf-source/external/freetype",
        .{},
    );
    _ = sources.addCopyDirectory(
        b.dependency("harfbuzz", .{}).path("harfbuzz-564bf9818a18709776856533829c0c04950773d6"),
        "sdl-ttf-source/external/harfbuzz",
        .{},
    );

    const configure = b.addSystemCommand(&.{ "cmake", "-S" });
    configure.addDirectoryArg2(source_dir, .{ .make_absolute = true });
    configure.addArg("-B");
    const build_dir = configure.addOutputDirectoryArg2(
        "sdl-ttf-build",
        .{ .make_absolute = true },
    );
    configure.addDirectoryArg2(sdl_prefix.path(b, "lib/cmake/SDL3"), .{
        .prefix = "-DSDL3_DIR=",
        .make_absolute = true,
    });
    configure.addArgs(&.{
        "-DCMAKE_BUILD_TYPE=Release",
        "-DCMAKE_INSTALL_LIBDIR=lib",
        "-DCMAKE_POLICY_VERSION_MINIMUM=3.5",
        "-DBUILD_SHARED_LIBS=ON",
        "-DSDLTTF_VENDORED=ON",
        "-DSDLTTF_INSTALL=ON",
        "-DSDLTTF_INSTALL_CPACK=OFF",
        "-DSDLTTF_SAMPLES=OFF",
        "-DSDLTTF_STRICT=ON",
        "-DSDLTTF_PLUTOSVG=OFF",
    });
    switch (target.result.os.tag) {
        .linux => configure.addArg("-DCMAKE_INSTALL_RPATH=$ORIGIN"),
        .macos => configure.addArg("-DCMAKE_INSTALL_RPATH=@loader_path"),
        else => {},
    }

    const compile = b.addSystemCommand(&.{ "cmake", "--build" });
    compile.addDirectoryArg2(build_dir, .{ .make_absolute = true });
    compile.addArgs(&.{ "--config", "Release", "--parallel" });

    const install = b.addSystemCommand(&.{ "cmake", "--install" });
    install.addDirectoryArg2(build_dir, .{ .make_absolute = true });
    install.addArgs(&.{ "--config", "Release", "--prefix" });
    const prefix = install.addOutputDirectoryArg2(
        "sdl-ttf-install",
        .{ .make_absolute = true },
    );
    install.step.dependOn(&compile.step);

    exe.root_module.addLibraryPath(prefix.path(b, "lib"));
    exe.root_module.linkSystemLibrary("SDL3_ttf", .{ .use_pkg_config = .no });

    const copy = b.addInstallDirectory(.{
        .source_dir = prefix.path(b, if (target.result.os.tag == .windows) "bin" else "lib"),
        .install_dir = .bin,
        .install_subdir = "",
    });
    b.getInstallStep().dependOn(&copy.step);
    if (target.result.os.tag == .linux) {
        const runtime = b.addInstallFileWithDir(
            prefix.path(b, "lib/libSDL3_ttf.so.0"),
            .bin,
            "libSDL3_ttf.so.0",
        );
        b.getInstallStep().dependOn(&runtime.step);
    }
}
