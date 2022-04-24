const std = @import("std");
const Value = @import("value.zig").Value;
const Allocator = std.mem.Allocator;

pub const OpCode = enum(u8) { Return, LoadConstant };

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

    // Private "unsafe" implementation of writing bytes to our code array that
    // wraps required side effects (like writing to our lines array)
    fn write_byte(self: *Self, byte: u8, line: usize) Allocator.Error!void {
        try self.code.append(byte);
        try self.lines.append(line);
    }

    pub fn write_constant(self: *Self, value: Value) Allocator.Error!u8 {
        try self.constants.append(value);
        // we're kind of cheating here, by assuming that we could never have
        // more than 255 constants in a given chunk of bytecode
        return @intCast(u8, self.constants.items.len - 1);
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
