#!/system/bin/sh
# TV-8H56 tools; Copyright (c) 2026 Sanwead. MIT License.
# Invoke with sh; do not source this dispatcher into a boot shell.
(
    umask 077
    VERSION=0.2.0
    DATA=/data/tv8h56
    SYS=/system
    BB=/system/bin/busybox
    SH=/system/bin/sh
    MOUNTS=/proc/mounts
    LOCKED=0
    REMOUNTED=0
    TMP=
    b() { "$BB" "$@"; }
    fail() { printf 'Error: %s\n' "$*" >&2; exit 1; }
    require_bb() { [ -x "$BB" ] || fail 'BusyBox missing: /system/bin/busybox'; }
    need_root() { [ "$(id -u)" = 0 ] || fail 'This action needs an existing Root session'; }
    apply_flag() { [ "$#" -eq 1 ] && [ "$1" = --apply ] || fail 'Add --apply to confirm this change'; }
    plain_file() { [ -f "$1" ] && [ ! -L "$1" ] || fail 'Expected a regular, non-symlink file'; }
    digest() { b sha256sum "$1" | b awk '{print $1}'; }
    secure_node() {
        [ ! -L "$1" ] || fail 'Symlink in private state'
        if [ -d "$1" ]; then expected_mode=0:700
        else plain_file "$1"; expected_mode=0:600; fi
        [ "$(b stat -c '%u:%a' "$1")" = "$expected_mode" ] || fail 'Private directories need root:700; files need root:600'
    }
    cleanup() {
        rc=$?
        if [ -n "$TMP" ] && [ -f "$TMP" ] && [ ! -L "$TMP" ]; then
            b rm -f "$TMP" || rc=1
        fi
        if [ "$REMOUNTED" = 1 ]; then
            mount -o remount,ro "$SYS" || { printf '%s\n' 'Could not restore /system read-only; check mount state.' >&2; rc=1; }
        fi
        if [ "$LOCKED" = 1 ]; then b rmdir "$DATA/operation.lock" || rc=1; fi
        trap - 0
        exit "$rc"
    }
    trap cleanup 0
    trap 'exit 1' 1 2 15
    init_state() {
        need_root; require_bb
        [ -d "${DATA%/*}" ] || fail '/data is unavailable'
        if [ ! -e "$DATA" ] && [ ! -L "$DATA" ]; then b mkdir -m 700 "$DATA" || fail 'Cannot create private state'; fi
        [ -d "$DATA" ] || fail 'Private state is not a directory'
        secure_node "$DATA"
        for sub in state bin; do
            if [ ! -e "$DATA/$sub" ] && [ ! -L "$DATA/$sub" ]; then b mkdir -m 700 "$DATA/$sub" || fail 'Cannot create state directory'; fi
            [ -d "$DATA/$sub" ] || fail 'Invalid state directory'
            secure_node "$DATA/$sub"
        done
        b mkdir -m 700 "$DATA/operation.lock" || fail 'Another action is active (or a stale lock needs inspection)'
        LOCKED=1
    }
    check_layout() {
        plain_file "$SYS/pcfg/8H56_Q3A/config/general_config.xml"
        [ "$(getenforce 2>/dev/null)" = Disabled ] || fail 'This version supports only SELinux Disabled firmware'
    }
    system_rw() {
        options=$(b awk -v s="$SYS" '$2==s {print $4; n++} END {if(n!=1) exit 1}' "$MOUNTS") || fail 'Cannot identify the /system mount'
        case ,$options, in *,ro,*)
            mount -o remount,rw "$SYS" || fail 'Cannot remount /system writable'
            REMOUNTED=1;;
            *,rw,*) ;; *) fail 'Unknown /system mount options';;
        esac
    }
    # Stage in the target directory, keep the original inode via a hard link,
    # then atomically replace the pathname. Never truncate a live system file.
    stage_target() {
        target=$1; key=$2
        plain_file "$target"
        [ "$(b readlink -f "$target")" = "$target" ] || fail 'System target has a symlink ancestor'
        secure_parent=${target%/*}
        while [ "$secure_parent" != / ] && [ -n "$secure_parent" ]; do
            [ "$(b stat -c %u "$secure_parent")" = 0 ] || fail 'System parent is not root-owned'
            parent_mode=$(b stat -c %a "$secure_parent") || fail 'Cannot read parent mode'
            case $parent_mode in [0-7][0-7][0-7]|[0-7][0-7][0-7][0-7]) ;; *) fail 'Invalid parent mode';; esac
            [ "$((0$parent_mode & 0022))" -eq 0 ] || fail 'System parent is writable by non-root users'
            secure_parent=${secure_parent%/*}
        done
        [ "$(b stat -c %u "$target")" = 0 ] || fail 'System target is not root-owned'
        existing_mode=$(b stat -c %a "$target") || fail 'Cannot read system target mode'
        case $existing_mode in [0-7][0-7][0-7]|[0-7][0-7][0-7][0-7]) ;; *) fail 'Invalid system target mode';; esac
        [ "$((0$existing_mode & 0022))" -eq 0 ] || fail 'System target is writable by non-root users'
        [ ! -e "$target.tv8h56-original" ] && [ ! -L "$target.tv8h56-original" ] || fail 'Original backup already exists; restore first'
        [ ! -e "$DATA/state/$key.record" ] && [ ! -L "$DATA/state/$key.record" ] || fail 'Previous state exists; inspect or restore it first'
        system_rw
        TMP=$target.tv8h56-new
        [ ! -e "$TMP" ] && [ ! -L "$TMP" ] || fail 'Staging path already exists; inspect it first'
        (set -C; : > "$TMP") || fail 'Cannot exclusively create staged file'
        target_mode=$(b stat -c %a "$target") || fail 'Cannot read original mode'
        target_gid=$(b stat -c %g "$target") || fail 'Cannot read original group'
    }
    commit_target() {
        b chown "0:$target_gid" "$TMP" && b chmod "$target_mode" "$TMP" || fail 'Cannot set staged file metadata'
        original_hash=$(digest "$target"); new_hash=$(digest "$TMP")
        [ "${#original_hash}" = 64 ] && [ "${#new_hash}" = 64 ] || fail 'Cannot hash files'
        record=$DATA/state/$key.record
        (set -C; printf '%s\n%s\n' "$original_hash" "$new_hash" > "$record") || fail 'Cannot save transaction hashes'
        b chmod 600 "$record" || fail 'Cannot secure transaction hashes'
        if ! b ln "$target" "$target.tv8h56-original"; then
            b rm -f "$record"
            fail 'Cannot preserve original inode; target unchanged'
        fi
        b sync || fail 'Cannot sync original backup and transaction record'
        # A failed rename leaves both the target and its original backup intact.
        b mv -f "$TMP" "$target" || fail 'Atomic install failed; original is preserved'
        TMP=
        b sync || fail 'Sync failed; inspect status before reboot'
        printf '%s\n' 'Applied. Original file is preserved beside the system file.'
    }
    restore_target() {
        target=$1; key=$2
        plain_file "$target"; plain_file "$target.tv8h56-original"
        [ "$(b readlink -f "$target")" = "$target" ] && [ "$(b readlink -f "$target.tv8h56-original")" = "$target.tv8h56-original" ] || fail 'Restore paths contain symlinks'
        record=$DATA/state/$key.record
        plain_file "$record"; secure_node "$record"
        original_hash=$(b sed -n 1p "$record"); new_hash=$(b sed -n 2p "$record")
        [ "${#original_hash}" = 64 ] && [ "${#new_hash}" = 64 ] || fail 'Invalid transaction hashes'
        [ "$(digest "$target.tv8h56-original")" = "$original_hash" ] || fail 'Original backup changed; refusing restore'
        current_hash=$(digest "$target")
        [ "$current_hash" = "$new_hash" ] || [ "$current_hash" = "$original_hash" ] || fail 'Target changed outside this tool; refusing overwrite'
        original_identity=$(b stat -c '%d:%i' "$target.tv8h56-original") || fail 'Cannot inspect original inode'
        current_identity=$(b stat -c '%d:%i' "$target") || fail 'Cannot inspect target inode'
        [ -n "$original_identity" ] && [ -n "$current_identity" ] || fail 'Missing inode identity'
        system_rw
        if [ "$original_identity" = "$current_identity" ]; then
            # Commit failed before rename: both names still refer to the original inode.
            b rm -f "$target.tv8h56-original" || fail 'Cannot remove duplicate original link'
        else
            b mv -f "$target.tv8h56-original" "$target" || fail 'Restore failed; original remains beside target'
        fi
        b sync || fail 'Sync failed after restore; inspect before reboot'
        b rm -f "$record" || fail 'Restored but transaction record remains'
        printf '%s\n' 'Restored original file, including its inode metadata.'
    }
    component_ok() {
        case $1 in ''|*[!A-Za-z0-9_./\$]*|/*|*/|*/*/*) return 1;; esac
        case $1 in *.*/*) ;; *) return 1;; esac
    }
    require_component() {
        component_ok "$1" || fail 'Expected PACKAGE/ACTIVITY'
        pkg=${1%%/*}
        pm path "$pkg" 2>/dev/null | b grep -q '^package:' || fail 'Launcher package is not installed'
    }
    here() {
        require_bb
        location=$(b readlink -f "$0") || fail 'Cannot resolve toolkit path'
        HERE=${location%/*}
    }
    trusted_source() {
        # An installer must not promote code from a shell-writable directory.
        parent=$HERE
        # /data itself is maintained by Android (often system:system 0771).
        # Inspect the private subtree, not Android's trusted top-level policy.
        while [ "$parent" != / ] && [ "$parent" != "${DATA%/*}" ] && [ -n "$parent" ]; do
            [ ! -L "$parent" ] && [ "$(b stat -c %u "$parent")" = 0 ] || fail 'Stage the toolkit in a root-owned private directory first'
            mode=$(b stat -c %a "$parent") || fail 'Cannot inspect source directory'
            case $mode in [0-7][0-7][0-7]|[0-7][0-7][0-7][0-7]) ;; *) fail 'Invalid source directory mode';; esac
            [ "$((0$mode & 0022))" -eq 0 ] || fail 'Source directory is writable by non-root users; see USB-ROOT.md'
            parent=${parent%/*}
        done
        for source_file in tv8h56.sh nas-route.sh backup-partitions.sh; do
            plain_file "$HERE/$source_file"; secure_node "$HERE/$source_file"
        done
    }
    helper() {
        here
        helper_file=$1; shift
        plain_file "$HERE/$helper_file"
        "$SH" "$HERE/$helper_file" "$@"
    }
    status() {
        printf 'TV-8H56 tools %s\n' "$VERSION"
        printf 'UID: %s\n' "$(id -u)"
        printf 'Android: %s\n' "$(getprop ro.build.version.release)"
        printf 'SDK: %s\n' "$(getprop ro.build.version.sdk)"
        printf 'Firmware: %s\n' "$(getprop ro.build.display.id)"
        printf 'ABI: %s\n' "$(getprop ro.product.cpu.abi)"
        printf 'SELinux: %s\n' "$(getenforce 2>/dev/null)"
        for item in bootvideo home startup; do
            if [ -r "$DATA/state/$item.record" ]; then printf '%s: modified or pending recovery (inspect transaction record)\n' "$item"
            else printf '%s: no readable transaction record\n' "$item"; fi
        done
    }
    doctor() {
        status; require_bb
        for applet in stat sha256sum awk sed grep readlink ln mv cp chmod chown mkdir rmdir sync; do
            b --list | b grep -qx "$applet" || fail "BusyBox applet missing: $applet"
        done
        check_layout
        plain_file "$SYS/bin/bootvideo"; plain_file "$SYS/bin/hisi_boot_shell.sh"
        printf '%s\n' 'Expected layout found. Doctor did not modify the device.'
    }
    bootvideo() {
        [ "$#" -eq 2 ] || fail 'Usage: bootvideo disable|restore --apply'
        action=$1; shift; apply_flag "$@"; init_state; check_layout
        case $action in
            disable)
                stage_target "$SYS/bin/bootvideo" bootvideo
                printf '#!/system/bin/sh\nexit 0\n' > "$TMP" || fail 'Cannot write staged player stub'
                "$SH" -n "$TMP" || fail 'Invalid player stub'
                commit_target;;
            restore) restore_target "$SYS/bin/bootvideo" bootvideo;;
            *) fail 'Expected disable or restore';;
        esac
    }
    home() {
        action=${1-}; [ "$#" -gt 0 ] && shift
        case $action in
            set)
                [ "$#" -eq 2 ] || fail 'Usage: home set PACKAGE/ACTIVITY --apply'
                component=$1; shift; apply_flag "$@"; init_state; check_layout; require_component "$component"
                cfg=$SYS/pcfg/8H56_Q3A/config/general_config.xml
                # Only the documented simple leaf form is supported. Refuse other XML layouts.
                pattern='^[[:space:]]*<[^ >][^ >]*[[:space:]][[:space:]]*name="DEFAULT_HOMEPAGE"[[:space:]][[:space:]]*value="[^"]*"[[:space:]]*/>[[:space:]]*$'
                [ "$(b grep -c DEFAULT_HOMEPAGE "$cfg")" = 1 ] && b grep -q "$pattern" "$cfg" || fail 'Unsupported DEFAULT_HOMEPAGE XML shape; original unchanged'
                stage_target "$cfg" home
                b sed "s|\(name=\"DEFAULT_HOMEPAGE\"[[:space:]][[:space:]]*value=\"\)[^\"]*|\1$component|" "$cfg" > "$TMP" || fail 'Cannot prepare launcher XML'
                b grep -Fq "value=\"$component\"" "$TMP" || fail 'Launcher replacement did not match'
                commit_target
                printf '%s\n' 'Configured for the next boot. Original launcher package is kept.';;
            restore) apply_flag "$@"; init_state; check_layout; restore_target "$SYS/pcfg/8H56_Q3A/config/general_config.xml" home;;
            launch) [ "$#" -eq 1 ] || fail 'Usage: home launch PACKAGE/ACTIVITY'; need_root; require_bb; require_component "$1"; am start -n "$1";;
            *) fail 'Usage: home set|restore|launch';;
        esac
    }
    config_value() {
        b sed -n "s/^$1=//p" "$DATA/startup.conf"
    }
    validate_config() {
        plain_file "$DATA/startup.conf"; secure_node "$DATA/startup.conf"
        [ "$(b wc -c < "$DATA/startup.conf")" -le 2048 ] || fail 'Startup config too large'
        for field in HOME_COMPONENT NAS_NETWORK NAS_GATEWAY NAS_INTERFACE; do
            [ "$(b grep -c "^$field=" "$DATA/startup.conf")" = 1 ] || fail 'Missing or duplicated startup setting'
        done
        b grep -Ev '^(HOME_COMPONENT|NAS_NETWORK|NAS_GATEWAY|NAS_INTERFACE)=[A-Za-z0-9_./:$-]*$' "$DATA/startup.conf" | b grep -q . && fail 'Invalid startup setting'
        return 0
    }
    write_config() {
        temp_config=$DATA/startup.conf.new
        [ ! -e "$temp_config" ] && [ ! -L "$temp_config" ] || fail 'Config staging path exists'
        (set -C; printf 'HOME_COMPONENT=%s\nNAS_NETWORK=%s\nNAS_GATEWAY=%s\nNAS_INTERFACE=%s\n' "$home_value" "$net_value" "$gw_value" "$if_value" > "$temp_config") || fail 'Cannot write startup config'
        b chmod 600 "$temp_config" && b mv "$temp_config" "$DATA/startup.conf" || fail 'Cannot install startup config'
    }
    load_config() {
        if [ ! -e "$DATA/startup.conf" ] && [ ! -L "$DATA/startup.conf" ]; then
            home_value=; net_value=; gw_value=; if_value=; write_config
        fi
        validate_config
        home_value=$(config_value HOME_COMPONENT); net_value=$(config_value NAS_NETWORK)
        gw_value=$(config_value NAS_GATEWAY); if_value=$(config_value NAS_INTERFACE)
    }
    secure_runtime() {
        for node in "$DATA" "$DATA/bin" "$DATA/bin/tv8h56.sh" "$DATA/bin/nas-route.sh" "$DATA/bin/backup-partitions.sh"; do secure_node "$node"; done
    }
    startup_run() {
        init_state; secure_runtime; load_config
        if [ -n "$home_value" ]; then
            require_component "$home_value"
            setprop persist.service.homepage.pkg "${home_value%%/*}" || fail 'Cannot set homepage package'
            setprop persist.service.homepage.cls "${home_value#*/}" || fail 'Cannot set homepage activity'
            am start -n "$home_value" || fail 'Cannot launch homepage'
        fi
        if [ -n "$net_value" ]; then
            "$SH" "$DATA/bin/nas-route.sh" --preview "$net_value" "$gw_value" "$if_value" >/dev/null || fail 'Invalid configured route'
            # Accept only an exact already-present route; never replace another route.
            existing=$(ip -4 route show exact "$net_value") || fail 'Cannot inspect configured route'
            expected="$net_value via $gw_value dev $if_value"
            if [ "$existing" != "$expected" ]; then
                [ -z "$existing" ] || fail 'A conflicting or differently formatted route already exists'
                "$SH" "$DATA/bin/nas-route.sh" --apply "$net_value" "$gw_value" "$if_value" || fail 'Startup route failed'
            fi
        fi
        printf '%s\n' 'Configured startup tasks finished.'
    }
    startup() {
        action=${1-}; [ "$#" -gt 0 ] && shift
        case $action in
            install)
                apply_flag "$@"; init_state; check_layout; here; trusted_source
                for file in tv8h56.sh nas-route.sh backup-partitions.sh; do
                    plain_file "$HERE/$file"; "$SH" -n "$HERE/$file" || fail 'Invalid toolkit source'
                    if [ -e "$DATA/bin/$file" ] || [ -L "$DATA/bin/$file" ]; then
                        plain_file "$DATA/bin/$file"; secure_node "$DATA/bin/$file"
                        [ "$(digest "$HERE/$file")" = "$(digest "$DATA/bin/$file")" ] || fail 'A different runtime is installed; remove its hook and inspect before updating'
                    else
                        b cp "$HERE/$file" "$DATA/bin/$file" && b chmod 600 "$DATA/bin/$file" || fail 'Cannot install root-owned runtime'
                    fi
                done
                load_config; secure_runtime
                hook=$SYS/bin/hisi_boot_shell.sh
                b grep -q 'TV8H56 STARTUP' "$hook" && fail 'Startup marker already present'
                stage_target "$hook" startup
                b cat "$hook" > "$TMP" || fail 'Cannot stage boot hook'
                cat >> "$TMP" <<'HOOK'

