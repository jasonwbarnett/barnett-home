# cifs-utils mounts the share; gdisk/fdisk/dosfstools/e2fsprogs/rsync are
# what image-backup shells out to (it prompts to install gdisk if missing,
# which would hang an unattended run).
package %w(cifs-utils rsync gdisk fdisk dosfstools e2fsprogs)

remote_file '/usr/local/sbin/image-backup' do
  source   node['pi_backup']['image_backup']['url']
  checksum node['pi_backup']['image_backup']['checksum']
  owner 'root'
  group 'root'
  mode  '0755'
end

cookbook_file '/usr/local/sbin/pi-backup' do
  source 'pi-backup'
  owner 'root'
  group 'root'
  mode  '0755'
end

directory '/etc/pi-backup' do
  owner 'root'
  group 'root'
  mode  '0700'
end

directory '/etc/pi-backup/pre.d' do
  owner 'root'
  group 'root'
  mode  '0755'
end

%w(10-postgres 20-sqlite).each do |hook|
  cookbook_file "/etc/pi-backup/pre.d/#{hook}" do
    source "pre.d/#{hook}"
    owner 'root'
    group 'root'
    mode  '0755'
  end
end

file '/etc/pi-backup/pi-backup.conf' do
  owner 'root'
  group 'root'
  mode  '0644'
  content <<~CONF
    # Managed by Chef (pi_backup). Edit attributes, not this file.
    SHARE='#{node['pi_backup']['share']}'
    MOUNT_POINT='#{node['pi_backup']['mount_point']}'
  CONF
end

# Credentials are a host-local secret, so Chef only reminds rather than
# creating them. The timer still runs and fails loudly until they exist.
log 'pi_backup: /etc/pi-backup/smb-credentials is missing — see cookbooks/pi_backup/README.md' do
  level :warn
  not_if { ::File.exist?('/etc/pi-backup/smb-credentials') }
end

systemd_unit 'pi-backup.service' do
  content <<~UNIT
    [Unit]
    Description=Bootable image backup to #{node['pi_backup']['share']}
    Wants=network-online.target
    After=network-online.target

    [Service]
    Type=oneshot
    ExecStart=/usr/local/sbin/pi-backup
    Nice=10
    IOSchedulingClass=idle
  UNIT
  action :create
end

systemd_unit 'pi-backup.timer' do
  content <<~UNIT
    [Unit]
    Description=Nightly image backup

    [Timer]
    OnCalendar=#{node['pi_backup']['on_calendar']}
    RandomizedDelaySec=#{node['pi_backup']['randomized_delay']}
    FixedRandomDelay=true
    Persistent=true

    [Install]
    WantedBy=timers.target
  UNIT
  action [:create, :enable, :start]
end
