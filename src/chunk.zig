const std = @import("std");
const Allocator = std.mem.Allocator;

pub const OpCode = enum { Return };

pub const Chunk = struct {
    code: std.ArrayList(OpCode),

    const Self = @This();

    pub fn init(allocator: Allocator) Self {
        return .{ .code = std.ArrayList(OpCode).init(allocator) };
    }

    pub fn deinit(self: *Self) void {
        self.code.deinit();
    }

    /// Writes a new op-code into the bytecode chunk
    pub fn write_chunk(self: *Self, byte: OpCode) Allocator.Error!void {
        try self.code.append(byte);
    }

    /// Disassembles a chunk of bytecode and writes formatted result to stdout
    pub fn disassemble_chunk(self: *Self, name: []const u8) std.os.WriteError!void {
        const stdin = std.io.getStdOut().writer();

        try std.fmt.format(stdin, "== {s} ==\n", .{name});

        for (self.code.items) |op_code, offset| {
            try std.fmt.format(stdin, "{d:0>4} {s}\n", .{ offset, op_code });
        }
    }
};
