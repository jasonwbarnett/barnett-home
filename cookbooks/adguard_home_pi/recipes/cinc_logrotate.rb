# cinc logs at :info every 30 minutes and nothing rotated it: by Oct 2026
# /var/log/cinc held ~125 MB, filling the 128M log2ram tmpfs and getting
# rewritten to the SD card on every log2ram sync.
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
      copytruncate
    }
  CONF
  notifies :run, 'execute[logrotate cinc]', :delayed
end

execute 'logrotate cinc' do
  command 'logrotate -f /etc/logrotate.d/cinc'
  action :nothing
end
