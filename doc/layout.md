# Memory & Disk Layout

Reference for the physical memory map, disk image structure, and virtual address
space as they exist after the kernel has booted.

---

## Disk Image Layout

The final `boot.bin` is a raw disk image built by concatenating four flat binaries.
The BIOS loads sector 0 automatically; stage1 loads the rest.

```
Sector   LBA   Physical    Size     Contents
──────────────────────────────────────────────────────────────────────
  0       0    0x7C00     512 B    stage1.s   – 16-bit real-mode bootloader
  1       1    0x8000     512 B    stage2.s   – 32-bit protected-mode trampoline
  2       2    0x8200     512 B    stage3.s   – 64-bit entry trampoline
  3+      3    0x8400     variable kernel     – 64-bit Zig kernel (kentry at 0x8400)
```

> `STAGE2_SIZE` passed to `fasm` when assembling `stage1.s` equals the total
> byte count of **stage2 + stage3 + kernel** (all padded to 512-byte sector boundaries).

---

## Physical Memory Map (at kernel entry)

```
Physical address   Size      Who sets it      Contents
───────────────────────────────────────────────────────────────────────────────
0x0000 – 0x03FF    1 KB      BIOS             Real-mode Interrupt Vector Table
0x0400 – 0x04FF    256 B     BIOS             BIOS Data Area (BDA)
0x0500 – 0x0FFF    ~3 KB     —                (free / unused)

0x1000 – 0x1FFF    4 KB      stage2.s         PML4  – Page-Map Level-4 table (1 entry)
0x2000 – 0x2FFF    4 KB      stage2.s         PDPT  – Page-Directory Pointer Table (4 entries)
0x3000 – 0x3FFF    4 KB      stage2.s         PD0   – Page Directory for GiB 0 (0x00000000 – 0x3FFFFFFF)
0x4000 – 0x4FFF    4 KB      stage2.s         PD1   – Page Directory for GiB 1 (0x40000000 – 0x7FFFFFFF)
0x5000 – 0x5FFF    4 KB      stage2.s         PD2   – Page Directory for GiB 2 (0x80000000 – 0xBFFFFFFF)
0x6000 – 0x6FFF    4 KB      stage2.s         PD3   – Page Directory for GiB 3 (0xC0000000 – 0xFFFFFFFF)
                                               (stage1 used 0x6000 as a temp VBE mode-info buffer,
                                                but copied the needed fields to 0x7000 first)

0x7000 – 0x700A    11 B      stage1.s         Framebuffer info struct (see below)
0x700B – 0x7BFF    ~3 KB     —                (free / unused)

0x7C00 – 0x7DFF    512 B     BIOS             stage1 (BIOS loads the MBR here)
0x7E00 – 0x7FFF    512 B     —                (free / unused)

0x8000 – 0x81FF    512 B     stage1.s         stage2.s flat binary
0x8200 – 0x83FF    512 B     stage1.s         stage3.s flat binary
0x8400 – …         variable  stage1.s         Zig kernel flat binary (kentry at 0x8400)

         …

0x90000            —         stage3.s         Stack top (RSP; grows downward)
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

The QEMU/Bochs linear framebuffer for mode `0x142` sits at approximately
`0xFD000000` (~3.95 GiB), which is why the page tables must cover the full 4 GiB.

---

## Page Tables (`0x1000 – 0x6FFF`)

Set up by `stage2.s` using 2 MiB huge pages (no level-3 PT needed).
Six consecutive 4 KiB frames are zeroed and then populated.

```
CR3 ──► PML4[0] ──► PDPT[0] ──► PD0[0..511]   → 0x0000_0000 – 0x3FFF_FFFF  (GiB 0)
                    PDPT[1] ──► PD1[0..511]   → 0x4000_0000 – 0x7FFF_FFFF  (GiB 1)
                    PDPT[2] ──► PD2[0..511]   → 0x8000_0000 – 0xBFFF_FFFF  (GiB 2)
                    PDPT[3] ──► PD3[0..511]   → 0xC000_0000 – 0xFFFF_FFFF  (GiB 3)
```

- Covers the first **4 GiB** of physical memory (2048 entries × 2 MiB each).
- All entries are **present + writable**; user-accessible bit is not set (ring 0 only).
- Virtual address == physical address (identity mapping).
- The framebuffer at ~`0xFD000000` falls in GiB 3 and is therefore accessible.

---

## Virtual Address Space (at kernel entry)

```
Virtual address                       Mapped to              Notes
─────────────────────────────────────────────────────────────────────────────
0x0000_0000_0000_0000
  – 0x0000_0000_FFFF_FFFF             Physical 0 – 4 GiB    Identity map (stage2.s)
0x0000_0001_0000_0000
  – 0xFFFF_FFFF_FFFF_FFFF             —                      Not mapped (page fault)
```

> The identity map is intentionally minimal. A proper higher-half or full virtual
> memory layout should be established by the kernel's memory manager before
> userspace or large allocations are needed.

---

## Boot Sequence Summary

```
Power on
  └─ BIOS loads sector 0 → 0x7C00, jumps to stage1

stage1  (real mode, 16-bit, 0x7C00)
  ├─ Detects and sets VBE framebuffer mode 0x142
  ├─ Saves framebuffer info → 0x7000
  ├─ Loads (stage2 + stage3 + kernel) sectors → 0x8000
  ├─ Sets up flat 32-bit GDT, sets CR0.PE
  └─ Far jumps to 0x8000  →  stage2

stage2  (protected mode, 32-bit, 0x8000)
  ├─ Zeroes page table region 0x1000 – 0x6FFF  (6 × 4 KiB frames)
  ├─ Builds identity-map PML4/PDPT/PD0–PD3 (4 GiB, 2 MiB pages)
  ├─ Enables PAE, loads CR3, sets EFER.LME, enables paging
  ├─ Installs 64-bit GDT
  └─ Far jumps to 0x8200 (64-bit CS)  →  stage3

stage3  (long mode, 64-bit, 0x8200)
  ├─ Sets RSP = 0x90000, clears RBP
  ├─ Enables FPU  (CR0: clear EM, set MP)
  ├─ Enables SSE  (CR4: set OSFXSR, OSXMMEXCPT)
  └─ call 0x8400  →  kernel kentry
     (call rather than jmp ensures RSP % 16 == 8, satisfying the SysV ABI)

kernel  (long mode, 64-bit, 0x8400)
  ├─ kentry() (entrypoint.zig): kernel entry point
  └─ kmain()  (kmain.zig):      kernel main loop
```
