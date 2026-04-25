# Upstream install.sh handles arch detection (armv6/armv7/arm64), unpacks to
# /opt/AdGuardHome, and registers AdGuardHome.service. AdGuard Home's built-in
# updater takes over for version bumps after this initial install.
execute 'install AdGuard Home' do
  command 'curl -fsSL https://raw.githubusercontent.com/AdguardTeam/AdGuardHome/master/scripts/install.sh | sh -s -- -v'
  not_if { ::File.exist?('/opt/AdGuardHome/AdGuardHome') }
end

service 'AdGuardHome' do
  action [:enable, :start]
end
