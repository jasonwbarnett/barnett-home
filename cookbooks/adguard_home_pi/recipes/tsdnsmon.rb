# tsdnsmon: per-minute record of each iOS tailnet peer's tunnel state and DNS
# packets to this Pi, to catch phones that stop resolving after a cellular /
# satellite handoff until Tailscale is toggled. See files/default/tsdnsmon.py.
cookbook_file '/usr/local/sbin/tsdnsmon' do
  source 'tsdnsmon.py'
  owner 'root'
  group 'root'
  mode  '0755'
  notifies :restart, 'service[tsdnsmon]', :delayed
end

systemd_unit 'tsdnsmon.service' do
  content <<~UNIT
    [Unit]
    Description=Record iOS tailnet peers' tunnel state and DNS packets
    After=tailscaled.service nftables.service
    Wants=tailscaled.service

    [Service]
    ExecStart=/usr/bin/python3 /usr/local/sbin/tsdnsmon
    Restart=always
    RestartSec=30
    Nice=10

    [Install]
    WantedBy=multi-user.target
  UNIT
  action [:create, :enable]
  notifies :restart, 'service[tsdnsmon]', :delayed
end

service 'tsdnsmon' do
  action :start
end
