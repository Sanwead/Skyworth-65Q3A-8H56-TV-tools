#!/system/bin/sh
# No saved network configuration. Preview by default; never eval input.
(
    fail() { printf '%s\n' "$*" >&2; exit 2; }
    mode=--preview
    case ${1-} in --preview|--apply|--remove) mode=$1; shift;; esac
    [ "$#" -eq 3 ] || fail 'Usage: nas-route.sh [--preview|--apply|--remove] NETWORK/PREFIX GATEWAY INTERFACE'
    net=$1; gw=$2; iface=$3
    ipv4() {
        case $1 in ''|*[!0-9.]*|.*|*.|*..*) return 1;; esac
        saved_ifs=$IFS; IFS=.; set -- $1; IFS=$saved_ifs
        [ "$#" -eq 4 ] || return 1
        for octet do
            case $octet in 0) ;; 0*) return 1;; esac
            [ "${#octet}" -le 3 ] && [ "$octet" -le 255 ] || return 1
        done
    }
    case $net in */*) ;; *) fail 'Expected IPv4 CIDR';; esac
    addr=${net%/*}; prefix=${net##*/}
    ipv4 "$addr" && ipv4 "$gw" || fail 'Invalid IPv4 address'
    case $prefix in [1-9]|[12][0-9]|3[0-2]) ;; *) fail 'Prefix must be 1..32; default route is not supported';; esac
    case $iface in ''|*[!a-zA-Z0-9_.:-]*|[-.:]*) fail 'Invalid interface';; esac
    [ "${#iface}" -le 15 ] || fail 'Interface is too long'
    # Refuse host bits rather than silently changing the requested network.
    saved_ifs=$IFS; IFS=.; set -- $addr; IFS=$saved_ifs
    bits=$prefix
    for octet do
        if [ "$bits" -ge 8 ]; then bits=$((bits - 8))
        elif [ "$bits" -eq 0 ]; then [ "$octet" -eq 0 ] || fail 'CIDR contains host bits'
        else
            divisor=$((1 << (8 - bits)))
            [ "$((octet % divisor))" -eq 0 ] || fail 'CIDR contains host bits'
            bits=0
        fi
    done
    action=add
    [ "$mode" != --remove ] || action=del
    printf 'Requested: ip route %s %s via %s dev %s\n' "$action" "$net" "$gw" "$iface"
    [ "$mode" != --preview ] || exit 0
    [ "$(id -u)" = 0 ] || fail 'Root required for route changes'
    command -v ip >/dev/null 2>&1 || fail 'ip is unavailable'
    ip link show dev "$iface" >/dev/null 2>&1 || fail 'Interface unavailable'
    ip route "$action" "$net" via "$gw" dev "$iface"
    exit "$?"
)
