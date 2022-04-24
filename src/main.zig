const std = @import("std");
const ck = @import("chunk.zig");

const test_allocator = std.testing.allocator;
const Chunk = ck.Chunk;
const OpCode = ck.OpCode;

pub fn main() anyerror!void {
    var chunk = Chunk.init(test_allocator);
    defer chunk.deinit();

    const offset = try chunk.write_constant(1.2);
    try chunk.write_opcode(OpCode.LoadConstant, 123);
    try chunk.write_operand(offset, 123);
    try chunk.write_opcode(OpCode.Return, 123);

    try chunk.disassemble_chunk("test chunk");
}

test "basic test" {
    try std.testing.expectEqual(10, 3 + 7);
}
