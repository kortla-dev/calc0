const std = @import("std");
const mem = std.mem;

const common = @import("common.zig");
const debug = @import("../debug/debug.zig");

const core = @import("core.zig");
const Chunk = core.Chunk;
const Compiler = core.Compiler;
const OpCode = core.OpCode;

var stdout_writer = std.fs.File.stdout().writer(&.{});
var stderr_writer = std.fs.File.stderr().writer(&.{});

const stdout = &stdout_writer.interface;
const stderr = &stderr_writer.interface;

const VM = @This();

pub const InterpretResult = error{
    Comptime,
};

stack: struct {
    items: [256]f64 = [_]f64{0} ** 256,
    top: usize = 0,

    pub fn push(self: *@This(), value: f64) void {
        self.items[self.top] = value;
        self.top += 1;
    }

    pub fn pop(self: *@This()) f64 {
        self.top -= 1;
        return self.items[self.top];
    }
},
chunk: *Chunk,
ip: [*]u8,

pub fn init(chunk: *Chunk) VM {
    return VM{
        .stack = .{},
        .chunk = chunk,
        .ip = chunk.instructions.items.ptr,
    };
}

fn readByte(self: *VM) u8 {
    const retval = self.ip[0];
    self.ip += 1;

    return retval;
}

fn readValue(self: *VM) f64 {
    return self.chunk.value_pool.items[self.readByte()];
}

fn binaryOp(self: *VM, operand_opcode: OpCode) void {
    const b = self.stack.pop();
    const a = self.stack.pop();

    const result = switch (operand_opcode) {
        .add => a + b,
        .subtract => a - b,
        .multiply => a * b,
        .divide => a / b,
        .exponentiate => std.math.pow(f64, a, b),
        else => unreachable,
    };

    self.stack.push(result);
}

fn run(self: *VM) void {
    while (true) {
        if (common.DEBUG_TRACE_EXECUTION_FLAG) {
            self.printStack();
            _ = debug.disassembleInstruction(
                self.chunk,
                @as(usize, @intFromPtr(self.ip) - @intFromPtr(self.chunk.instructions.items.ptr)),
            );
        }

        const instruction: OpCode = @enumFromInt(self.readByte());

        switch (instruction) {
            .push => {
                const value: f64 = self.readValue();
                self.stack.push(value);
            },

            .add,
            .subtract,
            .multiply,
            .divide,
            .exponentiate,
            => self.binaryOp(instruction),

            .negate => self.stack.push(-self.stack.pop()),
            .@"return" => {
                std.debug.print("retval: {d}\n", .{self.stack.pop()});
                break;
            },
            // else => @panic("not implemented"),
        }
    }
}

fn printStack(self: *VM) void {
    _ = stdout.write("\x1b[38;2;255;191;0mStack ") catch unreachable;

    var idx: usize = 0;
    while (idx < self.stack.top) : (idx += 1) {
        stdout.print("[ {d} ]", .{self.stack.items[idx]}) catch unreachable;
    }

    _ = stdout.write("\x1b[0m\n") catch unreachable;
    stdout.flush() catch unreachable;
}

pub fn interpret(gpa: *const mem.Allocator, source: []const u8) error{Comptime}!void {
    var chunk = Chunk.init(gpa);
    defer chunk.deinit();

    var compiler = Compiler.init(source, &chunk);

    if (!compiler.compile()) {
        return error.Comptime;
    }

    debug.disassembleChunk(&chunk, "test chunk");

    var vm = VM.init(&chunk);
    vm.run();
}
