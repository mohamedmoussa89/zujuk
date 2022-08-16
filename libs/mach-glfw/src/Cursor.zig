//! Represents a cursor and provides facilities for setting cursor images.

const std = @import("std");
const testing = std.testing;

const c = @import("c.zig").c;
const Error = @import("errors.zig").Error;
const getError = @import("errors.zig").getError;
const Image = @import("Image.zig");

const internal_debug = @import("internal_debug.zig");

const Cursor = @This();

ptr: *c.GLFWcursor,

/// Standard system cursor shapes.
///
/// These are the standard cursor shapes that can be requested from the platform (window system).
pub const Shape = enum(i32) {
    /// The regular arrow cursor shape.
    arrow = c.GLFW_ARROW_CURSOR,

    /// The text input I-beam cursor shape.
    ibeam = c.GLFW_IBEAM_CURSOR,

    /// The crosshair cursor shape.
    crosshair = c.GLFW_CROSSHAIR_CURSOR,

    /// The pointing hand cursor shape.
    ///
    /// NOTE: This supersedes the old `hand` enum.
    pointing_hand = c.GLFW_POINTING_HAND_CURSOR,

    /// The horizontal resize/move arrow shape.
    ///
    /// The horizontal resize/move arrow shape. This is usually a horizontal double-headed arrow.
    //
    // NOTE: This supersedes the old `hresize` enum.
    resize_ew = c.GLFW_RESIZE_EW_CURSOR,

    /// The vertical resize/move arrow shape.
    ///
    /// The vertical resize/move shape. This is usually a vertical double-headed arrow.
    ///
    /// NOTE: This supersedes the old `vresize` enum.
    resize_ns = c.GLFW_RESIZE_NS_CURSOR,

    /// The top-left to bottom-right diagonal resize/move arrow shape.
    ///
    /// The top-left to bottom-right diagonal resize/move shape. This is usually a diagonal
    /// double-headed arrow.
    ///
    /// macos: This shape is provided by a private system API and may fail CursorUnavailable in the
    /// future.
    ///
    /// x11: This shape is provided by a newer standard not supported by all cursor themes.
    ///
    /// wayland: This shape is provided by a newer standard not supported by all cursor themes.
    resize_nwse = c.GLFW_RESIZE_NWSE_CURSOR,

    /// The top-right to bottom-left diagonal resize/move arrow shape.
    ///
    /// The top-right to bottom-left diagonal resize/move shape. This is usually a diagonal
    /// double-headed arrow.
    ///
    /// macos: This shape is provided by a private system API and may fail with CursorUnavailable
    /// in the future.
    ///
    /// x11: This shape is provided by a newer standard not supported by all cursor themes.
    ///
    /// wayland: This shape is provided by a newer standard not supported by all cursor themes.
    resize_nesw = c.GLFW_RESIZE_NESW_CURSOR,

    /// The omni-directional resize/move cursor shape.
    ///
    /// The omni-directional resize cursor/move shape. This is usually either a combined horizontal
    /// and vertical double-headed arrow or a grabbing hand.
    resize_all = c.GLFW_RESIZE_ALL_CURSOR,

    /// The operation-not-allowed shape.
    ///
    /// The operation-not-allowed shape. This is usually a circle with a diagonal line through it.
    ///
    /// x11: This shape is provided by a newer standard not supported by all cursor themes.
    ///
    /// wayland: This shape is provided by a newer standard not supported by all cursor themes.
    not_allowed = c.GLFW_NOT_ALLOWED_CURSOR,
};

/// Creates a custom cursor.
///
/// Creates a new custom cursor image that can be set for a window with glfw.Cursor.set. The cursor
/// can be destroyed with glfwCursor.destroy. Any remaining cursors are destroyed by glfw.terminate.
///
/// The pixels are 32-bit, little-endian, non-premultiplied RGBA, i.e. eight bits per channel with
/// the red channel first. They are arranged canonically as packed sequential rows, starting from
/// the top-left corner.
///
/// The cursor hotspot is specified in pixels, relative to the upper-left corner of the cursor
/// image. Like all other coordinate systems in GLFW, the X-axis points to the right and the Y-axis
/// points down.
///
/// @param[in] image The desired cursor image.
/// @param[in] xhot The desired x-coordinate, in pixels, of the cursor hotspot.
/// @param[in] yhot The desired y-coordinate, in pixels, of the cursor hotspot.
/// @return The handle of the created cursor.
///
/// @pointer_lifetime The specified image data is copied before this function returns.
///
/// @thread_safety This function must only be called from the main thread.
///
/// see also: cursor_object, glfw.Cursor.destroy, glfw.Cursor.createStandard
pub inline fn create(image: Image, xhot: i32, yhot: i32) error{ PlatformError, InvalidValue }!Cursor {
    internal_debug.assertInitialized();
    const img = image.toC();
    if (c.glfwCreateCursor(&img, @intCast(c_int, xhot), @intCast(c_int, yhot))) |cursor| return Cursor{ .ptr = cursor };
    getError() catch |err| return switch (err) {
        Error.NotInitialized => unreachable,
        Error.PlatformError => |e| e,
        Error.InvalidValue => |e| e,
        else => unreachable,
    };
    // `glfwCreateCursor` returns `null` only for errors
    unreachable;
}

