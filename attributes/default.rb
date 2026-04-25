default['barnett_home']['packages'] = %w(curl vim htop git)

default['barnett_home']['journald']['storage']          = 'volatile'
default['barnett_home']['journald']['runtime_max_use']  = '50M'

default['barnett_home']['log2ram']['version']   = 'master'
default['barnett_home']['log2ram']['size']      = '128M'
default['barnett_home']['log2ram']['use_rsync'] = true
default['barnett_home']['log2ram']['mail']      = false
