const std = @import("std");
const util = @import("utility.zig");

pub const Vector2i = struct {
    const Self = @This();

    i: i32,
    j: i32,    

    pub fn init(i: i32, j: i32) Self {
        return Self {
            .i = i,
            .j = j
        };
    }

    pub const zero = Vector2i {.i = 0, .j = 0};
};

pub const Vector2f = struct {
    const Self = @This();

    x: f32,
    y: f32,
   
    pub fn init(x: f32, y: f32) Self {
        return Self {
            .x = x,
            .y = y
        };
    }

    pub const zero = Vector2f {.x = 0.0, .y = 0.0};
};

pub const Point2i = struct {
    const Self = @This();

    i: i32,
    j: i32,

    pub fn init(i: i32, j: i32) Self {
        return Self {
            .i = i,
            .j = j
        };
    }

    pub const zero = Point2i {.i = 0, .j = 0};
};

pub const Point3f = struct {
    const Self = @This();

    x: f32,
    y: f32,
    z: f32,
    
    pub fn init(x: f32, y: f32, z: f32) Point3f {
        return Point3f {
            .x = x,
            .y = y,
            .z = z
        };
    }

    /// Returns view of Point3f as a slice
    /// No copy is made
    pub fn asSlice(self: *Self) []f32 {        
        return util.asSlice(f32, self);
    }

    /// Returns view of Point3f as a const slice
    /// No copy is made
    pub fn asConstSlice(self: *const Self) []const f32 {        
        return util.asConstSlice(f32, self);
    }

    pub const zero = Point3f {.x = 0, .y = 0, .z = 0};    
        
};

pub const Vector3f = struct {    
    const Self = @This();

    x: f32,
    y: f32,
    z: f32,

    pub fn init(x: f32, y: f32, z: f32) Vector3f {
        return Vector3f {
            .x = x, .y = y, .z = z
        };
    }

    /// Returns view of Vector3f as a slice    
    pub fn asSlice(self: *Self) []f32 {        
        return util.asSlice(f32, self);
    }

    /// Returns view of Vector3f as a const slice        
    pub fn asConstSlice(self: *const Self) []const f32 {        
        return util.asConstSlice(f32, self);
    }

    pub const zero = Vector3f {.x = 0, .y = 0, .z = 0};    
    pub const unitX = Vector3f {.x = 1, .y = 0, .z = 0};   
    pub const unitY = Vector3f {.x = 0, .y = 1, .z = 0};   
    pub const unitZ = Vector3f {.x = 0, .y = 0, .z = 1};   

};

