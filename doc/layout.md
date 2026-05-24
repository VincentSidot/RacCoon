# Memory & Disk Layout

Reference for the physical memory map, disk image structure, and virtual address
space as they exist after the kernel has booted.

---

## Disk Image Layout

The final `boot.bin` is a raw disk image built by concatenating three flat binaries.
The BIOS loads sector 0 automatically; stage1 loads the rest.

```
Sector   LBA   Physical    Size     Contents
──────────────────────────────────────────────────────────
  0       0    0x7C00     512 B    stage1.s   – 16-bit real-mode bootloader
  1       1    0x8000     512 B    stage2.s   – 32-bit long-mode trampoline
  2+      2    0x8200     variable kernel     – 64-bit Zig kernel
```

> `STAGE2_SIZE` passed to `fasm` when assembling `stage1.s` equals the total
> byte count of **stage2 + kernel** (both padded to 512-byte sector boundaries).

---

## Physical Memory Map (at kernel entry)

```
Physical address   Size      Who sets it      Contents
───────────────────────────────────────────────────────────────────────────────
0x0000 – 0x03FF    1 KB      BIOS             Real-mode Interrupt Vector Table
0x0400 – 0x04FF    256 B     BIOS             BIOS Data Area (BDA)
0x0500 – 0x0FFF    ~3 KB     —                (free / unused)

0x1000 – 0x1FFF    4 KB      stage2.s         PML4  – Page-Map Level-4 table
0x2000 – 0x2FFF    4 KB      stage2.s         PDPT  – Page-Directory Pointer Table
0x3000 – 0x3FFF    4 KB      stage2.s         PD    – Page Directory (2 MiB huge pages)

0x4000 – 0x5FFF    8 KB      —                (free / unused)

0x6000 – 0x6FFF    256 B     stage1.s (BIOS)  VBE mode info block (INT 10h / AX=4F01h)
0x7000 – 0x700A    11 B      stage1.s         Framebuffer info struct (see below)
0x700B – 0x7BFF    ~3 KB     —                (free / unused)

0x7C00 – 0x7DFF    512 B     BIOS             stage1 (BIOS loads the MBR here)
0x7E00 – 0x7FFF    512 B     —                (free / unused)

0x8000 – 0x81FF    512 B     stage1.s         stage2.s flat binary
0x8200 – …         variable  stage1.s         Zig kernel flat binary (_start at 0x8200)

         …

0x90000            —         entry.zig        Stack top (RSP/RBP; grows downward)
```

---

## Framebuffer Info Struct  (`0x7000`)

Extracted from the VBE mode info block by `stage1.s` and read at runtime by
`kernel/drivers/framebuffer.zig` via `@ptrFromInt(0x7000)`.

```
Offset   Size   Field                   Source in VBE mode info block
────────────────────────────────────────────────────────────────────
+0x00    u32    Physical base address   [+0x28] PhysBasePtr
+0x04    u16    Pitch (bytes/scanline)  [+0x10] BytesPerScanline
+0x06    u16    Width  (pixels)         [+0x12] XResolution
+0x08    u16    Height (pixels)         [+0x14] YResolution
+0x0A    u8     Bits per pixel          [+0x19] BitsPerPixel
```

VBE mode used: `0x142` (1024 × 768 × 32 bpp, linear framebuffer).
Fallback:       `0x112` (640 × 480 × 24 bpp) — change `VBE_MODE` in `stage1.s`.

---

## Page Tables (`0x1000 – 0x3FFF`)

Set up by `stage2.s` using 2 MiB huge pages (no level-4 PT needed).

```
CR3 ──► PML4[0] ──► PDPT[0] ──► PD[0]   → 0x000000 – 0x1FFFFF  (2 MiB)
                               PD[1]   → 0x200000 – 0x3FFFFF
                               …
                               PD[511] → 0x3FE00000 – 0x3FFFFFFF
```

- Covers the first **1 GiB** of physical memory.
- All entries are **present + writable**; user-accessible bit is not set (ring 0 only).
- Virtual address == physical address (identity mapping) — no translation overhead,
  all hardcoded physical addresses in the kernel work without adjustment.

---

## Virtual Address Space (at kernel entry)

```
Virtual address         Mapped to            Notes
───────────────────────────────────────────────────────────────
0x0000_0000_0000_0000
  – 0x0000_0000_3FFF_FFFF   Physical 0 – 1 GiB   Identity map (stage2.s)
0x0000_0000_4000_0000
  – 0xFFFF_FFFF_FFFF_FFFF   —                     Not mapped (page fault)
```

> The identity map is intentionally minimal. A proper higher-half or full virtual
> memory layout should be established by the kernel's memory manager before
> userspace or large allocations are needed.

---

## Boot Sequence Summary

```
Power on
  └─ BIOS loads sector 0 → 0x7C00, jumps to stage1

stage1  (real mode, 16-bit)
  ├─ Detects and sets VBE framebuffer mode 0x142
  ├─ Saves framebuffer info → 0x7000
  ├─ Loads (stage2 + kernel) sectors → 0x8000
  ├─ Sets up flat 32-bit GDT, sets CR0.PE
  └─ Far jumps to 0x8000  →  stage2

stage2  (protected mode, 32-bit)
  ├─ Zeroes page table region 0x1000 – 0x3FFF
  ├─ Builds identity-map PML4/PDPT/PD (1 GiB, 2 MiB pages)
  ├─ Enables PAE, loads CR3, sets EFER.LME, enables paging
  ├─ Installs 64-bit GDT
  └─ Far jumps to 0x8200 (64-bit CS)  →  kernel _start

kernel  (long mode, 64-bit)
  ├─ _start (entry.zig): sets up RSP/RBP, enables FPU/SSE
  ├─ kentry(): calls kmain()
  └─ kmain(): kernel main loop
```
