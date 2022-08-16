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

    var pixelBuffer = try PixelBuffer.init(allocator, 800, 600);
    defer pixelBuffer.deinit();

    var scene = PointScene.init(allocator);
    defer scene.deinit();

    var camera = Camera.init();
    var aspect = @intToFloat(f32, pixelBuffer.width) / @intToFloat(f32, pixelBuffer.height);
    camera.setPerspectiveProjection(std.math.pi/2.0, 95, 205, aspect);
    camera.lookAtTarget(Point3f.init(0, -150, 60), Point3f.zero, Vector3f.unitZ);

    try graphics.createPointCube(&scene, Point3f.zero, 100.0, 100.0, 100.0, 9);

    //glfw.swapInterval(0);
    var gold = ColourRGBA.initRGBA(255, 214, 0, 255);

    while (!window.shouldClose()) {
        try glfw.pollEvents();
        pixelBuffer.clear(ColourRGBA.initRGBA(0, 0, 0, 255));

        graphics.renderPointScene(&pixelBuffer, camera, scene, gold);

        try pixelBuffer.copyToPrimaryFrameBuffer();
        try window.swapBuffers();
    }

    return 0;
}