/// Creates a cursor with a standard shape.
///
/// Returns a cursor with a standard shape, that can be set for a window with glfw.Window.setCursor.
/// The images for these cursors come from the system cursor theme and their exact appearance will
/// vary between platforms.
///
/// Most of these shapes are guaranteed to exist on every supported platform but a few may not be
/// present. See the table below for details.
///
/// | Cursor shape     | Windows | macOS           | X11               | Wayland           |
/// |------------------|---------|-----------------|-------------------|-------------------|
/// | `.arrow`         | Yes     | Yes             | Yes               | Yes               |
/// | `.ibeam`         | Yes     | Yes             | Yes               | Yes               |
/// | `.crosshair`     | Yes     | Yes             | Yes               | Yes               |
/// | `.pointing_hand` | Yes     | Yes             | Yes               | Yes               |
/// | `.resize_ew`     | Yes     | Yes             | Yes               | Yes               |
/// | `.resize_ns`     | Yes     | Yes             | Yes               | Yes               |
/// | `.resize_nwse`   | Yes     | Yes<sup>1</sup> | Maybe<sup>2</sup> | Maybe<sup>2</sup> |
/// | `.resize_nesw`   | Yes     | Yes<sup>1</sup> | Maybe<sup>2</sup> | Maybe<sup>2</sup> |
/// | `.resize_all`    | Yes     | Yes             | Yes               | Yes               |
/// | `.not_allowed`   | Yes     | Yes             | Maybe<sup>2</sup> | Maybe<sup>2</sup> |
///
/// 1. This uses a private system API and may fail in the future.
/// 2. This uses a newer standard that not all cursor themes support.
///
/// If the requested shape is not available, this function emits a CursorUnavailable error
///
/// thread_safety: This function must only be called from the main thread.
///
/// see also: cursor_object, glfwCreateCursor
pub inline fn createStandard(shape: Shape) error{ PlatformError, CursorUnavailable }!Cursor {
    internal_debug.assertInitialized();
    if (c.glfwCreateStandardCursor(@intCast(c_int, @enumToInt(shape)))) |cursor| return Cursor{ .ptr = cursor };
    getError() catch |err| return switch (err) {
        Error.NotInitialized => unreachable,
        Error.InvalidEnum => unreachable,
        Error.CursorUnavailable => |e| e,
        Error.PlatformError => |e| e,
        else => unreachable,
    };
    // `glfwCreateStandardCursor` returns `null` only for errors
    unreachable;
}

/// Destroys a cursor.
///
/// This function destroys a cursor previously created with glfw.Cursor.create. Any remaining
/// cursors will be destroyed by glfw.terminate.
///
/// If the specified cursor is current for any window, that window will be reverted to the default
/// cursor. This does not affect the cursor mode.
///
/// Possible errors include glfw.Error.NotInitialized and glfw.Error.PlatformError.
///
/// @reentrancy This function must not be called from a callback.
///
/// @thread_safety This function must only be called from the main thread.
///
/// see also: cursor_object, glfw.createCursor
pub inline fn destroy(self: Cursor) void {
    internal_debug.assertInitialized();
    c.glfwDestroyCursor(self.ptr);
    getError() catch |err| return switch (err) {
        Error.PlatformError => std.log.err("mach/glfw: unable to destroy Cursor: {}\n", .{err}),
        else => unreachable,
    };
}

test "create" {
    const allocator = testing.allocator;

    const glfw = @import("main.zig");
    try glfw.init(.{});
    defer glfw.terminate();

    const image = try Image.init(allocator, 32, 32, 32 * 32 * 4);
    defer image.deinit(allocator);

    const cursor = glfw.Cursor.create(image, 0, 0) catch |err| {
        std.debug.print("failed to create cursor, custom cursors not supported? error={}\n", .{err});
        return;
    };
    cursor.destroy();
}

test "createStandard" {
    const glfw = @import("main.zig");
    try glfw.init(.{});
    defer glfw.terminate();

    const cursor = glfw.Cursor.createStandard(.ibeam) catch |err| {
        std.debug.print("failed to create cursor, custom cursors not supported? error={}\n", .{err});
        return;
    };
    cursor.destroy();
}
