#!/system/bin/sh
# Private, single-partition export. No partition writes or restore operation.
(
    umask 077
    fail() { printf '%s\n' "$*" >&2; exit 1; }
    [ "$#" -eq 5 ] && [ "$1" = --partition ] && [ "$3" = --usb-mount ] &&
        [ "$5" = --confirm-sensitive-backup ] ||
        fail 'Usage: backup-partitions.sh --partition 1..23 --usb-mount /mnt/usb/MOUNT --confirm-sensitive-backup'
    part=$2; usb=$4
    case $part in [1-9]|1[0-9]|2[0-3]) ;; *) fail 'Only partitions 1..23 are allowed; userdata is excluded';; esac
    [ "$(id -u)" = 0 ] || fail 'Root required'
    bb=/system/bin/busybox
    [ -x "$bb" ] || fail 'Expected /system/bin/busybox'
    case $usb in /mnt/usb/*) ;; *) fail 'Expected a mounted USB path below /mnt/usb/';; esac
    case $usb in *[!a-zA-Z0-9_./-]*) fail 'Unsupported characters in USB path';; esac
    canonical=$("$bb" readlink -f "$usb") || fail 'Cannot resolve USB path'
    [ "$canonical" = "$usb" ] && [ -d "$usb" ] && [ ! -L "$usb" ] || fail 'USB path must be canonical and not a symlink'
    mount_info=$("$bb" awk -v p="$usb" '$2==p {print $1 " " $3; n++} END {if(n!=1) exit 1}' /proc/mounts) || fail 'USB path is not a unique mount point'
    case $mount_info in /dev/block/*\ *) ;; *) fail 'USB mount must have a block-device source';; esac
    fs=${mount_info#* }
    dev=/dev/block/mmcblk0p$part
    [ -b "$dev" ] || fail 'Source is not a block device'
    size=$("$bb" blockdev --getsize64 "$dev") || fail 'Cannot determine source size'
    case $size in ''|*[!0-9]*) fail 'Invalid source size';; esac
    [ "$size" -gt 0 ] || fail 'Empty source'
    case $fs in vfat|msdos) [ "$size" -lt 4294967295 ] || fail 'FAT file size limit';; esac
    free_kb=$("$bb" df -Pk "$usb" | "$bb" awk 'NR==2 {print $4}')
    case $free_kb in ''|*[!0-9]*) fail 'Cannot determine free space';; esac
    need_kb=$(((size + 1023) / 1024 + 65536))
    [ "$free_kb" -ge "$need_kb" ] || fail 'Insufficient space (includes 64 MiB reserve)'
    "$bb" sha256sum /dev/null >/dev/null 2>&1 || fail 'SHA-256 unavailable'
    lock=$usb/.tv8h56-backup.lock
    "$bb" mkdir "$lock" || fail 'Backup lock exists or USB is not writable'
    # Remove only the empty lock created by this invocation; never recursive delete.
    trap '"$bb" rmdir "$lock" 2>/dev/null' 0
    trap 'exit 1' 1 2 15
    stamp=$("$bb" date +%Y%m%dT%H%M%S) || fail 'Cannot create timestamp'
    dest=$usb/tv8h56-private-p$part-$stamp-$$
    "$bb" mkdir "$dest" || fail 'Cannot create fresh destination'
    printf '%s\n' 'PRIVATE sensitive export; incomplete until COMPLETE.txt exists.' > "$dest/PRIVATE.txt" || fail 'Cannot write warning'
    "$bb" dd if="$dev" of="$dest/partition.img.partial" bs=1048576 2>"$dest/error.log" || fail 'dd failed; partial export retained privately'
    actual=$("$bb" wc -c < "$dest/partition.img.partial") || fail 'Cannot measure output'
    [ "$actual" -eq "$size" ] || fail 'Output size mismatch; export is incomplete'
    "$bb" mv "$dest/partition.img.partial" "$dest/partition.img" || fail 'Cannot finalize image'
    (cd "$dest" && "$bb" sha256sum partition.img > SHA256SUMS && "$bb" sha256sum -c SHA256SUMS) || fail 'Checksum failed'
    "$bb" sync || fail 'Cannot sync output'
    if ! printf 'Partition p%s; bytes %s. Export verified; restore NOT tested.\n' "$part" "$size" > "$dest/COMPLETE.txt"; then
        "$bb" rm -f "$dest/COMPLETE.txt"
        fail 'Cannot write completion marker'
    fi
    if ! "$bb" sync; then
        "$bb" rm -f "$dest/COMPLETE.txt"
        "$bb" sync 2>/dev/null
        fail 'Final sync failed; completion marker withdrawn; inspect privately'
    fi
    printf '%s\n' 'Private export completed. Do not upload images, logs or manifests.'
)
