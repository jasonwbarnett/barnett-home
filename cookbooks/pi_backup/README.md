# pi_backup

Nightly **bootable image** backup of a Raspberry Pi, sent offsite with
[restic](https://restic.net).

1. RonR's [`image-backup`](https://forums.raspberrypi.com/viewtopic.php?t=332000)
   keeps `/mnt/pi-backup/<hostname>.img` up to date. The first run makes a
   full image. Later runs rsync only the changes into it, which takes a few
   minutes. The image is shrunk to the used space plus some headroom.
2. `restic backup` uploads the image to the repository in
   `/etc/pi-backup/restic.env`. restic deduplicates, so each night only the
   changed blocks go up, and Pis with similar contents share storage. Old
   snapshots are pruned to 7 daily, 5 weekly and 6 monthly.
3. `restic check` reads back a different 1/30th of the repository each
   night.

Before imaging, hooks in `/etc/pi-backup/pre.d/` take consistent dumps to
`/var/backups/pi-backup/`, so they end up inside the image:

- `10-postgres`: `pg_dump` of every database, if Postgres is running.
- `20-sqlite`: online-backup copies of the SQLite files listed in
  `/etc/pi-backup/sqlite-dbs`, one path per line.

If an incremental run fails (usually because the image ran out of headroom),
the script builds a fresh image next to the old one and swaps it in only when
the new one succeeds.

## Restore

Pull the image down on any machine that has restic and the repository
credentials, then flash it with Raspberry Pi Imager (**Choose OS → Use
custom**, and answer **No** to OS customisation):

```bash
restic snapshots --host rpi-dns-03
restic restore latest --host rpi-dns-03 --target ./restore --sparse
```

The restored system boots on any SD card or SSD at least as large as the
image. On first boot the root filesystem grows to fill the disk.

## Setup per host

1. Add `recipe[pi_backup]` to the run list in `/usr/local/sbin/cinc-converge.sh`
   and converge.
2. Write the secrets. Chef doesn't manage them because they're host-local:

   ```bash
   sudo install -m 0600 /dev/stdin /etc/pi-backup/restic.env <<'EOF'
   RESTIC_REPOSITORY=s3:https://<account>.r2.cloudflarestorage.com/<bucket>
   RESTIC_PASSWORD=<repo password>
   AWS_ACCESS_KEY_ID=<key id>
   AWS_SECRET_ACCESS_KEY=<secret>
   AWS_DEFAULT_REGION=auto
   # optional dead man's switch, e.g. https://hc-ping.com/<uuid>
   HC_PING_URL=
   EOF
   ```

3. Run the first backup by hand and watch it:

   ```bash
   sudo systemctl start pi-backup.service && journalctl -fu pi-backup
   ```

The timer fires at 02:00 plus a fixed per-host random offset of up to 60
minutes. To check it: `systemctl list-timers pi-backup.timer`.

The local image takes about 1.25× the system's used space on its own disk.
