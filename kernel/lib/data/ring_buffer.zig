const std = @import("std");
const mem = std.mem;

const Allocator = std.mem.Allocator;

pub fn RingBuffer(comptime T: type, comptime alignement: ?mem.Alignment) type {
    if (alignement) |a| {
        if (a.toByteUnits() == @alignOf(T)) {
            return RingBuffer(T, null);
        }
    }

    return struct {
        const Self = @This();

        items: Slice,
        len: usize,

        read_head: usize,
        write_head: usize,

        pub const empty: Self = .{
            .items = &.{},
            .read_head = 0,
            .write_head = 0,
            .len = 0,
        };

        pub const Slice = []T;

        pub fn initCapacity(gpa: Allocator, num: usize) Allocator.Error!Self {
            var self: Self = .empty;
            try self.ensureTotalCapacityPrecise(gpa, num);
            return self;
        }

        pub fn deinit(self: *Self, gpa: Allocator) void {
            if (self.capacity() > 0) {
                gpa.free(self.items);
            }
        }

        /// Pushes an item to the buffer, if the buffer is full, it will overwrite the oldest item
        pub fn push(self: *Self, item: T) void {
            if (self.capacity() == 0) return;

            if (self.len == self.capacity()) {
                // Buffer is full. Overwrite oldest item.
                self.items[self.write_head] = item;
                self.advanceCursor(&self.write_head);
                self.advanceCursor(&self.read_head);
            } else {
                // Buffer has free space.
                self.items[self.write_head] = item;
                self.advanceCursor(&self.write_head);
                self.len += 1;
            }
        }

        /// Pops the oldest item from the buffer, if the buffer is empty, it will return null
        pub fn pop(self: *Self) ?T {
            // Buffer is empty
            if (self.len == 0) return null;

            const item = self.items[self.read_head];
            self.advanceCursor(&self.read_head);
            self.len -= 1;
            return item;
        }

        pub fn capacity(self: *Self) usize {
            return self.items.len;
        }

        fn advanceCursor(self: *Self, cursor: *usize) void {
            cursor.* = (cursor.* + 1) % self.capacity();
        }

        fn rewindCursor(self: *Self, cursor: *usize) void {
            cursor.* = (cursor.* + self.len - 1) % self.len;
        }

        /// Note: this function will not preserve the content order of the buffer.
        pub fn ensureTotalCapacityPrecise(self: *Self, gpa: Allocator, new_capacity: usize) Allocator.Error!void {
            if (self.capacity() >= new_capacity) return;

            const old_memory = self.allocatedSlice();

            if (gpa.remap(old_memory, new_capacity)) |new_memory| {
                self.items = new_memory;
            } else {
                const new_memory = try gpa.alignedAlloc(T, alignement, new_capacity);
                if (self.capacity() > 0) {
                    gpa.free(self.items);
                }

                self.items = new_memory;
            }

            // Reset buffer state.
            self.read_head = 0;
            self.write_head = 0;
            self.items.len = 0;
        }

        fn allocatedSlice(self: *Self) Slice {
            return self.items.ptr[0..self.capacity()];
        }
    };
}

test "RingBuffer" {
    const gpa = std.testing.allocator;

    var buffer = RingBuffer(u8, null).empty;
    defer buffer.deinit(gpa);
    try buffer.ensureTotalCapacityPrecise(gpa, 4);

    buffer.push(1);
    buffer.push(2);
    buffer.push(3);
    buffer.push(4);

    std.debug.print("state #1: {any}\n", .{buffer});

    try std.testing.expectEqual(1, buffer.pop());
    std.debug.print("state #2: {any}\n", .{buffer});
    try std.testing.expectEqual(2, buffer.pop());
    buffer.push(5);

    try std.testing.expectEqual(3, buffer.pop());
    try std.testing.expectEqual(4, buffer.pop());
    try std.testing.expectEqual(5, buffer.pop());

    std.debug.print("state #3: {any}\n", .{buffer});

    try std.testing.expectEqual(null, buffer.pop());
}
