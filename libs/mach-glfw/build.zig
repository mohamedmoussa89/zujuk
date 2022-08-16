const std = @import("std");
const Builder = std.build.Builder;

const system_sdk = @import("system_sdk.zig");

pub fn build(b: *Builder) void {
    const mode = b.standardReleaseOptions();
    const target = b.standardTargetOptions(.{});

    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&testStep(b, mode, target).step);
    test_step.dependOn(&testStepShared(b, mode, target).step);
}

pub fn testStep(b: *Builder, mode: std.builtin.Mode, target: std.zig.CrossTarget) *std.build.RunStep {
    const main_tests = b.addTestExe("glfw_tests", (comptime thisDir()) ++ "/src/main.zig");
    main_tests.setBuildMode(mode);
    main_tests.setTarget(target);
    link(b, main_tests, .{});
    main_tests.install();
    return main_tests.run();
}

fn testStepShared(b: *Builder, mode: std.builtin.Mode, target: std.zig.CrossTarget) *std.build.RunStep {
    const main_tests = b.addTestExe("glfw_tests_shared", (comptime thisDir()) ++ "/src/main.zig");
    main_tests.setBuildMode(mode);
    main_tests.setTarget(target);
    link(b, main_tests, .{ .shared = true });
    main_tests.install();
    return main_tests.run();
}

pub const LinuxWindowManager = enum {
    X11,
    Wayland,
};

pub const Options = struct {
    /// Not supported on macOS.
    vulkan: bool = true,

    /// Only respected on macOS.
    metal: bool = true,

    /// Deprecated on macOS.
    opengl: bool = false,

    /// Not supported on macOS. GLES v3.2 only, currently.
    gles: bool = false,

    /// Only respected on Linux.
    x11: bool = true,

    /// Only respected on Linux.
    wayland: bool = true,

    /// System SDK options.
    system_sdk: system_sdk.Options = .{},

    /// Build and link GLFW as a shared library.
    shared: bool = false,
};

pub const pkg = std.build.Pkg{
    .name = "glfw",
    .source = .{ .path = thisDir() ++ "/src/main.zig" },
};

pub fn link(b: *Builder, step: *std.build.LibExeObjStep, options: Options) void {
    const lib = buildLibrary(b, step, options);
    step.linkLibrary(lib);
    addGLFWIncludes(b, step);
    if (!options.shared) linkGLFWDependencies(b, step, options);
    if (options.shared) step.defineCMacro("GLFW_DLL", null);
}

fn buildLibrary(b: *Builder, step: *std.build.LibExeObjStep, options: Options) *std.build.LibExeObjStep {
    // TODO(build-system): https://github.com/hexops/mach/issues/229#issuecomment-1100958939
    ensureDependencySubmodule(b.allocator, "upstream") catch unreachable;

    const main_abs = (comptime thisDir()) ++ "/src/main.zig";
    const lib = if (options.shared) b.addSharedLibrary("glfw", main_abs, .unversioned) else b.addStaticLibrary("glfw", main_abs);
    lib.setBuildMode(step.build_mode);
    lib.setTarget(step.target);
    addGLFWIncludes(b, lib);

    if (options.shared) {
        lib.defineCMacro("_GLFW_BUILD_DLL", null);
        lib.install();
    }
    addGLFWSources(b, step, lib, options);
    linkGLFWDependencies(b, lib, options);
    return lib;
}

fn addGLFWIncludes(b: *Builder, step: *std.build.LibExeObjStep) void {
    const include_dir = std.fs.path.join(b.allocator, &.{ (comptime thisDir()), "upstream/glfw/include" }) catch unreachable;
    defer b.allocator.free(include_dir);
    step.addIncludeDir(include_dir);

    const vulkan_include_dir = std.fs.path.join(b.allocator, &.{ (comptime thisDir()), "upstream/vulkan_headers/include" }) catch unreachable;
    defer b.allocator.free(vulkan_include_dir);
    step.addIncludeDir(vulkan_include_dir);
}

