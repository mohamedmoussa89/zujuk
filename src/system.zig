const std = @import("std");
const gl = @import("gl.zig");
const glfw = @import("glfw");


pub const Window = struct {
    const Self = @This();

    pub const Data = struct {
        allocator: std.mem.Allocator,
        glfwWindow: glfw.Window,
        eventQueue: EventQueue,   
    };
    
    data: *Data,

    pub fn init(allocator: std.mem.Allocator, width: u32, height: u32, title: []const u8) !Self {              
        try glfw.init(.{});

        var hints = .{
            .context_version_major = 4, 
            .context_version_minor = 3, 
            .resizable = false
        };
        
        var titleS = try allocator.alloc(u8, title.len + 1);
        defer allocator.free(titleS);
        std.mem.copy(u8, titleS, title);
        titleS[title.len] = 0;
        
        var glfwWindow = try glfw.Window.create(width, height, titleS[0..title.len:0], null, null, hints);
        var eventQueue = try EventQueue.init(allocator, 32);        

        var data = try allocator.create(Window.Data);
        data.allocator = allocator;        
        data.glfwWindow = glfwWindow;
        data.eventQueue = eventQueue;
        
        try glfw.makeContextCurrent(data.*.glfwWindow);
        const proc: glfw.GLProc = undefined;
        try gl.load(proc, glGetProcAddress);
        gl.enable(gl.DEBUG_OUTPUT);        

        // callbacks can retrieve the data struct        
        glfwWindow.setUserPointer(@ptrCast(*anyopaque, data));

        // hook GLFW event callbacks
        glfwWindow.setKeyCallback(EventQueue.enqueueKeyEvent);
        glfwWindow.setMouseButtonCallback(EventQueue.enqueueMouseEvent);

        return Window {
            .data = data
        };
    }

    fn glGetProcAddress(p: glfw.GLProc, proc: [:0]const u8) ?*const anyopaque {
        _ = p;
        return glfw.getProcAddress(proc);
    }

    pub fn deinit(self: Self) void {        
        var allocator = self.data.*.allocator;
        self.data.*.glfwWindow.destroy();        
        allocator.destroy(self.data);
        glfw.terminate();
    }

    pub fn shouldClose(self: Self) bool {
        return self.data.*.glfwWindow.shouldClose();
    }

    pub fn swapBuffers(self: Self) !void {
        return self.data.*.glfwWindow.swapBuffers();
    }

    pub fn getSize(self: Self) u32 {
        return self.*.data.glfwWindow.getSize();
    }    

};

pub const EventType = enum(u8) {
    keyEvent,
    mouseEvent
};

pub const Event = union(EventType){
    keyEvent: KeyEvent,
    mouseEvent: MouseEvent
};

pub const KeyEvent = struct {        
    key: glfw.Key,
    scanCode: i32,
    action: glfw.Action,
    mods: glfw.Mods
};   

pub const MouseEvent = struct {
    button: glfw.MouseButton, 
    action: glfw.Action, 
    mods: glfw.Mods
};


/// Ring buffer for storing events collected by GLFW 
/// Tightly coupled with Window/GLFW Window 
pub const EventQueue = struct {

    const Self = @This();

    pub const Errors = error {
        QueueIsEmpty,
    };

    allocator: std.mem.Allocator,    
    queue: []Event,                 // ring buffer    
    first: usize,
    count: usize,    

    pub fn init(allocator: std.mem.Allocator, capacity: u32) !EventQueue {
        var queue = try allocator.alloc(Event, capacity);
        var eventQueue = Self {
            .allocator = allocator,
            .queue = queue,
            .first = 0,
            .count = 0,
        };
        return eventQueue;
    }

    pub fn deinit(self: Self) !void {
        self.allocator.free(self.queue);
    }

    pub fn len(self: Self) usize {
        return self.count;
    }

    pub fn dequeue(self: *Self) !Event {
        if (self.count > 0){
            var event = self.queue[self.first];            
            self.first = (self.first + 1) % self.queue.len;            
            self.count -= 1;
            return event;
        }else{
            return Errors.QueueIsEmpty;
        }        
    }

    fn enqueueEvent(glfwWindow: glfw.Window, event: Event) void {
        // need to grab event queue from window user data
        var data = glfwWindow.getUserPointer(Window.Data) orelse return;                
        var self = &(data.*.eventQueue);

        // if full, stop writing events till old are processed 
        if (self.count < self.queue.len){
            var next = (self.first + self.count) % self.queue.len;
            self.count += 1;
            self.queue[next] = event;        
        }        
    }

    pub fn enqueueKeyEvent(glfwWindow: glfw.Window, key: glfw.Key, scanCode: i32, action: glfw.Action, mods: glfw.Mods) void {                                
        EventQueue.enqueueEvent( 
            glfwWindow,
            Event {
                .keyEvent = KeyEvent {
                .key = key,
                .scanCode = scanCode,
                .action = action,
                .mods = mods
            }
        });    
    }

    pub fn enqueueMouseEvent(glfwWindow: glfw.Window, button: glfw.MouseButton, action: glfw.Action, mods: glfw.Mods) void {           
        EventQueue.enqueueEvent( 
            glfwWindow,
            Event {
                .mouseEvent = MouseEvent {
                .button = button,                
                .action = action,
                .mods = mods
            }
        });                    
    }

};

