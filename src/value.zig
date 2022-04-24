/// Represents how a Lox value will be represented in our compiler.
/// TODO: define a real value type (since we want to have more than numbers. :D)
pub const Value = f32;

// Notes:
// How do we store a constant in a chunk of bytecode?
//
// 1.  For very small, fixed-size values (pointer sized or smaller), it makes
// sense to store them directly in the instruction (immedidate instructions)
//
// 2.  For larger values, we need to store a pointer into some kind of
// "constant pool" -- essentially our own manufactured version of the "data
// section" of a binary, but in our case as an interpreter, probably just a map
// stored on the heap, for each chunk of bytecode.

