# Debugging the OS Kernel

This document describes how to debug the kernel using **tmux + QEMU + GDB**.
All commands assume the working directory is the project root (`tryout2/`).

---

## Prerequisites

- `zig` 0.16+ — compiler
- `fasm` — assembler for bootloader stages
- `qemu-system-x86_64` — emulator
- `gdb` — debugger
- `tmux` — terminal multiplexer (for concurrent QEMU + GDB panes)

---

## Quick Start

```bash
# Build once
zig build

# Build + run + debug (all in one)
zig build debug64
```

`zig build debug64` runs `scripts/run.sh --debug64`, which:
1. Starts QEMU in headless mode (`-s -S`), listening on `localhost:1234`
2. Connects GDB with `scripts/gdb/64.gdb`
3. Breaks at `0x8400` (kernel entry `kentry`)
4. Exits automatically after the first prompt

---

## Interactive Debugging with tmux

For hands-on debugging, run QEMU and GDB in separate tmux panes:

### Step 1: Build

```bash
zig build
```

### Step 2: Start tmux session with QEMU (Pane 0)

```bash
tmux new-session -d -s osdev -n debug -x 200 -y 50
tmux send-keys -t osdev:debug.0 'qemu-system-x86_64 -name RacCoon -drive format=raw,file=zig-out/boot.bin -no-reboot -no-shutdown -s -S' Enter
sleep 1
```

> `-s` = expose GDB server on `localhost:1234`
> `-S` = freeze CPU at startup (wait for GDB to connect)

### Step 3: Split window + start GDB (Pane 1)

```bash
tmux split-window -v -t osdev:debug.0
tmux send-keys -t osdev:debug.1 'gdb' Enter
sleep 1

tmux send-keys -t osdev:debug.1 'set confirm off' Enter
tmux send-keys -t osdev:debug.1 'set architecture i386:x86-64' Enter
tmux send-keys -t osdev:debug.1 'file zig-out/kernel.elf' Enter
tmux send-keys -t osdev:debug.1 'target remote localhost:1234' Enter
tmux send-keys -t osdev:debug.1 'b *0x8400' Enter
tmux send-keys -t osdev:debug.1 'c' Enter
sleep 1
```

At this point:
- **Pane 0**: QEMU is running under GDB control
- **Pane 1**: GDB has connected to QEMU and stopped at `kentry` (`0x8400`)

### Step 4: Explore

```bash
# View registers
tmux send-keys -t osdev:debug.1 'info registers' Enter

# Disassemble at current instruction
tmux send-keys -t osdev:debug.1 'x/24i kentry' Enter

# Step one instruction at a time
tmux send-keys -t osdev:debug.1 'stepi' Enter

# Continue execution (kernel runs to completion → prints on QEMU screen)
tmux send-keys -t osdev:debug.1 'continue' Enter

# Interrupt a running kernel
tmux send-keys -t osdev:debug.1 C-c
```

### Step 5: Clean up

```bash
tmux kill-session -t osdev
```

---

## Memory Layout

| Address      | Size      | Content                          |
|--------------|-----------|----------------------------------|
| `0x00000`    | 512 B     | Stage 1: real-mode bootloader    |
| `0x07C00`    | 512 B     | Stage 2: 32-bit trampoline       |
| `0x08000`    | 512 B     | Stage 3: 64-bit entry            |
| `0x08400`    | ~500 KB   | Zig kernel (`kentry`, `kmain`)   |
| `0x02000000` | 6.2 MB    | Framebuffer (QEMU Q35)           |
| `0x6000`     | 512 B     | VBE mode info (stage1 scratch)   |
| `0x7000`     | 11 B      | FrameBufferInfo struct           |

### FrameBufferInfo at `0x7000`

This struct is populated by stage1 (real-mode VBE BIOS call) and consumed by the kernel.
It is a packed `extern struct` with no padding:

| Offset | Size | Field              | Description                  |
|--------|------|--------------------|------------------------------|
| `0x00` | 4 B  | `address`          | Framebuffer physical address |
| `0x04` | 2 B  | `pitch`            | Bytes per scanline           |
| `0x06` | 2 B  | `width`            | Screen width in pixels       |
| `0x08` | 2 B  | `height`           | Screen height in pixels      |
| `0x0A` | 1 B  | `bpp`              | Bits per pixel               |
| **Total** |   |                    | **11 bytes**                 |

