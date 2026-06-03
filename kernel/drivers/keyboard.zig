const io = @import("../arch.zig").io;
const spcs = @import("../lib/data/spsc.zig");

/// Keyboard scancodes (PS/2 scancode set 1, make codes).
/// Non-exhaustive: unmapped scancodes keep their raw value.
pub const KeyCode = enum(u8) {
    // zlinter-disable field_naming - field names mirror key scancodes
    KEY_ESC = 0x01,
    KEY_1 = 0x02,
    KEY_2 = 0x03,
    KEY_3 = 0x04,
    KEY_4 = 0x05,
    KEY_5 = 0x06,
    KEY_6 = 0x07,
    KEY_7 = 0x08,
    KEY_8 = 0x09,
    KEY_9 = 0x0A,
    KEY_0 = 0x0B,
    KEY_MINUS = 0x0C,
    KEY_EQUAL = 0x0D,
    KEY_BACKSPACE = 0x0E,
    KEY_TAB = 0x0F,
    KEY_Q = 0x10,
    KEY_W = 0x11,
    KEY_E = 0x12,
    KEY_R = 0x13,
    KEY_T = 0x14,
    KEY_Y = 0x15,
    KEY_U = 0x16,
    KEY_I = 0x17,
    KEY_O = 0x18,
    KEY_P = 0x19,
    KEY_LEFTBRACE = 0x1A,
    KEY_RIGHTBRACE = 0x1B,
    KEY_ENTER = 0x1C,
    KEY_LEFTCTRL = 0x1D,
    KEY_A = 0x1E,
    KEY_S = 0x1F,
    KEY_D = 0x20,
    KEY_F = 0x21,
    KEY_G = 0x22,
    KEY_H = 0x23,
    KEY_J = 0x24,
    KEY_K = 0x25,
    KEY_L = 0x26,
    KEY_SEMICOLON = 0x27,
    KEY_APOSTROPHE = 0x28,
    KEY_GRAVE = 0x29,
    KEY_LEFTSHIFT = 0x2A,
    KEY_BACKSLASH = 0x2B,
    KEY_Z = 0x2C,
    KEY_X = 0x2D,
    KEY_C = 0x2E,
    KEY_V = 0x2F,
    KEY_B = 0x30,
    KEY_N = 0x31,
    KEY_M = 0x32,
    KEY_COMMA = 0x33,
    KEY_DOT = 0x34,
    KEY_SLASH = 0x35,
    KEY_RIGHTSHIFT = 0x36,
    KEY_LEFTALT = 0x38,
    KEY_SPACE = 0x39,
    KEY_CAPSLOCK = 0x3A,
    KEY_F1 = 0x3B,
    KEY_F2 = 0x3C,
    KEY_F3 = 0x3D,
    KEY_F4 = 0x3E,
    KEY_F5 = 0x3F,
    KEY_F6 = 0x40,
    KEY_F7 = 0x41,
    KEY_F8 = 0x42,
    KEY_F9 = 0x43,
    KEY_F10 = 0x44,
    KEY_F11 = 0x57,
    KEY_F12 = 0x58,
    _,
    // zlinter-enable field_naming
};

pub const RawKeyEvent = struct {
    keycode: KeyCode,
    pressed: bool,
};

pub const Modifiers = packed struct {
    shift: bool,
    ctrl: bool,
    alt: bool,

    pub const empty: Modifiers = .{
        .shift = false,
        .ctrl = false,
        .alt = false,
    };
};

const buffer_size: usize = 256;
var buffer: [buffer_size]RawKeyEvent = undefined;

const State = struct {
    queue: spcs.SpscRing(RawKeyEvent),
    modifiers: Modifiers = .empty,
};

var state: State = .{
    .queue = spcs.SpscRing(RawKeyEvent).initWithBuffer(&buffer),
};