pub const Quaternion = struct {
    a: f32,     
    b: f32,     // i
    c: f32,     // j
    d: f32,     // k

    const identity: Quaternion = Quaternion {.a = 1, .b = 0, .c = 0, .d = 0};

    pub fn initRotation(v: Vector3f, theta: f32) Quaternion {
        const c = std.math.cos(theta / 2.0);
        const s = std.math.sin(theta / 2.0);
        return Quaternion {
            .a = c,
            .b = s * v.x,
            .c = s * v.y,
            .d = s * v.z,
        };
    }

    pub fn normSqrd(self: Quaternion) f32 {
        return self.a*self.a + self.b*self.b + self.c*self.c + self.d*self.d;
    }

    pub fn inverse(self: Quaternion) Quaternion {
        const n = self.normSqrd();
        return Quaternion {
            .a = self.a / n,
            .b = self.b / n,
            .c = self.c / n,
            .d = self.d / n
        };
    } 

    pub fn multiplyQQ(q1: Quaternion, q2: Quaternion) Quaternion {
        const a = q1.a;
        const b = q1.b;
        const c = q1.c;
        const d = q1.d;
        const r = q2.a;
        const s = q2.b;
        const t = q2.c;
        const u = q2.d;
        return Quaternion {
            .a = a*r - b*s - c*t - d*u,
            .b = b*r + a*s - d*t + c*u,
            .c = c*r + d*s + a*t - b*u,
            .d = d*r - c*s + b*t + a*u
        };
    }

    pub fn multiplyQVCQ(q: Quaternion, v: Vector3f) Vector3f {
        const a = q.a;
        const b = q.b;
        const c = q.c;
        const d = q.d;
        const x = v.x;
        const y = v.y;
        const z = v.z;
        const aa = a*a;
        const bb = b*b;
        const cc = c*c;
        const dd = d*d;
        return Vector3f {
            .x = aa*x + bb*x - (cc + dd)*x + a*(-2*d*y + 2*c*z) + 2*b*(c*y + d*z),
            .y = 2*b*c*x + 2*a*d*x + aa*y - bb*y + cc*y - dd*y - 2*a*b*z + 2*c*d*z,
            .z = a*(-2*c*x + 2*b*y) + 2*d*(b*x + c*y) + aa*z - (bb + cc - dd)*z
        };
    }

    pub fn rotateV(axis: Vector3f, theta: f32, v: Vector3f) Vector3f {
        const ax = axis.x;
        const ay = axis.y;
        const az = axis.z;
        const x = v.x;
        const y = v.y;
        const z = v.z;
        const c = std.math.cos(theta / 2.0);
        const s = std.math.sin(theta / 2.0);
        const cc = c*c;
        const ss = s*s;
        const axax = ax*ax;
        const ayay = ay*ay;
        const azaz = az*az;
        return Vector3f {
            .x = cc*x + 2*c*s*(-(az*y) + ay*z) + ss*(axax*x - (ayay + azaz)*x + 2*ax*(ay*y + az*z)),
            .y = cc*y - azaz*ss*y + s*(2*ax*ay*s*x - axax*s*y + ayay*s*y - 2*ax*c*z) + 2*az*s*(c*x + ay*s*z),
            .z = 2*s*(-(ay*c*x) + ax*az*s*x + ax*c*y + ay*az*s*y) + (cc - (axax + ayay - azaz)*ss)*z
        };
    }    

    pub fn rotateP(origin: Point3f, axis: Vector3f, theta: f32, p: Point3f) Point3f {
        const v = subtract(p, origin);  
        const w = rotateV(axis, theta, v);
        return Point3f {
            .x = origin.x + w.x,
            .y = origin.y + w.y,
            .z = origin.z + w.z
        };
    }

    pub fn rotateCsys(origin: Point3f, axis: Vector3f, theta: f32, csys: CSys) CSys {
        return CSys.initE1E2(
            Quaternion.rotateP(origin, axis, theta, csys.origin),
            Quaternion.rotateV(axis, theta, csys.e1),
            Quaternion.rotateV(axis, theta, csys.e2)
        );
    }
    
};

pub const Matrix4f = struct {
    data: [4][4]f32,

    pub fn initArray(array: [4][4]f32) Matrix4f {
        return Matrix4f{
            .data = array
        };
    }

    pub const zero = Matrix4f {
        .data = .{.{0.0} ** 4} ** 4
    };

    pub const identity = Matrix4f { 
        .data = [_][4]f32{
            .{1.0, 0.0, 0.0, 0.0},
            .{0.0, 1.0, 0.0, 0.0},
            .{0.0, 0.0, 1.0, 0.0},
            .{0.0, 0.0, 0.0, 1.0}
    }};
};

pub const CSys = struct {
    origin: Point3f,
    e1: Vector3f,
    e2: Vector3f,
    e3: Vector3f,

    pub fn init() CSys {
        return CSys {
            .origin = Point3f.zero,
            .e1 = Vector3f.unitX,
            .e2 = Vector3f.unitY,
            .e3 = Vector3f.unitZ 
        };
    }

    pub fn initE1E2(origin: Point3f, e1: Vector3f, e2: Vector3f) CSys {
        var e1n = normalise(e1);
        var e2n = normalise(e2);
        var e3n = cross(e1n, e2n);
        return CSys {
            .origin = origin,
            .e1 = e1n,
            .e2 = e2n,
            .e3 = e3n 
        };
    }

    pub fn initE1E3(origin: Point3f, e1: Vector3f, e3: Vector3f) CSys {
        var e1n = normalise(e1);
        var e3n = normalise(e3);
        var e2n = cross(e3n, e1n);
        return CSys {
            .origin = origin,
            .e1 = e1n,
            .e2 = e2n,
            .e3 = e3n 
        };
    }

};

fn is_vector(comptime T: type) bool {
    return T == Vector2f or T == Vector2i or T == Vector3f;
}

