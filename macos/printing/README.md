# macOS: "Error while printing" fix (cupsd local-socket buffer)

Fix for Macs that can't print to the home printer (Brother HL-L2350DW,
AirPrint) even though the printer is on and reachable. Found and fixed on the
Mac mini on 2026-10-17 (macOS 26.5, build 25F71). Use this to apply the same
fix to another Mac.

## Symptom

Printing from Preview (or any app):

1. **Print** → the print queue says **"Preparing…"** for about a minute
2. → **"Error while printing"**

Nothing reaches the printer. In Console you'll see
`PJCBeginDocument: -30870` from the app. `lp` in Terminal may fail with
`lp: No such file or directory`.

iPhones print fine: they send jobs straight to the printer and never use the
Mac's print service.

## Cause

Before printing, macOS asks its print service (`cupsd`) for the printer's
attributes over the local socket `/private/var/run/cupsd`. For this printer
the reply is about 11.8 KB, mostly the list of paper sizes.

macOS's local sockets default to an **8 KB** buffer
(`net.local.stream.sendspace=8192`). If the app doesn't start reading the
instant cupsd replies, cupsd delivers exactly one buffer (8,186 bytes) and the
rest never arrives. The app waits until it times out. It's a race, so it
occasionally works, which makes it look random.

Over TCP (`localhost:631`) the buffers are larger, so the same request always
works. That's why `lp -h localhost …` prints and Preview doesn't.

Raising the buffer only on the client side doesn't help. The limit is on
cupsd's side of the connection, which inherits its buffer size from the socket
launchd creates **at boot**. So the fix has to be set before boot.

## Fix

Raise the local-socket buffers to 64 KB in `/etc/sysctl.conf`, which launchd
applies at boot, then reboot.

```bash
git clone https://github.com/jasonwbarnett/barnett-home.git
cd barnett-home/macos/printing

./check-cups-socket.sh        # 1. confirm this Mac is affected (BROKEN)
sudo ./fix-cups-socket.sh     # 2. write the two settings (keeps anything else in the file)
sudo reboot                   # 3. required, see "Cause"
./check-cups-socket.sh        # 4. should now say OK for every queue
```

Then print something from Preview.

What the fix writes to `/etc/sysctl.conf`:

```
net.local.stream.sendspace=65536
net.local.stream.recvspace=65536
```

Run `sudo` in a real Terminal window: it can't prompt for a password from
inside a Claude Code `!` command.

### Before you start

- The printer has to be added on that Mac (System Settings → Printers &
  Scanners → Add, choose "Brother HL-L2350DW", AirPrint). The check script
  tests every queue in `lpstat -p`.
- If the check already says **OK**, that Mac isn't affected and needs no
  change. A printing failure there has some other cause.

## Verify / undo

- `./check-cups-socket.sh` prints the current buffer values, the contents of
  `/etc/sysctl.conf`, and OK/BROKEN for each queue. Exit code 0 = all OK.
- After the reboot, `sysctl net.local.stream.sendspace` should show `65536`.
  If it still says `8192`, macOS didn't apply `/etc/sysctl.conf`.
- Undo: `sudo ./fix-cups-socket.sh --undo` and reboot. Earlier versions of
  the file are kept as `/etc/sysctl.conf.bak-<timestamp>`.

## Side effects

Each local (Unix-domain) socket on the Mac may now buffer up to 64 KB
instead of 8 KB. That's a few MB of RAM in total at most, and is closer to
other OSes' defaults. No other effects seen on the Mac mini.

After a macOS update, run the check again. If Apple fixes the bug, the
setting is harmless to leave in place.

## Related

- The Brother **Firmware Update Tool** on a Mac reports "Cannot find a
  machine to update" because it discovers printers by SNMP broadcast, which
  doesn't cross from the main network to the IoT network where the printer
  lives. Use Brother iPrint&Scan on an iPhone joined to the printer's Wi-Fi
  instead, or temporarily put the Mac on that Wi-Fi with Ethernet unplugged.
