const std = @import("std");
const gl = @import("gl.zig");
const glfw = @import("glfw");
const math = @import("math.zig");
const graphics = @import("graphics.zig");
const system = @import("system.zig");

const PixelBuffer = graphics.PixelBuffer;
const ColourRGBA = graphics.ColourRGBA;
const Camera = graphics.Camera;
const PointScene = graphics.PointScene;

const Vector3f = math.Vector3f;
const Point3f = math.Point3f;

const TimeAccumulator = system.TimeAccumulator;

fn cameraTarget(angle: f32, radius: f32) Point3f {
    return Point3f.init(radius*std.math.sin(angle), radius*std.math.cos(angle), 75);
}

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
    var cameraAngle: f32 = 0.0;
    var cameraRadius: f32 = 150.0;

    var aspect = @intToFloat(f32, pixelBuffer.width) / @intToFloat(f32, pixelBuffer.height);
    camera.setPerspectiveProjection(std.math.pi/2.0, 50, 205, aspect);
    camera.lookAtTarget(cameraTarget(cameraAngle, cameraRadius), Point3f.zero, Vector3f.unitZ);

    try graphics.createPointCube(&scene, Point3f.zero, 100.0, 100.0, 100.0, 9);

    var perfTimeAccum = try TimeAccumulator.init();
    var cameraAnimAccum = try TimeAccumulator.init();
    
    try glfw.swapInterval(0);
    var gold = ColourRGBA.initRGBA(0, 255, 0, 255);

    var frameCount: u64 = 0;
    while (!window.shouldClose()) {
        try glfw.pollEvents();
        pixelBuffer.clear(ColourRGBA.initRGBA(0, 0, 0, 255));

        while (cameraAnimAccum.consume(20)){
            cameraAngle += (2.0*std.math.pi / 5000.0) * 20.0;
            camera.lookAtTarget(cameraTarget(cameraAngle, cameraRadius), Point3f.zero, Vector3f.unitZ);
        }

        graphics.renderPointScene(&pixelBuffer, camera, scene, gold);

        try pixelBuffer.copyToPrimaryFrameBuffer();
        try window.swapBuffers();

        frameCount += 1;        
        var consumedMs = perfTimeAccum.consumeAtleast(1000);
        if (consumedMs >= 1000){        
            const frameTime = @intToFloat(f64, consumedMs) / @intToFloat(f64, frameCount);
            std.debug.print("Frame time = {d:.2}\n", .{frameTime});
            frameCount = 0;
        }

    }

    return 0;
}