# TV8H56 STARTUP BEGIN
if [ "$(/system/bin/busybox stat -c %u:%a /data/tv8h56 2>/dev/null)" = 0:700 ] &&
   [ "$(/system/bin/busybox stat -c %u:%a /data/tv8h56/bin 2>/dev/null)" = 0:700 ] &&
   [ "$(/system/bin/busybox stat -c %u:%a /data/tv8h56/bin/tv8h56.sh 2>/dev/null)" = 0:600 ]; then
    /system/bin/sh /data/tv8h56/bin/tv8h56.sh startup-run >/dev/null 2>&1
fi
# TV8H56 STARTUP END
HOOK
                "$SH" -n "$TMP" || fail 'Patched boot hook failed syntax check'
                commit_target
                printf '%s\n' 'Startup installed. Configure home/route explicitly; no command queue is enabled.';;
            remove)
                apply_flag "$@"; init_state; check_layout
                restore_target "$SYS/bin/hisi_boot_shell.sh" startup
                printf '%s\n' 'Startup hook removed. Private state and runtime are retained for inspection.';;
            home)
                [ "$#" -eq 2 ] || fail 'Usage: startup home PACKAGE/ACTIVITY|off --apply'
                value=$1; shift; apply_flag "$@"; init_state; here; load_config
                if [ "$value" = off ]; then home_value=; else require_component "$value"; home_value=$value; fi
                write_config; printf '%s\n' 'Startup home setting saved.';;
            route)
                if [ "${1-}" = off ]; then
                    shift; apply_flag "$@"; init_state; load_config; net_value=; gw_value=; if_value=
                else
                    [ "$#" -eq 4 ] || fail 'Usage: startup route NETWORK/PREFIX GATEWAY INTERFACE --apply'
                    net=$1; gw=$2; iface=$3; shift 3; apply_flag "$@"; init_state; here; load_config
                    "$SH" "$HERE/nas-route.sh" --preview "$net" "$gw" "$iface" || fail 'Invalid route settings'
                    net_value=$net; gw_value=$gw; if_value=$iface
                fi
                write_config; printf '%s\n' 'Startup route setting saved. Existing live routes are not changed.';;
            show) need_root; require_bb; secure_node "$DATA"; validate_config; b cat "$DATA/startup.conf";;
            *) fail 'Usage: startup install|remove|home|route|show';;
        esac
    }
    help() {
        cat <<'HELP'
TV-8H56 tools 0.2.0
  status | doctor
  backup --partition N --usb-mount PATH --confirm-sensitive-backup
  route [--preview|--apply|--remove] NETWORK/PREFIX GATEWAY INTERFACE
  bootvideo disable|restore --apply
  home set PACKAGE/ACTIVITY --apply
  home restore --apply
  home launch PACKAGE/ACTIVITY
  startup install|remove --apply
  startup home PACKAGE/ACTIVITY|off --apply
  startup route NETWORK/PREFIX GATEWAY INTERFACE --apply
  startup route off --apply
  startup show
  startup-run
Read README.md first. System changes require an existing Root session.
HELP
    }
    cmd=${1-help}; [ "$#" -gt 0 ] && shift
    case $cmd in
        help|--help|-h) help;;
        --version) printf '%s\n' "$VERSION";;
        status) [ "$#" -eq 0 ] || fail 'status takes no arguments'; status;;
        doctor) [ "$#" -eq 0 ] || fail 'doctor takes no arguments'; doctor;;
        backup) helper backup-partitions.sh "$@";;
        route) helper nas-route.sh "$@";;
        bootvideo) bootvideo "$@";;
        home) home "$@";;
        startup) startup "$@";;
        startup-run) [ "$#" -eq 0 ] || fail 'startup-run takes no arguments'; startup_run;;
        *) fail 'Unknown command; run help';;
    esac
)
