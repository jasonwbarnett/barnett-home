service 'dphys-swapfile' do
  action [:disable, :stop]
  only_if 'systemctl list-unit-files | grep -q ^dphys-swapfile'
end

execute 'swapoff -a' do
  only_if 'swapon --show=NAME --noheadings | grep -q .'
end
