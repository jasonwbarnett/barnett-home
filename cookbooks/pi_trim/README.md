# pi_trim

Enables TRIM on Raspberry Pis whose boot drive is connected through an
ASMedia 174c:55aa USB-to-SATA bridge (ASM1051E / ASM1053E / ASM1153 /
ASM1153E chip family). This bridge is common in generic and budget-branded
2.5" enclosures.

## Background

The bridge chip correctly implements the SCSI UNMAP command (the SCSI
equivalent of ATA TRIM), but Linux defaults to `provisioning_mode=full` for
it because the drive's VPD page 0xb2 reports "not known or fully provisioned"
rather than declaring thin provisioning. With `provisioning_mode=full`, the
kernel never sends UNMAP commands, so `fstrim` fails with:

```
fstrim: /: the discard operation is not supported
```

This cookbook drops a udev rule that forces `provisioning_mode=unmap`
whenever the bridge is detected, which unlocks TRIM without any change to the
kernel or bridge firmware. It also ensures `fstrim.timer` is enabled so the
OS trims unused blocks weekly.

### How to confirm your enclosure uses this bridge

```bash
lsusb | grep 174c
```

If you see `174c:55aa ASMedia Technology Inc.`, this cookbook applies.
`idVendor=174c` is ASMedia's USB Vendor ID; `idProduct=55aa` identifies this
chip family. Both values are identical across every unit manufactured with
this chip — they are not per-device.

## Platform

Tested on Raspberry Pi OS Bookworm (Debian 12). Should work on any Debian or
Ubuntu system running systemd and udev.

## Recipe

The default recipe applies three resources in order:

1. **`file '/etc/udev/rules.d/10-trim-asmt.rules'`** — writes the udev rule
   that sets `provisioning_mode=unmap` on `add` and `change` events for any
   scsi_disk device matching `174c:55aa`. Notifies the `execute` resource
   immediately if the file is created or changed.

2. **`execute 'reload-udev-rules'`** — runs
   `udevadm control --reload-rules && udevadm trigger --subsystem-match=scsi_disk`
   to apply the rule to already-connected devices without a reboot. Runs only
   when notified by the `file` resource (i.e. on first converge or if the rule
   file was modified).

3. **`service 'fstrim.timer'`** — enables and starts the systemd timer that
   runs `fstrim` weekly across all mounted filesystems. `fstrim.timer` is
   preset-enabled in Raspberry Pi OS, but this resource makes the cookbook the
   source of truth regardless of OS defaults.

## Usage

Add `recipe[pi_trim]` to the run list in the cinc-converge wrapper script
alongside any other recipes for that host:

```bash
exec /opt/cinc/bin/cinc-client \
  --local-mode \
  --config /etc/cinc/client.rb \
  --runlist 'recipe[adguard_home_pi],recipe[pi_trim]'
```

To verify TRIM is working after the first converge:

```bash
cat /sys/class/scsi_disk/0:0:0:0/provisioning_mode   # should print: unmap
sudo fstrim -v /                                       # should report bytes trimmed
```

## Idempotency

All three resources are safe to converge repeatedly. The `file` resource only
notifies udev reload if the file content changes. The `execute` resource never
runs on its own. The `service` resource is a no-op if the timer is already
enabled and running.
