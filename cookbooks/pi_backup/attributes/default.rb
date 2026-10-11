# SMB share the image is written to. Credentials are NOT managed here — put
# them in /etc/pi-backup/smb-credentials on the host (see README).
default['pi_backup']['share']       = '//10.0.15.130/PiBackups'
default['pi_backup']['mount_point'] = '/mnt/pi-backup'

# Nightly window. FixedRandomDelay gives each host a stable offset inside the
# window so the Pis don't all hit the share at once.
default['pi_backup']['on_calendar']      = '*-*-* 02:00:00'
default['pi_backup']['randomized_delay'] = '60min'

# RonR image-backup, pinned. Mirror of the forum attachment (file id 74592,
# first post last edited 2025-10-04) because the forum blocks scripted
# downloads.
default['pi_backup']['image_backup']['url']      = 'https://raw.githubusercontent.com/seamusdemora/RonR-RPi-image-utils/0ee5757f43eca29c581ccb6d7ee8818e6ed2cb98/image-backup'
default['pi_backup']['image_backup']['checksum'] = '636728a813b9ee1621adf2b59ce1b831a0be5deb5cbc814366c8746da63e9699'
