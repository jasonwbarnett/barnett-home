apt_update 'update apt cache' do
  action :periodic
end

package node['barnett_home']['packages'] + %w(unattended-upgrades)

# `dpkg-reconfigure unattended-upgrades` non-interactively just writes this
# file to enable the daily timers. Managing the file directly is idempotent
# and avoids needing debconf preseeding.
file '/etc/apt/apt.conf.d/20auto-upgrades' do
  owner 'root'
  group 'root'
  mode  '0644'
  content <<~CONF
    APT::Periodic::Update-Package-Lists "1";
    APT::Periodic::Unattended-Upgrade "1";
  CONF
end
