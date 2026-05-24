source scripts/gdb/common.gdb

# Break at stage1 entry (0x7C00, 16-bit real mode).
# GDB 17+ with qemu-system-x86_64 always reports the target as i386:x86-64 even
# during real-mode execution; mode16 is called after the break, not before.
target remote localhost:1234

hb *0x7c00
c

mode16

printf "\n=== stage1  0x7C00  [16-bit real mode] ===\n\n"
regs16
printf "\n"
xip16