pub fn convert(comptime TO: type, obj: anytype) TO {
    const TI = @TypeOf(obj);
    if (TI == Vector2i and TO == Vector2f){
        return convertV2iV2f(obj);
    }
    @compileError("Unsupported conversion");
}

pub fn convertV2iV2f(v: Vector2i) Vector2f {
    return Vector2f {
        .x = @intToFloat(f32, v.i),
        .y = @intToFloat(f32, v.j)
    };
}

pub fn negate(v: Vector3f) Vector3f {
    return Vector3f.init(-v.x, -v.y, -v.z);
}

pub fn norm(v: anytype) f32 {        
    return std.math.sqrt(dot(v, v));
}

pub fn normalise(v: anytype) @TypeOf(v) {        
    return multiply(v, 1.0/norm(v));    
}

pub fn cross(a: Vector3f, b: Vector3f) Vector3f {
    return Vector3f.init(
        a.y * b.z - b.y * a.z,
        a.z * b.x - b.z * a.x,
        a.x * b.y - b.x * a.y
    );
}

pub fn dot(a: anytype, b: @TypeOf(a)) f32 {
    const T = @TypeOf(a);        
    if (T == Vector2f){
       return dotV2f(a, b);
    }else if (T == Vector3f){
        return dotV3f(a, b);
    }
    @compileError("Unsupported types for dot");
}

pub fn dotV2f(a: Vector2f, b: Vector2f) f32 {
     return a.x*b.x + a.y*b.y;
}

pub fn dotV3f(a: Vector3f, b: Vector3f) f32 {
     return a.x*b.x + a.y*b.y + a.z*b.z;
}

pub fn add(a: anytype, b: anytype) Add(@TypeOf(a), @TypeOf(b)) {
    const TA = @TypeOf(a);
    const TB = @TypeOf(b);
    if (TA == Vector3f and TB == Vector3f){
        return addV3fV3f(a, b);
    }else if (TA == Point3f and TB == Vector3f){
        return addP3fV3f(a, b);
    }else if (TA == Vector3f and TB == Point3f){
        return addP3fV3f(b, a);
    }
}

pub fn Add(TA: type, TB: type) type {
    if (TA == Vector3f and TB == Vector3f){
        return Vector3f;
    }else if ((TA == Vector3f and TB == Point3f) or (TB == Vector3f and TA == Point3f)){
        return Point3f;
    }
}

pub fn addV3fV3f(a: Vector3f, b: Vector3f) Vector3f {
    return Vector3f.init(
        a.x + b.x, 
        a.y + b.y, 
        a.z + b.z
    );
}

pub fn addP3fV3f(a: Point3f, b: Vector3f) Point3f {
    return Point3f.init(
        a.x + b.x, 
        a.y + b.y, 
        a.z + b.z
    );
}

pub fn subtract(a: anytype, b: @TypeOf(a)) Subtract(@TypeOf(a)) {
    const T = @TypeOf(a);    
    if (T == Point2i) {
        return subtractP2iP2i(a, b);
    }else if (T == Point3f) {
        return subtractP3fP3f(a, b);
    }else{
        @compileError("Unknown types for subtract");
    }
}

pub fn Subtract(comptime T: type) type {
    if (T == Point2i or T == Vector2i){
        return Vector2i;
    }else if (T == Point3f or T == Vector3f){
        return Vector3f;
    }else{
        @compileError("Unknown types for subtract");
    }        
}

pub fn subtractP2iP2i(a: Point2i, b: Point2i) Vector2i {
    return Vector2i.init(
        a.i - b.i,
        a.j - b.j
    );    
}

pub fn subtractP3fP3f(a: Point3f, b: Point3f) Vector3f {
    return Vector3f.init(
        a.x - b.x,
        a.y - b.y,
        a.z - b.z
    );
}

