# barnett-home

Chef cookbooks for home-network hosts. Currently contains `adguard_home_pi/`,
which prepares a Raspberry Pi OS Lite host to run AdGuard Home.

## How it works

Each Pi clones this repo and runs [cinc-client](https://cinc.sh) — the
open-source rebuild of Chef Infra Client — every 30 minutes from cron in local
mode (`chef-zero`). The wrapper script `git pull`s first, then converges the
host against the cookbook in this repo.

To roll out a change: push to the default branch. Every Pi picks it up within
30 minutes. No central Chef Server, no `knife`, no nodes to register.

## One-time setup per Pi

Assumes Raspberry Pi OS Lite (Bookworm or newer) and that you've added a
**deploy key** for this repo to `/root/.ssh/` so unattended `git fetch` works
from cron.

### 1. Install cinc-client

The Cinc omnitruck installer detects the Pi's architecture (`armhf` /
`aarch64`) and pulls the matching build:

```bash
curl -L https://omnitruck.cinc.sh | sudo bash -s -- -P cinc -c stable
/opt/cinc/bin/cinc-client --version   # sanity check
```

### 2. Clone this repo

```bash
sudo git clone git@github.com:<owner>/barnett-home.git /opt/barnett-home
```

The path `/opt/barnett-home` is what the wrapper below assumes — change both
together if you use a different location.

### 3. Drop in `client.rb`

```bash
sudo install -d -m 0755 /etc/cinc /var/log/cinc
sudo tee /etc/cinc/client.rb >/dev/null <<'EOF'
cookbook_path '/opt/barnett-home'
local_mode    true
log_level     :info
log_location  '/var/log/cinc/client.log'
EOF
```

`cookbook_path` is the **parent** directory of the cookbook, not the cookbook
itself — cinc finds `adguard_home_pi/` underneath it by name.

### 4. Drop in the converge wrapper

```bash
sudo tee /usr/local/sbin/cinc-converge.sh >/dev/null <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

REPO_DIR=/opt/barnett-home
cd "$REPO_DIR"

# Always match origin's tip — discard any local edits on the Pi so a stray
# change can't block updates.
branch=$(git symbolic-ref --short HEAD)
git fetch --quiet origin
git reset --hard --quiet "origin/$branch"

exec /opt/cinc/bin/cinc-client \
  --local-mode \
  --config /etc/cinc/client.rb \
  --runlist 'recipe[adguard_home_pi]'
EOF
sudo chmod 0755 /usr/local/sbin/cinc-converge.sh
```

### 5. Install the cron job

```bash
sudo tee /etc/cron.d/cinc-converge >/dev/null <<'EOF'
# Converge every 30 minutes. flock prevents overlap if a run runs long.
SHELL=/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
*/30 * * * * root flock -n /var/lock/cinc-converge.lock /usr/local/sbin/cinc-converge.sh >>/var/log/cinc/cron.log 2>&1
EOF
```

### 6. First run

Run once by hand to bootstrap, then reboot so log2ram's tmpfs mount of
`/var/log` takes effect:

```bash
sudo /usr/local/sbin/cinc-converge.sh
sudo reboot
```

After the reboot, cron takes over.

## Updating

```bash
git push origin main
```

Every Pi converges within 30 minutes. To force an immediate run on a host:

```bash
sudo /usr/local/sbin/cinc-converge.sh
```

To dry-run (cinc reports what it would change without doing it):

```bash
sudo /opt/cinc/bin/cinc-client --local-mode --config /etc/cinc/client.rb \
  --runlist 'recipe[adguard_home_pi]' --why-run
```

## Logs

- Cron stdout/stderr: `/var/log/cinc/cron.log`
- cinc-client run log: `/var/log/cinc/client.log`

`/var/log` lives on tmpfs once log2ram is active, so these reset on reboot.
log2ram syncs to the SD card hourly by default; for anything you need to keep
long-term, ship it off the host.
