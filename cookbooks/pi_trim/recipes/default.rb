# The ASMedia 174c:55aa bridge supports SCSI UNMAP (TRIM) but Linux defaults to
# provisioning_mode=full because the drive's VPD page 0xb2 doesn't declare thin
# provisioning. This udev rule forces provisioning_mode=unmap on every boot.
file '/etc/udev/rules.d/10-trim-asmt.rules' do
  content <<~UDEV
    ACTION=="add|change", ATTRS{idVendor}=="174c", ATTRS{idProduct}=="55aa", SUBSYSTEM=="scsi_disk", ATTR{provisioning_mode}="unmap"
  UDEV
  owner 'root'
  group 'root'
  mode '0644'
  notifies :run, 'execute[reload-udev-rules]', :immediately
end

execute 'reload-udev-rules' do
  command 'udevadm control --reload-rules && udevadm trigger --subsystem-match=scsi_disk'
  action :nothing
end

# fstrim.timer is preset-enabled in Raspberry Pi OS, but we declare it explicitly
# so this cookbook is the source of truth regardless of OS defaults.
service 'fstrim.timer' do
  action [:enable, :start]
end
