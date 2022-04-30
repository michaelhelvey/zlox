const std = @import("std");
const Value = @import("value.zig").Value;
const Allocator = std.mem.Allocator;
const test_allocator = std.testing.allocator;

pub const OpCode = enum(u8) { Return, LoadConstant, LoadConstantLong };

const LineIndex = struct {
    code_index: usize,
    line_no: usize,
};

/// MVP, easy to understand bytecode specification.
///
/// Features that we should implement when we get an MVP working:
/// 1) Support immediate instructions
/// 2) Could probably speed up writing bytes quite a bit by optimizing the allocator
pub const Chunk = struct {
    code: std.ArrayList(u8),
    constants: std.ArrayList(Value),
    lines: std.ArrayList(LineIndex),
    _last_written_line: usize,

    const Self = @This();

    pub fn init(allocator: Allocator) Self {
        return .{
            .code = std.ArrayList(u8).init(allocator),
            .constants = std.ArrayList(Value).init(allocator),
            .lines = std.ArrayList(LineIndex).init(allocator),
            ._last_written_line = 0,
        };
    }

    pub fn deinit(self: *Self) void {
        self.code.deinit();
        self.constants.deinit();
        self.lines.deinit();
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

    /// Write a constant, and use the size of the current number of constants to
    /// determine whether to write a LoadConstant or a LoadConstantLong
    /// instruction
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

    // Private "unsafe" implementation of writing bytes to our code array that
    // wraps required side effects (like writing to our lines array)
    fn write_byte(self: *Self, byte: u8, line: usize) Allocator.Error!void {
        try self.code.append(byte);
        const code_index = self.code.items.len - 1;

        if (self._last_written_line != line) {
            try self.lines.append(.{ .line_no = line, .code_index = code_index });
            self._last_written_line = line;
        }
    }

    pub fn disassemble_chunk(self: *Self, name: []const u8) std.os.WriteError!void {
        const stdin = std.io.getStdOut().writer();

        try std.fmt.format(stdin, "\n== {s} ==\n", .{name});

        var offset: usize = 0;
        while (offset < self.code.items.len) {
            const op_code = @intToEnum(OpCode, self.code.items[offset]);
            const line = self.get_line(offset);

            try print_opcode(stdin, op_code, offset, line);

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

    /// Gets a line number from the index of an instruction in O(n) time
    fn get_line(self: *Self, inst_index: usize) LineIndex {
        // iterate through lines and find the nearest {line,offset} tuple behind the current offset
        for (self.lines.items) |line_index, idx| {
            if (line_index.code_index > inst_index) {
                // if we've passed the offset, return the previous one
                return self.lines.items[idx - 1];
            }
        }

        // otherwise return the most recent line
        return self.lines.items[self.lines.items.len - 1];
    }

    fn print_opcode(writer: anytype, op_code: OpCode, offset: usize, line: LineIndex) std.os.WriteError!void {
        if ((offset > 0) and line.code_index != offset) {
            try std.fmt.format(writer, "{d:0>4}    | {s}", .{ offset, op_code });
        } else {
            try std.fmt.format(writer, "{d:0>4} {d:>4} {s}", .{ offset, line.line_no, op_code });
        }
    }
};

test "chunks can be written to and disassembled" {
    var chunk = Chunk.init(test_allocator);
    defer chunk.deinit();

    // TODO: split up disassembly into an output format and a printer for that
    // format, so we can make assertions about the datastructure, rather than
    // formatting.  As it is, at least we're asserting that it runs, and that
    // it doesn't leak memory etc.

    // expect an output like:
    // == test chunk ==
    //0000  123 OpCode.LoadConstant 1.20
    //0002    | OpCode.Return
    //0003    | OpCode.Return
    //0004  234 OpCode.Return
    //0005    | OpCode.Return

    try chunk.write_constant(1.2, 123);
    try chunk.write_opcode(OpCode.Return, 123);
    try chunk.write_opcode(OpCode.Return, 123);
    try chunk.write_opcode(OpCode.Return, 234);
    try chunk.write_opcode(OpCode.Return, 234);

    try chunk.disassemble_chunk("test chunk");
}
