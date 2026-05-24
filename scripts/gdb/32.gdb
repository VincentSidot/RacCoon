source scripts/gdb/common.gdb

# Break at stage2 entry (0x8000, 32-bit protected mode).
target remote localhost:1234

hb *0x8000
c

mode32

printf "\n=== stage2  0x8000  [32-bit protected mode] ===\n\n"
regs32
printf "\n"
xip32
