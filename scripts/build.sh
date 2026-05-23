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

stage1="$1"
stage2="$2"
output="$3"

tmp_stage2="$(mktemp)"
tmp_output="$(mktemp)"
trap 'rm -f "$tmp_stage2" "$tmp_output"' EXIT

cp "$stage2" "$tmp_stage2"

log "Step 1: Align the stage2 binary file to multiple of 512 bytes"
stage2_size=$(stat -c%s "$tmp_stage2")

if [ $((stage2_size % 512)) -ne 0 ]; then
    padding_size=$((512 - (stage2_size % 512)))
    dd if=/dev/zero bs=1 count="$padding_size" >> "$tmp_stage2" 2>/dev/null
fi

log "Step 2: Compile the stage1 bootloader source code"
stage2_size=$(stat -c%s "$tmp_stage2")

command -v fasm >/dev/null

fasm -d STAGE2_SIZE="$stage2_size" "$stage1" "$tmp_output" >/dev/null

log "Step 3: Append the stage2 binary file to the stage1 bootloader file"
cat "$tmp_stage2" >> "$tmp_output"

mv "$tmp_output" "$output"

log "bootloader built successfully: $output"
