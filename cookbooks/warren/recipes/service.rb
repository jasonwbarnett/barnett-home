systemd_unit 'warren.service' do
  content <<~UNIT
    [Unit]
    Description=warren web server
    After=network.target

    [Service]
    ExecStart=#{node['warren']['binary_path']}
    Restart=always
    User=#{node['warren']['user']}
    Group=#{node['warren']['group']}
    Environment=PORT=#{node['warren']['port']}

    # Hardening
    NoNewPrivileges=yes
    PrivateTmp=yes
    PrivateDevices=yes
    ProtectSystem=strict
    ProtectHome=yes
    ProtectKernelTunables=yes
    ProtectKernelModules=yes
    ProtectControlGroups=yes
    RestrictNamespaces=yes
    RestrictRealtime=yes
    RestrictSUIDSGID=yes
    LockPersonality=yes
    CapabilityBoundingSet=
    AmbientCapabilities=
    SystemCallArchitectures=native
    SystemCallFilter=@system-service
    SystemCallFilter=~@privileged @resources

    [Install]
    WantedBy=multi-user.target
  UNIT
  action [:create, :enable]
  notifies :restart, 'service[warren]', :delayed
end

service 'warren' do
  action [:enable, :start]
end
