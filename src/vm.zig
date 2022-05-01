const std = @import("std");
const Chunk = @import("chunk.zig").Chunk;
const bytecode = @import("bytecode.zig");

const Allocator = std.mem.Allocator;

const InterpretResult = enum { Ok, CompileError, RuntimeError };

pub const VM = struct {
    chunk: *Chunk,
    const Self = @This();

    pub fn init() Self {
        return .{
            .chunk = undefined,
        };
    }

    pub fn deinit() void {
        // do something
    }

    pub fn interpret(self: *Self, chunk: *Chunk) InterpretResult {
        self.chunk = chunk;
        var iter = bytecode.InstructionIter.init(self.chunk.code.items);

        while (iter.next()) |instruction| {
            switch (instruction.op_code) {
                .Return => {
                    return InterpretResult.Ok;
                },
                else => {
                    std.log.err("unhandled opcode {s}", .{instruction.op_code});
                    return InterpretResult.Ok;
                },
            }
        }

        unreachable;
    }
};

test "vm can execute code" {
    const test_allocator = std.testing.allocator;
    const OpCode = bytecode.OpCode;

    var chunk = Chunk.init(test_allocator);
    defer chunk.deinit();

    try chunk.write_constant(1.2, 123);
    try chunk.write_opcode(OpCode.Return, 123);

    var vm = VM.init();
    const result = vm.interpret(&chunk);

    try std.testing.expectEqual(result, InterpretResult.Ok);
}
