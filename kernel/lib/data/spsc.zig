const std = @import("std");

/// A single-producer, single-consumer lock-free queue.
/// This is a simple implementation of a lock-free queue with
/// an internal buffer.
pub fn SpscRing(comptime T: type) type {
    const Index = usize;

    return struct {
        const Self = @This();

        items: []T,

        // Monotonic counters, not wrapped indexes.
        write: Index,
        read: Index,

        pub fn initWithBuffer(buffer: []T) Self {
            std.debug.assert(buffer.len > 0);

            return .{
                .items = buffer,
                .write = 0,
                .read = 0,
            };
        }

        fn maskOrMod(self: *const Self, index: Index) Index {
            return index % self.items.len;
        }

        pub fn capacity(self: *const Self) usize {
            return self.items.len;
        }

        pub fn emit(self: *Self, item: T) void {
            const write = @atomicLoad(Index, &self.write, .monotonic);
            self.items[self.maskOrMod(write)] = item;
            @atomicStore(Index, &self.write, write +% 1, .release);
        }

        pub fn consume(self: *Self) ?T {
            while (true) {
                var read = @atomicLoad(Index, &self.read, .monotonic);
                const write_before = @atomicLoad(Index, &self.write, .acquire);

                if (read == write_before) return null; // empty

                if (write_before -% read > self.items.len) {
                    read = write_before -% self.items.len; // producer has lapped the consumer, skip to the oldest item
                }

                const value = self.items[self.maskOrMod(read)];

                // Check if the producer has overwritten the item before we can consume it.
                const write_after = @atomicLoad(Index, &self.write, .acquire);
                if (write_after -% read <= self.items.len) {
                    @atomicStore(Index, &self.read, read +% 1, .release);
                    return value;
                }

                // If we get here, it means the producer has overwritten the item before we could consume it.
                // We need to retry to get a consistent view of the queue.
            }
        }
    };
}

test "SpscRing" {
    var buffer: [4]u8 = undefined;

    var queue = SpscRing(u8).initWithBuffer(&buffer);

    try std.testing.expectEqual(4, queue.capacity());

    queue.emit(1);
    queue.emit(2);

    try std.testing.expectEqual(1, queue.consume());
    try std.testing.expectEqual(2, queue.consume());

    queue.emit(3);
    queue.emit(4);
    queue.emit(5);
    queue.emit(6);

    try std.testing.expectEqual(3, queue.consume());
    try std.testing.expectEqual(4, queue.consume());
    try std.testing.expectEqual(5, queue.consume());
    try std.testing.expectEqual(6, queue.consume());

    try std.testing.expectEqual(null, queue.consume());
}

test "SpscRing overwrite" {
    var buffer: [3]u8 = undefined;

    var queue = SpscRing(u8).initWithBuffer(&buffer);

    queue.emit(1);
    queue.emit(2);
    queue.emit(3);
    queue.emit(4);

    try std.testing.expectEqual(2, queue.consume());
    try std.testing.expectEqual(3, queue.consume());
    try std.testing.expectEqual(4, queue.consume());

    try std.testing.expectEqual(null, queue.consume());
}
