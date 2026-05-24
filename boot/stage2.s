; stage2.s  –  32-bit protected-mode trampoline
; Loaded at 0x8000 by stage1 (padded to exactly 512 bytes).
;
; Responsibility:
;   1. Build minimal identity-map page tables (first 4 GiB, 2 MiB huge pages)
;   2. Enable PAE + EFER.LME + paging  →  CPU atomically enters 64-bit long mode
;   3. Install 64-bit GDT
;   4. Far-jump into the Zig kernel at KERNEL_ENTRY (0x8200)

use32
org 0x8000

KERNEL_ENTRY = 0x8200       ; Zig _start, immediately after this 512-byte blob

; Page table locations (six consecutive 4 KiB frames in unused low memory)
;
;   0x1000  PML4  – page-map level 4 (1 entry used)
;   0x2000  PDPT  – page-directory pointer table (4 entries, covering 0–4 GiB)
;   0x3000  PD0   – page directory for GiB 0  (0x00000000 – 0x3FFFFFFF)
;   0x4000  PD1   – page directory for GiB 1  (0x40000000 – 0x7FFFFFFF)
;   0x5000  PD2   – page directory for GiB 2  (0x80000000 – 0xBFFFFFFF)
;   0x6000  PD3   – page directory for GiB 3  (0xC0000000 – 0xFFFFFFFF)
;
; Note: 0x6000 was used by stage1 as a temporary VBE mode-info buffer, but
; stage1 already copied the needed fields to 0x7000 before jumping here,
; so overwriting 0x6000 as PD3 is safe.
;
; The 4 GiB range covers the BOCHS/QEMU linear framebuffer which sits at
; ~0xFD000000 for mode 0x142 (1024×768×32 bpp).
PML4 = 0x1000
PDPT = 0x2000
PD   = 0x3000               ; base of PD0; PD1–PD3 follow contiguously at +0x1000 each

macro ASSERT_SIZE target_size {
    times (target_size - ($ - $$)) db 0
}

start32:
    cli

    ; --- Zero all six page-table frames (6 × 4 KiB) ---
    mov edi, PML4
    xor eax, eax
    mov ecx, (6 * 0x1000) / 4      ; 6144 dwords
    rep stosd

    ; PML4[0] → PDPT  (present | writable)
    mov dword [PML4],     PDPT or 0x3
    mov dword [PML4 + 4], 0

    ; PDPT[0..3] → PD0..PD3  (present | writable)
    ; PD[i] is at 0x3000 + i*0x1000; each covers one 1-GiB window.
    mov ecx, 0
  .fill_pdpt:
    mov eax, ecx
    shl eax, 12                     ; i * 0x1000
    add eax, PD or 0x3              ; base of PD[i] | present | writable
    mov [PDPT + ecx * 8],     eax
    mov dword [PDPT + ecx * 8 + 4], 0
    inc ecx
    cmp ecx, 4
    jl  .fill_pdpt

    ; PD[i] → i × 2 MiB  (present | writable | PS huge page)
    ; 2048 entries × 2 MiB = 4 GiB identity-mapped.
    ; Entries 0–511 land in PD0 (0x3000), 512–1023 in PD1 (0x4000), etc.,
    ; because the four PD frames are contiguous: 0x3000 + ecx*8 spans
    ; 0x3000–0x6FF8 for ecx in [0, 2047].
    mov ecx, 0
  .fill_pd:
    mov eax, ecx
    shl eax, 21                     ; physical base = i × 2 MiB (≤ 0xFFE00000, fits u32)
    or  eax, 0x83                   ; present | writable | PS
    mov [PD + ecx * 8],     eax
    mov dword [PD + ecx * 8 + 4], 0
    inc ecx
    cmp ecx, 2048
    jl  .fill_pd

    ; --- Activate long mode ---

    ; 1. Enable PAE (CR4[5] = 0x20)
    mov eax, cr4
    or  eax, 0x20
    mov cr4, eax

    ; 2. Point CR3 at PML4
    mov eax, PML4
    mov cr3, eax

    ; 3. Set EFER.LME (MSR 0xC000_0080, bit 8 = 0x100)
    mov ecx, 0xC0000080
    rdmsr
    or  eax, 0x100
    wrmsr

    ; 4. Enable paging (CR0[31] = 0x80000000)
    ;    CPU atomically activates long mode because EFER.LME is set
    mov eax, cr0
    or  eax, 0x80000000
    mov cr0, eax

    ; 5. Install 64-bit GDT, then far-jump into 64-bit code segment (0x08)
    ;    This far jump switches from 32-bit compatibility submode to full 64-bit mode.
    lgdt [gdt64_ptr]
    jmp  0x08:KERNEL_ENTRY

; ── 64-bit GDT ──────────────────────────────────────────────────────────────
align 8
gdt64:
  .null:                            ; null descriptor (required by spec)
    dq 0
  .code:                            ; selector 0x08 – ring-0 code, 64-bit
    dw 0xFFFF                       ; limit[15:0]   (ignored in long mode)
    dw 0x0000                       ; base[15:0]    (ignored in long mode)
    db 0x00                         ; base[23:16]   (ignored in long mode)
    db 10011010b                    ; P=1 DPL=0 S=1 E=1 DC=0 RW=1 A=0
    db 00100000b                    ; G=0 D=0 L=1 AVL=0 | limit[19:16]=0
    db 0x00                         ; base[31:24]   (ignored in long mode)
  .data:                            ; selector 0x10 – ring-0 data
    dw 0xFFFF
    dw 0x0000
    db 0x00
    db 10010010b                    ; P=1 DPL=0 S=1 E=0 DC=0 RW=1 A=0
    db 00000000b
    db 0x00
gdt64_end:

gdt64_ptr:
    dw gdt64_end - gdt64 - 1       ; limit
    dd gdt64                        ; base (32-bit; zero-extended to 64-bit by CPU)

; ── Pad to exactly 512 bytes so KERNEL_ENTRY is at the known address 0x8200 ─
ASSERT_SIZE 512
