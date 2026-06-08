//! PS/2 keyboard driver: reads scancodes off the hardware in the IRQ handler,
//! parses them (see `scancodes.zig`), buffers key events in a lock-free queue,
//! and exposes them to consumers as `ScanCodeEvent`s / characters.

const io = @import("../arch.zig").io;
const spsc = @import("../lib/data/spsc.zig");
const scancodes = @import("scancodes.zig");
const arch = @import("../arch.zig");

const InterruptFrame = arch.idt.InterruptFrame;
const KeyEvent = scancodes.KeyEvent;
const pic = arch.pic;
const registerInterruptHandler = arch.idt.registerInterruptHandler;

pub const PhysicalKeyCode = scancodes.PhysicalKeyCode;

// ============================================================================
// Public event types
// ============================================================================

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

pub const Metadata = packed struct {
    missed_events: bool,
    pressed: bool,

    pub const empty: Metadata = .{
        .missed_events = false,
        .pressed = false,
    };
};

pub const ScanCodeEvent = packed struct {
    keycode: PhysicalKeyCode,
    modifiers: Modifiers = .empty,
    state: Metadata = .empty,
};

// ============================================================================
// Driver state
// ============================================================================

const buffer_size: usize = 256;
var buffer: [buffer_size]KeyEvent = undefined;

const Keyboard = struct {
    parser: scancodes.Parser = .{},
    queue: spsc.SpscRing(KeyEvent) = .initWithBuffer(&buffer),
    last_modifier: Modifiers = .empty,
};

var state: Keyboard = .{};

// ============================================================================
// IRQ side (producer)
// ============================================================================

fn onKeyboardInterrupt() void {
    const code = io.inb(0x60);
    if (state.parser.feed(code)) |event| {
        state.queue.emit(event);
    }
}

fn keyboardInterruptHandler(frame: *const InterruptFrame) void {
    _ = frame;
    onKeyboardInterrupt();
    pic.eoi(1);
}

pub fn registerKeyboardInterruptHandler() void {
    registerInterruptHandler(33, keyboardInterruptHandler);
}

// ============================================================================
// Event API (consumer)
// ============================================================================

fn updateModifiers(event: KeyEvent) void {
    // zlinter-disable-next-line require_exhaustive_enum_switch - only modifier keys are relevant; all other keys are intentionally ignored.
    switch (event.keycode) {
        .KEY_LSHIFT, .KEY_RSHIFT => state.last_modifier.shift = event.pressed,
        .KEY_LCTRL, .KEY_RCTRL => state.last_modifier.ctrl = event.pressed,
        .KEY_LALT, .KEY_RALT => state.last_modifier.alt = event.pressed,
        else => {},
    }
}

pub fn readRawEvent() ?ScanCodeEvent {
    var has_missed_events: bool = false;

    const raw_event = state.queue.consumeExt(&has_missed_events) catch |err| switch (err) {
        error.QueueEmpty => return null,
        error.ProducerOverrun => return null, // TODO#4 (low): we should probably handle this case better
    };

    const metadata: Metadata = .{
        .missed_events = has_missed_events,
        .pressed = raw_event.pressed,
    };

    if (has_missed_events) {
        // Reset modifiers
        state.last_modifier = .empty;
    }

    // Handle modifiers
    updateModifiers(raw_event);

    const event: ScanCodeEvent = .{
        .keycode = raw_event.keycode,
        .modifiers = state.last_modifier,
        .state = metadata,
    };

    return event;
}

/// Note: this function consume the key event, even if it's not a char event (e.g. shift press).
/// Only key presses produce a char; releases (break codes) are ignored so each
/// keystroke yields a single character.
pub fn readCharEvent() ?u8 {
    const event = readRawEvent() orelse return null;
    if (!event.state.pressed) return null;

    return convertKeycodeToChar(event);
}

// ============================================================================
// Character translation
// ============================================================================

/// This function is not handling all the available ascii characters.
pub fn convertKeycodeToChar(event: ScanCodeEvent) ?u8 {
    // zlinter-disable-next-line require_exhaustive_enum_switch - only printable/whitespace keys map to a char; the rest return null via `else`.
    switch (event.keycode) {
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
        .KEY_Q => return if (event.modifiers.shift) 'Q' else 'q',
        .KEY_W => return if (event.modifiers.shift) 'W' else 'w',
        .KEY_E => return if (event.modifiers.shift) 'E' else 'e',
        .KEY_R => return if (event.modifiers.shift) 'R' else 'r',
        .KEY_T => return if (event.modifiers.shift) 'T' else 't',
        .KEY_Y => return if (event.modifiers.shift) 'Y' else 'y',
        .KEY_U => return if (event.modifiers.shift) 'U' else 'u',
        .KEY_I => return if (event.modifiers.shift) 'I' else 'i',
        .KEY_O => return if (event.modifiers.shift) 'O' else 'o',
        .KEY_P => return if (event.modifiers.shift) 'P' else 'p',
        .KEY_A => return if (event.modifiers.shift) 'A' else 'a',
        .KEY_S => return if (event.modifiers.shift) 'S' else 's',
        .KEY_D => return if (event.modifiers.shift) 'D' else 'd',
        .KEY_F => return if (event.modifiers.shift) 'F' else 'f',
        .KEY_G => return if (event.modifiers.shift) 'G' else 'g',
        .KEY_H => return if (event.modifiers.shift) 'H' else 'h',
        .KEY_J => return if (event.modifiers.shift) 'J' else 'j',
        .KEY_K => return if (event.modifiers.shift) 'K' else 'k',
        .KEY_L => return if (event.modifiers.shift) 'L' else 'l',
        .KEY_Z => return if (event.modifiers.shift) 'Z' else 'z',
        .KEY_X => return if (event.modifiers.shift) 'X' else 'x',
        .KEY_C => return if (event.modifiers.shift) 'C' else 'c',
        .KEY_V => return if (event.modifiers.shift) 'V' else 'v',
        .KEY_B => return if (event.modifiers.shift) 'B' else 'b',
        .KEY_N => return if (event.modifiers.shift) 'N' else 'n',
        .KEY_M => return if (event.modifiers.shift) 'M' else 'm',
        else => return null,
    }
}
