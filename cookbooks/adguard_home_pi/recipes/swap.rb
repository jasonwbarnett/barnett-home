service 'dphys-swapfile' do
  action [:disable, :stop]
  only_if 'systemctl list-unit-files | grep -q ^dphys-swapfile'
end

# Debian 12+ / Raspberry Pi OS Bookworm+ may use zram-tools for swap
service 'zramswap' do
  action [:disable, :stop]
  only_if 'systemctl list-unit-files | grep -q ^zramswap'
end

# Comment out any fstab swap entries so they don't re-enable at boot
ruby_block 'disable swap in fstab' do
  block do
    lines = ::File.readlines('/etc/fstab')
    ::File.write('/etc/fstab', lines.map { |l|
      l !~ /^\s*#/ && l =~ /\bswap\b/ ? "# #{l.chomp}\n" : l
    }.join)
  end
  only_if { ::File.readlines('/etc/fstab').any? { |l| l !~ /^\s*#/ && l =~ /\bswap\b/ } }
end

execute 'swapoff -a' do
  only_if 'swapon --show=NAME --noheadings | grep -q .'
end
