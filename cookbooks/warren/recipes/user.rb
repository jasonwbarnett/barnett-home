group node['warren']['group'] do
  system true
end

user node['warren']['user'] do
  comment     'warren web server'
  system      true
  gid         node['warren']['group']
  shell       '/usr/sbin/nologin'
  home        '/nonexistent'
  create_home false
end
