const std = @import("std");
const Error = std.fmt.BufPrintError;

const buffer_size: usize = 512;
var buffer: [buffer_size]u8 = undefined;

/// Format a string into a temporary buffer and return it.
/// This buffer is available until the next call to 'format'
/// TODO#5 (high): This function is not thread safe.
pub fn tformat(comptime fmt: []const u8, args: anytype) Error![]u8 {
    return std.fmt.bufPrint(&buffer, fmt, args);
}
