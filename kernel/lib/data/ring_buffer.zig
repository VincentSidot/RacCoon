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

        pub fn initFromBuffer(buffer: Slice) Self {
            return Self{
                .items = buffer,
                .read_head = 0,
                .write_head = 0,
                .len = 0,
            };
        }

        pub fn deinit(self: *Self, gpa: Allocator) void {
            if (self.capacity() > 0) {
                gpa.free(self.items);
            }
        }

        /// Pushes an item to the buffer, if the buffer is full, it will overwrite the oldest item
        pub fn pushBack(self: *Self, item: T) void {
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

        pub fn pushFront(self: *Self, item: T) void {
            if (self.capacity() == 0) return;

            if (self.len == self.capacity()) {
                // Buffer is full. Overwrite oldest item.
                self.rewindCursor(&self.read_head);
                self.rewindCursor(&self.write_head);
                self.items[self.read_head] = item;
            } else {
                // Buffer has free space.
                self.rewindCursor(&self.read_head);
                self.items[self.read_head] = item;
                self.len += 1;
            }
        }

        /// Pops the oldest item from the buffer, if the buffer is empty, it will return null
        pub fn popFront(self: *Self) ?T {
            // Buffer is empty
            if (self.len == 0) return null;

            const item = self.items[self.read_head];
            self.advanceCursor(&self.read_head);
            self.len -= 1;
            return item;
        }

        pub fn popBack(self: *Self) ?T {
            // Buffer is empty
            if (self.len == 0) return null;

            self.rewindCursor(&self.write_head);
            const item = self.items[self.write_head];
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
            cursor.* = (cursor.* + self.capacity() - 1) % self.capacity();
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
            self.len = 0;
        }

        fn allocatedSlice(self: *Self) Slice {
            return self.items.ptr[0..self.capacity()];
        }
    };
}

test "RingBuffer Allocator" {
    const gpa = std.testing.allocator;

    var buffer = RingBuffer(u8, null).empty;
    defer buffer.deinit(gpa);
    try buffer.ensureTotalCapacityPrecise(gpa, 4);

    buffer.pushBack(1);
    buffer.pushBack(2);
    buffer.pushBack(3);
    buffer.pushBack(4);

    try std.testing.expectEqual(1, buffer.popFront());
    try std.testing.expectEqual(2, buffer.popFront());
    buffer.pushBack(5);

    try std.testing.expectEqual(3, buffer.popFront());
    try std.testing.expectEqual(4, buffer.popFront());
    try std.testing.expectEqual(5, buffer.popFront());

    try std.testing.expectEqual(null, buffer.popFront());

    buffer.pushFront(1);
    buffer.pushFront(2);
    buffer.pushBack(3);
    buffer.pushBack(4);
    buffer.pushFront(5);

    // Expected buffer state: {5, 2, 1, 3}
    try std.testing.expectEqual(3, buffer.popBack());
    try std.testing.expectEqual(1, buffer.popBack());
    try std.testing.expectEqual(2, buffer.popBack());
    try std.testing.expectEqual(5, buffer.popBack());
}

test "RingBuffer Slice" {
    var raw: [9]u8 = undefined;

    var buffer = RingBuffer(u8, null).initFromBuffer(&raw);

    var i: u8 = 0;
    while (i < 9) : (i += 1) {
        buffer.pushBack(i);
    }

    buffer.pushFront(9);

    const expected: [9]u8 = .{ 9, 0, 1, 2, 3, 4, 5, 6, 7 };
    for (expected) |value| {
        try std.testing.expectEqual(value, buffer.popFront().?);
    }
}
