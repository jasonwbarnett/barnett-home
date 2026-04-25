directory '/etc/systemd/journald.conf.d' do
  owner 'root'
  group 'root'
  mode  '0755'
  recursive true
end

file '/etc/systemd/journald.conf.d/volatile.conf' do
  owner 'root'
  group 'root'
  mode  '0644'
  content <<~CONF
    [Journal]
    Storage=#{node['adguard_home_pi']['journald']['storage']}
    RuntimeMaxUse=#{node['adguard_home_pi']['journald']['runtime_max_use']}
  CONF
  notifies :restart, 'service[systemd-journald]', :immediately
end

service 'systemd-journald' do
  action :nothing
end
