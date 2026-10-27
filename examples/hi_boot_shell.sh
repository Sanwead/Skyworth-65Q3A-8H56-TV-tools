#!/system/bin/sh
# USB Root entry for the original author's boot-shell mechanism.
# Copy the project to USB as /tv8h56; adjust USB_MOUNT to the real mount path.
# Select ONE operation explicitly. Default: status (no system change).
(
    USB_MOUNT=/mnt/usb/sda1
    TOOL=$USB_MOUNT/tv8h56/scripts/tv8h56.sh
    [ -f "$TOOL" ] && [ ! -L "$TOOL" ] || { echo 'Toolkit not found on USB' >&2; exit 1; }
    # Output stays in this invocation. Do not write command queues in /data/local/tmp.
    /system/bin/sh "$TOOL" status
    # Replace the line above with ONE command from docs/USB-ROOT.md.
)
