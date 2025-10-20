const std = @import("std");

const core = @import("core/core.zig");

const Chunk = core.Chunk;
const Cursor = core.Cursor;

const VM = @import("core/VM.zig");

pub fn main() !void {
    // const source: []const u8 = "( 1 + 3.4 \n)*5.6\x00";

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const ally = gpa.allocator();

    // var cursor = Cursor.init(source);
    //
    // var token = cursor.nextToken();
    // while (token.type != .eof) : (token = cursor.nextToken()) {
    //     std.debug.print("{f}\n", .{token});
    // }

    // VM.interpret(&ally, "-1^2*3\x00") catch |err| {

    VM.interpret(&ally, "5-6-7^2^3\x00") catch |err| {
        @panic(@errorName(err));
    };
}
