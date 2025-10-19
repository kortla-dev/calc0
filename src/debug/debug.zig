const std = @import("std");

const core = @import("../core/core.zig");
const Chunk = core.Chunk;
const OpCode = core.OpCode;

pub fn disassembleChunk(chunk: *Chunk, name: []const u8) void {
    std.debug.print("== {s} ==\n", .{name});

    var offset: usize = 0;
    while (offset < chunk.instructions.items.len) {
        offset = disassembleInstruction(chunk, offset);
    }
}

fn simpleInstruction(name: []const u8, offset: usize) usize {
    std.debug.print("{s}\n", .{name});

    return offset + 1;
}

fn constantInstruction(chunk: *Chunk, offset: usize) usize {
    const index = chunk.instructions.items[offset + 1];
    std.debug.print("{s:<16} {d:0>4} '{d}'\n", .{
        "op_constant",
        index,
        chunk.value_pool.items[index],
    });

    return offset + 2;
}

pub fn disassembleInstruction(chunk: *Chunk, offset: usize) usize {
    std.debug.print("{d:0>4} ", .{offset});

    // if (offset > 0 and (chunk.lines.items[offset] == chunk.lines.items[offset - 1])) {
    std.debug.print("   | ", .{});
    // } else {
    // std.debug.print("{d:4} ", .{chunk.lines.items[offset]});
    // }

    const instruction: OpCode = @enumFromInt(chunk.instructions.items[offset]);

    return switch (instruction) {
        .push => constantInstruction(chunk, offset),
        .negate,
        .add,
        .subtract,
        .multiply,
        .divide,
        .exponentiate,
        .@"return",
        => simpleInstruction(@tagName(instruction), offset),
        // else => {
        //     std.debug.print("Unknown opcode{d}\n", .{chunk.instructions.items[offset]});
        //     return offset + 1;
        // },
    };
}
