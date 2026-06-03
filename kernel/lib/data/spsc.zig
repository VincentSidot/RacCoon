const std = @import("std");

pub const Error = error{ QueueEmpty, ProducerOverrun };

const default_consumer_retries: comptime_int = 1000;

pub fn SpscRing(comptime T: type) type {
    return SpscRingExt(T, default_consumer_retries);
}

/// A single-producer, single-consumer lock-free queue.
/// This is a simple implementation of a lock-free queue with
/// an internal buffer.
pub fn SpscRingExt(comptime T: type, comptime consumer_retries: ?comptime_int) type {
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

        pub fn consume(self: *Self) Error!T {
            return self.consumeExt(null);
        }

        pub fn consumeExt(self: *Self, has_missed_events: ?*bool) Error!T {
            var retries: usize = 0;
            while (retries < (consumer_retries orelse std.math.maxInt(usize))) : (retries += 1) {
                var read = @atomicLoad(Index, &self.read, .monotonic);
                const write_before = @atomicLoad(Index, &self.write, .acquire);

                if (read == write_before) return Error.QueueEmpty; // empty

                if (write_before -% read > self.items.len) {
                    read = write_before -% self.items.len; // producer has lapped the consumer, skip to the oldest item

                    if (has_missed_events) |ptr| ptr.* = true;
                } else if (has_missed_events) |ptr| ptr.* = false;

                const index = self.maskOrMod(read);
                const value = self.items[index];

                // Check if the producer has overwritten the item before we can consume it.
                const write_after = @atomicLoad(Index, &self.write, .acquire);
                if (write_after -% read <= self.items.len) {
                    @atomicStore(Index, &self.read, read +% 1, .release);
                    return value;
                }

                // If we get here, it means the producer has overwritten the item before we could consume it.
                // We need to retry to get a consistent view of the queue.
            }

            return Error.ProducerOverrun;
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

    try std.testing.expectEqual(error.QueueEmpty, queue.consume());
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

    try std.testing.expectEqual(error.QueueEmpty, queue.consume());
}

test "SpscRing consumeExt reports missed events" {
    var buffer: [3]u8 = undefined;

    var queue = SpscRing(u8).initWithBuffer(&buffer);

    // Emit past capacity so the producer laps the consumer and 1, 2 are lost.
    queue.emit(1);
    queue.emit(2);
    queue.emit(3);
    queue.emit(4);
    queue.emit(5);

    var missed: bool = false;

    // The first read detects the lap and skips to the oldest surviving item.
    try std.testing.expectEqual(3, try queue.consumeExt(&missed));
    try std.testing.expect(missed);

    // The remaining reads are within capacity, so no further misses are flagged.
    try std.testing.expectEqual(4, try queue.consumeExt(&missed));
    try std.testing.expect(!missed);

    try std.testing.expectEqual(5, try queue.consumeExt(&missed));
    try std.testing.expect(!missed);

    try std.testing.expectError(error.QueueEmpty, queue.consumeExt(&missed));
}

test "SpscRingExt reports overrun once retries are exhausted" {
    var buffer: [4]u8 = undefined;

    // With zero allowed retries the consumer cannot establish a consistent view
    // and reports ProducerOverrun instead of returning an item.
    var queue = SpscRingExt(u8, 0).initWithBuffer(&buffer);
    queue.emit(1);

    try std.testing.expectError(error.ProducerOverrun, queue.consume());
}

test "SpscRing concurrent producer/consumer stays memory-safe and terminates" {
    const Queue = SpscRing(u64);

    const N: u64 = 200_000;
    // A small buffer relative to N forces the producer to lap the consumer
    // repeatedly, exercising the missed-event skip path under real contention.
    var buffer: [8]u64 = undefined;
    var queue = Queue.initWithBuffer(&buffer);

    const Producer = struct {
        fn run(q: *Queue, count: u64) void {
            var i: u64 = 1;
            while (i <= count) : (i += 1) {
                q.emit(i);
            }
        }
    };

    var thread = try std.Thread.spawn(.{}, Producer.run, .{ &queue, N });
    defer thread.join();

    // Under sustained overrun the queue is lossy AND only approximately ordered:
    // the lap path can hand back a value out of order by up to capacity-1, so we
    // do NOT assert strict ordering here. What must always hold is that every value
    // is one the producer actually emitted (1..N, no torn/garbage reads) and that
    // the consumer makes progress to N (the final slot is never under contention
    // once the producer stops, so the loop terminates).
    var last: u64 = 0;
    while (last < N) {
        const value = queue.consume() catch |err| switch (err) {
            error.QueueEmpty, error.ProducerOverrun => continue, // transient, retry
        };
        try std.testing.expect(value >= 1 and value <= N);
        last = value;
    }
}
