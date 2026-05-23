#!/usr/bin/env bash

set -e

# Parse arguments
BOOTLOADER_FILE=""
DEBUG_ENABLED=false

while [[ "$#" -gt 0 ]]; do
    case "$1" in
        --debug) DEBUG_ENABLED=true ;;
        *) BOOTLOADER_FILE="$1" ;;
    esac
    shift
done

# Run the bootloader in QEMU

if [[ -z "$BOOTLOADER_FILE" ]]; then
    echo "Usage: $0 [--debug] <bootloader_file>"
    exit 1
fi

if [[ "$DEBUG_ENABLED" == true ]]; then
    echo "Debug mode enabled. Starting QEMU with GDB server on port 1234."
    qemu-system-i386 \
        -drive format=raw,file="$BOOTLOADER_FILE" \
        -s -S \
        -no-reboot \
        -no-shutdown &
    gdb -x .gdbinit-boot

    # Close QEMU after GDB session ends
    kill $!
else
    qemu-system-i386 -drive format=raw,file="$BOOTLOADER_FILE"
fi
