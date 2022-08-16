const std = @import("std");

// used to pin things down so they don't get optimised away 
// see https://www.youtube.com/watch?v=nXaxk27zwlk&t=2446s

pub inline fn escape(obj: anytype) void {
    // comptime assert(@typeInfo(@TypeOf(ptr)) == .Pointer);        
    var ptr = @ptrCast(*const anyopaque, &obj);
    asm volatile ("" : : [g]""(&ptr) : "memory");
}

pub inline fn clobber() void {
    asm volatile ("" : : : "memory");
}

// convert struct of uniform type to slices

pub inline fn asSlice(comptime T: type, x: anytype) []T {        
    return std.mem.bytesAsSlice(T, std.mem.asBytes(x));
}

pub inline fn asConstSlice(comptime T: type, x: anytype) []const T {    
    return std.mem.bytesAsSlice(T, std.mem.asBytes(x));
}