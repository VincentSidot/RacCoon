//! PS/2 scancode set 1: physical keycodes and an incremental scancode parser.
//!
//! This module is pure: it knows how to turn a stream of scancode bytes into
//! `KeyEvent`s and nothing else (no IO, no queue). The driver in `keyboard.zig`
//! owns the hardware and feeds bytes into a `Parser`.

const std = @import("std");

// ============================================================================
// Physical keys
// ============================================================================

/// Physical keycode mapping based on standard PS/2 keyboard scancodes.
// zlinter-disable field_naming - we want the enum values to be in the form of KEY_<KEYNAME>.
pub const PhysicalKeyCode = enum(u8) {
    KEY_UNKNOWN,
    KEY_ESC,
    KEY_1,
    KEY_2,
    KEY_3,
    KEY_4,
    KEY_5,
    KEY_6,
    KEY_7,
    KEY_8,
    KEY_9,
    KEY_0,
    KEY_MINUS,
    KEY_EQUAL,
    KEY_BACKSPACE,
    KEY_TAB,
    KEY_Q,
    KEY_W,
    KEY_E,
    KEY_R,
    KEY_T,
    KEY_Y,
    KEY_U,
    KEY_I,
    KEY_O,
    KEY_P,
    KEY_LEFTBRACE,
    KEY_RIGHTBRACE,
    KEY_ENTER,
    KEY_LCTRL,
    KEY_A,
    KEY_S,
    KEY_D,
    KEY_F,
    KEY_G,
    KEY_H,
    KEY_J,
    KEY_K,
    KEY_L,
    KEY_SEMICOLON,
    KEY_APOSTROPHE,
    KEY_GRAVE,
    KEY_LSHIFT,
    KEY_BACKSLASH,
    KEY_Z,
    KEY_X,
    KEY_C,
    KEY_V,
    KEY_B,
    KEY_N,
    KEY_M,
    KEY_COMMA,
    KEY_DOT,
    KEY_SLASH,
    KEY_RSHIFT,
    KEY_LALT,
    KEY_SPACE,
    KEY_CAPSLOCK,
    KEY_F1,
    KEY_F2,
    KEY_F3,
    KEY_F4,
    KEY_F5,
    KEY_F6,
    KEY_F7,
    KEY_F8,
    KEY_F9,
    KEY_F10,
    KEY_F11,
    KEY_F12,
    KEY_RCTRL,
    KEY_RALT,
};
// zlinter-enable field_naming

/// A decoded key transition: a physical key and whether it was pressed (make
/// code) or released (break code). For `.KEY_UNKNOWN`, `pressed` is meaningless.
pub const KeyEvent = struct {
    keycode: PhysicalKeyCode,
    pressed: bool,
};

// ============================================================================
// Scancode table
// ============================================================================

const CompEntry = struct {
    key: PhysicalKeyCode,
    /// Make-code byte sequence. Single-byte for most keys; multi-byte for
    /// extended keys (a 0xE0 prefix plus the key byte).
    code: []const u8,
};

