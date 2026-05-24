# hyprland.sh – Hyprland window helpers for QEMU
#
# Intended to be sourced by run.sh (not executed directly).
# Provides two functions:
#
#   apply_window_props <pid>
#     Waits for the QEMU window to appear, then makes it floating,
#     centers it, and restores the last saved size from .qemu_window_size.
#     Registers a trap to save the final size on exit.
#
#   save_window_size <address>
#     Queries the window's current pixel size via hyprctl and writes it
#     to .qemu_window_size so it can be restored next run.
#
# Both functions are no-ops when hyprctl is not available or the window
# cannot be found (all hyprctl calls are silenced with 2>/dev/null || true).

# Persisted window size file (same directory as this script)
SIZE_FILE="$(dirname "${BASH_SOURCE[0]}")/.qemu_window_size"

save_window_size() {
    local addr="$1"
    local size
    size=$(hyprctl clients -j 2>/dev/null | jq -r ".[] | select(.address == \"$addr\") | [.size[0], .size[1]] | @tsv")
    if [[ -n "$size" && "$size" != "null	null" ]]; then
        echo "$size" > "$SIZE_FILE"
    fi
}

apply_window_props() {
    local qpid="$1"
    sleep 0.5

    local win
    win=$(hyprctl clients -j 2>/dev/null | jq -r ".[] | select(.pid == $qpid) | .address")
    [[ -z "$win" || "$win" == "null" ]] && return

    # Focus + make floating + center
    hyprctl dispatch focuswindow "address:$win" 2>/dev/null || true
    hyprctl dispatch togglefloating 2>/dev/null || true
    hyprctl dispatch centerwindow 2>/dev/null || true

    # Restore saved size (resizeactive uses relative delta, needs -- for negative values)
    if [[ -f "$SIZE_FILE" ]]; then
        local saved_w saved_h cur_w cur_h dw dh
        read -r saved_w saved_h < "$SIZE_FILE"
        read -r cur_w cur_h < <(hyprctl clients -j | jq -r ".[] | select(.address == \"$win\") | [.size[0], .size[1]] | @tsv")
        dw=$((saved_w - cur_w))
        dh=$((saved_h - cur_h))
        if [[ $dw -ne 0 || $dh -ne 0 ]]; then
            hyprctl -- dispatch resizeactive "$dw $dh" 2>/dev/null || true
        fi
    fi

    # Save size when QEMU exits
    trap "save_window_size \"$win\"" EXIT
}
