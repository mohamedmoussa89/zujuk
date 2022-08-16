const std = @import("std");
const gl = @import("gl.zig");
const glfw = @import("glfw");
const math = @import("math.zig");
const graphics = @import("graphics.zig");

const PixelBuffer = graphics.PixelBuffer;
const ColourRGBA = graphics.ColourRGBA;
const Camera = graphics.Camera;
const PointScene = graphics.PointScene;

const Vector3f = math.Vector3f;
const Point3f = math.Point3f;

pub fn main() !u8 {
    // var reader = std.io.getStdIn().reader();
    // _ = try reader.readByte();
    
    var window = try graphics.initWindow();
    defer graphics.deinitWindow(window);
    
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var pixelBuffer = try PixelBuffer.init(allocator, 640, 480);
    defer pixelBuffer.deinit();

    var scene = PointScene.init(allocator);
    defer scene.deinit();

    var camera = Camera.init();
    var aspect = @intToFloat(f32, pixelBuffer.width) / @intToFloat(f32, pixelBuffer.height);
    camera.setPerspectiveProjection(std.math.pi/2.0, 25, 250, aspect);
    camera.lookAtTarget(Point3f.init(0, -150, 60), Point3f.zero, Vector3f.unitZ);

    try graphics.createPointCube(&scene, Point3f.zero, 100.0, 100.0, 100.0, 9);

    //glfw.swapInterval(0);

    while (!window.shouldClose()) {
        try glfw.pollEvents();
        pixelBuffer.clear(ColourRGBA.FromRGB(0, 0, 0, 255));

        graphics.renderPointScene(&pixelBuffer, camera, scene);

        try pixelBuffer.copyToPrimaryFrameBuffer();
        try window.swapBuffers();
    }

    return 0;
}

// pub fn main() !void {
//     // Prints to stderr (it's a shortcut based on `std.io.getStdErr()`)
//     std.debug.print("All your {s} are belong to us.\n", .{"codebase"});

//     // stdout is for the actual output of your application, for example if you
//     // are implementing gzip, then only the compressed bytes should be sent to
//     // stdout, not any debugging messages.
//     const stdout_file = std.io.getStdOut().writer();
//     var bw = std.io.bufferedWriter(stdout_file);
//     const stdout = bw.writer();

//     try stdout.print("Run `zig build test` to run the tests.\n", .{});

//     try bw.flush(); // don't forget to flush!
// }