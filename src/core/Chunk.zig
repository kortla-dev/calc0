const std = @import("std");
const mem = std.mem;

const ArrayList = std.ArrayList;

const core = @import("core.zig");
const OpCode = core.OpCode;

const Chunk = @This();

gpa: *const mem.Allocator,
instructions: ArrayList(u8),
value_pool: ArrayList(f64),

pub fn init(gpa: *const mem.Allocator) Chunk {
    return Chunk{
        .gpa = gpa,
        .instructions = .empty,
        .value_pool = .empty,
    };
}

pub fn deinit(self: *Chunk) void {
    self.instructions.deinit(self.gpa.*);
    self.value_pool.deinit(self.gpa.*);
}

pub fn write(self: *Chunk, byte: u8) !void {
    try self.instructions.append(self.gpa.*, byte);
}

pub fn writeToValuePool(self: *Chunk, value: f64) usize {
    const value_index: usize = self.addToValuePool(value) catch {
        @panic("Failed to write to value_pool.");
    };

    return value_index;
}

pub fn addToValuePool(self: *Chunk, value: f64) !usize {
    try self.value_pool.append(self.gpa.*, value);
    return self.value_pool.items.len - 1;
}
