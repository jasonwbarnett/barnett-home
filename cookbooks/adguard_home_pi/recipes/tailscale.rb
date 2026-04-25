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
