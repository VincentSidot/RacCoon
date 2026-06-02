const io = @import("io.zig");

const pic1_cmd: u16 = 0x20;
const pic1_data: u16 = 0x21;
const pic2_cmd: u16 = 0xA0;
const pic2_data: u16 = 0xA1;

const icw1_init: u8 = 0x10;
const icw1_icw4: u8 = 0x01;
const icw4_8086: u8 = 0x01;

pub const irq_base_master: u8 = 32;
pub const irq_base_slave: u8 = 40;
pub const keyboard_vector: u8 = irq_base_master + 1;

pub fn initKeyboardOnly() void {
    io.outb(pic1_cmd, icw1_init | icw1_icw4);
    io.outb(pic2_cmd, icw1_init | icw1_icw4);

    io.outb(pic1_data, irq_base_master);
    io.outb(pic2_data, irq_base_slave);

    io.outb(pic1_data, 0x04); // slave on IRQ2
    io.outb(pic2_data, 0x02); // slave identity

    io.outb(pic1_data, icw4_8086);
    io.outb(pic2_data, icw4_8086);

    io.outb(pic1_data, 0xFD); // enable IRQ1 only
    io.outb(pic2_data, 0xFF); // disable all slave IRQs
}

pub fn eoi(irq: u8) void {
    if (irq >= 8) io.outb(pic2_cmd, 0x20);
    io.outb(pic1_cmd, 0x20);
}
