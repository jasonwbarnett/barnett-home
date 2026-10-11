# gdisk/fdisk/dosfstools/e2fsprogs/rsync are what image-backup shells out to
# (it prompts to install gdisk if missing, which would hang an unattended run).
package %w(restic rsync gdisk fdisk dosfstools e2fsprogs curl)

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
    IMAGE_DIR='#{node['pi_backup']['image_dir']}'
    KEEP_DAILY=#{node['pi_backup']['keep']['daily']}
    KEEP_WEEKLY=#{node['pi_backup']['keep']['weekly']}
    KEEP_MONTHLY=#{node['pi_backup']['keep']['monthly']}
  CONF
end

# Credentials are a host-local secret, so Chef only reminds rather than
# creating them. The timer still runs and fails loudly until they exist.
log 'pi_backup: /etc/pi-backup/restic.env is missing — see cookbooks/pi_backup/README.md' do
  level :warn
  not_if { ::File.exist?('/etc/pi-backup/restic.env') }
end

systemd_unit 'pi-backup.service' do
  content <<~UNIT
    [Unit]
    Description=Bootable image backup to restic
    Wants=network-online.target
    After=network-online.target

    [Service]
    Type=oneshot
    ExecStart=/usr/local/sbin/pi-backup
    # systemd services have no $HOME, so restic would run without a cache
    # and re-download repo metadata every night.
    Environment=RESTIC_CACHE_DIR=/var/cache/restic
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