/// Ordered by make-code value; the multi-byte (0xE0-prefixed) keys follow at
/// the end since they don't fit the single-byte progression.
const comp_entries = [_]CompEntry{
    .{ .key = .KEY_ESC, .code = &.{0x01} },
    .{ .key = .KEY_1, .code = &.{0x02} },
    .{ .key = .KEY_2, .code = &.{0x03} },
    .{ .key = .KEY_3, .code = &.{0x04} },
    .{ .key = .KEY_4, .code = &.{0x05} },
    .{ .key = .KEY_5, .code = &.{0x06} },
    .{ .key = .KEY_6, .code = &.{0x07} },
    .{ .key = .KEY_7, .code = &.{0x08} },
    .{ .key = .KEY_8, .code = &.{0x09} },
    .{ .key = .KEY_9, .code = &.{0x0A} },
    .{ .key = .KEY_0, .code = &.{0x0B} },
    .{ .key = .KEY_MINUS, .code = &.{0x0C} },
    .{ .key = .KEY_EQUAL, .code = &.{0x0D} },
    .{ .key = .KEY_BACKSPACE, .code = &.{0x0E} },
    .{ .key = .KEY_TAB, .code = &.{0x0F} },
    .{ .key = .KEY_Q, .code = &.{0x10} },
    .{ .key = .KEY_W, .code = &.{0x11} },
    .{ .key = .KEY_E, .code = &.{0x12} },
    .{ .key = .KEY_R, .code = &.{0x13} },
    .{ .key = .KEY_T, .code = &.{0x14} },
    .{ .key = .KEY_Y, .code = &.{0x15} },
    .{ .key = .KEY_U, .code = &.{0x16} },
    .{ .key = .KEY_I, .code = &.{0x17} },
    .{ .key = .KEY_O, .code = &.{0x18} },
    .{ .key = .KEY_P, .code = &.{0x19} },
    .{ .key = .KEY_LEFTBRACE, .code = &.{0x1A} },
    .{ .key = .KEY_RIGHTBRACE, .code = &.{0x1B} },
    .{ .key = .KEY_ENTER, .code = &.{0x1C} },
    .{ .key = .KEY_LCTRL, .code = &.{0x1D} },
    .{ .key = .KEY_A, .code = &.{0x1E} },
    .{ .key = .KEY_S, .code = &.{0x1F} },
    .{ .key = .KEY_D, .code = &.{0x20} },
    .{ .key = .KEY_F, .code = &.{0x21} },
    .{ .key = .KEY_G, .code = &.{0x22} },
    .{ .key = .KEY_H, .code = &.{0x23} },
    .{ .key = .KEY_J, .code = &.{0x24} },
    .{ .key = .KEY_K, .code = &.{0x25} },
    .{ .key = .KEY_L, .code = &.{0x26} },
    .{ .key = .KEY_SEMICOLON, .code = &.{0x27} },
    .{ .key = .KEY_APOSTROPHE, .code = &.{0x28} },
    .{ .key = .KEY_GRAVE, .code = &.{0x29} },
    .{ .key = .KEY_LSHIFT, .code = &.{0x2A} },
    .{ .key = .KEY_BACKSLASH, .code = &.{0x2B} },
    .{ .key = .KEY_Z, .code = &.{0x2C} },
    .{ .key = .KEY_X, .code = &.{0x2D} },
    .{ .key = .KEY_C, .code = &.{0x2E} },
    .{ .key = .KEY_V, .code = &.{0x2F} },
    .{ .key = .KEY_B, .code = &.{0x30} },
    .{ .key = .KEY_N, .code = &.{0x31} },
    .{ .key = .KEY_M, .code = &.{0x32} },
    .{ .key = .KEY_COMMA, .code = &.{0x33} },
    .{ .key = .KEY_DOT, .code = &.{0x34} },
    .{ .key = .KEY_SLASH, .code = &.{0x35} },
    .{ .key = .KEY_RSHIFT, .code = &.{0x36} },
    .{ .key = .KEY_LALT, .code = &.{0x38} },
    .{ .key = .KEY_SPACE, .code = &.{0x39} },
    .{ .key = .KEY_CAPSLOCK, .code = &.{0x3A} },
    .{ .key = .KEY_F1, .code = &.{0x3B} },
    .{ .key = .KEY_F2, .code = &.{0x3C} },
    .{ .key = .KEY_F3, .code = &.{0x3D} },
    .{ .key = .KEY_F4, .code = &.{0x3E} },
    .{ .key = .KEY_F5, .code = &.{0x3F} },
    .{ .key = .KEY_F6, .code = &.{0x40} },
    .{ .key = .KEY_F7, .code = &.{0x41} },
    .{ .key = .KEY_F8, .code = &.{0x42} },
    .{ .key = .KEY_F9, .code = &.{0x43} },
    .{ .key = .KEY_F10, .code = &.{0x44} },
    .{ .key = .KEY_F11, .code = &.{0x57} },
    .{ .key = .KEY_F12, .code = &.{0x58} },
    // Extended (0xE0-prefixed) keys.
    .{ .key = .KEY_RCTRL, .code = &.{ 0xE0, 0x1D } },
    .{ .key = .KEY_RALT, .code = &.{ 0xE0, 0x38 } },
};

