# pi_backup

Nightly **bootable image** backup of a Raspberry Pi to an SMB share, using
RonR's [`image-backup`](https://forums.raspberrypi.com/viewtopic.php?t=332000).

Each night the Pi writes `<share>/<hostname>/<hostname>.img`, a raw disk
image of the running system. To restore, flash that file with Raspberry Pi
Imager (**Choose OS → Use custom**) onto any SD card or SSD and boot it. The
image is shrunk to the used space, and the root filesystem grows to fill the
new disk on first boot.

- The first run makes a full image. Later runs rsync only the changes into it,
  which takes a few minutes.
- If an incremental run fails (usually because the image ran out of headroom),
  the script builds a fresh image next to the old one and swaps it in only
  when the new one succeeds.
- Before imaging, hooks in `/etc/pi-backup/pre.d/` take consistent dumps to
  `/var/backups/pi-backup/`, so they end up inside the image:
  - `10-postgres`: `pg_dump` of every database, if Postgres is running.
  - `20-sqlite`: online-backup copies of the SQLite files listed in
    `/etc/pi-backup/sqlite-dbs`, one path per line.
- On success the script writes `LAST-SUCCESS`. While it runs, an
  `IN-PROGRESS` marker sits beside the image, and anything that copies the
  images offsite should skip that host until the marker is gone.

## Setup per host

1. Add `recipe[pi_backup]` to the run list in `/usr/local/sbin/cinc-converge.sh`
   and converge.
2. Put the SMB credentials in place. This is a host-local secret, so Chef
   doesn't manage it:

   ```bash
   sudo install -m 0600 /dev/stdin /etc/pi-backup/smb-credentials <<'EOF'
   username=pibackup
   password=<password>
   EOF
   ```

3. Run the first backup by hand and watch it:

   ```bash
   sudo systemctl start pi-backup.service && journalctl -fu pi-backup
   ```

The timer fires at 02:00 plus a fixed per-host random offset of up to 60
minutes. To check it: `systemctl list-timers pi-backup.timer`.
