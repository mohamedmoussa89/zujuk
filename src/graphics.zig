const std = @import("std");
const gl = @import("gl.zig");
const glfw = @import("glfw");
const math = @import("math.zig");
const magic = @import("magic.zig");

const CSys = math.CSys;
const Point3f = math.Point3f;
const Vector3f = math.Vector3f;
const Matrix4f = math.Matrix4f;

pub fn initWindow() !glfw.Window {
    try glfw.init(.{});

    var hints = .{
        .context_version_major = 4, 
        .context_version_minor = 3, 
        .resizable = false
    };
    const window = try glfw.Window.create(640, 480, "Hello, mach-glfw!", null, null, hints);

    try glfw.makeContextCurrent(window);

    const proc: glfw.GLProc = undefined;
    try gl.load(proc, glGetProcAddress);
    gl.enable(gl.DEBUG_OUTPUT);

    return window;
}

fn glGetProcAddress(p: glfw.GLProc, proc: [:0]const u8) ?*const anyopaque {
    _ = p;
    return glfw.getProcAddress(proc);
}

pub fn deinitWindow(window: glfw.Window) void {
    window.destroy();
    glfw.terminate();

}

pub const PixelBuffer = struct {
    width: u32,
    height: u32,
    buffer: []ColourRGBA,

    _texture: gl.GLuint,
    _frameBuffer: gl.GLuint,
    _allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, width: u32, height: u32) !PixelBuffer {        
        var buffer: []ColourRGBA = try allocator.alloc(ColourRGBA, width*height);

        var width_c = @intCast(gl.GLint, width);
        var height_c = @intCast(gl.GLint, height);

        var texture: gl.GLuint = undefined;        
        gl.genTextures(1, &texture);
        gl.bindTexture(gl.TEXTURE_2D, texture);
        gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, width_c, height_c, 0, gl.RGBA, gl.UNSIGNED_BYTE, &buffer[0]);

        var frameBuffer: gl.GLuint = undefined;
        gl.genFramebuffers(1, &frameBuffer);
        gl.bindFramebuffer(gl.READ_FRAMEBUFFER, frameBuffer);
        gl.framebufferTexture2D(gl.READ_FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.TEXTURE_2D, texture, 0);

        return PixelBuffer {
            .width = width,
            .height = height,
            .buffer = buffer,
            ._texture = texture,
            ._frameBuffer = frameBuffer,
            ._allocator = allocator         
        };
    }

    pub fn deinit(self: PixelBuffer) void {
        self._allocator.free(self.buffer);
    }

    pub fn clear(self: PixelBuffer, colour: ColourRGBA) void {
        std.mem.set(ColourRGBA, self.buffer, colour);
    }

    pub fn copyToPrimaryFrameBuffer(self: PixelBuffer) !void {
        var width = @intCast(gl.GLint, self.width);
        var height = @intCast(gl.GLint, self.height);

        gl.bindTexture(gl.TEXTURE_2D, self._texture);
        gl.texSubImage2D(gl.TEXTURE_2D, 0, 0, 0, width, height, gl.RGBA, gl.UNSIGNED_INT_8_8_8_8_REV, &self.buffer[0]);

        gl.bindFramebuffer(gl.READ_FRAMEBUFFER, self._frameBuffer);
        gl.bindFramebuffer(gl.DRAW_FRAMEBUFFER, 0);
        gl.blitFramebuffer(0, 0, width, height, 0, 0, width, height, gl.COLOR_BUFFER_BIT, gl.NEAREST);        
    }

    pub fn set(self: *PixelBuffer, i: u32, j: u32, colour: ColourRGBA) void {
        self.buffer[self.width*j + i] = colour;
    }

};


pub const ColourRGBA = struct {
    value: u32,

    pub fn FromRGB(r: u8, g: u8, b: u8, a: u8) ColourRGBA {
        return ColourRGBA {
            .value = (@intCast(u32, r) << 0) | (@intCast(u32, g) << 8) | (@intCast(u32, b) << 16) | (@intCast(u32, a) << 24)
        };
    }
};

