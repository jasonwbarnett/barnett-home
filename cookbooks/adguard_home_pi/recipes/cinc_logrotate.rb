# cinc logs at :info every 30 minutes and nothing rotated it: by Oct 2026
# /var/log/cinc held ~125 MB, filling the 128M log2ram tmpfs and getting
# rewritten to the SD card on every log2ram sync.
#
# Rotate by rename rather than copytruncate: a copy needs as much free tmpfs
# as the log itself. Both writers reopen the file each run (cinc's logger per
# converge, cron's >> per invocation), so a rename is safe.
file '/etc/logrotate.d/cinc' do
  owner 'root'
  group 'root'
  mode  '0644'
  content <<~CONF
    /var/log/cinc/*.log {
      daily
      maxsize 5M
      rotate 7
      compress
      missingok
      notifempty
    }
  CONF
end
