pub const OpCode = enum(u8) {
    push,
    add,
    subtract,
    multiply,
    divide,
    exponentiate,
    negate,
    @"return",

    pub fn byte(op_code: OpCode) u8 {
        return @intFromEnum(op_code);
    }
};
