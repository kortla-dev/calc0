const std = @import("std");

const core = @import("core.zig");
const Chunk = core.Chunk;
const Cursor = core.Cursor;
const OpCode = core.OpCode;
const Token = core.Token;

// ----- IO

var stdout_writer: std.fs.File.Writer = undefined;
var stderr_writer: std.fs.File.Writer = undefined;

const stdout: *std.Io.Writer = &stdout_writer.interface;
const stderr: *std.Io.Writer = &stderr_writer.interface;

const Precedence = enum(u8) {
    none,
    init,
    term,
    factor,
    unary,
    exponent,
};

const Associativity = enum {
    left,
    right,
};

const ParseFn = *const fn (*Compiler) void;

// TODO: add new field for associativity default left
const ParseRule = struct {
    prefix: ?ParseFn = null,
    infix: ?ParseFn = null,
    precedence: Precedence = .none,
    associativity: Associativity = .left,
};

const Compiler = @This();

const U8_MAX = std.math.maxInt(u8);

const rules = blk: {
    var array = std.EnumArray(Token.Type, ParseRule).initUndefined();

    // .none
    array.set(.number, .{ .prefix = Compiler.number });
    array.set(.left_paren, .{ .prefix = Compiler.grouping });
    array.set(.right_paren, .{});
    array.set(.eof, .{});

    // .term
    array.set(.plus, .{ .infix = Compiler.binary, .precedence = .term });
    array.set(.dash, .{ .prefix = Compiler.unary, .infix = Compiler.binary, .precedence = .term });

    // .factor
    array.set(.asterisk, .{ .infix = Compiler.binary, .precedence = .factor });
    array.set(.forward_slash, .{ .infix = Compiler.binary, .precedence = .factor });

    // .exponent
    array.set(.caret, .{ .infix = Compiler.binary, .precedence = .exponent, .associativity = .right });

    break :blk array;
};

cursor: Cursor,
curr_tkn: Token = undefined,
prev_tkn: Token = undefined,
compiling_chunk: *Chunk,

pub fn init(source: []const u8, chunk: *Chunk) Compiler {
    stdout_writer = std.fs.File.stdout().writer(&.{});
    stderr_writer = std.fs.File.stderr().writer(&.{});

    return Compiler{
        .cursor = Cursor.init(source),
        .compiling_chunk = chunk,
        .curr_tkn = undefined,
        .prev_tkn = undefined,
    };
}

pub fn compile(self: *Compiler) bool {
    self.advance(); // we prime the token stream
    self.expression();
    self.consume(.eof, "Expected end of expression.");
    self.emitByte(OpCode.byte(.@"return"));

    // TODO: make had_error field and return !self.had_error;
    return true;
}

fn advance(self: *Compiler) void {
    self.prev_tkn = self.curr_tkn;

    self.curr_tkn = self.cursor.nextToken();

    if (self.curr_tkn.type != .@"error") return;

    // TODO: error message generator
    @panic("error");
}

fn consume(self: *Compiler, expect: Token.Type, message: []const u8) void {
    if (self.curr_tkn.type == expect) {
        self.advance();
        return;
    }

    @panic(message);
}

// Compiling instructions

fn emitByte(self: *Compiler, byte: u8) void {
    self.compiling_chunk.write(byte) catch |err| {
        @panic(@errorName(err));
    };
}

fn emitBytes(self: *Compiler, bytes: []const u8) void {
    for (bytes) |byte| self.emitByte(byte);
}

fn emitValue(self: *Compiler, value: f64) void {
    const value_idx: usize = self.compiling_chunk.writeToValuePool(value);

    if (value_idx > Compiler.U8_MAX) {
        @panic("Too many values in one chunk");
        // return 0;
    }

    self.emitBytes(&.{
        OpCode.byte(.push),
        @as(u8, @truncate(value_idx)),
    });
}

// Expression parsing

fn assocBool(
    self: *Compiler,
    precedence: Precedence,
    associativity: Associativity,
) bool {
    const curr_prec = @intFromEnum(precedence);
    const next_prec = @intFromEnum(Compiler.rules.get(self.curr_tkn.type).precedence);

    return switch (associativity) {
        .left => curr_prec < next_prec,
        .right => curr_prec <= next_prec,
    };
}

fn parsePrecedence(
    self: *Compiler,
    precedence: Precedence,
    associativity: Associativity,
) void {
    self.advance();

    const prev_tkn_prefix_rule = Compiler.rules.get(self.prev_tkn.type).prefix;

    if (prev_tkn_prefix_rule) |rule| {
        rule(self);
    } else {
        @panic("Expected expression.");
        // return;
    }

    var assoc_bool = self.assocBool(precedence, associativity);
    while (assoc_bool) : (assoc_bool = self.assocBool(precedence, associativity)) {
        self.advance();

        // NOTE: either make a precedence level for the first expression call or check if token type is .eof
        // if (self.prev_tkn.type == .eof) break;

        const prev_tkn_infix_rule = Compiler.rules.get(self.prev_tkn.type).infix;

        prev_tkn_infix_rule.?(self);
    }
}

fn expression(self: *Compiler) void {
    self.parsePrecedence(.init, .left);
}

fn grouping(self: *Compiler) void {
    self.expression();
    self.consume(.right_paren, "Expected a closing ')' after expression.");
}

fn number(self: *Compiler) void {
    const value = std.fmt.parseFloat(f64, self.prev_tkn.literal) catch |err| {
        @panic(@errorName(err));
    };

    self.emitValue(value);
}

fn binary(self: *Compiler) void {
    const operand_type: Token.Type = self.prev_tkn.type;
    const operand_rule: ParseRule = Compiler.rules.get(operand_type);
    self.parsePrecedence(operand_rule.precedence, operand_rule.associativity);

    const operand_opcode: OpCode = switch (operand_type) {
        .plus => .add,
        .dash => .subtract,
        .asterisk => .multiply,
        .forward_slash => .divide,
        .caret => .exponentiate,
        else => unreachable,
    };

    self.emitByte(OpCode.byte(operand_opcode));
}

fn unary(self: *Compiler) void {
    const op_type: Token.Type = self.prev_tkn.type;

    self.parsePrecedence(.unary, .left);

    switch (op_type) {
        .dash => self.emitByte(OpCode.byte(.negate)),
        else => unreachable,
    }
}

// ------------------
