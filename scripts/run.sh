#!/usr/bin/env bash

set -e

BOOTLOADER_FILE=""
DEBUG_MODE=""   # 16 | 32 | 64

while [[ "$#" -gt 0 ]]; do
    case "$1" in
        --debug16) DEBUG_MODE="16" ;;
        --debug32) DEBUG_MODE="32" ;;
        --debug64) DEBUG_MODE="64" ;;
        --debug)   DEBUG_MODE="64" ;;   # zig build debug → alias for debug64
        *) BOOTLOADER_FILE="$1" ;;
    esac
    shift
done

if [[ -z "$BOOTLOADER_FILE" ]]; then
    echo "Usage: $0 [--debug16|--debug32|--debug64] <bootloader_file>"
    exit 1
fi

QEMU_ARGS=(
    -drive format=raw,file="$BOOTLOADER_FILE"
    -no-reboot
)

if [[ -n "$DEBUG_MODE" ]]; then
    GDBINIT="scripts/gdb/${DEBUG_MODE}.gdb"

    if [[ ! -f "$GDBINIT" ]]; then
        echo "Error: GDB init file '$GDBINIT' not found" >&2
        exit 1
    fi

    echo "Debug ${DEBUG_MODE}-bit | init: ${GDBINIT} | GDB server: localhost:1234"

    qemu-system-x86_64 "${QEMU_ARGS[@]}" -no-shutdown -s -S &
    QEMU_PID=$!

    sleep 0.3
    gdb -x "$GDBINIT"

    kill "$QEMU_PID" 2>/dev/null || true
else
    qemu-system-x86_64 "${QEMU_ARGS[@]}"
fi
