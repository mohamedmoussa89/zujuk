const std = @import("std");

const Double3 = struct {
    x: f32,
    y: f32,
    z: f32    
};

fn asArray(x: Double3) [3]f32 {
    return @bitCast([3]f32, x);
}

fn asSlice(x: *Double3) []f32 {
    return (@ptrCast(*[3]f32, x).*)[0..3];
}

test "cast to array" {
    var x = Double3 {.x = 1, .y = 2, .z = 3};
    var y = asArray(x);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), y[0], 1e-6);
    try std.testing.expectApproxEqAbs(@as(f32, 2.0), y[1], 1e-6);
    try std.testing.expectApproxEqAbs(@as(f32, 3.0), y[2], 1e-6);

    y[0] = 5.0;
    y[1] = 6.0;
    y[2] = 7.0;
    try std.testing.expectApproxEqAbs(@as(f32, 5.0), x.x, 1e-6);
    try std.testing.expectApproxEqAbs(@as(f32, 6.0), x.y, 1e-6);
    try std.testing.expectApproxEqAbs(@as(f32, 7.0), x.z, 1e-6);
}
