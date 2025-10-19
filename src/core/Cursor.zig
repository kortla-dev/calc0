const std = @import("std");

const core = @import("core.zig");
const Token = core.Token;

const Cursor = @This();

source: []const u8,
start: usize,
current: usize,

pub fn init(source: []const u8) Cursor {
    return Cursor{
        .source = source,
        .start = 0,
        .current = 0,
    };
}

fn makeToken(self: *Cursor, @"type": Token.Type) Token {
    return Token{
        .type = @"type",
        .literal = self.source[self.start..self.current],
    };
}

fn makeNumberToken(self: *Cursor) Token {
    while (isDigit(self.peek())) self.advance();

    if (self.peek() == '.' and isDigit(self.peekNext())) {
        self.advance();

        while (isDigit(self.peek())) self.advance();
    }

    return self.makeToken(.number);
}

fn makeErrorToken(self: *Cursor, message: []const u8) Token {
    std.debug.print("{c}\n", .{self.peek()});
    var token = self.makeToken(.@"error");
    token.literal = message;

    return token;
}

pub fn nextToken(self: *Cursor) Token {
    self.skipWhiteSpace();
    self.start = self.current;

    if (self.isAtEnd()) return self.makeToken(.eof);

    const chr: u8 = self.peek();
    self.advance();

    if (isDigit(chr)) return self.makeNumberToken();

    const token_type: Token.Type = switch (chr) {
        '(' => .left_paren,
        ')' => .right_paren,
        '+' => .plus,
        '-' => .dash,
        '*' => .asterisk,
        '/' => .forward_slash,
        '^' => .caret,
        else => return self.makeErrorToken("Unexpected character."),
    };

    return self.makeToken(token_type);
}

fn isAtEnd(self: *Cursor) bool {
    return self.source[self.current] == 0;
}

fn advance(self: *Cursor) void {
    self.current += 1;
}

fn peek(self: *Cursor) u8 {
    return self.source[self.current];
}

fn peekNext(self: *Cursor) u8 {
    if (self.isAtEnd()) return 0;

    return self.source[self.current + 1];
}

fn skipWhiteSpace(self: *Cursor) void {
    while (true) {
        switch (self.peek()) {
            ' ', '\t', '\r', '\n' => self.advance(),
            else => return,
        }
    }
}

fn isDigit(chr: u8) bool {
    return switch (chr) {
        '0'...'9' => true,
        else => false,
    };
}
