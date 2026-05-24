#!/usr/bin/env bash
set -euo pipefail

debug="${DEBUG_BUILD_SCRIPT:-0}"

log() {
    if [[ "$debug" == "1" ]]; then
        echo "$@" >&2
    fi
}

if [[ "$debug" == "1" ]]; then
    set -x
fi

stage1="$1"     # boot/stage1.s  – 16-bit real-mode bootloader (FASM source)
stage2_s="$2"   # boot/stage2.s  – 32-bit long-mode trampoline (FASM source)
stage3_s="$3"   # boot/stage3.s  – 64-bit entry trampoline     (FASM source)
kernel="$4"     # kernel.bin     – 64-bit Zig kernel flat binary
output="$5"

tmp_stage2_bin="$(mktemp)"
tmp_stage3_bin="$(mktemp)"
tmp_kernel="$(mktemp)"
tmp_output="$(mktemp)"
trap 'rm -f "$tmp_stage2_bin" "$tmp_stage3_bin" "$tmp_kernel" "$tmp_output"' EXIT

command -v fasm >/dev/null

log "Step 1: Assemble stage2.s → flat binary (must be exactly 512 bytes)"
fasm "$stage2_s" "$tmp_stage2_bin" >/dev/null
stage2_bin_size=$(stat -c%s "$tmp_stage2_bin")
if [ "$stage2_bin_size" -ne 512 ]; then
    echo "Error: stage2.s assembled to $stage2_bin_size bytes (expected exactly 512)" >&2
    exit 1
fi

log "Step 2: Assemble stage3.s → flat binary (must be exactly 512 bytes)"
fasm "$stage3_s" "$tmp_stage3_bin" >/dev/null
stage3_bin_size=$(stat -c%s "$tmp_stage3_bin")
if [ "$stage3_bin_size" -ne 512 ]; then
    echo "Error: stage3.s assembled to $stage3_bin_size bytes (expected exactly 512)" >&2
    exit 1
fi

log "Step 3: Align the kernel binary to a multiple of 512 bytes"
cp "$kernel" "$tmp_kernel"
kernel_size=$(stat -c%s "$tmp_kernel")
if [ $((kernel_size % 512)) -ne 0 ]; then
    padding=$((512 - (kernel_size % 512)))
    dd if=/dev/zero bs=1 count="$padding" >> "$tmp_kernel" 2>/dev/null
fi

log "Step 4: Compile stage1.s with STAGE2_SIZE = stage2 + stage3 + padded kernel"
kernel_padded_size=$(stat -c%s "$tmp_kernel")
total_payload=$((stage2_bin_size + stage3_bin_size + kernel_padded_size))
fasm -d STAGE2_SIZE="$total_payload" "$stage1" "$tmp_output" >/dev/null

log "Step 5: Concatenate stage1 + stage2 + stage3 + kernel into final disk image"
cat "$tmp_stage2_bin" >> "$tmp_output"
cat "$tmp_stage3_bin" >> "$tmp_output"
cat "$tmp_kernel"     >> "$tmp_output"

mv "$tmp_output" "$output"

log "Disk image built successfully: $output"
log "  stage1 : 512 bytes  (0x7C00)"
log "  stage2 : 512 bytes  (0x8000)"
log "  stage3 : 512 bytes  (0x8200)"
log "  kernel : $kernel_padded_size bytes  (0x8400)"