### E820 Memory Map

The E820 memory map is located at `0x6000` (used as VBE mode info buffer by stage1).
This region is overwritten by page tables in stage2 (PD3 at `0x6000`) during long-mode setup.
The kernel does not need the E820 table — it relies solely on the framebuffer info at `0x7000`.

---

## Key Addresses & Symbols

| Symbol                          | Address  | Notes                        |
|---------------------------------|----------|------------------------------|
| `arch.x86.entry.kentry`         | `0x8400` | Kernel entry (first Zig code)|
| `kentry`                        | `0x8400` | (mangled name in ELF)        |
| `arch.x86.cpu.halt`             | `0xAFC0` | HLT loop                     |
| `panic.on_err`                  | `0xA8A0` | Panic handler (error)        |
| `panic.on_msg`                  | `0x9910` | Panic handler (message)      |
| `panic.render`                  | `0x9920` | Renders panic screen         |
| FrameBufferInfo                 | `0x7000` | Read-only from bootloader    |
| Framebuffer                     | `0x02000000` | Pixel data               |

---

## GDB Cheat Sheet (OS Dev Context)

### Architecture Switches

```gdb
set architecture i8086           # 16-bit real mode (stage1)
set architecture i386            # 32-bit protected mode (stage2)
set architecture i386:x86-64     # 64-bit long mode (kernel)
```

### Common Inspection Commands

```gdb
x/12i $rip                    # disassemble 12 instructions at RIP
x/10xg 0x7000                 # dump FrameBufferInfo as hex words
x/8xw 0x02000000              # dump framebuffer (32-bit words)
info registers                # all registers
info registers rip rsp        # specific registers
ptype FrameBufferInfo         # inspect struct type
print (void*)$rax             # cast register to pointer
```

### Useful Breakpoints

```gdb
b *0x8400                     # kernel entry (kentry)
b *0x8430                     # just before kmain call
b *arch.x86.cpu.halt          # kernel halt point
b panic.on_msg                # panic entry (if symbols accessible)
b *0xAFC0                     # CPU halt
```

### Step Control

```gdb
stepi                         # step one instruction
si                            # shorthand
nexti                         # step one, don't follow calls
continue                      # run until next breakpoint or halt
continue N                    # run N times before stopping
```

---

## Forcing a Panic During Debugging

The panic functions (`panic.on_msg`, `panic.render`) are internal symbols that may not be callable directly from GDB — Zig's name mangling, slice ABI, and visibility restrictions often prevent direct calls.

The reliable approach is to temporarily force a panic in the source and rebuild:

```zig
// In kernel/kmain.zig, before the body:
pub fn kmain() !void {
    return error.ForcedPanic;
    // ... original code
}
```

Then rebuild and debug:

```bash
zig build          # rebuild
# start GDB as described above
# kernel will halt at kentry, then panic before reaching cpu.halt()
```

When done, revert the change and rebuild.

---

## Troubleshooting

### QEMU doesn't start / no display

- Check that no other QEMU instance is running: `pkill -f qemu-system`
- On Wayland/Hyprland: ensure `XDG_RUNTIME_DIR` is set
- The `-s` flag only exposes the GDB server; the screen is still drawn if a display is available

### GDB can't find symbols

- Ensure `zig build` ran successfully (produces `zig-out/kernel.elf`)
- Use `file zig-out/kernel.elf` in GDB before connecting to target
- The `.elf` (not `.bin`) must be loaded for symbols

### Kernel panics / freezes

- Use `continue` then `Ctrl+C` to interrupt
- Check backtrace: `bt`
- Inspect FrameBufferInfo: `x/3xg 0x7000`
- Check if framebuffer is zeroed (no hardware/driver issue): `x/32xw 0x02000000`

### Pane targets don't resolve

If GDB panes become unreliable, inspect current layout:

```bash
tmux list-panes -t osdev          # see all pane IDs
tmux capture-pane -t osdev:debug.1 -p  # dump pane contents
```

Then re-target with the correct pane ID:

```bash
tmux send-keys -t osdev:debug.<N> 'gdb-command' Enter
```

To reset:

```bash
tmux kill-session -t osdev
# then start from Step 2
```
