#!/usr/bin/env bash
# Raise macOS's local (Unix-domain) socket buffers from 8 KB to 64 KB at boot
# so cupsd's printer-attributes reply isn't cut short. See README.md.
#
#   sudo ./fix-cups-socket.sh            # apply (then reboot)
#   sudo ./fix-cups-socket.sh --undo     # remove our settings (then reboot)
#
# Only touches the two net.local.stream.* lines; any other settings already
# in /etc/sysctl.conf are kept. The previous file is backed up first.
set -euo pipefail

CONF=${SYSCTL_CONF:-/etc/sysctl.conf}  # override only for testing
SETTINGS=(net.local.stream.sendspace=65536 net.local.stream.recvspace=65536)

if [[ -z ${SYSCTL_CONF:-} && $EUID -ne 0 ]]; then
  echo "Run with sudo: sudo $0 $*" >&2
  exit 1
fi

tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT
if [[ -f $CONF ]]; then
  cp -p "$CONF" "$CONF.bak-$(date +%Y%m%d-%H%M%S)"
  grep -vE '^[[:space:]]*net\.local\.stream\.(sendspace|recvspace)[[:space:]]*=' "$CONF" > "$tmp" || true
fi

if [[ ${1:-} == --undo ]]; then
  if [[ -s $tmp ]]; then
    cat "$tmp" > "$CONF"
  else
    rm -f "$CONF"
  fi
  echo "Removed net.local.stream settings from $CONF. Reboot to return to 8 KB buffers."
  exit 0
fi

printf '%s\n' "${SETTINGS[@]}" >> "$tmp"
cat "$tmp" > "$CONF"
chown root:wheel "$CONF" 2>/dev/null || true
chmod 644 "$CONF"
echo "$CONF now contains:"
sed 's/^/    /' "$CONF"
echo
echo "Reboot this Mac. The setting has to be in place before macOS creates the"
echo "print service's socket at boot. Then run ./check-cups-socket.sh to confirm."
