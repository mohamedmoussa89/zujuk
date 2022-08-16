const std = @import("std");

const Double3 = struct {
    x: f32,
    y: f32,
    z: f32    
};

const PackedDouble3 = extern struct {
    x: f32,
    y: f32,
    z: f32 
};

fn asArray(x: Double3) [3]f32 {
    return @bitCast([3]f32, x);
}

fn asSlice(x: *Double3) []f32 {
    //return (@ptrCast(*[3]f32, x).*)[0..3];
    var byteSlice = std.mem.asBytes(x);
    return std.mem.bytesAsSlice(f32, byteSlice);
}

fn asConstSlice(x: *const Double3) []const f32 {
    //return (@ptrCast(*[3]f32, x).*)[0..3];
    var byteSlice = std.mem.asBytes(x);
    return std.mem.bytesAsSlice(f32, byteSlice);
}

fn sum(x: Double3) f32 {
    var xSlice = asConstSlice(&x);
    return xSlice[0] + xSlice[1] + xSlice[2];
}

test "cast to array" {
    //var xp: PackedDouble3 align(4) = PackedDouble3 {.x = 1, .y = 2, .z = 3};
    @compileLog("@alignOf(Double3) = ", @alignOf(Double3));
    @compileLog("@allignOf(PackedDouble3) = ", @alignOf(PackedDouble3));

    var x = Double3 {.x = 1, .y = 2, .z = 3};
    var y = asSlice(&x);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), y[0], 1e-6);
    try std.testing.expectApproxEqAbs(@as(f32, 2.0), y[1], 1e-6);
    try std.testing.expectApproxEqAbs(@as(f32, 3.0), y[2], 1e-6);

    y[0] = 5.0;
    y[1] = 6.0;
    y[2] = 7.0;
    try std.testing.expectApproxEqAbs(@as(f32, 5.0), x.x, 1e-6);
    try std.testing.expectApproxEqAbs(@as(f32, 6.0), x.y, 1e-6);
    try std.testing.expectApproxEqAbs(@as(f32, 7.0), x.z, 1e-6);

    var totalSum = sum(x);
    try std.testing.expectApproxEqAbs(@as(f32, 18.0), totalSum, 1e-6);
}
