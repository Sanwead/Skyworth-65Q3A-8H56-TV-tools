#!/system/bin/sh
(
    BB=/system/bin/busybox
    path=$("$BB" readlink -f "$0") || exit 1
    dir=${path%/*}
    /system/bin/sh "$dir/tv8h56.sh" home set "$@"
)
