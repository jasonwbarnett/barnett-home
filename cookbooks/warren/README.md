# warren

Installs and manages the [warren](https://github.com/jasonwbarnett/warren) web
server on a Raspberry Pi. Builds the binary from source, creates a dedicated
unprivileged system user, and installs a hardened systemd unit.

## Background

warren is a small Go web server exposed to the internet via a Cloudflare tunnel
at [warren.barnett.network](https://warren.barnett.network). Because it faces
the public internet it runs as a dedicated `warren` system user with no shell,
no home directory, and no sudo access. The systemd unit applies a defence-in-
depth set of kernel-level restrictions so that even a full process compromise
has no path to the rest of the system.

## Platform

Tested on Raspberry Pi OS / Debian 13 (Trixie), ARM64. Requires systemd.

## Recipes

### `warren::default`

Includes the three sub-recipes in order: `user` → `install` → `service`.

---

### `warren::user`

Creates the `warren` group and `warren` system user:

- **`group 'warren'`** — system group, no members.
- **`user 'warren'`** — system user, gid `warren`, shell `/usr/sbin/nologin`,
  home `/nonexistent`, `create_home false`. Cannot be logged into and owns
  nothing outside of the binary itself.

---

### `warren::install`

Installs Go and git, clones the source repository, and builds the binary:

1. **`package %w[golang-go git]`** — ensures the Go toolchain and git are
   present. Idempotent via the apt package cache.

2. **`directory node['warren']['repo_path']`** — creates `/opt/warren` owned
   by root if absent.

3. **`git node['warren']['repo_path']`** — clones
   `https://github.com/jasonwbarnett/warren` on first converge; syncs
   (fast-forwards) on subsequent converges. Notifies
   `execute[build warren]` `:immediately` whenever the working tree changes,
   meaning the binary is only rebuilt when upstream code actually changes.

4. **`execute 'build warren'`** — runs `go build` targeting
   `node['warren']['binary_path']` (default `/usr/local/bin/warren`). Runs
   only when notified by the `git` resource. Sets `HOME`, `GOPATH`, and
   `GOCACHE` explicitly so the build works correctly when cinc runs as root
   with a non-standard environment. Notifies `service[warren]` `:restart`
   `:delayed` so the service picks up the new binary at the end of the
   converge.

5. **`file node['warren']['binary_path']`** — enforces `owner warren`,
   `group warren`, `mode 0500` on every converge. Mode `0500` (r-x------) means
   only the `warren` user can read or execute the binary; nothing else on the
   system can.

---

### `warren::service`

Writes the systemd unit and ensures the service is running:

1. **`systemd_unit 'warren.service'`** — writes
   `/etc/systemd/system/warren.service` from the attributes and runs
   `systemctl daemon-reload` automatically on change. The unit includes the
   following hardening directives:

   | Directive | Effect |
   |-----------|--------|
   | `NoNewPrivileges=yes` | Process can never gain additional privileges via setuid or capabilities |
   | `PrivateTmp=yes` | Isolated `/tmp` — cannot see other processes' temp files |
   | `PrivateDevices=yes` | No access to raw device nodes |
   | `ProtectSystem=strict` | Entire filesystem is read-only except `/tmp` and `/var` |
   | `ProtectHome=yes` | `/home`, `/root`, `/run/user` are invisible |
   | `ProtectKernelTunables=yes` | `/proc/sys` and similar are read-only |
   | `ProtectKernelModules=yes` | Cannot load or unload kernel modules |
   | `ProtectControlGroups=yes` | cgroup hierarchy is read-only |
   | `RestrictNamespaces=yes` | Cannot create new namespaces (blocks container-escape techniques) |
   | `RestrictRealtime=yes` | Cannot set real-time scheduling priorities |
   | `RestrictSUIDSGID=yes` | Cannot set SUID/SGID bits on files |
   | `LockPersonality=yes` | Cannot change the kernel execution domain |
   | `CapabilityBoundingSet=` | All Linux capabilities stripped |
   | `AmbientCapabilities=` | No ambient capabilities |
   | `SystemCallArchitectures=native` | Blocks foreign-arch syscalls |
   | `SystemCallFilter=@system-service` | Whitelist of syscalls a normal server needs |
   | `SystemCallFilter=~@privileged @resources` | Explicitly deny privileged and resource syscalls |

   Notifies `service[warren]` `:restart` `:delayed` if the unit file changes.

2. **`service 'warren'`** — enables the unit at boot and starts it if it is
   not already running. This resource is also the target of restart
   notifications from both `execute[build warren]` and `systemd_unit`.

## Attributes

| Attribute | Default | Description |
|-----------|---------|-------------|
| `['warren']['user']` | `'warren'` | System user to run the service |
| `['warren']['group']` | `'warren'` | System group for the service user |
| `['warren']['port']` | `8080` | Port the server listens on |
| `['warren']['binary_path']` | `'/usr/local/bin/warren'` | Installed binary location |
| `['warren']['repo_url']` | `'https://github.com/jasonwbarnett/warren'` | Source repository |
| `['warren']['repo_path']` | `'/opt/warren'` | Local clone location |
| `['warren']['branch']` | `'main'` | Branch or ref to track |

## Usage

Add `recipe[warren]` to the run list in the cinc-converge wrapper script:

```bash
exec /opt/cinc/bin/cinc-client \
  --local-mode \
  --config /etc/cinc/client.rb \
  --runlist 'recipe[warren]'
```

## Idempotency

- The `git` resource only triggers a rebuild when upstream changes are pulled.
- The `execute` resource never runs on its own — only when notified.
- The `file` resource enforces binary ownership and mode on every converge but
  makes no changes if they are already correct.
- The `systemd_unit` resource only writes and reloads if the unit content
  differs from what is on disk.
- The `service` resource is a no-op if the service is already enabled and
  running.
