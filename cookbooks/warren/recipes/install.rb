package %w[golang-go git]

directory node['warren']['repo_path'] do
  owner 'root'
  group 'root'
  mode  '0755'
end

git node['warren']['repo_path'] do
  repository node['warren']['repo_url']
  branch     node['warren']['branch']
  action     :sync
  notifies   :run, 'execute[build warren]', :immediately
end

execute 'build warren' do
  command     "go build -o #{node['warren']['binary_path']} ."
  cwd         node['warren']['repo_path']
  environment(
    'HOME'    => '/root',
    'GOPATH'  => '/root/go',
    'GOCACHE' => '/root/.cache/go-build',
    'PATH'    => '/usr/local/go/bin:/usr/bin:/bin'
  )
  action   :nothing
  notifies :restart, 'service[warren]', :delayed
end

file node['warren']['binary_path'] do
  owner node['warren']['user']
  group node['warren']['group']
  mode  '0500'
end