// ============================================================================
// Parsing trie
// ============================================================================

const NodeLookupKey = u8;
const ScanCode = u8;
const NodeIndex = usize;

const Entry = union(enum) {
    unknown,
    key: PhysicalKeyCode,
    step: NodeIndex,
};
const Node = [std.math.maxInt(NodeLookupKey)]Entry;

/// Scancodes are 1-based (0x01..0xFF); shifting to 0-based lets a
/// `maxInt(u8)`-element node cover the whole range without an off-by-one.
fn scancodeToSlot(code: ScanCode) ScanCode {
    return code - 1;
}

/// Upper bound on the number of trie nodes: the root, plus at most one node
/// per prefix byte of every multi-byte sequence. Sequences that share a prefix
/// (e.g. all the 0xE0-prefixed keys) reuse nodes, so the real count is smaller;
/// the extra nodes are left as all-`.unknown` and never reached.
fn nodeCount(comptime entries: []const CompEntry) usize {
    var count: usize = 1; // root
    for (entries) |entry| count += entry.code.len - 1;
    return count;
}

fn emptyNode() Node {
    return .{.unknown} ** std.math.maxInt(NodeLookupKey);
}

/// Build the scancode-parsing trie. Each entry's `code` is walked byte by byte:
/// the leading bytes are prefixes that create/follow `.step` links into child
/// nodes, and the final byte is a terminal `.key`. Both the make code and its
/// break code (high bit set) are mapped to the key so presses and releases
/// resolve to the same key (releases are told apart by the `pressed` bit).
fn buildTrie(comptime entries: []const CompEntry) [nodeCount(entries)]Node {
    var new_nodes: [nodeCount(entries)]Node = .{emptyNode()} ** nodeCount(entries);
    var next_free: NodeIndex = 1; // node 0 is the root
    for (entries) |entry| {
        if (entry.code.len == 0) {
            @compileError("Scancode sequence must not be empty");
        }

        var current: NodeIndex = 0;
        for (entry.code, 0..) |code, i| {
            if (code == 0) {
                @compileError("Scancode 0 is reserved for unknown keys");
            }

            const slot = scancodeToSlot(code);
            if (i == entry.code.len - 1) {
                new_nodes[current][slot] = .{ .key = entry.key };
                new_nodes[current][slot | 0x80] = .{ .key = entry.key };
            } else switch (new_nodes[current][slot]) {
                .step => |next| current = next,
                else => {
                    new_nodes[current][slot] = .{ .step = next_free };
                    current = next_free;
                    next_free += 1;
                },
            }
        }
    }

    return new_nodes;
}

const nodes = buildTrie(&comp_entries);

// ============================================================================
// Parser
// ============================================================================

/// Incremental PS/2 scancode parser. Feed scancode bytes one at a time;
/// multi-byte sequences (e.g. 0xE0-prefixed keys) span several `feed` calls,
/// with the in-progress position held in `current_state`.
pub const Parser = struct {
    current_state: NodeIndex = 0,

    /// Feed one scancode byte. Returns the completed key event, or `null` when
    /// the byte was a prefix and more bytes are needed before a key resolves.
    pub fn feed(self: *Parser, code: ScanCode) ?KeyEvent {
        if (code == 0) {
            // Key-detection error / internal buffer overrun: reset and report.
            self.current_state = 0;
            return .{ .keycode = .KEY_UNKNOWN, .pressed = false };
        }

        const pressed = (code & 0x80) == 0;
        switch (nodes[self.current_state][scancodeToSlot(code)]) {
            .unknown => {
                self.current_state = 0;
                return .{ .keycode = .KEY_UNKNOWN, .pressed = pressed };
            },
            .key => |key| {
                self.current_state = 0;
                return .{ .keycode = key, .pressed = pressed };
            },
            .step => |step| {
                self.current_state = step;
                return null;
            },
        }
    }
};