pub fn multiply(a: anytype, b: anytype) Multiply(@TypeOf(a), @TypeOf(b)) {
    const TA = @TypeOf(a);
    const TB = @TypeOf(b);
    if (TA == Matrix4f and TB == Matrix4f){
        return multiplyM4fM4f(a, b);
    }else if (TA == Vector2f and TB == f32){
        return multiplyV2ff32(a, b);
    }else if (TA == f32 and TB == Vector2f){
        return multiplyV2ff32(b, a);
    }else if (TA == Vector3f and TB == f32){
        return multiplyV3ff32(a, b);
    }else if (TA == f32 and TB == Vector3f){
        return multiplyV3ff32(b, a);
    }
    @compileError("Unsupported types for multiply");
}

pub fn Multiply(TA: type, TB: type) type {
    if (TA == Matrix4f and TB == Matrix4f){
        return Matrix4f;
    }else if ((TA == Vector2f and TB == f32) or (TA == f32 and TB == Vector2f)){
        return Vector2f;
    }else if ((TA == Vector3f and TB == f32) or (TA == f32 and TB == Vector3f)){
        return Vector3f;
    }
    @compileError("Unsupported types for multiply");
}

pub fn multiplyV2ff32(v: Vector2f, s: f32) Vector2f {
    return Vector2f {
        .x = v.x * s,
        .y = v.y * s
    };
}

pub fn multiplyV3ff32(v: Vector3f, s: f32) Vector3f {
    return Vector3f {
        .x = v.x * s,
        .y = v.y * s,
        .z = v.z * s
    };
}

pub fn multiplyM4fM4f(matA: Matrix4f, matB: Matrix4f) Matrix4f {
    var result = Matrix4f.zero;
    
    var r = &result.data;
    var mA = matA.data;
    var mB = matB.data;

    {var i: u32 = 0; while (i < 4) : (i += 1){        
        var j: u32 = 0; while (j < 4) : (j += 1){            
            var k: u32 = 0; while (k < 4) : (k += 1){
                (r.*)[i][j] += mA[i][k] * mB[k][j];
            }
        }
    }}

    return result;
}

pub fn transform(mat: Matrix4f, entity: anytype) @TypeOf(entity){    
    const T = @TypeOf(entity);
    if (T == Point3f){
        return transformPoint3f(mat, entity);
    }else if (T == Vector3f){
        return transformVector3f(mat, entity);
    }else{
        @compileError("Unsupported types for multiply");
    }
}

pub fn transformPoint3f(mat: Matrix4f, point: Point3f) Point3f {
    var result = Point3f.zero;

    var p = point.asConstSlice();
    var r = result.asSlice();    
    var m = mat.data;

    // get w component
    var w = m[3][3];
    {var j: u32 = 0; while (j < 3) : (j += 1){
        w += m[3][j] * p[j];
    }}

    // multiply out and scale by w to get equivalent Euclidean point
    {var i: u32 = 0; while (i < 3) : (i += 1){
        r[i] = m[i][3];
        {var j: u32 = 0; while (j < 3) : (j +=1){
            r[i] += m[i][j] * p[j];
        }}
        r[i] /= w;
    }}

    return result;
}

pub fn transformVector3f(mat: Matrix4f, vector: Vector3f) Vector3f {    
    var result = Vector3f.zero;

    var v = vector.asConstSlice();
    var r = result.asSlice();
    var m = mat.data;

    {var i: u32 = 0; while (i < 3):(i += 1){
        {var j: u32 = 0; while (j < 3):(j += 1){
            r[i] += m[i][j] * v[j];            
        }}
    }}
    return result;
}

pub fn globalToLocalTransform(o: Point3f, e1: Vector3f, e2: Vector3f, e3: Vector3f) Matrix4f {    
    return Matrix4f.initArray(.{
        .{e1.x, e1.y, e1.z, -(e1.x*o.x + e1.y*o.y + e1.z*o.z)},
        .{e2.x, e2.y, e2.z, -(e2.x*o.x + e2.y*o.y + e2.z*o.z)},
        .{e3.x, e3.y, e3.z, -(e3.x*o.x + e3.y*o.y + e3.z*o.z)},
        .{0, 0, 0, 1}
    });
}


