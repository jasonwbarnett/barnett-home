#!/usr/bin/env python3
"""Per-minute snapshot of every iOS peer on the tailnet, from this Pi's view.

For each phone it records Tailscale's path state (direct/DERP, last handshake,
bytes), how many DNS packets the phone sent to this Pi (nftables counter on
tailscale0, no query names), and a periodic `tailscale ping`. Written to help
catch phones whose tunnel wedges after a cellular/satellite handoff.

One JSON line per peer per minute in /var/log/tsdnsmon/YYYY-MM-DD.jsonl.
/var/log is log2ram tmpfs, so this costs one small sync to the SD card a day.
"""
import datetime
import glob
import json
import os
import re
import subprocess
import time

LOG_DIR = '/var/log/tsdnsmon'
INTERVAL = 60
PING_EVERY = 2  # ticks; each ping wakes the phone's radio, so not every minute
KEEP_DAYS = 14
TABLE = 'tsdnsmon'


def run(*cmd, stdin=None, timeout=15):
    return subprocess.run(cmd, input=stdin, capture_output=True, text=True, timeout=timeout)


def ensure_table():
    if run('nft', 'list', 'table', 'inet', TABLE).returncode == 0:
        return
    run('nft', '-f', '-', stdin=(
        f'add table inet {TABLE}\n'
        f'add chain inet {TABLE} input {{ type filter hook input priority -5; policy accept; }}\n'
    ))


def dns_counters():
    """Map of peer IP -> DNS packets counted so far."""
    out = run('nft', '-j', 'list', 'chain', 'inet', TABLE, 'input')
    counts = {}
    for item in json.loads(out.stdout or '{"nftables": []}')['nftables']:
        rule = item.get('rule')
        if not rule or 'comment' not in rule:
            continue
        for expr in rule['expr']:
            if 'counter' in expr:
                counts[rule['comment']] = expr['counter']['packets']
    return counts


def add_counter(ip):
    run('nft', 'add', 'rule', 'inet', TABLE, 'input',
        'iifname', 'tailscale0', 'ip', 'saddr', ip,
        'meta', 'l4proto', '{', 'udp', ',', 'tcp', '}', 'th', 'dport', '53',
        'counter', 'comment', f'"{ip}"')


def ping(ip):
    try:
        out = run('tailscale', 'ping', '--c', '1', '--timeout', '5s', '--until-direct=false', ip)
    except subprocess.TimeoutExpired:
        return {'ping': 'exec-timeout'}
    line = (out.stdout or out.stderr).strip().splitlines()[-1:] or ['']
    m = re.search(r'via (\S+) in ([\d.]+)ms', line[0])
    if m:
        return {'ping': m.group(1), 'ping_ms': float(m.group(2))}
    return {'ping': 'fail', 'ping_err': line[0][:120]}


def age_s(ts, now):
    if not ts or ts.startswith('0001'):
        return None
    t = datetime.datetime.fromisoformat(ts.replace('Z', '+00:00'))
    return round((now - t).total_seconds())


def prune():
    cutoff = (datetime.date.today() - datetime.timedelta(days=KEEP_DAYS)).isoformat()
    for f in glob.glob(f'{LOG_DIR}/*.jsonl'):
        if os.path.basename(f) < f'{cutoff}.jsonl':
            os.remove(f)


def main():
    os.makedirs(LOG_DIR, exist_ok=True)
    ensure_table()
    prev = {}
    tick = 0
    while True:
        started = time.monotonic()
        now = datetime.datetime.now(datetime.timezone.utc)
        status = json.loads(run('tailscale', 'status', '--json').stdout or '{}')
        peers = [p for p in (status.get('Peer') or {}).values() if p.get('OS') == 'iOS']
        counters = dns_counters()
        lines = []
        for p in peers:
            ip = p['TailscaleIPs'][0]
            if ip not in counters:
                add_counter(ip)
            cur = {'dns': counters.get(ip, 0), 'rx': p.get('RxBytes', 0), 'tx': p.get('TxBytes', 0)}
            last = prev.get(ip)
            rec = {
                't': now.isoformat(timespec='seconds'),
                'peer': p.get('DNSName', '').split('.')[0] or p.get('HostName'),
                'ip': ip,
                'online': p.get('Online'),
                'active': p.get('Active'),
                'cur': p.get('CurAddr') or None,
                'relay': p.get('Relay') or None,
                'hs_age': age_s(p.get('LastHandshake'), now),
                # Deltas since the previous tick; null on the first tick.
                'dns': cur['dns'] - last['dns'] if last else None,
                'rx': cur['rx'] - last['rx'] if last else None,
                'tx': cur['tx'] - last['tx'] if last else None,
            }
            if tick % PING_EVERY == 0 and p.get('Online'):
                rec.update(ping(ip))
            prev[ip] = cur
            lines.append(json.dumps(rec, separators=(',', ':')))
        if lines:
            with open(f'{LOG_DIR}/{now.astimezone().date().isoformat()}.jsonl', 'a') as f:
                f.write('\n'.join(lines) + '\n')
        if tick % 60 == 0:
            prune()
        tick += 1
        time.sleep(max(1, INTERVAL - (time.monotonic() - started)))


if __name__ == '__main__':
    main()
