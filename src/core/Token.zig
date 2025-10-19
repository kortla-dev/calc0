const std = @import("std");

const Token = @This();

type: Token.Type,
literal: []const u8,

pub const Type = enum {
    number,
    plus,
    dash,
    forward_slash,
    asterisk,
    left_paren,
    right_paren,
    caret,
    @"error",
    eof,
};

pub fn format(
    self: @This(),
    writer: *std.Io.Writer,
) std.Io.Writer.Error!void {
    try writer.print("Token(.{s}, \"{s}\")", .{ @tagName(self.type), self.literal });
}
