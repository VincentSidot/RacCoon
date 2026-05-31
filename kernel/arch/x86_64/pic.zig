const io = @import("io.zig");

const PIC1_CMD: u16 = 0x20;
const PIC1_DATA: u16 = 0x21;
const PIC2_CMD: u16 = 0xA0;
const PIC2_DATA: u16 = 0xA1;

const ICW1_INIT: u8 = 0x10;
const ICW1_ICW4: u8 = 0x01;
const ICW4_8086: u8 = 0x01;

pub const IRQ_BASE_MASTER: u8 = 32;
pub const IRQ_BASE_SLAVE: u8 = 40;
pub const KEYBOARD_VECTOR: u8 = IRQ_BASE_MASTER + 1;

pub fn init_keyboard_only() void {
    io.outb(PIC1_CMD, ICW1_INIT | ICW1_ICW4);
    io.outb(PIC2_CMD, ICW1_INIT | ICW1_ICW4);

    io.outb(PIC1_DATA, IRQ_BASE_MASTER);
    io.outb(PIC2_DATA, IRQ_BASE_SLAVE);

    io.outb(PIC1_DATA, 0x04); // slave on IRQ2
    io.outb(PIC2_DATA, 0x02); // slave identity

    io.outb(PIC1_DATA, ICW4_8086);
    io.outb(PIC2_DATA, ICW4_8086);

    io.outb(PIC1_DATA, 0xFD); // enable IRQ1 only
    io.outb(PIC2_DATA, 0xFF); // disable all slave IRQs
}

pub fn eoi(irq: u8) void {
    if (irq >= 8) io.outb(PIC2_CMD, 0x20);
    io.outb(PIC1_CMD, 0x20);
}