pub const Camera = struct {
    csys: CSys,
    fieldOfViewHorizontal: f32,
    aspectRatioWidthHeight: f32,
    near: f32,
    far: f32,

    viewTransform: Matrix4f,
    projectionTransform: Matrix4f,
    totalTransform: Matrix4f,

    pub fn init() Camera {
        var camera = Camera {
            .csys = CSys.init(),
            .fieldOfViewHorizontal = std.math.pi/2.0,
            .aspectRatioWidthHeight = 1.0,
            .near = 1.0,
            .far = 2.0,
            .viewTransform = Matrix4f.identity,
            .projectionTransform = Matrix4f.identity,
            .totalTransform = Matrix4f.identity
        };        
        return camera;
    }

    pub fn setPerspectiveProjection(self: *Camera, fovHorizontal: f32, near: f32, far: f32, aspectRatioWidthHeight: f32) void {
        self.fieldOfViewHorizontal = fovHorizontal;
        self.near = near;
        self.far = far;
        self.aspectRatioWidthHeight = aspectRatioWidthHeight;
        var left = -near * std.math.tan(fovHorizontal/2.0);
        var right = -left;
        var top = right / aspectRatioWidthHeight;
        var bottom = -top;
        self.projectionTransform = math.projectionTransform(left, right, bottom, top, near, far);
        self.updateTotalTransform();
    }

    fn updateViewTransform(self: *Camera) void {
        self.viewTransform = math.globalToLocalTransform(self.csys.origin, self.csys.e1, self.csys.e2, self.csys.e3);
    }

    fn updateTotalTransform(self: *Camera) void {
        self.totalTransform = math.multiply(self.projectionTransform, self.viewTransform);
    }

    pub fn setCoordinateSystem(self: *Camera, csys: CSys) void {
        self.csys = csys;
        self.updateViewTransform();
        self.updateTotalTransform();
    }

    pub fn lookAtTarget(self: *Camera, position: Point3f, target: Point3f, up: Vector3f) void {
        var direction = math.subtract(target, position);
        var e3 = math.negate(direction);
        var e1 = math.cross(up, e3);        
        var csys = math.CSys.initE1E3(position, e1, e3);
        self.setCoordinateSystem(csys);
    }

};

pub const PointScene  = struct {
    const PointList = std.ArrayList(Point3f);

    allocator: std.mem.Allocator,
    points: PointList,

    pub fn init(allocator: std.mem.Allocator) PointScene {        
        return PointScene {
            .allocator = allocator,
            .points = PointList.init(allocator)
        };
    }

    pub fn deinit(self: *PointScene) void {
        self.points.deinit();
    }

    pub fn addPoint(self: *PointScene, p: Point3f) !void {
        try self.points.append(p);
    }
};

pub fn createPointCube(scene: *PointScene, origin: Point3f, dx: f32, dy: f32, dz: f32, layers: u32) !void {
    var topLeft = Vector3f.init(origin.x() - dx/2, origin.y() - dy/2, origin.z() - dz/2);
    var divisions = @intToFloat(f32, layers - 1);
    var delta = Vector3f.init(dx / divisions, dy / divisions, dz / divisions);    
    {var k: u32 = 0; while(k < layers):(k += 1){
        {var j: u32 = 0; while(j < layers):(j += 1){
            {var i: u32 = 0; while(i < layers):(i += 1){
                try scene.addPoint(Point3f.init(
                    topLeft.x() + delta.x() * @intToFloat(f32, i),
                    topLeft.y() + delta.y() * @intToFloat(f32, j),
                    topLeft.z() + delta.z() * @intToFloat(f32, k),
                ));
            }}
        }}
    }}
}

pub fn renderPointScene(buffer: *PixelBuffer, camera: Camera, pointScene: PointScene) void {
    magic.escape(camera);
    var transform = camera.totalTransform;

    for (pointScene.points.items) |p|{
        var q = math.transform(transform, p);
        var outOfBounds = 
            q.x() <= -1 or q.x() >= 1 or
            q.y() <= -1 or q.y() >= 1 or
            q.z() <= -1 or q.z() >= 1;
        if (outOfBounds){
            continue;
        }        
        var i = @floatToInt(u32, 0.5*(q.x() + 1.0) * @intToFloat(f32, buffer.width));
        var j = @floatToInt(u32, 0.5*(q.y() + 1.0) * @intToFloat(f32, buffer.height));
        var colour = ColourRGBA.FromRGB(255, 255, 255, 255);
        buffer.set(i, j, colour);
    }
}