const std = @import("std");
const Value = @import("value.zig").Value;
const Allocator = std.mem.Allocator;

pub const OpCode = enum(u8) { Return, LoadConstant, LoadConstantLong };

/// MVP, easy to understand bytecode specification.
///
/// Features that we should implement when we get an MVP working:
/// 1) Encode line number information better
/// 2) Support multi-byte operands / instructions
/// 3) Support immediate instructions
pub const Chunk = struct {
    code: std.ArrayList(u8),
    constants: std.ArrayList(Value),
    lines: std.ArrayList(usize),

    const Self = @This();

    pub fn init(allocator: Allocator) Self {
        return .{
            .code = std.ArrayList(u8).init(allocator),
            .constants = std.ArrayList(Value).init(allocator),
            .lines = std.ArrayList(usize).init(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        self.code.deinit();
    }

    pub fn write_opcode(self: *Self, op_code: OpCode, line: usize) Allocator.Error!void {
        try self.write_byte(@enumToInt(op_code), line);
    }

    pub fn write_operand(self: *Self, operand_offset: u8, line: usize) Allocator.Error!void {
        try self.write_byte(operand_offset, line);
    }

    pub fn write_operand_long(self: *Self, operand_offset: u32, line: usize) Allocator.Error!void {
        // cast the 32bit integer to an array of bytes
        const as_byte_array = @bitCast([4]u8, operand_offset);
        // write each byte into our code
        for (as_byte_array) |byte| {
            try self.write_byte(byte, line);
        }
    }

    // Private "unsafe" implementation of writing bytes to our code array that
    // wraps required side effects (like writing to our lines array)
    fn write_byte(self: *Self, byte: u8, line: usize) Allocator.Error!void {
        try self.code.append(byte);
        try self.lines.append(line);
    }

    // modify this function to return void, and figure out on its own whether
    // to write a LoadConstant, or a LoadConstantLong
    pub fn write_constant(self: *Self, value: Value, line: usize) Allocator.Error!void {
        try self.constants.append(value);

        if (self.constants.items.len < 0xFF) {
            const offset = @intCast(u8, self.constants.items.len - 1);
            try self.write_opcode(OpCode.LoadConstant, line);
            try self.write_operand(offset, line);
        } else {
            const offset = @intCast(u32, self.constants.items.len - 1);
            try self.write_opcode(OpCode.LoadConstantLong, line);
            try self.write_operand_long(offset, line);
        }
    }

    pub fn disassemble_chunk(self: *Self, name: []const u8) std.os.WriteError!void {
        const stdin = std.io.getStdOut().writer();

        try std.fmt.format(stdin, "== {s} ==\n", .{name});

        var offset: usize = 0;
        while (offset < self.code.items.len) {
            const op_code = @intToEnum(OpCode, self.code.items[offset]);
            const line = self.lines.items[offset];

            try self.print_opcode(stdin, op_code, offset, line);

            switch (op_code) {
                .Return => {
                    _ = try stdin.write("\n");
                    offset += 1;
                },
                .LoadConstant => {
                    const operand_idx = self.code.items[offset + 1];
                    const operand = self.constants.items[operand_idx];
                    // TODO: abstract value formatting, and standardize width
                    try std.fmt.format(stdin, " {d:.2}\n", .{operand});
                    offset += 2;
                },
                .LoadConstantLong => {
                    // not sure why the slice is not trivially able to be
                    // de-referenced without this @ptrCast nonsense...see
                    // https://stackoverflow.com/questions/70102667/converting-a-slice-to-an-array
                    const array: *[4]u8 = @ptrCast(*[4]u8, self.code.items[offset + 1 .. offset + 4]);
                    const operand_idx: u32 = @bitCast(u32, array.*);
                    const operand = self.constants.items[operand_idx];
                    try std.fmt.format(stdin, " operand: {d:.2}\n", .{operand});
                    offset += 5;
                },
            }
        }
    }

    fn print_opcode(self: *Self, writer: anytype, op_code: OpCode, offset: usize, line: usize) std.os.WriteError!void {
        if ((offset > 0) and (self.lines.items[offset] == self.lines.items[offset - 1])) {
            try std.fmt.format(writer, "{d:0>4}    | {s}", .{ offset, op_code });
        } else {
            try std.fmt.format(writer, "{d:0>4} {d:>4} {s}", .{ offset, line, op_code });
        }
    }
};
