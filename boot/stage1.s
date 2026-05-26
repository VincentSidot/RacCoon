; Stage 1 bootloader - 512 bytes
; Loads protected-mode stage2/kernel from LBA 1 using INT 13h extensions.
; The stage2 blob may include embedded image data.

; GDT entry selectors
CODE_SEL = 0x08
DATA_SEL = 0x10

; Address map
STAGE1_LOAD_ADDRESS = 0x0000_7C00
STAGE2_LOAD_ADDRESS = 0x0000_8000

; VBE Constants
VBE_MODE = 0x142  ; Current QEMU/BIOS mode observed as 640x480x32bpp
; VBE_MODE = 0x112 ; Current QEMU/BIOS mode observed as 640x480x24bpp
; TODO: write a proper query vbe mode function. (but painful in stage1 since asm 16-bit is not straightforward to write and debug)
VBE_LINEAR_FLAG = 0x4000

VBE_MODE_INFO_ADDRESS = 0x6000
VBE_INFO_ADDRESS = 0x7000

; Sizes
STAGE1_SIZE = 512
; STAGE2_SIZE is passed via -d flags and must be the final stage2/blob size in bytes.
STAGE2_SECTORS = (STAGE2_SIZE + 511) / 512

MAX_READ_SECTORS = 64

macro ASSERT_SIZE target_size {
    times (target_size - ($ - $$)) db 0
}

use16
org STAGE1_LOAD_ADDRESS

boot:
    cli
    cld

    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, STAGE1_LOAD_ADDRESS

    sti

    ; BIOS passes boot drive in DL.
    mov [boot_drive], dl

    ; Load stage2/kernel blob from LBA 1 to 0000:8000.
    mov word [dap_offset], STAGE2_LOAD_ADDRESS
    mov word [dap_segment], 0x0000
    mov dword [dap_lba], 1
    mov dword [dap_lba + 4], 0

    mov bx, STAGE2_SECTORS

    .load_stage2_loop:
    test bx, bx
    jz .stage2_loaded

    mov cx, MAX_READ_SECTORS
    cmp bx, cx
    ja .count_ready
    mov cx, bx

    .count_ready:
    mov word [dap_count], cx

    mov dl, [boot_drive]
    call read_lba
    jc disk_error

    ; Remaining sectors -= sectors read.
    sub bx, cx

    ; LBA += sectors_read.
    add word [dap_lba], cx
    adc word [dap_lba + 2], 0
    adc word [dap_lba + 4], 0
    adc word [dap_lba + 6], 0

    ; Destination += sectors_read * 512.
    ; Since 512 bytes = 32 paragraphs, advance segment by cx * 32.
    shl cx, 5
    add word [dap_segment], cx

    jmp .load_stage2_loop

    .stage2_loaded:
    ; Set up VBE mode and save framebuffer info for stage2/kernel.
    call setup_vbe

    ; Enter protected mode.
    cli

    lgdt [gdt_descriptor]

    mov eax, cr0
    or eax, 1
    mov cr0, eax

    ; Far jump: reload CS with protected-mode code selector.
    jmp CODE_SEL:STAGE2_LOAD_ADDRESS

; Setup VBE mode 0x112
setup_vbe:
    ; Get VBE mode info for mode 0x112.
    mov ax, 0x4F01 ; VBE function 01h: Return VBE Mode Information
    mov cx, VBE_MODE
    xor di, di
    mov es, di
    mov di, VBE_MODE_INFO_ADDRESS
    int 0x10
    cmp ax, 0x004F
    jne vbe_error

    ; Set VBE mode 0x112 with linear framebuffer.
    mov ax, 0x4F02 ; VBE function 02h: Set VBE Mode
    mov bx, VBE_MODE or VBE_LINEAR_FLAG
    int 0x10
    cmp ax, 0x004F
    jne vbe_error

    ; Save framebuffer info for protected-mode kernel.
    ; VBE mode info offsets:
    ; +0x10 word pitch / bytes per scanline
    ; +0x12 word width
    ; +0x14 word height
    ; +0x19 byte bits per pixel
    ; +0x28 dword physical framebuffer address

    xor ax, ax
    mov ds, ax
    mov si, VBE_MODE_INFO_ADDRESS
    mov di, VBE_INFO_ADDRESS

    mov eax, dword [si + 0x28] ; physical framebuffer address
    mov dword [di + 0], eax

    mov ax, word [si + 0x10] ; pitch
    mov word [di + 4], ax

    mov ax, word [si + 0x12] ; width
    mov word [di + 6], ax

    mov ax, word [si + 0x14] ; height
    mov word [di + 8], ax

    mov al, byte [si + 0x19] ; bits per pixel
    mov byte [di + 10], al

    ret

; Errors are fatal in stage1, so print message and halt.
vbe_error:
    mov si, vbe_error_msg
    call print
    jmp halt
disk_error:
    mov si, disk_error_msg
    call print
    jmp halt

halt:
    hlt
    jmp halt

; Print null-terminated string.
; input: DS:SI = string
print:
    lodsb
    test al, al
    jz .done

    mov ah, 0x0E
    int 0x10
    jmp print
    .done:
    ret

; INT 13h extensions read.
; input:
;   DL = boot drive
;   DAP fields already filled
; output:
;   CF set on error
read_lba:
    mov ah, 0x42
    mov si, dap
    int 0x13
    ret

disk_error_msg db "Error reading stage2 from disk!", 13, 10, 0
vbe_error_msg db "Error setting VBE mode!", 13, 10, 0

boot_drive db 0

align 8

gdt_start:
gdt_null:
    dq 0

gdt_code:
    ; base=0, limit=4GiB, code, readable, 32-bit, 4KiB granularity
    dw 0xFFFF
    dw 0x0000
    db 0x00
    db 10011010b
    db 11001111b
    db 0x00

gdt_data:
    ; base=0, limit=4GiB, data, writable, 32-bit, 4KiB granularity
    dw 0xFFFF
    dw 0x0000
    db 0x00
    db 10010010b
    db 11001111b
    db 0x00

gdt_end:

gdt_descriptor:
    dw gdt_end - gdt_start - 1
    dd gdt_start

; Disk Address Packet for INT 13h AH=42h.
; Must be below 1 MiB, which it is because stage1 is at 0x7C00.
dap:
    db 0x10          ; packet size
    db 0x00          ; reserved
dap_count:
    dw 0             ; sectors to read
dap_offset:
    dw 0             ; destination offset
dap_segment:
    dw 0             ; destination segment
dap_lba:
    dq 0             ; starting LBA

ASSERT_SIZE STAGE1_SIZE - 2
dw 0xAA55
