pub const KeyEvent = struct {
    keycode: u8,
    pressed: bool,
};

const event_buffer_size = 256;
var event_buffer: [event_buffer_size]KeyEvent = undefined;
var current_event_index: usize = 0;

pub const Keyboard = struct {};
