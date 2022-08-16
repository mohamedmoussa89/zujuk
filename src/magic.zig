
// see https://www.youtube.com/watch?v=nXaxk27zwlk&t=2446s
// used to pin things down so they don't get optimised away 

pub inline fn escape(obj: anytype) void {
    // comptime assert(@typeInfo(@TypeOf(ptr)) == .Pointer);        
    var ptr = @ptrCast(*const anyopaque, &obj);
    asm volatile ("" : : [g]""(&ptr) : "memory");
}

pub inline fn clobber() void {
    asm volatile ("" : : : "memory");
}