pub fn onKeyboardInterrupt() void {
    const scancode = io.inb(0x60);

    const pressed = (scancode & 0x80) == 0;
    const keycode: KeyCode = @enumFromInt(scancode & 0x7F);

    const event: RawKeyEvent = .{
        .keycode = keycode,
        .pressed = pressed,
    };

    // Handle key modifiers
    // Note: right shift and alt needs extended scancodes which are not handled yet.
    switch (keycode) {
        .KEY_LEFTSHIFT, .KEY_RIGHTSHIFT => state.modifiers.shift = pressed,
        .KEY_LEFTCTRL => state.modifiers.ctrl = pressed,
        .KEY_LEFTALT => state.modifiers.alt = pressed,
        else => {},
    }

    state.queue.emit(event);
}

pub fn readRawEvent() ?RawKeyEvent {
    return state.queue.consume();
}

/// Note: this function consume the key event, even if it's not a char event (e.g. shift press).
/// Only key presses produce a char; releases (break codes) are ignored so each
/// keystroke yields a single character.
pub fn readCharEvent() ?u8 {
    const event = readRawEvent() orelse return null;
    if (!event.pressed) return null;

    return convertKeycodeToChar(event.keycode);
}

pub fn modifiers() Modifiers {
    return state.modifiers;
}

/// This function is not handling all the available ascii characters.
pub fn convertKeycodeToChar(code: KeyCode) ?u8 {
    switch (code) {
        .KEY_ENTER => return '\n',
        .KEY_COMMA => return ',',
        .KEY_DOT => return '.',
        .KEY_SLASH => return '/',
        .KEY_SPACE => return ' ',
        .KEY_MINUS => return '-',
        .KEY_EQUAL => return '=',
        .KEY_1 => return '1',
        .KEY_2 => return '2',
        .KEY_3 => return '3',
        .KEY_4 => return '4',
        .KEY_5 => return '5',
        .KEY_6 => return '6',
        .KEY_7 => return '7',
        .KEY_8 => return '8',
        .KEY_9 => return '9',
        .KEY_0 => return '0',
        .KEY_Q => return if (state.modifiers.shift) 'Q' else 'q',
        .KEY_W => return if (state.modifiers.shift) 'W' else 'w',
        .KEY_E => return if (state.modifiers.shift) 'E' else 'e',
        .KEY_R => return if (state.modifiers.shift) 'R' else 'r',
        .KEY_T => return if (state.modifiers.shift) 'T' else 't',
        .KEY_Y => return if (state.modifiers.shift) 'Y' else 'y',
        .KEY_U => return if (state.modifiers.shift) 'U' else 'u',
        .KEY_I => return if (state.modifiers.shift) 'I' else 'i',
        .KEY_O => return if (state.modifiers.shift) 'O' else 'o',
        .KEY_P => return if (state.modifiers.shift) 'P' else 'p',
        .KEY_A => return if (state.modifiers.shift) 'A' else 'a',
        .KEY_S => return if (state.modifiers.shift) 'S' else 's',
        .KEY_D => return if (state.modifiers.shift) 'D' else 'd',
        .KEY_F => return if (state.modifiers.shift) 'F' else 'f',
        .KEY_G => return if (state.modifiers.shift) 'G' else 'g',
        .KEY_H => return if (state.modifiers.shift) 'H' else 'h',
        .KEY_J => return if (state.modifiers.shift) 'J' else 'j',
        .KEY_K => return if (state.modifiers.shift) 'K' else 'k',
        .KEY_L => return if (state.modifiers.shift) 'L' else 'l',
        .KEY_Z => return if (state.modifiers.shift) 'Z' else 'z',
        .KEY_X => return if (state.modifiers.shift) 'X' else 'x',
        .KEY_C => return if (state.modifiers.shift) 'C' else 'c',
        .KEY_V => return if (state.modifiers.shift) 'V' else 'v',
        .KEY_B => return if (state.modifiers.shift) 'B' else 'b',
        .KEY_N => return if (state.modifiers.shift) 'N' else 'n',
        .KEY_M => return if (state.modifiers.shift) 'M' else 'm',
        else => return null,
    }
}
