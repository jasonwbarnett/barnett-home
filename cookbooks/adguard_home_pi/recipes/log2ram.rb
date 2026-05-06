version  = node['adguard_home_pi']['log2ram']['version']
tarball  = "#{Chef::Config[:file_cache_path]}/log2ram-#{version}.tar.gz"
src_dir  = "#{Chef::Config[:file_cache_path]}/log2ram-#{version}"

remote_file tarball do
  source "https://github.com/azlux/log2ram/archive/#{version}.tar.gz"
  owner 'root'
  group 'root'
  mode  '0644'
  not_if { ::File.exist?('/usr/local/bin/log2ram') }
end

execute 'extract log2ram' do
  command "tar zxf #{tarball} -C #{Chef::Config[:file_cache_path]}"
  not_if { ::File.exist?('/usr/local/bin/log2ram') }
end

execute 'install log2ram' do
  command './install.sh'
  cwd src_dir
  environment 'TERM' => 'dumb'
  not_if { ::File.exist?('/usr/local/bin/log2ram') }
end

desired_log2ram = {
  'SIZE' => node['adguard_home_pi']['log2ram']['size'],
}

ruby_block 'configure /etc/log2ram.conf' do
  block do
    require 'chef/util/file_edit'
    fe = Chef::Util::FileEdit.new('/etc/log2ram.conf')
    desired_log2ram.each do |k, v|
      fe.search_file_replace_line(/^#{k}=.*/, "#{k}=#{v}")
      fe.insert_line_if_no_match(/^#{k}=/, "#{k}=#{v}")
    end
    fe.write_file
  end
  notifies :restart, 'service[log2ram]', :delayed
  only_if do
    ::File.exist?('/etc/log2ram.conf') &&
      desired_log2ram.any? do |k, v|
        ::File.readlines('/etc/log2ram.conf', chomp: true).none? { |line| line == "#{k}=#{v}" }
      end
  end
end

service 'log2ram' do
  action [:enable, :start]
end

# log2ram's tmpfs mount of /var/log only takes effect after a reboot. Once a
# reboot has happened the service alone is enough; restarts on config changes
# above are handled via the :delayed notify.
log 'log2ram-reboot-reminder' do
  message 'log2ram installed — reboot the host so /var/log is mounted on tmpfs.'
  level :warn
  only_if { !::File.exist?('/var/hdd.log') }
end
