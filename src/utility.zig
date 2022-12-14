const std = @import("std");

/// Used to prevent optimiser from stripping this object away
/// See https://www.youtube.com/watch?v=nXaxk27zwlk&t=2446s
pub inline fn escape(obj: anytype) void {
    // comptime assert(@typeInfo(@TypeOf(ptr)) == .Pointer);        
    var ptr = @ptrCast(*const anyopaque, &obj);
    asm volatile ("" : : [g]""(&ptr) : "memory");
}

/// No-op read and write to all memory
/// See https://www.youtube.com/watch?v=nXaxk27zwlk&t=2446s
pub inline fn clobber() void {
    asm volatile ("" : : : "memory");
}

/// Converts a struct of uniform type to slice of that type
pub inline fn asSlice(comptime T: type, x: anytype) []T {        
    return std.mem.bytesAsSlice(T, std.mem.asBytes(x));
}

/// Converts a struct of uniform type to const slice of that type
pub inline fn asConstSlice(comptime T: type, x: anytype) []const T {    
    return std.mem.bytesAsSlice(T, std.mem.asBytes(x));
}