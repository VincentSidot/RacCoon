extern fn __outb(port: u16, value: u8) callconv(.c) void;
extern fn __inb(port: u16) callconv(.c) u8;
extern fn __sti() callconv(.c) void;

pub const outb = __outb;
pub const inb = __inb;
pub const sti = __sti;
