; stage3.s  –  64-bit entry trampoline
; Entered via far jump from stage2 at 0x8200.
;
; Responsibility:
;   1. Set up kernel stack at 0x90000
;   2. Enable FPU  (CR0: clear EM bit 2, set MP bit 1)
;   3. Enable SSE  (CR4: set OSFXSR bit 9, OSXMMEXCPT bit 10)
;   4. Call Zig kernel entry at KENTRY (0x8400)
;
; CPU state on entry (guaranteed by stage2):
;   - 64-bit long mode active, CS = 0x08
;   - Identity paging for 0–4 GiB
;   - Interrupts disabled (no IDT yet)

use64
org 0x8200

KENTRY = 0x8400     ; first byte of the Zig kernel, immediately after this blob

macro ASSERT_SIZE target_size {
    times (target_size - ($ - $$)) db 0
}

start64:
    ; ── Stack ────────────────────────────────────────────────────────────────
    mov rsp, 0x90000
    xor rbp, rbp                    ; clear frame pointer (no caller frame)

    ; ── FPU ──────────────────────────────────────────────────────────────────
    ; Clear EM (bit 2) so FPU instructions are not emulated.
    ; Set  MP (bit 1) so WAIT/FWAIT check for a pending FPU exception.
    mov rax, cr0
    and eax, 0xFFFFFFFB             ; clear EM
    or  eax, 0x00000002             ; set MP
    mov cr0, rax

    ; ── SSE ──────────────────────────────────────────────────────────────────
    ; Set OSFXSR   (bit 9)  – OS saves/restores XMM state with FXSAVE/FXRSTOR.
    ; Set OSXMMEXCPT (bit 10) – OS handles SIMD floating-point exceptions.
    mov rax, cr4
    or  eax, 0x00000600
    mov cr4, rax

    ; ── Jump to Zig kernel ────────────────────────────────────────────────────
    ; `call` (not `jmp`) so the pushed return address makes RSP % 16 = 8 at
    ; KENTRY, satisfying the x86-64 SysV ABI.  kentry is noreturn so the
    ; address is never consumed.
    call KENTRY

    ; Should never be reached.
  .halt:
    hlt
    jmp .halt

ASSERT_SIZE 512
