# RacCoon

A minimal x86_64 hobby OS kernel written in Zig, booted by a hand-written multi-stage bootloader.

## Architecture

The boot pipeline transitions the CPU through three modes before reaching the kernel:

```
stage1 (real mode, 0x7C00)
  → sets VBE graphics mode, loads stage2+stage3+kernel into RAM
stage2 (protected mode, 0x8000)
  → builds 4 GiB identity-mapped page tables (2 MiB huge pages)
  → enables PAE, EFER.LME, and paging → jumps to stage3
stage3 (64-bit long mode, 0x8200)
  → sets up RSP, enables FPU/SSE → calls kernel at 0x8400
kernel (64-bit, 0x8400)
  → kentry → kmain
```

## Requirements

- [Zig](https://ziglang.org/) 0.14+
- [FASM](https://flatassembler.net/) (flat assembler)
- `qemu-system-x86_64`
- `gdb` (optional, for debugging)

## Build

```sh
zig build
```

Output files are placed in `zig-out/`:
- `boot.bin` — bootable raw disk image
- `kernel.elf` — kernel ELF with debug symbols (for GDB)

## Run

```sh
zig build run
```

## Debug

Break at each boot stage under GDB:

```sh
zig build debug16   # stage1 — real mode   (0x7C00)
zig build debug32   # stage2 — protected   (0x8000)
zig build debug64   # kernel — long mode   (0x8400)
```

GDB init files live in `scripts/gdb/`. Common helpers (register display, mode inspection) are in `scripts/gdb/common.gdb`.

## Project layout

```
boot/
  stage1.s      16-bit real-mode bootloader
  stage2.s      32-bit protected-mode trampoline + page tables
  stage3.s      64-bit entry trampoline
  kernel.ld     kernel linker script
kernel/
  entrypoint.zig  low-level entry point (kentry)
  kmain.zig       kernel main
  arch/           architecture-specific code
  drivers/        device drivers
  lib/            shared utilities
scripts/
  build.sh        assembles stages and produces the disk image
  run.sh          launches QEMU (with optional GDB server)
  gdb/            GDB init files per boot stage
doc/
  layout.md       memory layout details
```

## Known limitations

- No IDT / exception handlers yet — a fault causes a triple-fault and QEMU resets.
- `ReleaseSafe` is required; `Debug` mode produces a binary that breaks the custom linker script layout under Zig 0.16.