pub const TimeAccumulator = struct {    
    timer: std.time.Timer,
    lastReadNs: u64,
    accumulatedNs: u64,

    pub fn init() !TimeAccumulator {
        var timer = try std.time.Timer.start();
        return TimeAccumulator {
            .timer = timer,
            .lastReadNs = timer.read(),
            .accumulatedNs = 0,
        };        
    }

    pub fn consume(self: *TimeAccumulator, consumeMs: u64) bool {
        const consumeNs = consumeMs * std.time.ns_per_ms;     

        const currentReadNs = self.timer.read();
        self.accumulatedNs += currentReadNs - self.lastReadNs;
        self.lastReadNs = currentReadNs;

        if (self.accumulatedNs >= consumeNs){
            self.accumulatedNs -= consumeNs;
            return true;
        }else{
            return false;
        }
    }

    pub fn consumeAtleast(self: *TimeAccumulator, consumeMs: u64) u64 {
        const consumeNs = consumeMs * std.time.ns_per_ms;     

        const currentReadNs = self.timer.read();
        self.accumulatedNs += currentReadNs - self.lastReadNs;
        self.lastReadNs = currentReadNs;

        if (self.accumulatedNs >= consumeNs){
            var consumed: u64 = 0;
            while (self.accumulatedNs >= consumeNs){
                consumed += consumeMs;
                self.accumulatedNs -= consumeNs;
            }            
            return consumed;
        }else{
            return 0;
        }
    }
};

test "event queue" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    
    var window = try Window.init(allocator, 100, 100, "");
        
    EventQueue.enqueueKeyEvent(window.data.glfwWindow, glfw.Key.a, try glfw.Key.getScancode(glfw.Key.a), glfw.Action.press, glfw.Mods {});
    EventQueue.enqueueKeyEvent(window.data.glfwWindow, glfw.Key.b, try glfw.Key.getScancode(glfw.Key.b), glfw.Action.press, glfw.Mods {});
    EventQueue.enqueueKeyEvent(window.data.glfwWindow, glfw.Key.c, try glfw.Key.getScancode(glfw.Key.c), glfw.Action.press, glfw.Mods {});
    EventQueue.enqueueKeyEvent(window.data.glfwWindow, glfw.Key.d, try glfw.Key.getScancode(glfw.Key.d), glfw.Action.press, glfw.Mods {});
    EventQueue.enqueueKeyEvent(window.data.glfwWindow, glfw.Key.e, try glfw.Key.getScancode(glfw.Key.e), glfw.Action.press, glfw.Mods {});
    EventQueue.enqueueKeyEvent(window.data.glfwWindow, glfw.Key.f, try glfw.Key.getScancode(glfw.Key.f), glfw.Action.press, glfw.Mods {});
    EventQueue.enqueueKeyEvent(window.data.glfwWindow, glfw.Key.g, try glfw.Key.getScancode(glfw.Key.g), glfw.Action.press, glfw.Mods {});
    EventQueue.enqueueKeyEvent(window.data.glfwWindow, glfw.Key.h, try glfw.Key.getScancode(glfw.Key.h), glfw.Action.press, glfw.Mods {});

    var eventQueue = &window.data.eventQueue;
    var event1 = try eventQueue.dequeue();
    var event2 = try eventQueue.dequeue();
    
    try std.testing.expect(event1.keyEvent.key == glfw.Key.a);
    try std.testing.expect(event2.keyEvent.key == glfw.Key.b);
    try std.testing.expect(eventQueue.count == 0);
}