const std = @import("std");
const util = @import("utility.zig");

const Vector2i = struct {
    data: [2]u32,

    pub fn i(self: Vector2i) u32 {
        return self.data[0];
    }

    pub fn j(self: Vector2i) u32 {
        return self.data[1];
    }    
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

pub fn negate(v: Vector3f) Vector3f {
    return Vector3f.init(-v.x, -v.y, -v.z);
}

pub fn norm2(v: Vector3f) f32{  
    return std.math.sqrt(dot(v, v));
}

pub fn normalise(v: Vector3f) Vector3f {
    var norm = norm2(v);
    return Vector3f.init(v.x/norm, v.y/norm, v.z/norm);
}

pub fn cross(a: Vector3f, b: Vector3f) Vector3f {
    return Vector3f.init(
        a.y * b.z - b.y * a.z,
        a.z * b.x - b.z * a.x,
        a.x * b.y - b.x * a.y
    );
}

pub fn dot(a: Vector3f, b: Vector3f) f32 {
    return a.x*b.x + a.y*b.y + a.z*b.z;
}

pub fn subtract(a: Point3f, b: Point3f) Vector3f {
    return Vector3f.init(
        a.x - b.x,
        a.y - b.y,
        a.z - b.z
    );
}

pub fn multiply(matA: Matrix4f, matB: Matrix4f) Matrix4f{
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
    var norm = norm2(v);
    var actual: f32 = std.math.sqrt(1.0*1.0 + 2.0*2.0 + 3.0*3.0);
    try std.testing.expectApproxEqAbs(actual, norm, 1e-6);
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