/// Maps truncated pyramid from camera space to normalised cube coordinates
///     l: left coordinate of frustrum at near plane (maps to x = -1)
///     r: right coordinate of frustrum at near plane (maps to x = 1)
///     b: bottom coordinate of frustrum at near plane (maps to y = -1)
///     t: top coordinate of frustrum at near plane (maps to y = 1)
///     n: distance to near plane (positive number, near plane maps to -1)
///     f: distance to far plane (positive number, far plane maps to 1)
/// View space is right-handed while resulting cube is left-handed
pub fn projectionTransform(l: f32, r: f32, b: f32, t: f32, n: f32, f: f32) Matrix4f {
    var dXdXc: f32 = 2 * n / (r - l);
    var dXdZc: f32 = (r + l) / (r - l);
    var dYdYc: f32 = 2 * n / (t - b);
    var dYdZc: f32 = (t + b) / (t - b);
    var dZdZc: f32 = -(f + n) / (f - n);
    var dZdWc: f32 = -(2 * f * n) / (f - n);
    var dWdZc: f32 = -1;
    return Matrix4f.initArray(.{
        .{dXdXc, 0, dXdZc, 0},
        .{0, dYdYc, dYdZc, 0},
        .{0, 0, dZdZc, dZdWc},
        .{0, 0, dWdZc, 0}
    });
}


test "vector3 create calc norm" {
    var v = Vector3f.init(1, 2, 3);    
    var n = norm(v);
    var actual: f32 = std.math.sqrt(1.0*1.0 + 2.0*2.0 + 3.0*3.0);
    try std.testing.expectApproxEqAbs(actual, n, 1e-6);
}

test "matrix4f from array" {
    var m = Matrix4f.initArray(
        .{
            [_]f32{1.0, 0.0, 0.0, 0.0},
            [_]f32{0.0, 1.0, 0.0, 0.0},
            [_]f32{0.0, 0.0, 1.0, 0.0},
            [_]f32{0.0, 0.0, 0.0, 1.0}
        }
    );
    try std.testing.expect(m.data[0] == 1.0);
    try std.testing.expect(m.data[4] == 0.0);
    try std.testing.expect(m.data[5] == 1.0);
    try std.testing.expect(m.data[14] == 0.0);
    try std.testing.expect(m.data[15] == 1.0);
}

test "cross product" {
    var a = Vector3f.init(0.0, 0.0, 1.0);
    var b = Vector3f.init(1.0, 0.0, 0.0);
    var c = cross(a, b);    
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), c.x, 1e-10);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), c.y, 1e-10);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), c.z, 1e-10);
}

test "dot product" {
    var a = Vector3f.init(1.0, 2.0, 3.0);
    var b = Vector3f.init(5.0, 6.0, 7.0);
    var expected: f32 = 5.0 + 12.0 + 21.0;
    try std.testing.expectApproxEqAbs(expected, dot(a, b), 1e-6);
}

test "vector subtract" {
    var p1 = Point3f.init(1.0, 2.0, 3.0);
    var p2 = Point3f.init(9.0, 7.0, 5.0);
    var v = subtract(p2, p1);
    try std.testing.expectApproxEqAbs(@as(f32, 8), v.x, 1e-6);
    try std.testing.expectApproxEqAbs(@as(f32, 5), v.y, 1e-6);
    try std.testing.expectApproxEqAbs(@as(f32, 2), v.z, 1e-6);
}

test "matrix multiply" {
    var m1 = Matrix4f.initArray(.{
        .{1.0, 2.0, 3.0, 4.0},
        .{5.0, 6.0, -7.0, 8.0},
        .{-9.0, 10.0, 11.0, 12.0},
        .{13.0, -14.0, 15.0, 16.0}
    });
    var m2 = Matrix4f.initArray(.{
        .{3.0, 1.0, 4.0, 3.0},
        .{6.0, 5.0, 8.0, -7.0},
        .{10.0, 11.0, 9.0, 12.0},
        .{16.0, 15.0, -14.0, 13.0}
    });   
    var m3 = multiply(m1, m2);

    var expected = [_][4]f32{
        .{109.0,  104.0,   -9.0,   77.0},
        .{109.0,   78.0, -107.0,   -7.0},
        .{335.0,  342.0,  -25.0,  191.0},
        .{361.0,  348.0, -149.0,  525.0}
    };

    for (expected) |_, i| {
        var valActual = m3.data[i];
        var valExpected = expected[i];
        try std.testing.expectApproxEqAbs(valExpected, valActual, 1e-6);
    }

}