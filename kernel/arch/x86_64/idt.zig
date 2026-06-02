const std = @import("std");
const kpanic = @import("../../panic.zig");
const pic = @import("pic.zig");
const io = @import("io.zig");

const Idtr = packed struct {
    limit: u16,
    base: u64,
};

const IdtEntry = packed struct {
    offset_low: u16,
    selector: u16,
    ist: u8,
    try_attr: u8,
    offset_mid: u16,
    offset_high: u32,
    zero: u32,

    /// Helper to create an empty IDT entry
    const missing: IdtEntry = .{
        .offset_low = 0,
        .selector = 0,
        .ist = 0,
        .try_attr = 0,
        .offset_mid = 0,
        .offset_high = 0,
        .zero = 0,
    };

    // In stage2, gdt64 is set up with:
    // index 0: null
    // index 1: kernel code segment <-- this is the one we want to use for our interrupt handlers
    // index 2: kernel data segment
    // TODO: I need to be able to ensure alignment with the stage2.s gdt64 setup
    const kernel_code_selector: u16 = 0x08; // TODO: This should be defined in the GDT module

    fn setGate(vector: u8, handler: usize) void {
        idt[vector] = .{
            .offset_low = @truncate(handler),
            .selector = kernel_code_selector,
            .ist = 0,
            .try_attr = 0x8E, // Interrupt gate, present, DPL=0
            .offset_mid = @truncate(handler >> 16),
            .offset_high = @truncate(handler >> 32),
            .zero = 0,
        };
    }
};

pub const InterruptFrame = extern struct {
    // Registers snapshot by the CPU during an interrupt
    // zlinter-disable field_naming - field names mirror x86-64 CPU registers
    r15: u64,
    r14: u64,
    r13: u64,
    r12: u64,
    r11: u64,
    r10: u64,
    r9: u64,
    r8: u64,
    rbp: u64,
    rdi: u64,
    rsi: u64,
    rdx: u64,
    rcx: u64,
    rbx: u64,
    rax: u64,

    vector: u64,
    error_code: u64, // Some interrupts push an error code, others don't

    rip: u64,
    cs: u64,
    rflags: u64,
    // zlinter-enable field_naming
};

const idt_len = 256;

var idt: [idt_len]IdtEntry = [_]IdtEntry{IdtEntry.missing} ** idt_len;

extern fn __isr0() callconv(.naked) void;
extern fn __isr6() callconv(.naked) void;
extern fn __isr8() callconv(.naked) void;
extern fn __isr13() callconv(.naked) void;
extern fn __isr14() callconv(.naked) void;
extern fn __isr33() callconv(.naked) void;

fn setupHandlers() void {
    IdtEntry.setGate(0, @intFromPtr(&__isr0)); // Divide by zero
    IdtEntry.setGate(6, @intFromPtr(&__isr6)); // Invalid opcode
    IdtEntry.setGate(8, @intFromPtr(&__isr8)); // Double fault
    IdtEntry.setGate(13, @intFromPtr(&__isr13)); // General protection fault
    IdtEntry.setGate(14, @intFromPtr(&__isr14)); // Page fault
    IdtEntry.setGate(33, @intFromPtr(&__isr33)); // Timer interrupt (IRQ0)
}

var idtr: Idtr = undefined;

extern fn __load_idt(*const Idtr) callconv(.c) void;

pub fn init() void {
    setupHandlers();

    idtr.limit = @sizeOf(@TypeOf(idt)) - 1;
    idtr.base = @intFromPtr(&idt);

    __load_idt(&idtr);
}

pub var last_scancode: u8 = 0;

export fn zigInterruptDispatch(frame: *InterruptFrame) callconv(.c) void {
    var buffer: [256]u8 = undefined;

    switch (frame.vector) {
        0 => {
            kpanic.onMsg("Divide by zero");
        },
        6 => {
            kpanic.onMsg("Invalid opcode");
        },
        8 => {
            const msg = std.fmt.bufPrint(
                &buffer,
                "Error code: 0x{x}",
                .{frame.error_code},
            ) catch "";
            kpanic.onMsgExt("Double fault", msg);
        },
        13 => {
            const msg = std.fmt.bufPrint(
                &buffer,
                "Error code: 0x{x}",
                .{frame.error_code},
            ) catch "";
            kpanic.onMsgExt("General protection fault", msg);
        },
        14 => {
            var fault_address: usize = undefined;
            asm volatile (
                \\ movq %cr2, %[addr]
                : [addr] "=r" (fault_address),
            );

            const msg = std.fmt.bufPrint(
                &buffer,
                "Fault address: 0x{x}",
                .{fault_address},
            ) catch "";
            kpanic.onMsgExt("Page fault", msg);
        },
        33 => {
            last_scancode = io.inb(0x60);
            pic.eoi(1);

            // For now, let's panic on keyboard interrupts
            const msg = std.fmt.bufPrint(
                &buffer,
                "Scancode: 0x{x}",
                .{last_scancode},
            ) catch "";

            kpanic.onMsgExt("Keyboard interrupt", msg);
        },
        else => {
            kpanic.onMsg("Unhandled CPU exception");
        },
    }
}
