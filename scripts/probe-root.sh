#!/system/bin/sh
# Read-only identity probe. Does not acquire root or create files.
(
    uid=$(id -u) || exit 1
    printf 'Current UID: %s\n' "$uid"
    [ "$uid" = 0 ]
)
