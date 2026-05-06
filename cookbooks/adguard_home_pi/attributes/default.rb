default['adguard_home_pi']['packages'] = %w(curl vim htop git)

default['adguard_home_pi']['journald']['storage']          = 'volatile'
default['adguard_home_pi']['journald']['runtime_max_use']  = '50M'

default['adguard_home_pi']['log2ram']['version'] = 'master'
default['adguard_home_pi']['log2ram']['size']    = '128M'
