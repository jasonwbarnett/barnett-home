#!/usr/bin/env bash
# Check whether this Mac's print service (cupsd) truncates large replies over
# its local socket. Run as your normal user, no sudo. See README.md.
#
#   ./check-cups-socket.sh            # every print queue
#   ./check-cups-socket.sh QUEUE      # one queue (name from `lpstat -p`)
set -uo pipefail

SOCKET_URI='ipp://%2Fprivate%2Fvar%2Frun%2Fcupsd'
TIMEOUT=10

echo "macOS $(sw_vers -productVersion) ($(sw_vers -buildVersion))"
echo "net.local.stream.sendspace = $(sysctl -n net.local.stream.sendspace)"
echo "net.local.stream.recvspace = $(sysctl -n net.local.stream.recvspace)"
if [[ -f /etc/sysctl.conf ]]; then
  echo "/etc/sysctl.conf:"; sed 's/^/    /' /etc/sysctl.conf
else
  echo "/etc/sysctl.conf: (none)"
fi
echo

if [[ $# -gt 0 ]]; then
  queues=("$1")
else
  queues=()
  while read -r _ q _; do queues+=("$q"); done < <(lpstat -p 2>/dev/null | grep '^printer ')
fi
if [[ ${#queues[@]} -eq 0 ]]; then
  echo "No print queues found. Add the printer in System Settings → Printers & Scanners first."
  exit 2
fi

status=0
for q in "${queues[@]}"; do
  # The same Get-Printer-Attributes request apps make before printing, sent
  # over the local socket. With the bug it times out; when healthy it's instant.
  start=$(date +%s)
  if ipptool -T "$TIMEOUT" -t "$SOCKET_URI/printers/$q" get-printer-attributes.test >/dev/null 2>&1; then
    printf '%-30s OK      (%ss)\n' "$q" "$(( $(date +%s) - start ))"
  else
    printf '%-30s BROKEN  (no full reply within %ss over the local socket)\n' "$q" "$TIMEOUT"
    status=1
  fi
done

if [[ $status -ne 0 ]]; then
  echo
  echo "Affected. Apply the fix: sudo ./fix-cups-socket.sh, then reboot."
fi
exit $status
