source scripts/gdb/common.gdb

# Break at kernel kentry (0x8400, 64-bit long mode).
# stage3 trampoline runs 0x8200–0x83FF; Zig code starts at 0x8400.
target remote localhost:1234

hb *0x8400
c

mode64

python
import os
sym = "zig-out/kernel.elf"
if os.path.exists(sym):
    gdb.execute("file " + sym)
    try:
        gdb.execute("info address kmain", to_string=True)
        print("[gdb] symbols loaded from: " + sym)
    except gdb.error:
        print("[gdb] warning: " + sym + " has no debug symbols — rebuild with 'zig build' (uses Debug mode by default)")
else:
    print("[gdb] note: " + sym + " not found — run 'zig build' first")
end

printf "\n=== kernel  0x8400  [64-bit long mode] ===\n\n"
regs64
printf "\n"
xip64