fn addGLFWSources(b: *Builder, step: *std.build.LibExeObjStep, lib: *std.build.LibExeObjStep, options: Options) void {
    const target = (std.zig.system.NativeTargetInfo.detect(b.allocator, step.target) catch unreachable).target;
    const include_glfw_src = "-I" ++ (comptime thisDir()) ++ "/upstream/glfw/src";
    switch (target.os.tag) {
        .windows => lib.addCSourceFiles(&.{
            (comptime thisDir()) ++ "/src/sources_all.c",
            (comptime thisDir()) ++ "/src/sources_windows.c",
        }, &.{ "-D_GLFW_WIN32", include_glfw_src }),
        .macos => lib.addCSourceFiles(&.{
            (comptime thisDir()) ++ "/src/sources_all.c",
            (comptime thisDir()) ++ "/src/sources_macos.m",
            (comptime thisDir()) ++ "/src/sources_macos.c",
        }, &.{ "-D_GLFW_COCOA", include_glfw_src }),
        else => {
            // TODO(future): for now, Linux must be built with glibc, not musl:
            //
            // ```
            // ld.lld: error: cannot create a copy relocation for symbol stderr
            // thread 2004762 panic: attempt to unwrap error: LLDReportedFailure
            // ```
            step.target.abi = .gnu;
            lib.setTarget(step.target);

            var sources = std.ArrayList([]const u8).init(b.allocator);
            var flags = std.ArrayList([]const u8).init(b.allocator);
            sources.append((comptime thisDir()) ++ "/src/sources_all.c") catch unreachable;
            sources.append((comptime thisDir()) ++ "/src/sources_linux.c") catch unreachable;
            if (options.x11) {
                sources.append((comptime thisDir()) ++ "/src/sources_linux_x11.c") catch unreachable;
                flags.append("-D_GLFW_X11") catch unreachable;
            }
            if (options.wayland) {
                sources.append((comptime thisDir()) ++ "/src/sources_linux_wayland.c") catch unreachable;
                flags.append("-D_GLFW_WAYLAND") catch unreachable;
            }
            flags.append("-I" ++ (comptime thisDir()) ++ "/upstream/glfw/src") catch unreachable;

            lib.addCSourceFiles(sources.items, flags.items);
        },
    }
}

fn ensureDependencySubmodule(allocator: std.mem.Allocator, path: []const u8) !void {
    if (std.process.getEnvVarOwned(allocator, "NO_ENSURE_SUBMODULES")) |no_ensure_submodules| {
        if (std.mem.eql(u8, no_ensure_submodules, "true")) return;
    } else |_| {}
    var child = std.ChildProcess.init(&.{ "git", "submodule", "update", "--init", path }, allocator);
    child.cwd = (comptime thisDir());
    child.stderr = std.io.getStdErr();
    child.stdout = std.io.getStdOut();

    _ = try child.spawnAndWait();
}

fn thisDir() []const u8 {
    return std.fs.path.dirname(@src().file) orelse ".";
}

fn linkGLFWDependencies(b: *Builder, step: *std.build.LibExeObjStep, options: Options) void {
    step.linkLibC();
    // TODO(build-system): pass system SDK options through
    system_sdk.include(b, step, .{});
    const target = (std.zig.system.NativeTargetInfo.detect(b.allocator, step.target) catch unreachable).target;
    switch (target.os.tag) {
        .windows => {
            step.linkSystemLibraryName("gdi32");
            step.linkSystemLibraryName("user32");
            step.linkSystemLibraryName("shell32");
            if (options.opengl) {
                step.linkSystemLibraryName("opengl32");
            }
            if (options.gles) {
                step.linkSystemLibraryName("GLESv3");
            }
        },
        .macos => {
            step.linkFramework("IOKit");
            step.linkFramework("CoreFoundation");
            if (options.metal) {
                step.linkFramework("Metal");
            }
            if (options.opengl) {
                step.linkFramework("OpenGL");
            }
            step.linkSystemLibraryName("objc");
            step.linkFramework("AppKit");
            step.linkFramework("CoreServices");
            step.linkFramework("CoreGraphics");
            step.linkFramework("Foundation");
        },
        else => {
            // Assume Linux-like
            if (options.wayland) {
                step.defineCMacro("WL_MARSHAL_FLAG_DESTROY", null);
            }
            if (options.x11) {
                step.linkSystemLibraryName("X11");
                step.linkSystemLibraryName("xcb");
                step.linkSystemLibraryName("Xau");
                step.linkSystemLibraryName("Xdmcp");
            }
            // Note: no need to link against vulkan, GLFW finds it dynamically at runtime.
            // https://www.glfw.org/docs/3.3/vulkan_guide.html#vulkan_loader
            if (options.opengl) {
                step.linkSystemLibraryName("GL");
            }
            if (options.gles) {
                step.linkSystemLibraryName("GLESv3");
            }
        },
    }
}
