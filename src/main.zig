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

const Point2i = math.Point2i;
const Point3f = math.Point3f;
const Vector2f = math.Vector2f;
const Vector3f = math.Vector3f;
const Quaternion = math.Quaternion;

const TimeAccumulator = system.TimeAccumulator;
const EventQueue = system.EventQueue;
const EventType = system.EventType;
const KeyEvent = system.KeyEvent;
const MouseEvent = system.MouseEvent;

pub fn main() !u8 {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var window = try system.Window.init(allocator, 800, 600, "zujuk");
    defer window.deinit();    

    var pixelBuffer = try PixelBuffer.init(allocator, 800, 600);
    defer pixelBuffer.deinit();

    var scene = PointScene.init(allocator);
    defer scene.deinit();

    var aspect = @intToFloat(f32, pixelBuffer.width) / @intToFloat(f32, pixelBuffer.height);
    var camera = Camera.init();
    camera.setPerspectiveProjection(std.math.pi/2.0, 5, 500, aspect);
    camera.lookAtTarget(Point3f.init(0, 0, 150), Point3f.zero, Vector3f.unitY);

    var cameraControl = graphics.MouseCameraControl.init(&camera, pixelBuffer.width, pixelBuffer.height);

    try graphics.createPointCube(&scene, Point3f.zero, 100.0, 100.0, 100.0, 9, ColourRGBA.initRGBA(255, 0, 0, 255));
    var perfTimeAccum = try TimeAccumulator.init();
    try glfw.swapInterval(0);

    var frameCount: u64 = 0;
    while (!window.shouldClose()) {
        try glfw.pollEvents();
        
        var eventQueue = &window.data.eventQueue;
        const events = eventQueue.queue[eventQueue.first..eventQueue.count];
        cameraControl.handleEvents(events);
        eventQueue.clear();    
        
        pixelBuffer.clear(ColourRGBA.initRGBA(0, 0, 0, 255));
        graphics.renderPointScene(&pixelBuffer, camera, scene);

        try pixelBuffer.copyToPrimaryFrameBuffer();
        try window.swapBuffers();

        frameCount += 1;        
        var consumedMs = perfTimeAccum.consumeAtleast(1000);
        if (consumedMs >= 1000){        
            const frameTime = @intToFloat(f64, consumedMs) / @intToFloat(f64, frameCount);
            const fps = 1000.0 / frameTime;
            std.debug.print("Frame time = {d:.2} ({d:.0} FPS)\n", .{frameTime, fps});
            frameCount = 0;
        }

    }

    return 0;
}