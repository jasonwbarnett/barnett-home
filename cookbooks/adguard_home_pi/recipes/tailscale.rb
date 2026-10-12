# Tailscale's official install.sh handles distro detection, apt repo, and the
# signing key. Idempotent — once /usr/bin/tailscale exists we skip it; future
# version bumps come via apt.
execute 'install Tailscale' do
  command 'curl -fsSL https://tailscale.com/install.sh | sh'
  not_if { ::File.exist?('/usr/bin/tailscale') }
end

service 'tailscaled' do
  action [:enable, :start]
end

# Opt out of Tailscale's client log upload. Its on-disk log buffer
# (/var/lib/tailscale/tailscaled.log*.txt) was the Pi's biggest SD-card writer.
# Only safe while network flow logs are off for the tailnet: with them on,
# tailscaled refuses to start ("tailnet requires logging to be enabled").
ruby_block 'tailscaled --no-logs-no-support' do
  block do
    f = '/etc/default/tailscaled'
    ::File.write(f, ::File.read(f).sub(/^FLAGS=.*$/, 'FLAGS="--no-logs-no-support"'))
  end
  not_if { ::File.read('/etc/default/tailscaled').match?(/^FLAGS="--no-logs-no-support"$/) }
  notifies :restart, 'service[tailscaled]', :immediately
end
