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

fn cameraTarget(angle: f32, radius: f32) Point3f {
    return Point3f.init(radius*std.math.sin(angle), radius*std.math.cos(angle), 75);
}

pub fn main() !u8 {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var window = try system.Window.init(allocator, 800, 600, "zujuk");
    defer window.deinit();    

    var pixelBuffer = try PixelBuffer.init(allocator, 800, 600);
    defer pixelBuffer.deinit();

    var scene = PointScene.init(allocator);
    defer scene.deinit();
    
    // var cameraAngle: f32 = 0.0;
    // var cameraRadius: f32 = 150.0;

    var aspect = @intToFloat(f32, pixelBuffer.width) / @intToFloat(f32, pixelBuffer.height);
    var camera = Camera.init();
    camera.setPerspectiveProjection(std.math.pi/2.0, 5, 500, aspect);
    camera.lookAtTarget(Point3f.init(0, 0, 150), Point3f.zero, Vector3f.unitY);

    try graphics.createPointCube(&scene, Point3f.zero, 100.0, 100.0, 100.0, 9, ColourRGBA.initRGBA(255, 0, 0, 255));
    // try scene.addPoint(Point3f.init(50, 50, 0), ColourRGBA.initRGBA(255, 0, 0, 255));
    // try scene.addPoint(Point3f.init(-50, 50, 0), ColourRGBA.initRGBA(0, 255, 0, 255));
    // try scene.addPoint(Point3f.init(-50, -50, 0), ColourRGBA.initRGBA(0, 0, 255, 255));
    // try scene.addPoint(Point3f.init(50, -50, 0), ColourRGBA.initRGBA(255, 255, 0, 255));

    var perfTimeAccum = try TimeAccumulator.init();
    //var cameraAnimAccum = try TimeAccumulator.init();

    //var mouseClickInitial: ?Point3f = null;    
    var cameraRotating = false;
    var cameraRotationInitialClick: math.Point2i = undefined;
    var cameraRotationInitialCSys: math.CSys = undefined;    
    
    try glfw.swapInterval(0);
    // var gold = ColourRGBA.initRGBA(0, 255, 0, 255);

    var frameCount: u64 = 0;
    while (!window.shouldClose()) {
        try glfw.pollEvents();
        
        var eventQueue = &window.data.eventQueue;

        // camera rotation handling
        {var i: u32 = 0; while (i < eventQueue.count) : (i += 1) {        
            const event = eventQueue.queue[i];
            const isLeftButton = event == EventType.mouseButtonEvent and event.mouseButtonEvent.button == glfw.MouseButton.left;
            const isPress = event == EventType.mouseButtonEvent and event.mouseButtonEvent.action == glfw.Action.press;
            const isRelease = event == EventType.mouseButtonEvent and event.mouseButtonEvent.action == glfw.Action.release;
            const isMouseMove = event == EventType.mouseMoveEvent;     

            if (!cameraRotating and isLeftButton and isPress){
                cameraRotating = true;
                cameraRotationInitialClick = Point2i{
                    .i = @floatToInt(i32, event.mouseButtonEvent.x), 
                    .j = @intCast(i32, pixelBuffer.height) - @floatToInt(i32, event.mouseButtonEvent.y)
                };                                
                cameraRotationInitialCSys = camera.csys;       

            }else if (cameraRotating and isMouseMove){     
                const cameraRotationCurrentClick = Point2i{
                    .i = @floatToInt(i32, event.mouseMoveEvent.x), 
                    .j = @intCast(i32, pixelBuffer.height) - @floatToInt(i32, event.mouseMoveEvent.y)
                };

                const width = @intToFloat(f32, pixelBuffer.width);
                const height = @intToFloat(f32, pixelBuffer.height);

                const deltai = math.subtract(cameraRotationCurrentClick, cameraRotationInitialClick);                                                            
                if (deltai.i != 0 or deltai.j != 0){
                    const delta = math.convert(Vector2f, deltai);
                    const distance = math.norm(delta); 
                    const direction = math.multiply(delta, 1.0/distance);
                    const maxDistance = std.math.sqrt(
                        std.math.pow(f32, @fabs(direction.x) * width, 2.0) + 
                        std.math.pow(f32, @fabs(direction.y) * height, 2.0)
                    );
                    const theta = distance / maxDistance * (2*std.math.pi);
                    
                    // compute rotation angle
                    const csys = cameraRotationInitialCSys;
                    const axis = math.normalise(
                        math.add(
                            math.multiply(-direction.x, csys.e2), 
                            math.multiply(direction.y, csys.e1)
                        )
                    );

                    // finally, update camera coordinate system
                    camera.setCoordinateSystem(Quaternion.rotateCsys(Point3f.zero, axis, theta, cameraRotationInitialCSys));  
                }

            }else if (cameraRotating and isLeftButton and isRelease){
                cameraRotating = false;

            }
        }}

        eventQueue.clear();    
        
        pixelBuffer.clear(ColourRGBA.initRGBA(0, 0, 0, 255));

        // while (cameraAnimAccum.consume(20)){
        //     cameraAngle += (2.0*std.math.pi / 5000.0) * 20.0;
        //     camera.lookAtTarget(cameraTarget(cameraAngle, cameraRadius), Point3f.zero, Vector3f.unitZ);
        // }

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