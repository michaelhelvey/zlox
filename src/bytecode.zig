const std = @import("std");

pub const OpCode = enum(u8) {
    Return,
    LoadConstant,
    LoadConstantLong,
    // gets the size in bytes of the associated instruction
    pub fn instruction_size(self: OpCode) usize {
        return switch (self) {
            .Return => 1,
            .LoadConstant => 2,
            .LoadConstantLong => 5,
        };
    }
};

pub const Instruction = struct {
    op_code: OpCode,
    bytes: []const u8, // the bytes of an instruction are just a pointer into existing memory...

    const Self = @This();

    pub fn init(op_code: OpCode, bytes: []const u8) Self {
        return .{ .op_code = op_code, .bytes = bytes };
    }

    pub fn operand_as_byte(self: Self) u8 {
        return @bitCast(u8, self.bytes[1]);
    }

    pub fn operand_as_long(self: Self) u32 {
        const array: *const [4]u8 = @ptrCast(*const [4]u8, self.bytes[1..self.op_code.instruction_size()]);
        const operand_idx: u32 = @bitCast(u32, array.*);
        return operand_idx;
    }
};

pub const InstructionIter = struct {
    bytes: []const u8,
    offset: usize,

    const Self = @This();

    pub fn init(bytes: []const u8) Self {
        return .{ .bytes = bytes, .offset = 0 };
    }

    pub fn next(self: *Self) ?Instruction {
        if (self.offset >= self.bytes.len) {
            return null;
        }

        const op_code = @intToEnum(OpCode, self.bytes[self.offset]);
        const bytes_len = op_code.instruction_size();
        const instruction = Instruction.init(op_code, self.bytes[self.offset .. self.offset + bytes_len]);

        self.offset += bytes_len;
        return instruction;
    }
};

test {
    _ = InstructionEncodingTests;
    _ = InstructionIteratorTests;
}

const InstructionEncodingTests = struct {
    test "OpCode.Return" {
        const op_code = OpCode.Return;
        const bytes = &[_]u8{@enumToInt(op_code)};
        const inst = Instruction.init(op_code, bytes);

        try std.testing.expectEqual(inst.op_code, op_code);
    }

    test "OpCode.LoadConstant" {
        const op_code = OpCode.LoadConstant;
        const operand: u8 = 69;
        const bytes = &[_]u8{ @enumToInt(op_code), operand };
        const inst = Instruction.init(op_code, bytes);

        try std.testing.expectEqual(inst.op_code, OpCode.LoadConstant);
        try std.testing.expectEqual(inst.operand_as_byte(), operand);
    }

    test "OpCode.LoadConstantLong" {
        const op_code = OpCode.LoadConstantLong;
        const operand: u32 = 12345;
        const oab = @bitCast([4]u8, operand);
        const bytes = &[_]u8{ @enumToInt(op_code), oab[0], oab[1], oab[2], oab[3] };
        const inst = Instruction.init(op_code, bytes);

        try std.testing.expectEqual(inst.op_code, OpCode.LoadConstantLong);
        try std.testing.expectEqual(inst.operand_as_long(), operand);
    }
};

const InstructionIteratorTests = struct {
    const test_allocator = std.testing.allocator;

    test "can iterate over single byte instruction" {
        var buffer = std.ArrayList(u8).init(test_allocator);
        defer buffer.deinit();

        const ret_inst = &[_]u8{@enumToInt(OpCode.Return)};
        const short_inst = &[_]u8{ @enumToInt(OpCode.LoadConstant), 69 };
        // NB: 65535 in revrese, because endianness
        const long_inst = &[_]u8{ @enumToInt(OpCode.LoadConstantLong), 0xFF, 0xFF, 0x00, 0x00 };

        try buffer.appendSlice(ret_inst);
        try buffer.appendSlice(short_inst);
        try buffer.appendSlice(long_inst);

        var iter = InstructionIter.init(buffer.items);

        var idx: u32 = 0;
        while (iter.next()) |instruction| {
            switch (idx) {
                0 => {
                    try std.testing.expectEqual(instruction.op_code, OpCode.Return);
                },
                1 => {
                    try std.testing.expectEqual(instruction.op_code, OpCode.LoadConstant);
                    try std.testing.expectEqual(instruction.operand_as_byte(), 69);
                },
                2 => {
                    try std.testing.expectEqual(instruction.op_code, OpCode.LoadConstantLong);
                    try std.testing.expectEqual(instruction.operand_as_long(), 65535);
                },
                else => unreachable,
            }

            idx += 1;
        }
    }
};
