const std = @import("std");

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

    pub fn consume(self: *TimeAccumulator, consumeMs: u64) true {
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